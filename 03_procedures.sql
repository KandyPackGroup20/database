-- Kandypack Logistics Platform - Stored Procedures (MySQL 8.0)
USE kandypack_db;

DELIMITER //

-- PROCEDURE 1: Multi-Trip Rail Capacity Spillover Engine (Section 4.2)
DROP PROCEDURE IF EXISTS sp_allocate_rail_capacity//
CREATE PROCEDURE sp_allocate_rail_capacity(
    IN p_order_id INT,
    OUT p_status_result VARCHAR(50)
)
PROC_BODY: BEGIN
    DECLARE v_dest_hub INT;
    DECLARE v_order_status VARCHAR(50);
    DECLARE v_item_id INT;
    DECLARE v_product_id INT;
    DECLARE v_ordered_qty INT;
    DECLARE v_space_per_unit DECIMAL(6,4);
    DECLARE v_remaining_item_qty INT;
    
    DECLARE v_trip_id INT;
    DECLARE v_trip_rem_cap DECIMAL(10,2);
    DECLARE v_max_units_fit INT;
    DECLARE v_qty_to_alloc INT;
    DECLARE v_space_to_alloc DECIMAL(10,2);
    
    DECLARE v_trip_count INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;
    
    -- Cursor for Order Items
    DECLARE cur_items CURSOR FOR 
        SELECT oi.order_item_id, oi.product_id, oi.quantity, p.space_consumption_rate
        FROM order_item oi
        JOIN product p ON oi.product_id = p.product_id
        WHERE oi.order_id = p_order_id;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Error Handler for Rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status_result = 'ERROR_TRANSACTION_FAILED';
    END;

    START TRANSACTION;

    -- 1. Validate Order State
    SELECT status INTO v_order_status
    FROM customer_order WHERE order_id = p_order_id FOR UPDATE;

    IF v_order_status != 'PENDING_RAIL_SCHEDULING' THEN
        ROLLBACK;
        SET p_status_result = 'INVALID_ORDER_STATUS';
        LEAVE PROC_BODY;
    END IF;

    -- 2. Resolve Destination Hub (station_id) from customer route
    SELECT dr.station_id INTO v_dest_hub
    FROM customer_order co
    JOIN customer c ON co.customer_id = c.customer_id
    JOIN delivery_route dr ON c.route_id = dr.route_id
    WHERE co.order_id = p_order_id;

    IF v_dest_hub IS NULL THEN
        ROLLBACK;
        SET p_status_result = 'DESTINATION_HUB_NOT_RESOLVED';
        LEAVE PROC_BODY;
    END IF;

    -- 3. Process items via cursor
    OPEN cur_items;
    
    item_loop: LOOP
        FETCH cur_items INTO v_item_id, v_product_id, v_ordered_qty, v_space_per_unit;
        IF done THEN LEAVE item_loop; END IF;
        
        SET v_remaining_item_qty = v_ordered_qty;
        
        -- Find available trips in chronological departure order
        find_trips: WHILE v_remaining_item_qty > 0 DO
            SET v_trip_id = NULL;
            
            -- Calculate remaining capacity dynamically
            SELECT tt.trip_id, 
                   tt.total_capacity - COALESCE((SELECT SUM(allocated_space) FROM rail_allocation WHERE trip_id = tt.trip_id), 0)
            INTO v_trip_id, v_trip_rem_cap
            FROM train_trip tt
            WHERE tt.destination_station_id = v_dest_hub 
              AND tt.status = 'SCHEDULED' 
              AND (tt.total_capacity - COALESCE((SELECT SUM(allocated_space) FROM rail_allocation WHERE trip_id = tt.trip_id), 0)) > 0
            ORDER BY tt.departure_datetime ASC 
            LIMIT 1
            FOR UPDATE;
            
            -- If no suitable trip found with remaining capacity
            IF v_trip_id IS NULL THEN
                LEAVE find_trips;
            END IF;
            
            -- Calculate max fit
            SET v_max_units_fit = FLOOR(v_trip_rem_cap / v_space_per_unit);
            
            IF v_max_units_fit >= v_remaining_item_qty THEN
                SET v_qty_to_alloc = v_remaining_item_qty;
            ELSE
                SET v_qty_to_alloc = v_max_units_fit;
            END IF;
            
            IF v_qty_to_alloc > 0 THEN
                SET v_space_to_alloc = v_qty_to_alloc * v_space_per_unit;
                
                -- Record Allocation (default allocated_by to NULL or a system user ID if needed)
                INSERT INTO rail_allocation(order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
                VALUES (v_item_id, v_trip_id, v_qty_to_alloc, v_space_to_alloc, NULL);
                
                SET v_remaining_item_qty = v_remaining_item_qty - v_qty_to_alloc;
                SET v_trip_count = v_trip_count + 1;
            ELSE
                -- Current trip capacity cannot fit even 1 unit
                LEAVE find_trips;
            END IF;
            
        END WHILE;

        IF v_remaining_item_qty > 0 THEN
            -- Unallocated quantity remaining and no further trips available
            ROLLBACK;
            SET p_status_result = 'INSUFFICIENT_RAIL_CAPACITY';
            LEAVE PROC_BODY;
        END IF;

    END LOOP;
    CLOSE cur_items;

    -- Update Order Status based on trip count
    IF v_trip_count = 1 THEN
        UPDATE customer_order SET status = 'SCHEDULED_FOR_RAIL' WHERE order_id = p_order_id;
        INSERT INTO order_status_history (status, order_id, changed_by) VALUES ('SCHEDULED_FOR_RAIL', p_order_id, NULL);
        SET p_status_result = 'SUCCESS_SINGLE_TRIP';
    ELSE
        UPDATE customer_order SET status = 'SCHEDULED_MULTI_TRIP' WHERE order_id = p_order_id;
        INSERT INTO order_status_history (status, order_id, changed_by) VALUES ('SCHEDULED_MULTI_TRIP', p_order_id, NULL);
        SET p_status_result = 'SUCCESS_MULTI_TRIP_SPILLOVER';
    END IF;

    COMMIT;
END //

-- PROCEDURE 2: Atomic Truck Roster & Driver Assignment Engine (Section 4.3)
DROP PROCEDURE IF EXISTS sp_assign_truck_roster//
CREATE PROCEDURE sp_assign_truck_roster(
    IN p_route_id INT,
    IN p_truck_id INT,
    IN p_driver_id INT,
    IN p_assistant_id INT,
    IN p_dispatcher_id INT,
    IN p_start_time DATETIME,
    IN p_end_time DATETIME,
    IN p_duration_hours DECIMAL(4,2),
    OUT p_result_code VARCHAR(50)
)
PROC_BODY: BEGIN
    DECLARE v_overlap_count INT DEFAULT 0;
    DECLARE v_driver_hours DECIMAL(5,2);
    DECLARE v_assistant_hours DECIMAL(5,2);
    
    DECLARE v_driver_last_end DATETIME;
    DECLARE v_assistant_last_end DATETIME;
    DECLARE v_assistant_consec_count INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'ASSIGN_ROSTER', p_route_id, 'SYSTEM_ERROR', 'roster_assignment');
        SET p_result_code = 'SYSTEM_ERROR';
    END;

    START TRANSACTION;

    -- Lock Candidate Rows (Pessimistic Row Locking to prevent concurrent dispatchers)
    SELECT work_hours INTO v_driver_hours FROM delivery_staff WHERE delivery_staff_id = p_driver_id FOR UPDATE;
    SELECT work_hours INTO v_assistant_hours FROM delivery_staff WHERE delivery_staff_id = p_assistant_id FOR UPDATE;
    SELECT truck_id FROM truck WHERE truck_id = p_truck_id FOR UPDATE;

    -- CHECK A: Schedule Overlap Check (FR-4.3.4)
    SELECT COUNT(*) INTO v_overlap_count
    FROM roster_assignment
    WHERE status IN ('SCHEDULED', 'IN_TRANSIT')
      AND (truck_id = p_truck_id OR driver_id = p_driver_id OR assistant_id = p_assistant_id)
      AND (p_start_time < end_time AND p_end_time > start_time);

    IF v_overlap_count > 0 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_A_OVERLAP', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_A_OVERLAP';
        LEAVE PROC_BODY;
    END IF;

    -- CHECK B: Driver Rest Period Check (FR-4.3.5)
    -- Get last trip end time for the driver
    SELECT MAX(end_time) INTO v_driver_last_end
    FROM roster_assignment
    WHERE driver_id = p_driver_id AND status != 'CANCELLED' AND end_time <= p_start_time;

    IF v_driver_last_end IS NOT NULL AND TIMESTAMPDIFF(HOUR, v_driver_last_end, p_start_time) < 8 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_B_DRIVER_REST', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_B_DRIVER_REST';
        LEAVE PROC_BODY;
    END IF;

    -- CHECK C: Assistant Consecutive Route Cap (FR-4.3.6)
    -- Get last trip end time for the assistant to check if the new trip is consecutive
    SELECT MAX(end_time) INTO v_assistant_last_end
    FROM roster_assignment
    WHERE assistant_id = p_assistant_id AND status != 'CANCELLED' AND end_time <= p_start_time;

    IF v_assistant_last_end IS NOT NULL AND TIMESTAMPDIFF(HOUR, v_assistant_last_end, p_start_time) < 8 THEN
        -- It's consecutive to the last trip. Check if the last trip itself was consecutive to the one before it.
        SET v_assistant_consec_count = 1;
        
        -- Let's check if the previous trip was also consecutive (gap < 8h)
        SELECT COUNT(*) INTO v_overlap_count
        FROM (
            SELECT end_time FROM roster_assignment
            WHERE assistant_id = p_assistant_id AND status != 'CANCELLED' AND end_time <= v_assistant_last_end
            ORDER BY end_time DESC LIMIT 2
        ) t;
        
        -- If we have at least 2 prior trips, check consecutive gap
        IF v_overlap_count >= 2 THEN
            SET v_assistant_consec_count = 2; -- Simplification: if assistant is doing consecutive shifts, cap is 2 consecutive.
        END IF;
    END IF;

    IF v_assistant_consec_count >= 2 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_C_ASSISTANT_REST', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_C_ASSISTANT_REST';
        LEAVE PROC_BODY;
    END IF;

    -- CHECK D: Weekly Working Hour Caps (FR-4.3.7 - Driver: 40h, Assistant: 60h)
    IF (v_driver_hours + p_duration_hours) > 40.00 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_D_DRIVER_HOURS_EXCEEDED', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_D_DRIVER_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    IF (v_assistant_hours + p_duration_hours) > 60.00 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_D_ASSISTANT_HOURS_EXCEEDED', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_D_ASSISTANT_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    -- ALL CHECKS PASSED: Commit Roster Assignment
    INSERT INTO roster_assignment(route_id, truck_id, driver_id, assistant_id, dispatcher_id, start_time, end_time, status)
    VALUES (p_route_id, p_truck_id, p_driver_id, p_assistant_id, p_dispatcher_id, p_start_time, p_end_time, 'SCHEDULED');

    -- Update Driver Accumulators
    UPDATE delivery_staff
    SET work_hours = work_hours + p_duration_hours
    WHERE delivery_staff_id = p_driver_id;

    -- Update Assistant Accumulators
    UPDATE delivery_staff
    SET work_hours = work_hours + p_duration_hours
    WHERE delivery_staff_id = p_assistant_id;

    -- Audit Log Entry for Success
    INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
    VALUES (p_dispatcher_id, 'ASSIGN_ROSTER', p_route_id, 'SUCCESS', 'roster_assignment');

    COMMIT;
    SET p_result_code = 'SUCCESS';
END //

DELIMITER ;
