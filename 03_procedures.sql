-- Kandypack Logistics Platform - Stored Procedures (MySQL 8.0)
USE kandypack_db;

DELIMITER //

-- PROCEDURE 3: Station Cargo Receiving Engine (Feature 4.4 - Sanjana)
DROP PROCEDURE IF EXISTS sp_receive_manifest//
CREATE PROCEDURE sp_receive_manifest(
    IN p_station_id INT,
    IN p_trip_id INT,
    IN p_user_id INT,
    OUT p_result_code VARCHAR(50)
)
PROC_BODY: BEGIN
    DECLARE v_manifest_id INT;
    DECLARE v_manifest_status VARCHAR(50);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = 'ERROR_TRANSACTION_FAILED';
    END;

    START TRANSACTION;

    -- 1. Lock and validate the manifest (stops two managers receiving it at once)
    SELECT manifest_id, status INTO v_manifest_id, v_manifest_status
    FROM manifest
    WHERE station_id = p_station_id AND trip_id = p_trip_id
    FOR UPDATE;

    IF v_manifest_id IS NULL THEN
        ROLLBACK;
        SET p_result_code = 'MANIFEST_NOT_FOUND';
        LEAVE PROC_BODY;
    END IF;

    IF v_manifest_status <> 'PENDING' THEN
        ROLLBACK;
        SET p_result_code = 'MANIFEST_ALREADY_RECEIVED';
        LEAVE PROC_BODY;
    END IF;

    -- 2. Add every allocated product/quantity into this station's stock
    add_stock: BEGIN
        DECLARE v_product_id INT;
        DECLARE v_qty INT;
        DECLARE done INT DEFAULT FALSE;

        DECLARE cur_items CURSOR FOR
            SELECT oi.product_id, ra.allocated_quantity
            FROM rail_allocation ra
            JOIN order_item oi ON ra.order_item_id = oi.order_item_id
            WHERE ra.trip_id = p_trip_id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

        OPEN cur_items;
        item_loop: LOOP
            FETCH cur_items INTO v_product_id, v_qty;
            IF done THEN LEAVE item_loop; END IF;

            INSERT INTO inventory (station_id, product_id, stored_quantity)
            VALUES (p_station_id, v_product_id, v_qty)
            ON DUPLICATE KEY UPDATE stored_quantity = stored_quantity + v_qty;

        END LOOP;
        CLOSE cur_items;
    END add_stock;

    -- 3. Mark the manifest as received
    UPDATE manifest
    SET status = 'RECEIVED', received_at = NOW()
    WHERE manifest_id = v_manifest_id;

    -- 4. For every order that had items on this trip, move it forward, but only
    --    once ALL of that order's trips (in case it spilled over onto several) have arrived.
    advance_orders: BEGIN
        DECLARE v_order_id INT;
        DECLARE v_remaining_trips INT;
        DECLARE done2 INT DEFAULT FALSE;

        DECLARE cur_orders CURSOR FOR
            SELECT DISTINCT oi.order_id
            FROM rail_allocation ra
            JOIN order_item oi ON ra.order_item_id = oi.order_item_id
            WHERE ra.trip_id = p_trip_id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done2 = TRUE;

        OPEN cur_orders;
        order_loop: LOOP
            FETCH cur_orders INTO v_order_id;
            IF done2 THEN LEAVE order_loop; END IF;

            SELECT COUNT(*) INTO v_remaining_trips
            FROM rail_allocation ra2
            JOIN order_item oi2 ON ra2.order_item_id = oi2.order_item_id
            JOIN train_trip tt2 ON ra2.trip_id = tt2.trip_id
            LEFT JOIN manifest m2 ON m2.trip_id = tt2.trip_id AND m2.station_id = tt2.destination_station_id
            WHERE oi2.order_id = v_order_id
              AND (m2.status IS NULL OR m2.status <> 'RECEIVED');

            IF v_remaining_trips = 0 THEN
                UPDATE customer_order
                SET status = 'ARRIVED_AT_STATION_STORE'
                WHERE order_id = v_order_id;

                INSERT INTO order_status_history (status, order_id, changed_by)
                VALUES ('ARRIVED_AT_STATION_STORE', v_order_id, p_user_id);
            END IF;

        END LOOP;
        CLOSE cur_orders;
    END advance_orders;

    COMMIT;
    SET p_result_code = 'SUCCESS';
END //

DELIMITER ;
