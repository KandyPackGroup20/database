-- capacity CHECK as triggers (a CHECK constraint cannot look at other rows)
USE kandypack_db;
DELIMITER //

DROP TRIGGER IF EXISTS trg_rail_alloc_capacity_bi//
CREATE TRIGGER trg_rail_alloc_capacity_bi
BEFORE INSERT ON rail_allocation
FOR EACH ROW
BEGIN
  DECLARE v_cap    DECIMAL(10,2);
  DECLARE v_status VARCHAR(50);
  DECLARE v_used   DECIMAL(10,2);
  DECLARE v_manifest_status VARCHAR(50);

  SET NEW.allocated_space = fn_order_item_space(NEW.order_item_id, NEW.allocated_quantity);

  -- lock the trip row first: every writer for this trip queues here
  SELECT total_capacity, status INTO v_cap, v_status
    FROM train_trip WHERE trip_id = NEW.trip_id FOR UPDATE;

  IF v_status <> 'SCHEDULED' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: trip is not open for allocation.';
  END IF;

  SELECT MAX(status) INTO v_manifest_status FROM manifest WHERE trip_id=NEW.trip_id FOR UPDATE;
  IF v_manifest_status = 'RECEIVED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: manifest already received.';
  END IF;

  -- FOR SHARE is a current read under REPEATABLE READ. Unlike FOR UPDATE,
  -- it is supported when reading the invoking table from this trigger (verified on MySQL 8).
  -- A plain SUM could reuse an older snapshot and permit overbooking.
  SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
    FROM rail_allocation WHERE trip_id = NEW.trip_id FOR SHARE;

  IF v_used + NEW.allocated_space > v_cap THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation exceeds trip capacity.';
  END IF;
END //

DROP TRIGGER IF EXISTS trg_rail_alloc_manifest_ai//
CREATE TRIGGER trg_rail_alloc_manifest_ai AFTER INSERT ON rail_allocation
FOR EACH ROW
BEGIN
  INSERT INTO manifest (station_id, trip_id, status)
  SELECT destination_station_id, trip_id, 'PENDING' FROM train_trip WHERE trip_id=NEW.trip_id
  ON DUPLICATE KEY UPDATE manifest_id=manifest_id;
END //

DROP TRIGGER IF EXISTS trg_rail_alloc_capacity_bu//
CREATE TRIGGER trg_rail_alloc_capacity_bu
BEFORE UPDATE ON rail_allocation
FOR EACH ROW
BEGIN
  DECLARE v_cap  DECIMAL(10,2);
  DECLARE v_used DECIMAL(10,2);
  DECLARE v_status VARCHAR(50);
  DECLARE v_received VARCHAR(50);

  SET NEW.allocated_space = fn_order_item_space(NEW.order_item_id, NEW.allocated_quantity);

  SELECT total_capacity, status INTO v_cap, v_status
    FROM train_trip WHERE trip_id = NEW.trip_id FOR UPDATE;
  SELECT MAX(status) INTO v_received FROM manifest WHERE trip_id IN (OLD.trip_id, NEW.trip_id) FOR UPDATE;
  IF v_status <> 'SCHEDULED' OR v_received = 'RECEIVED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation is closed or received.';
  END IF;

  SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
    FROM rail_allocation
   WHERE trip_id = NEW.trip_id AND allocation_id <> OLD.allocation_id FOR SHARE;

  IF v_used + NEW.allocated_space > v_cap THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation exceeds trip capacity.';
  END IF;
END //

DROP TRIGGER IF EXISTS trg_rail_alloc_receipt_bd//
CREATE TRIGGER trg_rail_alloc_receipt_bd BEFORE DELETE ON rail_allocation
FOR EACH ROW
BEGIN
  DECLARE v_trip INT;
  DECLARE v_received VARCHAR(50);
  SELECT trip_id INTO v_trip FROM train_trip WHERE trip_id=OLD.trip_id FOR UPDATE;
  SELECT MAX(status) INTO v_received FROM manifest WHERE trip_id=OLD.trip_id FOR UPDATE;
  IF v_received = 'RECEIVED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: received allocation cannot be reversed.';
  END IF;
END //

DROP TRIGGER IF EXISTS trg_rail_alloc_manifest_au//
CREATE TRIGGER trg_rail_alloc_manifest_au AFTER UPDATE ON rail_allocation
FOR EACH ROW
BEGIN
  INSERT INTO manifest (station_id, trip_id, status)
  SELECT destination_station_id, trip_id, 'PENDING' FROM train_trip WHERE trip_id=NEW.trip_id
  ON DUPLICATE KEY UPDATE manifest_id=manifest_id;
END //

DELIMITER ;
