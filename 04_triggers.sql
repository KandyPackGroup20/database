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
    IF COALESCE(@kandypack_staff_provisioning, 0) = 1 AND NEW.role = 'CUSTOMER' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Staff provisioning cannot create customers.';
    END IF;
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

-- 4. Feature 4.4: Stock Handling
-- trg_apply_stock_adjustment: Synchronizes inventory quantities with stock-adjustment records
DROP TRIGGER IF EXISTS trg_apply_stock_adjustment//
CREATE TRIGGER trg_apply_stock_adjustment
AFTER INSERT ON stock_adjustment
FOR EACH ROW
BEGIN
    IF NEW.inventory_id IS NOT NULL
       AND NEW.quantity_delta IS NOT NULL THEN

        UPDATE inventory
        SET stored_quantity = stored_quantity + NEW.quantity_delta
        WHERE inventory_id = NEW.inventory_id;

    END IF;
END //

-- 5. Business Rule: Orders must be placed at least 7 days in advance
DROP TRIGGER IF EXISTS trg_enforce_7_day_advance_order//
CREATE TRIGGER trg_enforce_7_day_advance_order
BEFORE INSERT ON customer_order
FOR EACH ROW
BEGIN
    IF NEW.delivery_date IS NOT NULL AND NEW.order_date IS NOT NULL THEN
        IF DATEDIFF(NEW.delivery_date, NEW.order_date) < 7 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'BUSINESS RULE VIOLATION: Orders must be placed at least 7 days in advance.';
        END IF;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_enforce_7_day_advance_order_update//
CREATE TRIGGER trg_enforce_7_day_advance_order_update
BEFORE UPDATE ON customer_order
FOR EACH ROW
BEGIN
    IF (NEW.delivery_date <> OLD.delivery_date OR NEW.order_date <> OLD.order_date) THEN
        IF DATEDIFF(NEW.delivery_date, NEW.order_date) < 7 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'BUSINESS RULE VIOLATION: Orders must be placed at least 7 days in advance.';
        END IF;
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


-- trg_assigned_item_insert: Prevents adding items after a delivery record exists
DROP TRIGGER IF EXISTS trg_assigned_item_insert//
CREATE TRIGGER trg_assigned_item_insert
BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_order INT;

    SELECT order_id INTO v_order
    FROM customer_order
    WHERE order_id = NEW.order_id
    FOR UPDATE;

    IF EXISTS (
        SELECT 1
        FROM delivery
        WHERE order_id = NEW.order_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assigned order items are immutable';
    END IF;
END //


-- trg_assigned_item_update: Prevents changing key order-item fields after delivery assignment
DROP TRIGGER IF EXISTS trg_assigned_item_update//
CREATE TRIGGER trg_assigned_item_update
BEFORE UPDATE ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id = LEAST(OLD.order_id, NEW.order_id) FOR UPDATE;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id = GREATEST(OLD.order_id, NEW.order_id) FOR UPDATE;

    IF (NOT (OLD.order_id <=> NEW.order_id) OR NOT (OLD.product_id <=> NEW.product_id)
        OR NOT (OLD.quantity <=> NEW.quantity) OR NOT (OLD.order_item_id <=> NEW.order_item_id))
       AND EXISTS (
           SELECT 1
           FROM delivery
           WHERE order_id IN (OLD.order_id, NEW.order_id)
       ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assigned order items are immutable';
    END IF;
END //


-- trg_assigned_item_delete: Prevents deleting order items after delivery assignment
DROP TRIGGER IF EXISTS trg_assigned_item_delete//
CREATE TRIGGER trg_assigned_item_delete
BEFORE DELETE ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_order INT;

    SELECT order_id INTO v_order
    FROM customer_order
    WHERE order_id = OLD.order_id
    FOR UPDATE;

    IF EXISTS (
        SELECT 1
        FROM delivery
        WHERE order_id = OLD.order_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assigned order items are immutable';
    END IF;
END //

-- 8. Feature 4.4 Stock Handling: Validate sufficient inventory, deduct upon cargo assignment, and restore on cancellation
DROP TRIGGER IF EXISTS trg_check_inventory_before_delivery//
CREATE TRIGGER trg_check_inventory_before_delivery
BEFORE INSERT ON delivery
FOR EACH ROW
BEGIN
    DECLARE v_station_id INT;
    DECLARE v_shortage_count INT DEFAULT 0;

    -- Only check inventory for active (non-cancelled) deliveries
    IF NEW.delivery_status <> 'CANCELLED' THEN
        -- Resolve fulfillment station store from roster route or customer order route
        SELECT dr.station_id INTO v_station_id
        FROM roster_assignment ra
        JOIN delivery_route dr ON dr.route_id = ra.route_id
        WHERE ra.roster_id = NEW.roster_id
        LIMIT 1;

        IF v_station_id IS NULL THEN
            SELECT dr.station_id INTO v_station_id
            FROM customer_order co
            JOIN delivery_route dr ON dr.route_id = co.delivery_route_id
            WHERE co.order_id = NEW.order_id
            LIMIT 1;
        END IF;

        IF v_station_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INSUFFICIENT_STOCK: Destination station store could not be resolved for delivery order';
        END IF;

        -- Verify every product in the order has sufficient stock (aggregating multi-line items)
        SELECT COUNT(*) INTO v_shortage_count
        FROM (
            SELECT oi.product_id, SUM(oi.quantity) AS required_qty
            FROM order_item oi
            WHERE oi.order_id = NEW.order_id
            GROUP BY oi.product_id
        ) req
        LEFT JOIN inventory inv 
            ON inv.station_id = v_station_id 
           AND inv.product_id = req.product_id
        WHERE inv.stored_quantity IS NULL 
           OR inv.stored_quantity < req.required_qty;

        IF v_shortage_count > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INSUFFICIENT_STOCK: Required inventory shortage or missing stock record at fulfillment station store';
        END IF;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_deduct_inventory_on_delivery//
CREATE TRIGGER trg_deduct_inventory_on_delivery
AFTER INSERT ON delivery
FOR EACH ROW
BEGIN
    DECLARE v_station_id INT;

    IF NEW.delivery_status <> 'CANCELLED' THEN
        SELECT dr.station_id INTO v_station_id
        FROM roster_assignment ra
        JOIN delivery_route dr ON dr.route_id = ra.route_id
        WHERE ra.roster_id = NEW.roster_id
        LIMIT 1;

        IF v_station_id IS NULL THEN
            SELECT dr.station_id INTO v_station_id
            FROM customer_order co
            JOIN delivery_route dr ON dr.route_id = co.delivery_route_id
            WHERE co.order_id = NEW.order_id
            LIMIT 1;
        END IF;

        IF v_station_id IS NOT NULL THEN
            UPDATE inventory inv
            JOIN (
                SELECT product_id, SUM(quantity) AS required_qty
                FROM order_item
                WHERE order_id = NEW.order_id
                GROUP BY product_id
            ) req ON req.product_id = inv.product_id
            SET inv.stored_quantity = inv.stored_quantity - req.required_qty
            WHERE inv.station_id = v_station_id;
        END IF;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_check_inventory_before_delivery_update//
CREATE TRIGGER trg_check_inventory_before_delivery_update
BEFORE UPDATE ON delivery
FOR EACH ROW
BEGIN
    DECLARE v_station_id INT;
    DECLARE v_shortage_count INT DEFAULT 0;

    -- If un-cancelling a delivery, ensure sufficient inventory exists
    IF OLD.delivery_status = 'CANCELLED' AND NEW.delivery_status <> 'CANCELLED' THEN
        SELECT dr.station_id INTO v_station_id
        FROM roster_assignment ra
        JOIN delivery_route dr ON dr.route_id = ra.route_id
        WHERE ra.roster_id = NEW.roster_id
        LIMIT 1;

        IF v_station_id IS NULL THEN
            SELECT dr.station_id INTO v_station_id
            FROM customer_order co
            JOIN delivery_route dr ON dr.route_id = co.delivery_route_id
            WHERE co.order_id = NEW.order_id
            LIMIT 1;
        END IF;

        IF v_station_id IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INSUFFICIENT_STOCK: Destination station store could not be resolved for delivery order';
        END IF;

        SELECT COUNT(*) INTO v_shortage_count
        FROM (
            SELECT oi.product_id, SUM(oi.quantity) AS required_qty
            FROM order_item oi
            WHERE oi.order_id = NEW.order_id
            GROUP BY oi.product_id
        ) req
        LEFT JOIN inventory inv 
            ON inv.station_id = v_station_id 
           AND inv.product_id = req.product_id
        WHERE inv.stored_quantity IS NULL 
           OR inv.stored_quantity < req.required_qty;

        IF v_shortage_count > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'INSUFFICIENT_STOCK: Required inventory shortage or missing stock record at fulfillment station store';
        END IF;
    END IF;
END //

DROP TRIGGER IF EXISTS trg_handle_inventory_on_delivery_status_change//
CREATE TRIGGER trg_handle_inventory_on_delivery_status_change
AFTER UPDATE ON delivery
FOR EACH ROW
BEGIN
    DECLARE v_station_id INT;

    -- 1. If an active delivery is CANCELLED: restore deducted stock back to station inventory
    IF OLD.delivery_status <> 'CANCELLED' AND NEW.delivery_status = 'CANCELLED' THEN
        SELECT dr.station_id INTO v_station_id
        FROM roster_assignment ra
        JOIN delivery_route dr ON dr.route_id = ra.route_id
        WHERE ra.roster_id = OLD.roster_id
        LIMIT 1;

        IF v_station_id IS NULL THEN
            SELECT dr.station_id INTO v_station_id
            FROM customer_order co
            JOIN delivery_route dr ON dr.route_id = co.delivery_route_id
            WHERE co.order_id = OLD.order_id
            LIMIT 1;
        END IF;

        IF v_station_id IS NOT NULL THEN
            UPDATE inventory inv
            JOIN (
                SELECT product_id, SUM(quantity) AS required_qty
                FROM order_item
                WHERE order_id = OLD.order_id
                GROUP BY product_id
            ) req ON req.product_id = inv.product_id
            SET inv.stored_quantity = inv.stored_quantity + req.required_qty
            WHERE inv.station_id = v_station_id;
        END IF;

    -- 2. If a CANCELLED delivery is reactivated: re-deduct required stock
    ELSEIF OLD.delivery_status = 'CANCELLED' AND NEW.delivery_status <> 'CANCELLED' THEN
        SELECT dr.station_id INTO v_station_id
        FROM roster_assignment ra
        JOIN delivery_route dr ON dr.route_id = ra.route_id
        WHERE ra.roster_id = NEW.roster_id
        LIMIT 1;

        IF v_station_id IS NULL THEN
            SELECT dr.station_id INTO v_station_id
            FROM customer_order co
            JOIN delivery_route dr ON dr.route_id = co.delivery_route_id
            WHERE co.order_id = NEW.order_id
            LIMIT 1;
        END IF;

        IF v_station_id IS NOT NULL THEN
            UPDATE inventory inv
            JOIN (
                SELECT product_id, SUM(quantity) AS required_qty
                FROM order_item
                WHERE order_id = NEW.order_id
                GROUP BY product_id
            ) req ON req.product_id = inv.product_id
            SET inv.stored_quantity = inv.stored_quantity - req.required_qty
            WHERE inv.station_id = v_station_id;
        END IF;
    END IF;
    -- Note: When delivery transitions between active states (e.g., ASSIGNED -> IN_TRANSIT -> DELIVERED),
    -- stock is already deducted and remains untouched (no double deduction).
END //

DELIMITER ;

