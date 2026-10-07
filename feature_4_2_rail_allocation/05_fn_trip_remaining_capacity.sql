-- remaining space on a trip
USE kandypack_db;
DELIMITER //

DROP FUNCTION IF EXISTS fn_trip_remaining_capacity//
CREATE FUNCTION fn_trip_remaining_capacity(p_trip_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_cap  DECIMAL(10,2);
  DECLARE v_used DECIMAL(10,2);

  SELECT total_capacity INTO v_cap FROM train_trip WHERE trip_id = p_trip_id;
  IF v_cap IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(SUM(allocated_space), 0) INTO v_used
    FROM rail_allocation WHERE trip_id = p_trip_id;

  RETURN v_cap - v_used;
END //

DELIMITER ;