-- space needed by an order item (or by part of it)
USE kandypack_db;
DELIMITER //

DROP FUNCTION IF EXISTS fn_order_item_space//
CREATE FUNCTION fn_order_item_space(p_order_item_id INT, p_quantity INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_rate DECIMAL(6,4);
  DECLARE v_qty  INT;

  SELECT p.space_consumption_rate, COALESCE(p_quantity, oi.quantity)
    INTO v_rate, v_qty
    FROM order_item oi
    JOIN product p ON p.product_id = oi.product_id
   WHERE oi.order_item_id = p_order_item_id;

  IF v_rate IS NULL THEN
    RETURN NULL;
  END IF;

  -- round UP to 2 decimals so we never under-count space
  RETURN CEILING(v_qty * v_rate * 100) / 100;
END //

DELIMITER ;