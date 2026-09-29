USE kandypack_db;

-- Accepted audit rows reference the immutable assignment request in the base schema.
ALTER TABLE roster_assignment
    ADD CONSTRAINT chk_roster_assignment_interval CHECK (end_time > start_time),
    ADD CONSTRAINT chk_roster_assignment_people CHECK (driver_id <> assistant_id);

CREATE INDEX idx_roster_truck_window
    ON roster_assignment (truck_id, status, start_time, end_time);
CREATE INDEX idx_roster_driver_window
    ON roster_assignment (driver_id, status, start_time, end_time);
CREATE INDEX idx_roster_assistant_window
    ON roster_assignment (assistant_id, status, start_time, end_time);

-- Status may evolve, but retries and accepted history must retain the request.
DELIMITER //
DROP TRIGGER IF EXISTS trg_roster_assignment_request_immutable//
CREATE TRIGGER trg_roster_assignment_request_immutable
BEFORE UPDATE ON roster_assignment
FOR EACH ROW
BEGIN
    IF NOT (OLD.roster_id <=> NEW.roster_id)
       OR NOT (OLD.request_key <=> NEW.request_key)
       OR NOT (OLD.route_id <=> NEW.route_id)
       OR NOT (OLD.truck_id <=> NEW.truck_id)
       OR NOT (OLD.driver_id <=> NEW.driver_id)
       OR NOT (OLD.assistant_id <=> NEW.assistant_id)
       OR NOT (OLD.dispatcher_id <=> NEW.dispatcher_id)
       OR NOT (OLD.start_time <=> NEW.start_time)
       OR NOT (OLD.end_time <=> NEW.end_time)
       OR NOT (OLD.created_at <=> NEW.created_at) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Roster assignment request facts are immutable';
    END IF;
END //
DELIMITER ;
