-- Stored Procedure: sp_reverse_rail_allocation (LM-18: Reschedule / Reversal Engine)
-- Reverses existing rail allocations for an order, resets order status to PENDING_RAIL_SCHEDULING,
-- records trip-by-trip audit logs, and guards against reversing departed/inactive trips.
USE kandypack_db;

DELIMITER //

DROP PROCEDURE IF EXISTS sp_reverse_rail_allocation//
CREATE PROCEDURE sp_reverse_rail_allocation(
    IN  p_order_id INT,
    IN  p_user_id  INT,
    OUT p_result   VARCHAR(50)
)
proc_body: BEGIN
    DECLARE v_status VARCHAR(50);
    DECLARE v_alloc_count INT;
    DECLARE v_invalid_trip_count INT;
    DECLARE done INT DEFAULT FALSE;

    -- Variables for per-allocation audit logging
    DECLARE v_audit_alloc_id INT;
    DECLARE v_audit_trip_id INT;
    DECLARE v_audit_qty INT;
    DECLARE v_audit_space DECIMAL(10,2);

    DECLARE cur_allocs CURSOR FOR
        SELECT ra.allocation_id, ra.trip_id, ra.allocated_quantity, ra.allocated_space
        FROM rail_allocation ra
        JOIN order_item oi ON oi.order_item_id = ra.order_item_id
        WHERE oi.order_id = p_order_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    DECLARE EXIT HANDLER FOR 1213, 1205
    BEGIN
        ROLLBACK;
        SET p_result = 'DEADLOCK_RETRY';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ERROR_TRANSACTION_FAILED';
        IF p_user_id IS NOT NULL THEN
            INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
            VALUES (p_user_id, 'REVERSE_RAIL_ORDER', p_order_id, 'ERROR_TRANSACTION_FAILED', 'customer_order');
            COMMIT;
        END IF;
    END;

    START TRANSACTION;

    -- 1. Validate and lock order
    SET v_status = NULL;
    SELECT status INTO v_status
      FROM customer_order
     WHERE order_id = p_order_id
       FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SET p_result = 'ORDER_NOT_FOUND';
        IF p_user_id IS NOT NULL THEN
            INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
            VALUES (p_user_id, 'REVERSE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
            COMMIT;
        END IF;
        LEAVE proc_body;
    END IF;

    -- Only orders currently scheduled for rail can be reversed
    IF v_status NOT IN ('SCHEDULED_FOR_RAIL', 'SCHEDULED_MULTI_TRIP') THEN
        ROLLBACK;
        SET p_result = 'INVALID_ORDER_STATUS';
        IF p_user_id IS NOT NULL THEN
            INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
            VALUES (p_user_id, 'REVERSE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
            COMMIT;
        END IF;
        LEAVE proc_body;
    END IF;

    -- 2. Guard: refuse reversal if any of the order's trips has already departed or is not SCHEDULED
    SELECT COUNT(*) INTO v_invalid_trip_count
      FROM rail_allocation ra
      JOIN order_item oi ON oi.order_item_id = ra.order_item_id
      JOIN train_trip tt ON tt.trip_id = ra.trip_id
     WHERE oi.order_id = p_order_id
       AND (tt.status <> 'SCHEDULED' OR tt.departure_datetime <= CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+05:30')
            OR EXISTS (SELECT 1 FROM manifest m WHERE m.trip_id=tt.trip_id AND m.status='RECEIVED'));

    IF v_invalid_trip_count > 0 THEN
        ROLLBACK;
        SET p_result = 'CANNOT_REVERSE_DEPARTED_OR_INACTIVE_TRIP';
        IF p_user_id IS NOT NULL THEN
            INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
            VALUES (p_user_id, 'REVERSE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
            COMMIT;
        END IF;
        LEAVE proc_body;
    END IF;

    -- 3. Record trip-by-trip audit log for what is being reversed
    IF p_user_id IS NOT NULL THEN
        OPEN cur_allocs;
        audit_loop: LOOP
            FETCH cur_allocs INTO v_audit_alloc_id, v_audit_trip_id, v_audit_qty, v_audit_space;
            IF done THEN
                LEAVE audit_loop;
            END IF;
            INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
            VALUES (
                p_user_id,
                'REVERSE_RAIL_ALLOCATION_ITEM',
                v_audit_alloc_id,
                CONCAT('TRIP:', v_audit_trip_id, ';QTY:', v_audit_qty, ';SPACE:', v_audit_space),
                'rail_allocation'
            );
        END LOOP;
        CLOSE cur_allocs;
    END IF;

    -- 4. Delete allocation rows (freeing up train trip capacity)
    DELETE ra FROM rail_allocation ra
      JOIN order_item oi ON oi.order_item_id = ra.order_item_id
     WHERE oi.order_id = p_order_id;

    -- 5. Reset customer_order status to PENDING_RAIL_SCHEDULING
    UPDATE customer_order
       SET status = 'PENDING_RAIL_SCHEDULING'
     WHERE order_id = p_order_id;

    -- 6. Record status history
    INSERT INTO order_status_history (status, order_id, changed_by)
    VALUES ('PENDING_RAIL_SCHEDULING', p_order_id, p_user_id);

    -- 7. Audit log summary entry
    IF p_user_id IS NOT NULL THEN
        INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
        VALUES (p_user_id, 'REVERSE_RAIL_ORDER', p_order_id, 'SUCCESS', 'customer_order');
    END IF;

    COMMIT;
    SET p_result = 'SUCCESS_REVERSED';
END //

DELIMITER ;
