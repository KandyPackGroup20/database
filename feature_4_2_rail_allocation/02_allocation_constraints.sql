-- RAIL_ALLOCATION integrity rules
USE kandypack_db;

ALTER TABLE rail_allocation
  ADD CONSTRAINT chk_alloc_qty_positive   CHECK (allocated_quantity > 0),
  ADD CONSTRAINT chk_alloc_space_positive CHECK (allocated_space > 0);