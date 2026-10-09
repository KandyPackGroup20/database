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

-- 4. Feature 4.4: keep station stock in sync with the stock_adjustment log
DROP TRIGGER IF EXISTS trg_apply_stock_adjustment//
CREATE TRIGGER trg_apply_stock_adjustment
AFTER INSERT ON stock_adjustment
FOR EACH ROW
BEGIN
    IF NEW.inventory_id IS NOT NULL AND NEW.quantity_delta IS NOT NULL THEN
        UPDATE inventory
        SET stored_quantity = stored_quantity + NEW.quantity_delta
        WHERE inventory_id = NEW.inventory_id;
    END IF;
END //

DELIMITER ;

DELIMITER //
DROP TRIGGER IF EXISTS trg_order_destination_immutable//
CREATE TRIGGER trg_order_destination_immutable BEFORE UPDATE ON customer_order FOR EACH ROW
BEGIN
    IF (NOT (OLD.delivery_route_id <=> NEW.delivery_route_id)
        OR NOT (OLD.delivery_address <=> NEW.delivery_address)
        OR NOT (OLD.recipient_name <=> NEW.recipient_name)
        OR NOT (OLD.recipient_phone <=> NEW.recipient_phone))
       AND (EXISTS(SELECT 1 FROM rail_allocation ra JOIN order_item oi ON oi.order_item_id=ra.order_item_id WHERE oi.order_id=OLD.order_id)
            OR EXISTS(SELECT 1 FROM delivery WHERE order_id=OLD.order_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Allocated order destinations are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_route_station_immutable//
CREATE TRIGGER trg_route_station_immutable BEFORE UPDATE ON delivery_route FOR EACH ROW
BEGIN
    IF OLD.station_id<>NEW.station_id AND
       (EXISTS(SELECT 1 FROM customer_order WHERE delivery_route_id=OLD.route_id)
        OR EXISTS(SELECT 1 FROM roster_assignment WHERE route_id=OLD.route_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Referenced route station is immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_delivery_assignment_immutable//
CREATE TRIGGER trg_delivery_assignment_immutable BEFORE UPDATE ON delivery FOR EACH ROW
BEGIN
    IF NOT (OLD.delivery_id <=> NEW.delivery_id) OR NOT (OLD.roster_id <=> NEW.roster_id)
       OR NOT (OLD.order_id <=> NEW.order_id) OR NOT (OLD.assigned_at <=> NEW.assigned_at)
       OR NOT (OLD.assigned_by <=> NEW.assigned_by) OR NOT (OLD.cargo_weight_kg <=> NEW.cargo_weight_kg) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cargo assignment facts are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_delivery_evidence_delete//
CREATE TRIGGER trg_delivery_evidence_delete BEFORE DELETE ON delivery FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cargo assignment evidence cannot be deleted';
END //
DROP TRIGGER IF EXISTS trg_assigned_item_insert//
CREATE TRIGGER trg_assigned_item_insert BEFORE INSERT ON order_item FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=NEW.order_id FOR UPDATE;
    IF EXISTS(SELECT 1 FROM delivery WHERE order_id=NEW.order_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order items are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_assigned_item_update//
CREATE TRIGGER trg_assigned_item_update BEFORE UPDATE ON order_item FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=LEAST(OLD.order_id,NEW.order_id) FOR UPDATE;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=GREATEST(OLD.order_id,NEW.order_id) FOR UPDATE;
    IF (NOT (OLD.order_id <=> NEW.order_id) OR NOT (OLD.product_id <=> NEW.product_id)
        OR NOT (OLD.quantity <=> NEW.quantity) OR NOT (OLD.order_item_id <=> NEW.order_item_id))
       AND EXISTS(SELECT 1 FROM delivery WHERE order_id IN (OLD.order_id,NEW.order_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order items are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_assigned_item_delete//
CREATE TRIGGER trg_assigned_item_delete BEFORE DELETE ON order_item FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=OLD.order_id FOR UPDATE;
    IF EXISTS(SELECT 1 FROM delivery WHERE order_id=OLD.order_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order items are immutable';
    END IF;
END //
DELIMITER ;
