-- Kandypack Logistics Platform - Triggers (MySQL 8.0)
USE kandypack_db;

DELIMITER //

-- 1. Prevent UPDATE on audit_log
DROP TRIGGER IF EXISTS trg_prevent_audit_log_modification//
CREATE TRIGGER trg_prevent_audit_log_modification
BEFORE UPDATE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs are immutable and cannot be updated or altered.';
END //

-- 2. Prevent DELETE on audit_log
DROP TRIGGER IF EXISTS trg_prevent_audit_log_deletion//
CREATE TRIGGER trg_prevent_audit_log_deletion
BEFORE DELETE ON audit_log
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs are immutable and cannot be deleted.';
END //

-- 3. Feature 4.1: Enforce Account Creation Policy & Force Password Reset (Gunasekara P.S.I)
DROP TRIGGER IF EXISTS trg_user_account_creation_policy//
CREATE TRIGGER trg_user_account_creation_policy
BEFORE INSERT ON user
FOR EACH ROW
BEGIN
    -- Force staff accounts to reset password on first login
    IF NEW.role != 'CUSTOMER' THEN
        SET NEW.force_password_reset = 1;
        
        -- Enforce company domain for internal staff roles
        IF NEW.email NOT LIKE '%@kandypack.lk' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Internal staff users must have an email ending with @kandypack.lk';
        END IF;
    ELSE
        -- Customers default to not forcing reset unless explicitly specified
        IF NEW.force_password_reset IS NULL THEN
            SET NEW.force_password_reset = 0;
        END IF;
    END IF;

    -- Validate role is in allowed set
    IF NEW.role NOT IN ('SUPERADMIN', 'LOGISTICS_MGR', 'DISPATCHER', 'STORE_MGR', 'WAREHOUSE_STAFF', 'DRIVER', 'ASSISTANT', 'CUSTOMER') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Invalid user role specified.';
    END IF;
END //

DELIMITER ;

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
