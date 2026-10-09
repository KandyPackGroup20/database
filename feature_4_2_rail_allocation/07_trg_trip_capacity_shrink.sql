-- a trip's capacity cannot be cut below what is already booked
USE kandypack_db;
DELIMITER //

DROP TRIGGER IF EXISTS trg_train_trip_capacity_bu//
CREATE TRIGGER trg_train_trip_capacity_bu
BEFORE UPDATE ON train_trip
FOR EACH ROW
BEGIN
  DECLARE v_used DECIMAL(10,2);

  IF NEW.total_capacity < OLD.total_capacity THEN
    SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
      FROM rail_allocation WHERE trip_id = OLD.trip_id FOR SHARE;

    IF NEW.total_capacity < v_used THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: capacity cannot go below already allocated space.';
    END IF;
  END IF;
END //

DELIMITER ;