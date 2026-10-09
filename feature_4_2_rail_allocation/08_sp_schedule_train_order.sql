-- multi trip spillover scheduler (transaction + row locking)
-- Feature 4.2: Rail Capacity Allocation & Spillover
USE kandypack_db;
DELIMITER //

DROP PROCEDURE IF EXISTS sp_schedule_train_order//
CREATE PROCEDURE sp_schedule_train_order(
  IN  p_order_id INT,
  IN  p_user_id  INT,            -- logistics manager; NULL is allowed
  OUT p_result   VARCHAR(50)
)
proc_body: BEGIN
  DECLARE v_status        VARCHAR(50);
  DECLARE v_delivery_date DATE;
  DECLARE v_dest_station  INT;
  DECLARE v_kandy_station INT;
  DECLARE v_item_id       INT DEFAULT 0;
  DECLARE v_next_item     INT;
  DECLARE v_item_qty      INT;
  DECLARE v_rate          DECIMAL(6,4);
  DECLARE v_remaining     INT;
  DECLARE v_last_dep      DATETIME;
  DECLARE v_last_trip     INT;
  DECLARE v_trip_id       INT;
  DECLARE v_trip_dep      DATETIME;
  DECLARE v_trip_cap      DECIMAL(10,2);
  DECLARE v_used          DECIMAL(10,2);
  DECLARE v_fit           INT;
  DECLARE v_alloc_qty     INT;
  DECLARE v_trip_count    INT DEFAULT 0;
  DECLARE v_any_item      INT DEFAULT 0;

  -- 1213 = deadlock, 1205 = lock wait timeout >> caller may simply retry
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
      VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, 'ERROR_TRANSACTION_FAILED', 'customer_order');
      COMMIT;
    END IF;
  END;

  START TRANSACTION;

  -- 1. lock the order row and validate its state
  SET v_status = NULL;
  SELECT status, delivery_date INTO v_status, v_delivery_date
    FROM customer_order WHERE order_id = p_order_id FOR UPDATE;

  IF v_status IS NULL THEN
    ROLLBACK; SET p_result = 'ORDER_NOT_FOUND';
    IF p_user_id IS NOT NULL THEN
      INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
      VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
      COMMIT;
    END IF;
    LEAVE proc_body;
  END IF;

  IF v_status <> 'PENDING_RAIL_SCHEDULING' THEN
    ROLLBACK; SET p_result = 'INVALID_ORDER_STATUS';
    IF p_user_id IS NOT NULL THEN
      INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
      VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
      COMMIT;
    END IF;
    LEAVE proc_body;
  END IF;

  -- 2. destination hub = station of the customer's delivery route
  SET v_dest_station = NULL;
  SELECT dr.station_id INTO v_dest_station
    FROM customer_order co
    JOIN customer c        ON c.customer_id = co.customer_id
    JOIN delivery_route dr ON dr.route_id   = co.delivery_route_id
   WHERE co.order_id = p_order_id;

  IF v_dest_station IS NULL THEN
    ROLLBACK; SET p_result = 'DESTINATION_HUB_NOT_RESOLVED';
    IF p_user_id IS NOT NULL THEN
      INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
      VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
      COMMIT;
    END IF;
    LEAVE proc_body;
  END IF;

  -- LM-03: Origin must be Kandy
  SET v_kandy_station = NULL;
  SELECT station_id INTO v_kandy_station FROM station_store WHERE city = 'Kandy' LIMIT 1;
  IF v_kandy_station IS NULL THEN
    ROLLBACK; SET p_result = 'ORIGIN_HUB_NOT_FOUND';
    IF p_user_id IS NOT NULL THEN
      INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
      VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
      COMMIT;
    END IF;
    LEAVE proc_body;
  END IF;

  -- 3. walk the order items one by one
  item_loop: LOOP
    SET v_next_item = NULL;
    SELECT MIN(order_item_id) INTO v_next_item
      FROM order_item WHERE order_id = p_order_id AND order_item_id > v_item_id;

    IF v_next_item IS NULL THEN
      LEAVE item_loop;
    END IF;

    SET v_item_id  = v_next_item;
    SET v_any_item = 1;

    SELECT oi.quantity, p.space_consumption_rate INTO v_item_qty, v_rate
      FROM order_item oi JOIN product p ON p.product_id = oi.product_id
     WHERE oi.order_item_id = v_item_id;

    IF v_rate <= 0 THEN
      ROLLBACK; SET p_result = 'INVALID_PRODUCT_SPACE_RATE';
      IF p_user_id IS NOT NULL THEN
        INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
        VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
        COMMIT;
      END IF;
      LEAVE proc_body;
    END IF;

    SET v_remaining = v_item_qty;
    SET v_last_dep  = '1000-01-01 00:00:00';
    SET v_last_trip = 0;

    -- 4. spillover: earliest trip first, then the next one, ...
    trip_loop: WHILE v_remaining > 0 DO
      SET v_trip_id = NULL;

      SELECT tt.trip_id, tt.departure_datetime, tt.total_capacity
        INTO v_trip_id, v_trip_dep, v_trip_cap
        FROM train_trip tt
       WHERE tt.origin_station_id = v_kandy_station
         AND tt.destination_station_id = v_dest_station
         AND tt.status = 'SCHEDULED'
         AND tt.departure_datetime > NOW()
         AND tt.arrival_datetime < v_delivery_date + INTERVAL 1 DAY
         AND (tt.departure_datetime > v_last_dep
              OR (tt.departure_datetime = v_last_dep AND tt.trip_id > v_last_trip))
       ORDER BY tt.departure_datetime, tt.trip_id
       LIMIT 1
       FOR UPDATE;                                   -- row lock on the trip

      IF v_trip_id IS NULL THEN
        LEAVE trip_loop;                             -- no more trips
      END IF;

      SET v_last_dep  = v_trip_dep;
      SET v_last_trip = v_trip_id;

      -- locking read so we see allocations committed by other sessions
      SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
        FROM rail_allocation WHERE trip_id = v_trip_id FOR UPDATE;

      SET v_fit = FLOOR((v_trip_cap - v_used) / v_rate);

      IF v_fit > 0 THEN
        SET v_alloc_qty = LEAST(v_fit, v_remaining);

        INSERT INTO rail_allocation
               (order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
        VALUES (v_item_id, v_trip_id, v_alloc_qty,
                fn_order_item_space(v_item_id, v_alloc_qty), p_user_id);

        SET v_remaining = v_remaining - v_alloc_qty;
      END IF;
    END WHILE trip_loop;

    IF v_remaining > 0 THEN
      ROLLBACK; SET p_result = 'INSUFFICIENT_RAIL_CAPACITY';
      IF p_user_id IS NOT NULL THEN
        INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
        VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
        COMMIT;
      END IF;
      LEAVE proc_body;
    END IF;
  END LOOP item_loop;

  IF v_any_item = 0 THEN
    ROLLBACK; SET p_result = 'ORDER_HAS_NO_ITEMS';
    IF p_user_id IS NOT NULL THEN
      INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
      VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, p_result, 'customer_order');
      COMMIT;
    END IF;
    LEAVE proc_body;
  END IF;

  -- 5. single trip or multi-trip?
  SELECT COUNT(DISTINCT ra.trip_id) INTO v_trip_count
    FROM rail_allocation ra
    JOIN order_item oi ON oi.order_item_id = ra.order_item_id
   WHERE oi.order_id = p_order_id;

  IF v_trip_count = 1 THEN
    UPDATE customer_order SET status = 'SCHEDULED_FOR_RAIL' WHERE order_id = p_order_id;
    INSERT INTO order_status_history (status, order_id, changed_by)
    VALUES ('SCHEDULED_FOR_RAIL', p_order_id, p_user_id);
    SET p_result = 'SUCCESS_SINGLE_TRIP';
  ELSE
    UPDATE customer_order SET status = 'SCHEDULED_MULTI_TRIP' WHERE order_id = p_order_id;
    INSERT INTO order_status_history (status, order_id, changed_by)
    VALUES ('SCHEDULED_MULTI_TRIP', p_order_id, p_user_id);
    SET p_result = 'SUCCESS_MULTI_TRIP_SPILLOVER';
  END IF;

  IF p_user_id IS NOT NULL THEN
    INSERT INTO audit_log (user_id, action, entity_id, outcome, entity_name)
    VALUES (p_user_id, 'SCHEDULE_RAIL_ORDER', p_order_id, 'SUCCESS', 'customer_order');
  END IF;

  COMMIT;
END //

-- keep the old name working (an older draft already lived in 03_procedures.sql)
DROP PROCEDURE IF EXISTS sp_allocate_rail_capacity//
CREATE PROCEDURE sp_allocate_rail_capacity(IN p_order_id INT, OUT p_status_result VARCHAR(50))
BEGIN
  CALL sp_schedule_train_order(p_order_id, NULL, p_status_result);
END //

DELIMITER ;