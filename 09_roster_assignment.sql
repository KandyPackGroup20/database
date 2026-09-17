-- Member 3 Feature 4.3: durable roster decision details and lock-friendly indexes.
-- Apply once after the corrected 00-08 database scripts. This script does not
-- recreate or seed business tables.
USE kandypack_db;

CREATE TABLE roster_assignment_audit_detail (
    roster_audit_detail_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    audit_id INT NOT NULL,
    request_key VARCHAR(128) NOT NULL,
    roster_id INT NULL,
    route_id INT NOT NULL,
    truck_id INT NOT NULL,
    driver_id INT NOT NULL,
    assistant_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    duration_seconds BIGINT NOT NULL,
    policy_id VARCHAR(50) NOT NULL,
    outcome VARCHAR(50) NOT NULL,
    reason_code VARCHAR(100) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_roster_audit_detail_audit UNIQUE (audit_id),
    CONSTRAINT uq_roster_audit_detail_request UNIQUE (request_key),
    CONSTRAINT fk_roster_audit_detail_audit
        FOREIGN KEY (audit_id) REFERENCES audit_log(audit_id) ON DELETE RESTRICT,
    CONSTRAINT fk_roster_audit_detail_roster
        FOREIGN KEY (roster_id) REFERENCES roster_assignment(roster_id) ON DELETE SET NULL,
    CONSTRAINT chk_roster_audit_detail_interval CHECK (end_time > start_time),
    CONSTRAINT chk_roster_audit_detail_duration CHECK (duration_seconds > 0),
    CONSTRAINT chk_roster_audit_detail_outcome CHECK (outcome IN ('ACCEPTED', 'REJECTED')),
    CONSTRAINT chk_roster_audit_detail_result CHECK (
        (outcome = 'ACCEPTED' AND roster_id IS NOT NULL AND reason_code IS NULL)
        OR (outcome = 'REJECTED' AND roster_id IS NULL AND reason_code IS NOT NULL)
    )
) ENGINE=InnoDB;

ALTER TABLE roster_assignment
    ADD CONSTRAINT chk_roster_assignment_interval CHECK (end_time > start_time),
    ADD CONSTRAINT chk_roster_assignment_people CHECK (driver_id <> assistant_id);

CREATE INDEX idx_roster_truck_window
    ON roster_assignment (truck_id, status, start_time, end_time);
CREATE INDEX idx_roster_driver_window
    ON roster_assignment (driver_id, status, start_time, end_time);
CREATE INDEX idx_roster_assistant_window
    ON roster_assignment (assistant_id, status, start_time, end_time);

DELIMITER $$
CREATE TRIGGER trg_roster_audit_detail_no_update
BEFORE UPDATE ON roster_assignment_audit_detail
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Roster assignment audit details are immutable';
END$$

CREATE TRIGGER trg_roster_audit_detail_no_delete
BEFORE DELETE ON roster_assignment_audit_detail
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Roster assignment audit details are immutable';
END$$
DELIMITER ;
