-- Valid rail hub connections; capacity remains derived from rail_allocation.
USE kandypack_db;
DELIMITER //
DROP TRIGGER IF EXISTS trg_train_trip_hubs_bi//
CREATE TRIGGER trg_train_trip_hubs_bi BEFORE INSERT ON train_trip
FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM station_store WHERE station_id=NEW.origin_station_id AND city='Kandy' AND is_active=1)
     OR NOT EXISTS (SELECT 1 FROM station_store WHERE station_id=NEW.destination_station_id AND is_active=1
                    AND city IN ('Colombo','Negombo','Galle','Matara','Jaffna','Trincomalee')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RAIL RULE VIOLATION: active Kandy origin and supported destination required.';
  END IF;
END//
DROP TRIGGER IF EXISTS trg_train_trip_hubs_bu//
CREATE TRIGGER trg_train_trip_hubs_bu BEFORE UPDATE ON train_trip
FOR EACH ROW
BEGIN
  IF NEW.origin_station_id <> OLD.origin_station_id OR NEW.destination_station_id <> OLD.destination_station_id THEN
    IF EXISTS (SELECT 1 FROM rail_allocation WHERE trip_id=OLD.trip_id) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RAIL RULE VIOLATION: allocated trip hubs are immutable.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM station_store WHERE station_id=NEW.origin_station_id AND city='Kandy' AND is_active=1)
       OR NOT EXISTS (SELECT 1 FROM station_store WHERE station_id=NEW.destination_station_id AND is_active=1
                      AND city IN ('Colombo','Negombo','Galle','Matara','Jaffna','Trincomalee')) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='RAIL RULE VIOLATION: active Kandy origin and supported destination required.';
    END IF;
  END IF;
END//
DELIMITER ;
