-- Kandypack Logistics Platform - Triggers (MySQL 8.0)
USE kandypack_db;

DELIMITER //

-- 1. Prevent UPDATE on roster_audit_logs (Log Protection Rule in App B.2.5)
DROP TRIGGER IF EXISTS trg_prevent_audit_log_modification//
CREATE TRIGGER trg_prevent_audit_log_modification
BEFORE UPDATE ON roster_audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'SECURITY VIOLATION: Roster audit logs are immutable and cannot be updated or altered.';
END //

-- 2. Prevent DELETE on roster_audit_logs (Log Protection Rule in App B.2.5)
DROP TRIGGER IF EXISTS trg_prevent_audit_log_deletion//
CREATE TRIGGER trg_prevent_audit_log_deletion
BEFORE DELETE ON roster_audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'SECURITY VIOLATION: Roster audit logs are immutable and cannot be deleted.';
END //

DELIMITER ;
