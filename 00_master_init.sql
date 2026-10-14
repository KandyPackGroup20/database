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

-- 8. Feature 4.4 Stock Handling: Reserve and deduct station store inventory upon cargo assignment
DROP TRIGGER IF EXISTS trg_deduct_inventory_on_delivery//
CREATE TRIGGER trg_deduct_inventory_on_delivery
AFTER INSERT ON delivery
FOR EACH ROW
BEGIN
    DECLARE v_station_id INT;

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
        JOIN order_item oi ON oi.product_id = inv.product_id
        SET inv.stored_quantity = GREATEST(0, inv.stored_quantity - oi.quantity)
        WHERE oi.order_id = NEW.order_id AND inv.station_id = v_station_id;
    END IF;
END //
DELIMITER ;

CREATE INDEX idx_order_destination_date ON customer_order (delivery_route_id, delivery_date, status);
CREATE INDEX idx_delivery_run_status ON delivery (roster_id, delivery_status, delivery_id);

CREATE INDEX idx_manifest_station_status ON manifest (station_id, status);

CREATE INDEX idx_stock_adjust_inv_date ON stock_adjustment (inventory_id, adjusted_at);
