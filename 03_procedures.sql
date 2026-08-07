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
    DECLARE v_dest_hub VARCHAR(10);
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
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
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
    SELECT destination_hub, status INTO v_dest_hub, v_order_status
    FROM orders WHERE order_id = p_order_id FOR UPDATE;

    IF v_order_status != 'PENDING_RAIL_SCHEDULING' THEN
        ROLLBACK;
        SET p_status_result = 'INVALID_ORDER_STATUS';
        LEAVE PROC_BODY;
    END IF;

    -- 2. Process items via cursor
    OPEN cur_items;
    
    item_loop: LOOP
        FETCH cur_items INTO v_item_id, v_product_id, v_ordered_qty, v_space_per_unit;
        IF done THEN LEAVE item_loop; END IF;
        
        SET v_remaining_item_qty = v_ordered_qty;
        
        -- Find available trips in chronological departure order
        find_trips: WHILE v_remaining_item_qty > 0 DO
            SET v_trip_id = NULL;
            
            SELECT trip_id, remaining_capacity_cubic_m 
            INTO v_trip_id, v_trip_rem_cap
            FROM train_trips
            WHERE destination_hub = v_dest_hub 
              AND status = 'SCHEDULED' 
              AND remaining_capacity_cubic_m > 0
            ORDER BY departure_time ASC 
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
                
                -- Record Allocation
                INSERT INTO order_trip_allocations(order_id, order_item_id, trip_id, allocated_quantity, allocated_space)
                VALUES (p_order_id, v_item_id, v_trip_id, v_qty_to_alloc, v_space_to_alloc);
                
                -- Deduct trip remaining capacity
                UPDATE train_trips 
                SET remaining_capacity_cubic_m = remaining_capacity_cubic_m - v_space_to_alloc
                WHERE trip_id = v_trip_id;
                
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
        UPDATE orders SET status = 'SCHEDULED_FOR_RAIL' WHERE order_id = p_order_id;
        SET p_status_result = 'SUCCESS_SINGLE_TRIP';
    ELSE
        UPDATE orders SET status = 'SCHEDULED_MULTI_TRIP' WHERE order_id = p_order_id;
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
    DECLARE v_driver_consec INT;
    DECLARE v_assistant_consec INT;
    DECLARE v_driver_last_end DATETIME;
    DECLARE v_assistant_last_end DATETIME;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
        VALUES (p_dispatcher_id, 'REJECTED', 'SYSTEM_ERROR', 'SQL exception occurred during transaction');
        SET p_result_code = 'SYSTEM_ERROR';
    END;

    START TRANSACTION;

    -- Lock Candidate Rows (Pessimistic Row Locking to prevent concurrent dispatchers)
    SELECT accumulated_weekly_hours, consecutive_routes_count, last_trip_end_time 
    INTO v_driver_hours, v_driver_consec, v_driver_last_end
    FROM drivers WHERE driver_id = p_driver_id FOR UPDATE;

    SELECT accumulated_weekly_hours, consecutive_routes_count, last_trip_end_time 
    INTO v_assistant_hours, v_assistant_consec, v_assistant_last_end
    FROM assistants WHERE assistant_id = p_assistant_id FOR UPDATE;

    SELECT truck_id FROM trucks WHERE truck_id = p_truck_id FOR UPDATE;

    -- CHECK A: Schedule Overlap Check (FR-4.3.4)
    SELECT COUNT(*) INTO v_overlap_count
    FROM roster_assignments
    WHERE status IN ('SCHEDULED', 'IN_TRANSIT')
      AND (truck_id = p_truck_id OR driver_id = p_driver_id OR assistant_id = p_assistant_id)
      AND (p_start_time < scheduled_end AND p_end_time > scheduled_start);

    IF v_overlap_count > 0 THEN
        ROLLBACK;
        INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
        VALUES (p_dispatcher_id, 'REJECTED', 'CHECK_A_OVERLAP', CONCAT('Truck, Driver, or Assistant already booked for route window ', p_start_time, ' to ', p_end_time));
        SET p_result_code = 'REJECTED_CHECK_A_OVERLAP';
        LEAVE PROC_BODY;
    END IF;

    -- CHECK B: Driver Rest Period Check (FR-4.3.5)
    IF v_driver_consec >= 1 AND v_driver_last_end IS NOT NULL AND TIMESTAMPDIFF(HOUR, v_driver_last_end, p_start_time) < 8 THEN
        ROLLBACK;
        INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
        VALUES (p_dispatcher_id, 'REJECTED', 'CHECK_B_DRIVER_REST', 'Driver requires at least 8 hours rest between consecutive routes');
        SET p_result_code = 'REJECTED_CHECK_B_DRIVER_REST';
        LEAVE PROC_BODY;
    END IF;

    -- CHECK C: Assistant Consecutive Route Cap (FR-4.3.6)
    IF v_assistant_consec >= 2 THEN
        ROLLBACK;
        INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
        VALUES (p_dispatcher_id, 'REJECTED', 'CHECK_C_ASSISTANT_REST', 'Assistant has reached maximum limit of 2 consecutive routes');
        SET p_result_code = 'REJECTED_CHECK_C_ASSISTANT_REST';
        LEAVE PROC_BODY;
    END IF;

    -- CHECK D: Weekly Working Hour Caps (FR-4.3.7 - Driver: 40h, Assistant: 60h)
    IF (v_driver_hours + p_duration_hours) > 40.00 THEN
        ROLLBACK;
        INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
        VALUES (p_dispatcher_id, 'REJECTED', 'CHECK_D_HOURS_CAP', CONCAT('Driver weekly limit exceeded: ', (v_driver_hours + p_duration_hours), 'h / 40h'));
        SET p_result_code = 'REJECTED_CHECK_D_DRIVER_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    IF (v_assistant_hours + p_duration_hours) > 60.00 THEN
        ROLLBACK;
        INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
        VALUES (p_dispatcher_id, 'REJECTED', 'CHECK_D_HOURS_CAP', CONCAT('Assistant weekly limit exceeded: ', (v_assistant_hours + p_duration_hours), 'h / 60h'));
        SET p_result_code = 'REJECTED_CHECK_D_ASSISTANT_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    -- ALL CHECKS PASSED: Commit Roster Assignment
    INSERT INTO roster_assignments(route_id, truck_id, driver_id, assistant_id, dispatcher_id, scheduled_start, scheduled_end, route_duration_hours)
    VALUES (p_route_id, p_truck_id, p_driver_id, p_assistant_id, p_dispatcher_id, p_start_time, p_end_time, p_duration_hours);

    -- Update Driver Accumulators
    UPDATE drivers
    SET accumulated_weekly_hours = accumulated_weekly_hours + p_duration_hours,
        consecutive_routes_count = consecutive_routes_count + 1,
        last_trip_end_time = p_end_time
    WHERE driver_id = p_driver_id;

    -- Update Assistant Accumulators
    UPDATE assistants
    SET accumulated_weekly_hours = accumulated_weekly_hours + p_duration_hours,
        consecutive_routes_count = consecutive_routes_count + 1,
        last_trip_end_time = p_end_time
    WHERE assistant_id = p_assistant_id;

    -- Audit Log Entry for Success
    INSERT INTO roster_audit_logs(dispatcher_id, status, violation_rule, details)
    VALUES (p_dispatcher_id, 'SUCCESS', NULL, CONCAT('Roster created successfully for route #', p_route_id));

    COMMIT;
    SET p_result_code = 'SUCCESS';
END //

DELIMITER ;
