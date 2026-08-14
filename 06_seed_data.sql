-- Kandypack Logistics Platform - Seed Data (MySQL 8.0)
USE kandypack_db;

-- Clear previous data
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE audit_log;
TRUNCATE TABLE delivery;
TRUNCATE TABLE roster_assignment;
TRUNCATE TABLE delivery_staff;
TRUNCATE TABLE truck;
TRUNCATE TABLE inventory;
TRUNCATE TABLE manifest;
TRUNCATE TABLE rail_allocation;
TRUNCATE TABLE order_status_history;
TRUNCATE TABLE order_item;
TRUNCATE TABLE customer_order;
TRUNCATE TABLE customer;
TRUNCATE TABLE delivery_route;
TRUNCATE TABLE train_trip;
TRUNCATE TABLE storage_location;
TRUNCATE TABLE station_store;
TRUNCATE TABLE product;
TRUNCATE TABLE user;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. USER
INSERT INTO user (user_id, name, role, email, password_hash) VALUES
(1, 'System Superadmin', 'SUPERADMIN', 'admin@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(2, 'Kimal Logistics Mgr', 'LOGISTICS_MGR', 'logistics@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(3, 'Dilan Fleet Dispatcher', 'DISPATCHER', 'dispatch@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(4, 'Sunil Colombo Store Mgr', 'STORE_MGR', 'store.colombo@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(5, 'Kamal Warehouse Staff', 'WAREHOUSE_STAFF', 'wh.staff1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(6, 'Driver Kasun', 'DRIVER', 'driver1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(7, 'Driver Nimal', 'DRIVER', 'driver2@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(8, 'Driver Ruwan', 'DRIVER', 'driver3@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(9, 'Assistant Pathum', 'ASSISTANT', 'assistant1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(10, 'Assistant Janith', 'ASSISTANT', 'assistant2@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(11, 'Assistant Mahesh', 'ASSISTANT', 'assistant3@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(12, 'Lanka Retailers Ltd', 'CUSTOMER', 'customer1@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW');

-- 2. PRODUCT
INSERT INTO product (product_id, product_name, unit_price, space_consumption_rate) VALUES
(1, 'Kandy Pure Ceylon Tea 500g Pack', 450.00, 0.0500),
(2, 'Kandy Spice Mixture Box (12 Units)', 850.00, 0.1200),
(3, 'FMCG Biscuits Master Carton (24 Packs)', 1200.00, 0.2500),
(4, 'Coconut Oil 5L Container', 2400.00, 0.1800);

-- 3. STATION_STORE
INSERT INTO station_store (station_id, city, address) VALUES
(1, 'Colombo', 'Colombo Main Railway Station Store, Colombo 10'),
(2, 'Negombo', 'Negombo Station Hub, Negombo'),
(3, 'Galle', 'Galle Station Hub, Galle'),
(4, 'Matara', 'Matara Station Hub, Matara'),
(5, 'Jaffna', 'Jaffna Station Hub, Jaffna'),
(6, 'Trincomalee', 'Trincomalee Station Hub, Trincomalee'),
(7, 'Kandy', 'Kandy Central Goods Yard, Kandy');

-- 4. STORAGE_LOCATION
INSERT INTO storage_location (location_id, station_id, location_code, location_type) VALUES
(1, 1, 'BIN-A1', 'General Goods'),
(2, 1, 'BIN-A2', 'General Goods'),
(3, 3, 'BIN-G1', 'General Goods');

-- 5. TRAIN_TRIP (Kandy -> Colombo, Galle)
INSERT INTO train_trip (trip_id, origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES
(1, 7, 1, '2026-08-10 06:00:00', '2026-08-10 09:30:00', 30.00, 'SCHEDULED'),
(2, 7, 1, '2026-08-10 14:00:00', '2026-08-10 17:30:00', 40.00, 'SCHEDULED'),
(3, 7, 3, '2026-08-11 07:00:00', '2026-08-11 11:30:00', 50.00, 'SCHEDULED');

-- 6. DELIVERY_ROUTE
INSERT INTO delivery_route (route_id, station_id, route_name, max_delivery_time) VALUES
(1, 1, 'Colombo Central Commercial Route', '04:30:00'),
(2, 1, 'Greater Colombo Industrial Hub Route', '06:00:00'),
(3, 3, 'Galle Coastal Route', '05:00:00');

-- 7. CUSTOMER
INSERT INTO customer (customer_id, user_id, customer_name, route_id, phone, address_line, city, postal_code) VALUES
(1, 12, 'Lanka Retailers Ltd', 1, '0112345678', 'Main Street Wholesalers, Pettah', 'Colombo 11', '01100');

-- 8. CUSTOMER_ORDER
INSERT INTO customer_order (order_id, customer_id, order_date, delivery_date, status) VALUES
(1001, 1, '2026-08-08', '2026-08-15', 'PENDING_RAIL_SCHEDULING');

-- 9. ORDER_ITEM
INSERT INTO order_item (order_item_id, order_id, product_id, quantity) VALUES
(1, 1001, 3, 200); -- 200 * 0.25 = 50.00 total space

-- 10. TRUCK
INSERT INTO truck (truck_id, plate_number, capacity) VALUES
(1, 'WP-CAB-1001', 3500.00),
(2, 'WP-CAB-1002', 3500.00),
(3, 'SP-CAB-2001', 5000.00);

-- 11. DELIVERY_STAFF (Consolidated drivers and assistants)
INSERT INTO delivery_staff (delivery_staff_id, user_id, license_number, work_hours) VALUES
(1, 6, 'LIC-D-101', 38.00), -- Driver 1
(2, 7, 'LIC-D-102', 27.00), -- Driver 2
(3, 8, 'LIC-D-103', 40.00), -- Driver 3 (cap reached)
(4, 9, 'LIC-A-201', 45.00), -- Assistant 1
(5, 10, 'LIC-A-202', 58.00), -- Assistant 2
(6, 11, 'LIC-A-203', 33.00); -- Assistant 3
