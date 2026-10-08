-- Trigger: trg_rail_alloc_origin_bi & trg_rail_alloc_origin_bu (LM-03 DB-level Guard: origin must be Kandy)
USE kandypack_db;

DELIMITER //

DROP TRIGGER IF EXISTS trg_rail_alloc_origin_bi//
CREATE TRIGGER trg_rail_alloc_origin_bi BEFORE INSERT ON rail_allocation
FOR EACH ROW FOLLOWS trg_rail_alloc_quantity_bi
BEGIN
    DECLARE v_origin_city VARCHAR(100);

    SELECT ss.city INTO v_origin_city
    FROM train_trip tt
    JOIN station_store ss ON ss.station_id = tt.origin_station_id
    WHERE tt.trip_id = NEW.trip_id;

    IF v_origin_city IS NULL OR v_origin_city <> 'Kandy' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: trip does not depart from Kandy.';
    END IF;
END//

DROP TRIGGER IF EXISTS trg_rail_alloc_origin_bu//
CREATE TRIGGER trg_rail_alloc_origin_bu BEFORE UPDATE ON rail_allocation
FOR EACH ROW FOLLOWS trg_rail_alloc_quantity_bu
BEGIN
    DECLARE v_origin_city VARCHAR(100);

    SELECT ss.city INTO v_origin_city
    FROM train_trip tt
    JOIN station_store ss ON ss.station_id = tt.origin_station_id
    WHERE tt.trip_id = NEW.trip_id;

    IF v_origin_city IS NULL OR v_origin_city <> 'Kandy' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: trip does not depart from Kandy.';
    END IF;
END//

DELIMITER ;
