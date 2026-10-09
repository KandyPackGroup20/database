USE kandypack_db;

DELIMITER //

DROP TRIGGER IF EXISTS trg_rail_alloc_quantity_bi//
CREATE TRIGGER trg_rail_alloc_quantity_bi BEFORE INSERT ON rail_allocation
FOR EACH ROW FOLLOWS trg_rail_alloc_capacity_bi
BEGIN
  DECLARE v_ordered INT;
  DECLARE v_already INT;
  SELECT quantity INTO v_ordered FROM order_item WHERE order_item_id = NEW.order_item_id;
  SELECT COALESCE(SUM(allocated_quantity), 0) INTO v_already FROM rail_allocation WHERE order_item_id = NEW.order_item_id;
  IF v_already + NEW.allocated_quantity > v_ordered THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation exceeds ordered quantity (duplicate allocation).';
  END IF;
END//

DROP TRIGGER IF EXISTS trg_rail_alloc_quantity_bu//
CREATE TRIGGER trg_rail_alloc_quantity_bu BEFORE UPDATE ON rail_allocation
FOR EACH ROW FOLLOWS trg_rail_alloc_capacity_bu
BEGIN
  DECLARE v_ordered INT;
  DECLARE v_already INT;
  SELECT quantity INTO v_ordered FROM order_item WHERE order_item_id = NEW.order_item_id;
  SELECT COALESCE(SUM(allocated_quantity), 0) INTO v_already
    FROM rail_allocation
   WHERE order_item_id = NEW.order_item_id AND allocation_id <> OLD.allocation_id;
  IF v_already + NEW.allocated_quantity > v_ordered THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'RAIL RULE VIOLATION: allocation exceeds ordered quantity (duplicate allocation).';
  END IF;
END//

DELIMITER ;
