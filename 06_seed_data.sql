-- Kandypack Logistics Platform - Seed Data (MySQL 8.0)
USE kandypack_db;

-- Clear previous data
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE audit_log;
TRUNCATE TABLE delivery;
TRUNCATE TABLE roster_assignment;
TRUNCATE TABLE delivery_staff;
TRUNCATE TABLE truck;
TRUNCATE TABLE stock_adjustment;
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
(12, 'Lanka Retailers Ltd', 'CUSTOMER', 'customer1@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(13, 'Roshan Negombo Store Mgr', 'STORE_MGR', 'store.negombo@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(14, 'Chaminda Galle Store Mgr', 'STORE_MGR', 'store.galle@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(15, 'Ishara Matara Store Mgr', 'STORE_MGR', 'store.matara@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(16, 'Vithursan Jaffna Store Mgr', 'STORE_MGR', 'store.jaffna@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(17, 'Nadeesha Trinco Store Mgr', 'STORE_MGR', 'store.trinco@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW'),
(18, 'Ajith Kandy Store Mgr', 'STORE_MGR', 'store.kandy@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW');

-- 2. PRODUCT
INSERT INTO product (product_id, product_name, category, unit_price, unit_weight_kg, space_consumption_rate, description, image_url) VALUES
(1, 'Kandy Pure Ceylon BOPF Tea (25kg Crate)', 'Ceylon Tea & Spices', 4500.00, 25.00, 0.0500, 'High-grown export grade Ceylon Black BOPF tea packed in moisture-resistant foil-lined wooden crates.', '/products/tea_crate.jpg'),
(2, 'Ceylon Spices & Cinnamon Sack (20kg)', 'Ceylon Tea & Spices', 3800.00, 20.00, 0.0400, 'Sun-cured Ceylon alba cinnamon sticks, premium cardamom pods, and organic cloves in heavy-duty jute sacks.', '/products/spices_sack.jpg'),
(3, 'Nuwara Eliya Highland Vegetables Crate (30kg)', 'Fresh Produce & FMCG', 2600.00, 30.00, 0.0800, 'Ventilated farm-fresh crates of premium highland carrots, leeks, bell peppers, and cabbage for rapid rail transit.', '/products/produce_crates.jpg'),
(4, 'Ceylon Virgin Coconut Oil Canister (20L / 18kg)', 'Fresh Produce & FMCG', 4200.00, 18.00, 0.0450, 'Cold-pressed extra-virgin coconut oil in food-grade sealed HDPE transit containers.', '/products/coconut_oil.jpg'),
(5, 'Kandy Handloom Cotton Textile Bolts (25kg)', 'Garments & Textiles', 5200.00, 25.00, 0.0600, 'Protective shrink-wrapped bolts of traditional Sri Lankan batik and handloom cotton textiles for commercial retail.', '/products/textile_rolls.jpg'),
(6, 'Apparel & Garment Export Cartons (20kg)', 'Garments & Textiles', 4800.00, 20.00, 0.0550, 'Triple-wall corrugated export master cartons of finished garments with security straps and barcoded tags.', '/products/garments_box.jpg'),
(7, 'Traditional Brassware & Metal Crafts Crate (35kg)', 'Hardware & Industrial', 7500.00, 35.00, 0.0700, 'Handcrafted polished brass oil lamps, brassware, and cultural souvenirs cushioned in protective wooden crates.', '/products/brassware_crate.jpg'),
(8, 'Precision Industrial Machinery Spares (40kg)', 'Hardware & Industrial', 8900.00, 40.00, 0.0850, 'High-grade steel gears, shafts, and mechanical components packed in shock-absorbing foam-lined transport cases.', '/products/machinery_parts.jpg');

-- 3. STATION_STORE
INSERT INTO station_store (station_id, city, address, manager_id) VALUES
(1, 'Colombo', 'Colombo Main Railway Station Store, Colombo 10', 4),
(2, 'Negombo', 'Negombo Station Hub, Negombo', 13),
(3, 'Galle', 'Galle Station Hub, Galle', 14),
(4, 'Matara', 'Matara Station Hub, Matara', 15),
(5, 'Jaffna', 'Jaffna Station Hub, Jaffna', 16),
(6, 'Trincomalee', 'Trincomalee Station Hub, Trincomalee', 17),
(7, 'Kandy', 'Kandy Central Goods Yard, Kandy', 18);

-- 4. STORAGE_LOCATION
INSERT INTO storage_location (location_id, station_id, location_code, location_type) VALUES
(1, 1, 'BIN-A1', 'General Goods'),
(2, 1, 'BIN-A2', 'General Goods'),
(3, 3, 'BIN-G1', 'General Goods'),
(4, 1, 'BIN-A3', 'Cold Storage'),
(5, 2, 'BIN-N1', 'General Goods'),
(6, 2, 'BIN-N2', 'General Goods'),
(7, 3, 'BIN-G2', 'General Goods'),
(8, 4, 'BIN-M1', 'General Goods'),
(9, 4, 'BIN-M2', 'General Goods'),
(10, 5, 'BIN-J1', 'General Goods'),
(11, 5, 'BIN-J2', 'General Goods'),
(12, 6, 'BIN-T1', 'General Goods'),
(13, 6, 'BIN-T2', 'General Goods'),
(14, 7, 'BIN-K1', 'General Goods'),
(15, 7, 'BIN-K2', 'General Goods');

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


-- 12. INVENTORY (Feature 4.4 - starting stock per station/product)
INSERT INTO inventory (inventory_id, station_id, product_id, location_id, stored_quantity) VALUES
(1, 1, 1, 1, 500),
(2, 1, 2, 2, 300),
(3, 1, 3, 4, 150),
(4, 1, 4, NULL, 80),
(5, 3, 1, 3, 200),
(6, 3, 3, 7, 90),
(7, 2, 1, 5, 120),
(8, 7, 4, 14, 50);

-- 12b. STOCK_ADJUSTMENT (Feature 4.4 - example damage/shortage history)
INSERT INTO stock_adjustment (adjustment_id, inventory_id, quantity_delta, reason, adjusted_by) VALUES
(1, 3, -5, 'Damaged during unloading - crushed carton', 5),
(2, 1, -2, 'Missing item - short shipment from train', 5);

-- 13. MANIFEST (Feature 4.4 - train arrivals at stations)
INSERT INTO manifest (manifest_id, station_id, trip_id, received_at, status) VALUES
(1, 1, 1, '2026-08-10 09:45:00', 'RECEIVED'),
(2, 1, 2, NULL, 'PENDING'),
(3, 3, 3, NULL, 'PENDING');
