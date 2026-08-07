-- Kandypack Logistics Platform - Seed Data (MySQL 8.0)
USE kandypack_db;

-- Clear previous data
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE roster_audit_logs;
TRUNCATE TABLE roster_assignments;
TRUNCATE TABLE station_inventory;
TRUNCATE TABLE order_trip_allocations;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
TRUNCATE TABLE train_trips;
TRUNCATE TABLE trucks;
TRUNCATE TABLE drivers;
TRUNCATE TABLE assistants;
TRUNCATE TABLE delivery_routes;
TRUNCATE TABLE products;
TRUNCATE TABLE station_stores;
TRUNCATE TABLE users;
SET FOREIGN_KEY_CHECKS = 1;

-- 1. USERS (Pass hash placeholder: 'hashed_password_123')
INSERT INTO users (user_id, email, password_hash, full_name, role) VALUES
(1, 'admin@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'System Superadmin', 'SUPERADMIN'),
(2, 'logistics@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Kimal Logistics Mgr', 'LOGISTICS_MGR'),
(3, 'dispatch@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Dilan Fleet Dispatcher', 'DISPATCHER'),
(4, 'store.colombo@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Sunil Colombo Store Mgr', 'STORE_MGR'),
(5, 'wh.staff1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Kamal Warehouse Staff', 'WAREHOUSE_STAFF'),
(6, 'driver1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Driver D-101 (Kasun)', 'DRIVER'),
(7, 'driver2@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Driver D-102 (Nimal)', 'DRIVER'),
(8, 'driver3@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Driver D-103 (Ruwan)', 'DRIVER'),
(9, 'customer1@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 'Lanka Retailers Ltd', 'CUSTOMER');

-- 2. STATIONS
INSERT INTO station_stores (station_id, city_name, manager_user_id) VALUES
('CMB', 'Colombo Regional Station', 4),
('NEG', 'Negombo Station Hub', NULL),
('GAL', 'Galle Station Hub', NULL),
('MAT', 'Matara Station Hub', NULL),
('JAF', 'Jaffna Station Hub', NULL),
('TRIN', 'Trincomalee Station Hub', NULL);

-- 3. PRODUCTS (Space rate in m^3)
INSERT INTO products (product_id, name, unit_sku, space_consumption_rate, category) VALUES
(1, 'Kandy Pure Ceylon Tea 500g Pack', 'SKU-TEA-500G', 0.0500, 'Beverages'),
(2, 'Kandy Spice Mixture Box (12 Units)', 'SKU-SPICE-BOX', 0.1200, 'Food Products'),
(3, 'FMCG Biscuits Master Carton (24 Packs)', 'SKU-BISC-CRT', 0.2500, 'Snacks'),
(4, 'Coconut Oil 5L Container', 'SKU-OIL-5L', 0.1800, 'Cooking Oils');

-- 4. TRAIN TRIPS (Kandy -> Colombo)
INSERT INTO train_trips (trip_id, trip_code, origin_hub, destination_hub, departure_time, arrival_time, total_capacity_cubic_m, remaining_capacity_cubic_m, status) VALUES
(1, 'TRIN-CMB-001', 'KDY', 'CMB', '2026-08-10 06:00:00', '2026-08-10 09:30:00', 30.00, 30.00, 'SCHEDULED'),
(2, 'TRIN-CMB-002', 'KDY', 'CMB', '2026-08-10 14:00:00', '2026-08-10 17:30:00', 40.00, 40.00, 'SCHEDULED'),
(3, 'TRIN-GAL-001', 'KDY', 'GAL', '2026-08-11 07:00:00', '2026-08-11 11:30:00', 50.00, 50.00, 'SCHEDULED');

-- 5. TRUCKS
INSERT INTO trucks (truck_id, plate_number, station_id, capacity_kg, status) VALUES
(1, 'WP-CAB-1001', 'CMB', 3500.00, 'AVAILABLE'),
(2, 'WP-CAB-1002', 'CMB', 3500.00, 'AVAILABLE'),
(3, 'SP-CAB-2001', 'GAL', 5000.00, 'AVAILABLE');

-- 6. DRIVERS & ASSISTANTS
INSERT INTO drivers (driver_id, user_id, full_name, license_no, accumulated_weekly_hours, consecutive_routes_count) VALUES
(1, 6, 'Driver D-101 (Kasun)', 'LIC-D-101', 38.00, 0), -- Near 40h cap!
(2, 7, 'Driver D-102 (Nimal)', 'LIC-D-102', 27.00, 0),
(3, 8, 'Driver D-103 (Ruwan)', 'LIC-D-103', 40.00, 1); -- Cap reached!

INSERT INTO assistants (assistant_id, user_id, full_name, accumulated_weekly_hours, consecutive_routes_count) VALUES
(1, 1, 'Assistant A-201 (Pathum)', 45.00, 0),
(2, 2, 'Assistant A-202 (Janith)', 58.00, 1), -- Near 60h cap!
(3, 3, 'Assistant A-203 (Mahesh)', 33.00, 2); -- 2 consecutive routes!

-- 7. DELIVERY ROUTES
INSERT INTO delivery_routes (route_id, station_id, route_name, estimated_duration_hours) VALUES
(1, 'CMB', 'Colombo Central Commercial Route', 4.50),
(2, 'CMB', 'Greater Colombo Industrial Hub Route', 6.00),
(3, 'GAL', 'Galle Coastal Route', 5.00);

-- 8. SAMPLE PENDING ORDER (Requiring 50 m^3 space -> test spillover across Trip 1 and Trip 2)
INSERT INTO orders (order_id, customer_id, destination_hub, delivery_address, delivery_date, status) VALUES
(1001, 9, 'CMB', 'Main Street Wholesalers, Pettah, Colombo 11', '2026-08-15', 'PENDING_RAIL_SCHEDULING');

-- Order item: 200 cartons of Biscuits (200 * 0.25 m^3 = 50 m^3)
INSERT INTO order_items (order_item_id, order_id, product_id, quantity, total_space_required) VALUES
(1, 1001, 3, 200, 50.00);
