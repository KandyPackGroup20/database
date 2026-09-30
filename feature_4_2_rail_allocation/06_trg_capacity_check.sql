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

  -- lock the trip row first: every writer for this trip queues here
  SELECT total_capacity, status INTO v_cap, v_status
    FROM train_trip WHERE trip_id = NEW.trip_id FOR UPDATE;

  IF v_status <> 'SCHEDULED' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: trip is not open for allocation.';
  END IF;

  -- MySQL forbids a locking read (FOR UPDATE) on the table a trigger is firing on (error 1442), so this is a plain read. The trip row lock above is what serialises writers; sp_schedule_train_order also re checks with a locking read.
  SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
    FROM rail_allocation WHERE trip_id = NEW.trip_id;

  IF v_used + NEW.allocated_space > v_cap THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation exceeds trip capacity.';
  END IF;
END //

DROP TRIGGER IF EXISTS trg_rail_alloc_capacity_bu//
CREATE TRIGGER trg_rail_alloc_capacity_bu
BEFORE UPDATE ON rail_allocation
FOR EACH ROW
BEGIN
  DECLARE v_cap  DECIMAL(10,2);
  DECLARE v_used DECIMAL(10,2);

  SELECT total_capacity INTO v_cap
    FROM train_trip WHERE trip_id = NEW.trip_id FOR UPDATE;

  SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
    FROM rail_allocation
   WHERE trip_id = NEW.trip_id AND allocation_id <> OLD.allocation_id;

  IF v_used + NEW.allocated_space > v_cap THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation exceeds trip capacity.';
  END IF;
END //

DELIMITER ;