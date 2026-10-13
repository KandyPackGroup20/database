-- Kandypack Logistics Platform - Comprehensive Seed Data (MySQL 8.0)
-- Compliant with Project 3 Specification: >= 40 Orders, >= 10 Routes, Multi-trip Rail, Full Delivery Life-cycle
USE kandypack_db;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE notification;
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

-- 1. USER ACCOUNTS (Internal Staff with @kandypack.lk and Customers)
INSERT INTO user (user_id, name, role, email, password_hash, force_password_reset, station_id) VALUES
(1, 'System Superadmin', 'SUPERADMIN', 'admin@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(2, 'Kimal Logistics Mgr', 'LOGISTICS_MGR', 'logistics@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(3, 'Dilan Fleet Dispatcher', 'DISPATCHER', 'dispatch@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 1),
(4, 'Sunil Colombo Store Mgr', 'STORE_MGR', 'store.colombo@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 1),
(5, 'Kamal Warehouse Staff', 'WAREHOUSE_STAFF', 'wh.staff1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 1),
(6, 'Driver Kasun', 'DRIVER', 'driver1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 1),
(7, 'Driver Nimal', 'DRIVER', 'driver2@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 2),
(8, 'Driver Ruwan', 'DRIVER', 'driver3@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 3),
(9, 'Assistant Pathum', 'ASSISTANT', 'assistant1@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 1),
(10, 'Assistant Janith', 'ASSISTANT', 'assistant2@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 2),
(11, 'Assistant Mahesh', 'ASSISTANT', 'assistant3@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 3),
(12, 'Lanka Retailers Ltd', 'CUSTOMER', 'customer1@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(13, 'Roshan Negombo Store Mgr', 'STORE_MGR', 'store.negombo@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 2),
(14, 'Chaminda Galle Store Mgr', 'STORE_MGR', 'store.galle@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 3),
(15, 'Ishara Matara Store Mgr', 'STORE_MGR', 'store.matara@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 4),
(16, 'Vithursan Jaffna Store Mgr', 'STORE_MGR', 'store.jaffna@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 5),
(17, 'Nadeesha Trinco Store Mgr', 'STORE_MGR', 'store.trinco@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 6),
(18, 'Ajith Kandy Store Mgr', 'STORE_MGR', 'store.kandy@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 7),
(19, 'Dharshana Galle Dispatcher', 'DISPATCHER', 'dispatch.galle@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 3),
(20, 'Nuwan Galle Warehouse Staff', 'WAREHOUSE_STAFF', 'wh.galle@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 3),
(21, 'Western Distributors PLC', 'CUSTOMER', 'western.dist@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(22, 'Southern Mart Enterprises', 'CUSTOMER', 'southern.mart@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(23, 'Negombo Seafood & Logistics', 'CUSTOMER', 'negombo.sea@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(24, 'Ruhuna Traders', 'CUSTOMER', 'ruhuna.traders@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(25, 'Northern Wholesale Hub', 'CUSTOMER', 'northern.hub@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(26, 'Eastern Ocean Cargo', 'CUSTOMER', 'eastern.cargo@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(27, 'Kelaniya Commercial Stores', 'CUSTOMER', 'kelaniya.stores@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(28, 'Galle Heritage Retail', 'CUSTOMER', 'galle.retail@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(29, 'Katunayake Air Cargo Consignees', 'CUSTOMER', 'katunayake.cargo@gmail.com', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, NULL),
(30, 'Driver Thilak', 'DRIVER', 'driver4@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 4),
(31, 'Driver Sahan', 'DRIVER', 'driver5@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 5),
(32, 'Assistant Chathura', 'ASSISTANT', 'assistant4@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 4),
(33, 'Assistant Dineth', 'ASSISTANT', 'assistant5@kandypack.lk', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW', 0, 5);

-- 2. PRODUCT (FMCG and Industrial Goods with Train Space Consumption Rates)
INSERT INTO product (product_id, product_name, category, unit_price, unit_weight_kg, space_consumption_rate, description, image_url) VALUES
(1, 'Kandy Pure Ceylon BOPF Tea (25kg Crate)', 'Ceylon Tea & Spices', 4500.00, 25.00, 0.0500, 'High-grown export grade Ceylon Black BOPF tea packed in moisture-resistant foil-lined wooden crates.', '/products/tea_crate.jpg'),
(2, 'Ceylon Spices & Cinnamon Sack (20kg)', 'Ceylon Tea & Spices', 3800.00, 20.00, 0.0400, 'Sun-cured Ceylon alba cinnamon sticks, premium cardamom pods, and organic cloves in heavy-duty jute sacks.', '/products/spices_sack.jpg'),
(3, 'Nuwara Eliya Highland Vegetables Crate (30kg)', 'Fresh Produce & FMCG', 2600.00, 30.00, 0.0800, 'Ventilated farm-fresh crates of premium highland carrots, leeks, bell peppers, and cabbage for rapid rail transit.', '/products/produce_crates.jpg'),
(4, 'Ceylon Virgin Coconut Oil Canister (20L / 18kg)', 'Fresh Produce & FMCG', 4200.00, 18.00, 0.0450, 'Cold-pressed extra-virgin coconut oil in food-grade sealed HDPE transit containers.', '/products/coconut_oil.jpg'),
(5, 'Kandy Handloom Cotton Textile Bolts (25kg)', 'Garments & Textiles', 5200.00, 25.00, 0.0600, 'Protective shrink-wrapped bolts of traditional Sri Lankan batik and handloom cotton textiles for commercial retail.', '/products/textile_rolls.jpg'),
(6, 'Apparel & Garment Export Cartons (20kg)', 'Garments & Textiles', 4800.00, 20.00, 0.0550, 'Triple-wall corrugated export master cartons of finished garments with security straps and barcoded tags.', '/products/garments_box.jpg'),
(7, 'Traditional Brassware & Metal Crafts Crate (35kg)', 'Hardware & Industrial', 7500.00, 35.00, 0.0700, 'Handcrafted polished brass oil lamps, brassware, and cultural souvenirs cushioned in protective wooden crates.', '/products/brassware_crate.jpg'),
(8, 'Precision Industrial Machinery Spares (40kg)', 'Hardware & Industrial', 8900.00, 40.00, 0.0850, 'High-grade steel gears, shafts, and mechanical components packed in shock-absorbing foam-lined transport cases.', '/products/machinery_parts.jpg');

-- 3. STATION_STORE (All main destination hubs and Kandy central goods shed)
INSERT INTO station_store (station_id, city, address, manager_id) VALUES
(1, 'Colombo', 'Colombo Main Railway Station Store, Colombo 10', 4),
(2, 'Negombo', 'Negombo Station Hub, Negombo', 13),
(3, 'Galle', 'Galle Station Hub, Galle', 14),
(4, 'Matara', 'Matara Station Hub, Matara', 15),
(5, 'Jaffna', 'Jaffna Station Hub, Jaffna', 16),
(6, 'Trincomalee', 'Trincomalee Station Hub, Trincomalee', 17),
(7, 'Kandy', 'Kandy Central Goods Yard, Kandy', 18);

-- 4. STORAGE_LOCATION (Depot storage bins for verified unloading)
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

-- 5. TRAIN_TRIP (Valid Sri Lanka Railways Schedule from Kandy to All Main Cities)
INSERT INTO train_trip (trip_id, origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES
(1, 7, 1, '2026-02-10 06:00:00', '2026-02-10 09:30:00', 30.00, 'COMPLETED'),
(2, 7, 1, '2026-02-10 14:00:00', '2026-02-10 17:30:00', 40.00, 'COMPLETED'),
(3, 7, 3, '2026-02-11 07:00:00', '2026-02-11 11:30:00', 50.00, 'COMPLETED'),
(4, 7, 2, '2026-05-15 06:30:00', '2026-05-15 10:00:00', 35.00, 'COMPLETED'),
(5, 7, 4, '2026-05-16 07:00:00', '2026-05-16 12:00:00', 40.00, 'COMPLETED'),
(6, 7, 5, '2026-05-17 05:00:00', '2026-05-17 12:30:00', 50.00, 'COMPLETED'),
(7, 7, 6, '2026-05-18 06:00:00', '2026-05-18 12:00:00', 35.00, 'COMPLETED'),
(8, 7, 1, '2026-08-10 06:00:00', '2026-08-10 09:30:00', 30.00, 'COMPLETED'),
(9, 7, 1, '2026-08-10 14:00:00', '2026-08-10 17:30:00', 40.00, 'COMPLETED'),
(10, 7, 3, '2026-08-11 07:00:00', '2026-08-11 11:30:00', 50.00, 'COMPLETED'),
(11, 7, 2, '2026-08-12 06:30:00', '2026-08-12 10:00:00', 35.00, 'COMPLETED'),
(12, 7, 4, '2026-08-13 07:00:00', '2026-08-13 12:00:00', 40.00, 'COMPLETED'),
(13, 7, 5, '2026-08-14 05:00:00', '2026-08-14 12:30:00', 50.00, 'COMPLETED'),
(14, 7, 6, '2026-08-15 06:00:00', '2026-08-15 12:00:00', 35.00, 'COMPLETED'),
(15, 7, 1, '2026-10-18 06:00:00', '2026-10-18 09:30:00', 30.00, 'SCHEDULED'),
(16, 7, 1, '2026-10-18 14:00:00', '2026-10-18 17:30:00', 40.00, 'SCHEDULED'),
(17, 7, 3, '2026-10-19 07:00:00', '2026-10-19 11:30:00', 50.00, 'SCHEDULED'),
(18, 7, 2, '2026-10-20 06:30:00', '2026-10-20 10:00:00', 35.00, 'SCHEDULED'),
(19, 7, 4, '2026-10-21 07:00:00', '2026-10-21 12:00:00', 40.00, 'SCHEDULED'),
(20, 7, 5, '2026-10-22 05:00:00', '2026-10-22 12:30:00', 50.00, 'SCHEDULED'),
(21, 7, 6, '2026-10-23 06:00:00', '2026-10-23 12:00:00', 35.00, 'SCHEDULED');

-- 6. DELIVERY_ROUTE (11 predefined routes with maximum delivery times)
INSERT INTO delivery_route (route_id, station_id, route_name, max_delivery_time) VALUES
(1, 1, 'Colombo Central Commercial Route', '04:30:00'),
(2, 1, 'Greater Colombo Industrial Hub Route', '06:00:00'),
(3, 3, 'Galle Coastal Route', '05:00:00'),
(4, 2, 'Negombo Coastal & Industrial Route', '04:00:00'),
(5, 4, 'Matara Southern Express Route', '04:30:00'),
(6, 5, 'Jaffna Northern Peninsula Route', '05:00:00'),
(7, 6, 'Trincomalee Eastern Port Route', '04:30:00'),
(8, 1, 'Colombo Suburbs & Kelaniya Route', '04:00:00'),
(9, 3, 'Galle Southern Inland Route', '05:30:00'),
(10, 7, 'Kandy Central Goods & Peradeniya Local Route', '03:30:00'),
(11, 2, 'Negombo Airport & Katunayake Logistics Route', '03:00:00');

-- 7. CUSTOMER (10 Commercial Customers paired with delivery routes)
INSERT INTO customer (customer_id, user_id, customer_name, route_id, phone, address_line, city, postal_code) VALUES
(1, 12, 'Lanka Retailers Ltd', 1, '0112345678', 'Main Street Wholesalers, Pettah', 'Colombo 11', '01100'),
(2, 21, 'Western Distributors PLC', 2, '0115551234', '12 Industrial Zone, Homagama', 'Colombo', '10200'),
(3, 22, 'Southern Mart Enterprises', 3, '0912234567', '45 Galle Bazaar Road', 'Galle', '80000'),
(4, 23, 'Negombo Seafood & Logistics', 4, '0312229876', '78 Sea Street', 'Negombo', '11500'),
(5, 24, 'Ruhuna Traders', 5, '0412224455', '88 Beach Road', 'Matara', '81000'),
(6, 25, 'Northern Wholesale Hub', 6, '0212223344', '105 Hospital Road', 'Jaffna', '40000'),
(7, 26, 'Eastern Ocean Cargo', 7, '0262225566', '33 Harbour Way', 'Trincomalee', '31000'),
(8, 27, 'Kelaniya Commercial Stores', 8, '0112911222', '140 Biyagama Road', 'Kelaniya', '11600'),
(9, 28, 'Galle Heritage Retail', 9, '0912248899', '21 Dutch Fort Rampart', 'Galle', '80000'),
(10, 29, 'Katunayake Air Cargo Consignees', 11, '0112255888', 'FTZ Phase 2, Katunayake', 'Negombo', '11450');

-- 8. TRUCK (Dedicated Fleet per Station)
INSERT INTO truck (truck_id, plate_number, capacity, station_id) VALUES
(1, 'WP-CAB-1001', 3500.00, 1),
(2, 'WP-CAB-1002', 3500.00, 1),
(3, 'WP-CAB-1003', 3500.00, 2),
(4, 'SP-CAB-2001', 5000.00, 3),
(5, 'SP-CAB-2002', 4500.00, 4),
(6, 'NP-CAB-3001', 4000.00, 5),
(7, 'EP-CAB-4001', 3500.00, 6),
(8, 'CP-CAB-5001', 3500.00, 7);

-- 9. DELIVERY_STAFF (Drivers & Assistants with accumulated weekly work hours)
INSERT INTO delivery_staff (delivery_staff_id, user_id, license_number, work_hours) VALUES
(1, 6, 'LIC-D-101', 34.00),
(2, 7, 'LIC-D-102', 28.00),
(3, 8, 'LIC-D-103', 39.50),
(4, 9, 'LIC-A-201', 42.00),
(5, 10, 'LIC-A-202', 57.00),
(6, 11, 'LIC-A-203', 30.00),
(7, 30, 'LIC-D-104', 18.00),
(8, 31, 'LIC-D-105', 22.00),
(9, 32, 'LIC-A-204', 24.00),
(10, 33, 'LIC-A-205', 19.00);

-- 10. CUSTOMER_ORDER (42 Orders spanning Q1, Q2, Q3, Q4 with >= 7 days advance notice)
INSERT INTO customer_order (order_id, customer_id, order_date, delivery_date, status, delivery_route_id, delivery_address, recipient_name, recipient_phone) VALUES
(1001, 1, '2026-02-01', '2026-02-10', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'),
(1002, 2, '2026-02-02', '2026-02-10', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'),
(1003, 3, '2026-02-03', '2026-02-11', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'),
(1004, 1, '2026-02-15', '2026-02-23', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'),
(1005, 8, '2026-02-16', '2026-02-24', 'COMPLETED', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'),
(1006, 9, '2026-03-01', '2026-03-10', 'COMPLETED', 9, '21 Dutch Fort Rampart', 'Galle Heritage Retail', '0912248899'),
(1007, 2, '2026-03-05', '2026-03-14', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'),
(1008, 3, '2026-03-10', '2026-03-18', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'),
(1009, 1, '2026-03-15', '2026-03-23', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'),
(1010, 8, '2026-03-20', '2026-03-28', 'COMPLETED', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'),
(1011, 4, '2026-05-01', '2026-05-15', 'COMPLETED', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'),
(1012, 10, '2026-05-02', '2026-05-15', 'COMPLETED', 11, 'FTZ Phase 2, Katunayake', 'Katunayake Air Cargo Consignees', '0112255888'),
(1013, 5, '2026-05-03', '2026-05-16', 'COMPLETED', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'),
(1014, 6, '2026-05-04', '2026-05-17', 'COMPLETED', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'),
(1015, 7, '2026-05-05', '2026-05-18', 'COMPLETED', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'),
(1016, 1, '2026-05-10', '2026-05-20', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'),
(1017, 2, '2026-05-12', '2026-05-22', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'),
(1018, 3, '2026-05-15', '2026-05-25', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'),
(1019, 4, '2026-06-01', '2026-06-10', 'COMPLETED', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'),
(1020, 5, '2026-06-05', '2026-06-15', 'COMPLETED', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'),
(1021, 6, '2026-06-10', '2026-06-20', 'COMPLETED', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'),
(1022, 7, '2026-06-15', '2026-06-25', 'COMPLETED', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'),
(1023, 1, '2026-08-01', '2026-08-10', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'),
(1024, 2, '2026-08-01', '2026-08-10', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'),
(1025, 3, '2026-08-02', '2026-08-11', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'),
(1026, 4, '2026-08-03', '2026-08-12', 'COMPLETED', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'),
(1027, 5, '2026-08-04', '2026-08-13', 'COMPLETED', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'),
(1028, 6, '2026-08-05', '2026-08-14', 'COMPLETED', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'),
(1029, 7, '2026-08-06', '2026-08-15', 'COMPLETED', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'),
(1030, 8, '2026-08-10', '2026-08-18', 'COMPLETED', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'),
(1031, 9, '2026-08-12', '2026-08-20', 'DELIVERED', 9, '21 Dutch Fort Rampart', 'Galle Heritage Retail', '0912248899'),
(1032, 10, '2026-08-15', '2026-08-23', 'DELIVERED', 11, 'FTZ Phase 2, Katunayake', 'Katunayake Air Cargo Consignees', '0112255888'),
(1033, 1, '2026-09-01', '2026-09-10', 'DELIVERED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'),
(1034, 2, '2026-09-05', '2026-09-14', 'DELIVERED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'),
(1035, 3, '2026-10-01', '2026-10-18', 'OUT_FOR_DELIVERY', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'),
(1036, 4, '2026-10-02', '2026-10-18', 'OUT_FOR_DELIVERY', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'),
(1037, 5, '2026-10-03', '2026-10-19', 'ARRIVED_AT_STATION_STORE', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'),
(1038, 6, '2026-10-04', '2026-10-20', 'ARRIVED_AT_STATION_STORE', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'),
(1039, 7, '2026-10-05', '2026-10-21', 'SCHEDULED_FOR_RAIL', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'),
(1040, 8, '2026-10-06', '2026-10-21', 'SCHEDULED_FOR_RAIL', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'),
(1041, 9, '2026-10-07', '2026-10-22', 'PENDING_RAIL_SCHEDULING', 9, '21 Dutch Fort Rampart', 'Galle Heritage Retail', '0912248899'),
(1042, 10, '2026-10-07', '2026-10-22', 'PENDING_RAIL_SCHEDULING', 11, 'FTZ Phase 2, Katunayake', 'Katunayake Air Cargo Consignees', '0112255888');

-- 11. ORDER_ITEMS (Multi-item Orders with Unit Prices and Product References)
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price_at_order) VALUES
(1, 1001, 4, 67, 4200.00),
(2, 1002, 7, 74, 7500.00),
(3, 1002, 3, 32, 2600.00),
(4, 1003, 2, 81, 3800.00),
(5, 1004, 5, 88, 5200.00),
(6, 1004, 6, 54, 4800.00),
(7, 1004, 7, 27, 7500.00),
(8, 1005, 8, 95, 8900.00),
(9, 1006, 3, 22, 2600.00),
(10, 1006, 7, 26, 7500.00),
(11, 1007, 6, 29, 4800.00),
(12, 1008, 1, 36, 4500.00),
(13, 1008, 2, 48, 3800.00),
(14, 1008, 3, 39, 2600.00),
(15, 1009, 4, 43, 4200.00),
(16, 1010, 7, 50, 7500.00),
(17, 1010, 3, 20, 2600.00),
(18, 1011, 2, 57, 3800.00),
(19, 1012, 5, 64, 5200.00),
(20, 1012, 6, 42, 4800.00),
(21, 1012, 7, 51, 7500.00),
(22, 1013, 8, 71, 8900.00),
(23, 1014, 3, 78, 2600.00),
(24, 1014, 7, 14, 7500.00),
(25, 1015, 6, 85, 4800.00),
(26, 1016, 1, 92, 4500.00),
(27, 1016, 2, 36, 3800.00),
(28, 1016, 3, 23, 2600.00),
(29, 1017, 4, 99, 4200.00),
(30, 1018, 7, 26, 7500.00),
(31, 1018, 3, 58, 2600.00),
(32, 1019, 2, 33, 3800.00),
(33, 1020, 5, 40, 5200.00),
(34, 1020, 6, 30, 4800.00),
(35, 1020, 7, 35, 7500.00),
(36, 1021, 8, 47, 8900.00),
(37, 1022, 3, 54, 2600.00),
(38, 1022, 7, 52, 7500.00),
(39, 1023, 6, 61, 4800.00),
(40, 1024, 1, 68, 4500.00),
(41, 1024, 2, 24, 3800.00),
(42, 1024, 3, 47, 2600.00),
(43, 1025, 4, 75, 4200.00),
(44, 1026, 7, 82, 7500.00),
(45, 1026, 3, 46, 2600.00),
(46, 1027, 2, 89, 3800.00),
(47, 1028, 5, 96, 5200.00),
(48, 1028, 6, 18, 4800.00),
(49, 1028, 7, 19, 7500.00),
(50, 1029, 8, 23, 8900.00),
(51, 1030, 3, 30, 2600.00),
(52, 1030, 7, 40, 7500.00),
(53, 1031, 6, 37, 4800.00),
(54, 1031, 4, 51, 4200.00),
(55, 1032, 1, 44, 4500.00),
(56, 1032, 2, 12, 3800.00),
(57, 1032, 3, 31, 2600.00),
(58, 1033, 4, 51, 4200.00),
(59, 1033, 6, 23, 4800.00),
(60, 1034, 7, 58, 7500.00),
(61, 1034, 3, 34, 2600.00),
(62, 1035, 2, 65, 3800.00),
(63, 1035, 8, 45, 8900.00),
(64, 1036, 5, 72, 5200.00),
(65, 1036, 6, 56, 4800.00),
(66, 1036, 7, 43, 7500.00),
(67, 1037, 8, 79, 8900.00),
(68, 1037, 2, 17, 3800.00),
(69, 1038, 3, 86, 2600.00),
(70, 1038, 7, 28, 7500.00),
(71, 1039, 6, 93, 4800.00),
(72, 1039, 4, 39, 4200.00),
(73, 1040, 1, 20, 4500.00),
(74, 1040, 2, 50, 3800.00),
(75, 1040, 3, 15, 2600.00),
(76, 1041, 4, 27, 4200.00),
(77, 1041, 6, 11, 4800.00),
(78, 1042, 7, 34, 7500.00),
(79, 1042, 3, 22, 2600.00);

-- 12. MANIFEST (Station Train Arrival Records)
INSERT INTO manifest (manifest_id, station_id, trip_id, received_at, status) VALUES
(1, 1, 1, '2026-02-10 09:45:00', 'RECEIVED'),
(2, 1, 2, '2026-02-10 17:45:00', 'RECEIVED'),
(3, 3, 3, '2026-02-11 11:45:00', 'RECEIVED'),
(4, 2, 4, '2026-05-15 10:15:00', 'RECEIVED'),
(5, 4, 5, '2026-05-16 12:15:00', 'RECEIVED'),
(6, 5, 6, '2026-05-17 12:45:00', 'RECEIVED'),
(7, 6, 7, '2026-05-18 12:15:00', 'RECEIVED'),
(8, 1, 8, '2026-08-10 09:45:00', 'RECEIVED'),
(9, 1, 9, '2026-08-10 17:45:00', 'RECEIVED'),
(10, 3, 10, '2026-08-11 11:45:00', 'RECEIVED'),
(11, 2, 11, '2026-08-12 10:15:00', 'RECEIVED'),
(12, 4, 12, '2026-08-13 12:15:00', 'RECEIVED'),
(13, 5, 13, '2026-08-14 12:45:00', 'RECEIVED'),
(14, 6, 14, '2026-08-15 12:15:00', 'RECEIVED'),
(15, 1, 15, NULL, 'PENDING'),
(16, 1, 16, NULL, 'PENDING'),
(17, 3, 17, NULL, 'PENDING'),
(18, 2, 18, NULL, 'PENDING'),
(19, 4, 19, NULL, 'PENDING'),
(20, 5, 20, NULL, 'PENDING'),
(21, 6, 21, NULL, 'PENDING')
ON DUPLICATE KEY UPDATE status=VALUES(status), received_at=VALUES(received_at);

-- 13. RAIL_ALLOCATION (Space allocation per train trip, single and multi-trip spillover)
INSERT INTO rail_allocation (allocation_id, order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by, allocated_at) VALUES
(1, 1, 1, 67, 3.0150, 2, '2026-08-02 09:00:00'),
(2, 2, 2, 74, 5.1800, 2, '2026-08-02 09:00:00'),
(3, 3, 2, 32, 2.5600, 2, '2026-08-02 09:00:00'),
(4, 4, 1, 81, 3.2400, 2, '2026-08-02 09:00:00'),
(5, 5, 3, 88, 5.2800, 2, '2026-08-02 09:00:00'),
(6, 6, 3, 54, 2.9700, 2, '2026-08-02 09:00:00'),
(7, 7, 3, 27, 1.8900, 2, '2026-08-02 09:00:00'),
(8, 8, 1, 95, 8.0750, 2, '2026-08-02 09:00:00'),
(9, 9, 3, 22, 1.7600, 2, '2026-08-02 09:00:00'),
(10, 10, 3, 26, 1.8200, 2, '2026-08-02 09:00:00'),
(11, 11, 1, 29, 1.5950, 2, '2026-08-02 09:00:00'),
(12, 12, 2, 36, 1.8000, 2, '2026-08-02 09:00:00'),
(13, 13, 2, 48, 1.9200, 2, '2026-08-02 09:00:00'),
(14, 14, 2, 39, 3.1200, 2, '2026-08-02 09:00:00'),
(15, 15, 1, 43, 1.9350, 2, '2026-08-02 09:00:00'),
(16, 16, 3, 50, 3.5000, 2, '2026-08-02 09:00:00'),
(17, 17, 3, 20, 1.6000, 2, '2026-08-02 09:00:00'),
(18, 18, 7, 57, 2.2800, 2, '2026-08-02 09:00:00'),
(19, 19, 4, 64, 3.8400, 2, '2026-08-02 09:00:00'),
(20, 20, 4, 42, 2.3100, 2, '2026-08-02 09:00:00'),
(21, 21, 4, 51, 3.5700, 2, '2026-08-02 09:00:00'),
(22, 22, 5, 71, 6.0350, 2, '2026-08-02 09:00:00'),
(23, 23, 6, 78, 6.2400, 2, '2026-08-02 09:00:00'),
(24, 24, 6, 14, 0.9800, 2, '2026-08-02 09:00:00'),
(25, 25, 7, 85, 4.6750, 2, '2026-08-02 09:00:00'),
(26, 26, 4, 92, 4.6000, 2, '2026-08-02 09:00:00'),
(27, 27, 4, 36, 1.4400, 2, '2026-08-02 09:00:00'),
(28, 28, 4, 23, 1.8400, 2, '2026-08-02 09:00:00'),
(29, 29, 5, 99, 4.4550, 2, '2026-08-02 09:00:00'),
(30, 30, 6, 26, 1.8200, 2, '2026-08-02 09:00:00'),
(31, 31, 6, 58, 4.6400, 2, '2026-08-02 09:00:00'),
(32, 32, 7, 33, 1.3200, 2, '2026-08-02 09:00:00'),
(33, 33, 4, 40, 2.4000, 2, '2026-08-02 09:00:00'),
(34, 34, 4, 30, 1.6500, 2, '2026-08-02 09:00:00'),
(35, 35, 4, 35, 2.4500, 2, '2026-08-02 09:00:00'),
(36, 36, 5, 47, 3.9950, 2, '2026-08-02 09:00:00'),
(37, 37, 6, 54, 4.3200, 2, '2026-08-02 09:00:00'),
(38, 38, 6, 52, 3.6400, 2, '2026-08-02 09:00:00'),
(39, 39, 9, 61, 3.3550, 2, '2026-08-02 09:00:00'),
(40, 40, 10, 68, 3.4000, 2, '2026-08-02 09:00:00'),
(41, 41, 10, 24, 0.9600, 2, '2026-08-02 09:00:00'),
(42, 42, 10, 47, 3.7600, 2, '2026-08-02 09:00:00'),
(43, 43, 11, 75, 3.3750, 2, '2026-08-02 09:00:00'),
(44, 44, 12, 82, 5.7400, 2, '2026-08-02 09:00:00'),
(45, 45, 12, 46, 3.6800, 2, '2026-08-02 09:00:00'),
(46, 46, 13, 89, 3.5600, 2, '2026-08-02 09:00:00'),
(47, 47, 14, 96, 5.7600, 2, '2026-08-02 09:00:00'),
(48, 48, 14, 18, 0.9900, 2, '2026-08-02 09:00:00'),
(49, 49, 14, 19, 1.3300, 2, '2026-08-02 09:00:00'),
(50, 50, 8, 23, 1.9550, 2, '2026-08-02 09:00:00'),
(51, 51, 9, 30, 2.4000, 2, '2026-08-02 09:00:00'),
(52, 52, 9, 40, 2.8000, 2, '2026-08-02 09:00:00'),
(53, 53, 10, 37, 2.0350, 2, '2026-08-02 09:00:00'),
(54, 54, 10, 51, 2.2950, 2, '2026-08-02 09:00:00'),
(55, 55, 11, 44, 2.2000, 2, '2026-08-02 09:00:00'),
(56, 56, 11, 12, 0.4800, 2, '2026-08-02 09:00:00'),
(57, 57, 11, 31, 2.4800, 2, '2026-08-02 09:00:00'),
(58, 58, 12, 51, 2.2950, 2, '2026-08-02 09:00:00'),
(59, 59, 12, 23, 1.2650, 2, '2026-08-02 09:00:00'),
(60, 60, 13, 58, 4.0600, 2, '2026-08-02 09:00:00'),
(61, 61, 13, 34, 2.7200, 2, '2026-08-02 09:00:00'),
(62, 62, 18, 65, 2.6000, 2, '2026-08-02 09:00:00'),
(63, 63, 18, 45, 3.8250, 2, '2026-08-02 09:00:00'),
(64, 64, 19, 72, 4.3200, 2, '2026-08-02 09:00:00'),
(65, 65, 19, 56, 3.0800, 2, '2026-08-02 09:00:00'),
(66, 66, 19, 43, 3.0100, 2, '2026-08-02 09:00:00'),
(67, 67, 20, 79, 6.7150, 2, '2026-08-02 09:00:00'),
(68, 68, 20, 17, 0.6800, 2, '2026-08-02 09:00:00'),
(69, 69, 15, 86, 6.8800, 2, '2026-08-02 09:00:00'),
(70, 70, 15, 28, 1.9600, 2, '2026-08-02 09:00:00'),
(71, 71, 16, 93, 5.1150, 2, '2026-08-02 09:00:00'),
(72, 72, 16, 39, 1.7550, 2, '2026-08-02 09:00:00'),
(73, 73, 17, 20, 1.0000, 2, '2026-08-02 09:00:00'),
(74, 74, 17, 50, 2.0000, 2, '2026-08-02 09:00:00'),
(75, 75, 17, 15, 1.2000, 2, '2026-08-02 09:00:00');

-- 14. INVENTORY & STOCK ADJUSTMENT (Station Stock Holdings & Audit Adjustments)
INSERT INTO inventory (inventory_id, station_id, product_id, location_id, stored_quantity) VALUES
(1, 1, 1, 1, 450),
(2, 1, 2, 2, 320),
(3, 1, 3, 4, 180),
(4, 1, 4, 1, 95),
(5, 3, 1, 3, 210),
(6, 3, 3, 7, 110),
(7, 2, 1, 5, 140),
(8, 2, 2, 6, 85),
(9, 4, 3, 8, 70),
(10, 5, 1, 10, 160),
(11, 6, 2, 12, 90),
(12, 7, 4, 14, 65);

INSERT INTO stock_adjustment (adjustment_id, station_id, product_id, quantity_adjusted, inventory_id, quantity_delta, reason, reported_by, adjusted_by) VALUES
(1, 1, 3, -5, 3, -5, 'Damaged during unloading - crushed carton', 5, 5),
(2, 1, 1, -2, 1, -2, 'Missing item - short shipment from train', 5, 5),
(3, 3, 1, 10, 5, 10, 'Stock reconciliation surplus from Colombo train manifest', 5, 5);

-- 15. ROSTER_ASSIGNMENT (Compliant Truck Dispatches: Drivers <= 40h, Assistants <= 60h, Non-overlapping, No consecutive driver runs)
INSERT INTO roster_assignment (roster_id, request_key, route_id, truck_id, driver_id, assistant_id, dispatcher_id, start_time, end_time, status) VALUES
(1, 'REQ-ROST-0001', 1, 1, 1, 4, 3, '2026-02-10 10:00:00', '2026-02-10 14:00:00', 'COMPLETED'),
(2, 'REQ-ROST-0002', 2, 2, 2, 4, 3, '2026-02-10 18:00:00', '2026-02-10 22:30:00', 'COMPLETED'),
(3, 'REQ-ROST-0003', 3, 4, 3, 6, 19, '2026-02-11 12:00:00', '2026-02-11 16:30:00', 'COMPLETED'),
(4, 'REQ-ROST-0004', 4, 3, 2, 5, 3, '2026-05-15 10:30:00', '2026-05-15 14:00:00', 'COMPLETED'),
(5, 'REQ-ROST-0005', 5, 5, 7, 9, 3, '2026-05-16 12:30:00', '2026-05-16 16:30:00', 'COMPLETED'),
(6, 'REQ-ROST-0006', 6, 6, 8, 10, 3, '2026-05-17 13:00:00', '2026-05-17 17:30:00', 'COMPLETED'),
(7, 'REQ-ROST-0007', 7, 7, 1, 4, 3, '2026-05-18 12:30:00', '2026-05-18 16:30:00', 'COMPLETED'),
(8, 'REQ-ROST-0008', 1, 1, 1, 4, 3, '2026-08-10 10:00:00', '2026-08-10 14:00:00', 'COMPLETED'),
(9, 'REQ-ROST-0009', 2, 2, 2, 5, 3, '2026-08-10 18:00:00', '2026-08-10 22:30:00', 'COMPLETED'),
(10, 'REQ-ROST-0010', 3, 4, 3, 6, 19, '2026-08-11 12:00:00', '2026-08-11 16:30:00', 'COMPLETED'),
(11, 'REQ-ROST-0011', 4, 3, 2, 5, 3, '2026-08-12 10:30:00', '2026-08-12 14:00:00', 'COMPLETED'),
(12, 'REQ-ROST-0012', 5, 5, 7, 9, 3, '2026-08-13 12:30:00', '2026-08-13 16:30:00', 'COMPLETED'),
(13, 'REQ-ROST-0013', 6, 6, 8, 10, 3, '2026-08-14 13:00:00', '2026-08-14 17:30:00', 'COMPLETED'),
(14, 'REQ-ROST-0014', 7, 7, 1, 4, 3, '2026-08-15 12:30:00', '2026-08-15 16:30:00', 'COMPLETED'),
(15, 'REQ-ROST-0015', 8, 1, 2, 5, 3, '2026-08-18 10:00:00', '2026-08-18 13:30:00', 'COMPLETED'),
(16, 'REQ-ROST-0016', 9, 4, 3, 6, 19, '2026-08-20 12:00:00', '2026-08-20 17:00:00', 'COMPLETED'),
(17, 'REQ-ROST-0017', 11, 3, 1, 4, 3, '2026-08-23 09:00:00', '2026-08-23 11:30:00', 'COMPLETED'),
(18, 'REQ-ROST-0018', 1, 1, 2, 5, 3, '2026-09-10 10:00:00', '2026-09-10 14:00:00', 'COMPLETED'),
(19, 'REQ-ROST-0019', 2, 2, 1, 4, 3, '2026-09-14 10:00:00', '2026-09-14 15:30:00', 'COMPLETED'),
(20, 'REQ-ROST-0020', 3, 4, 3, 6, 19, '2026-10-18 09:00:00', '2026-10-18 13:30:00', 'IN_TRANSIT'),
(21, 'REQ-ROST-0021', 4, 3, 2, 5, 3, '2026-10-18 10:00:00', '2026-10-18 13:30:00', 'IN_TRANSIT');

-- 16. DELIVERY (Doorstep Deliveries linked to Customer Orders and Roster Runs)
INSERT INTO delivery (delivery_id, roster_id, order_id, delivered_at, delivery_status, proof_reference, assigned_at, assigned_by, cargo_weight_kg) VALUES
(1, 1, 1001, '2026-02-10 13:45:00', 'DELIVERED', 'Signed by Recipient M. Fernando (NIC 841920391V)', '2026-02-10 09:50:00', 3, 500.00),
(2, 2, 1002, '2026-02-10 22:15:00', 'DELIVERED', 'Handed over to warehouse supervisor, seal verified', '2026-02-10 17:50:00', 3, 750.00),
(3, 3, 1003, '2026-02-11 16:15:00', 'DELIVERED', 'Signed by Store Mgr K. De Silva', '2026-02-11 11:50:00', 19, 600.00),
(4, 1, 1004, '2026-02-23 13:30:00', 'DELIVERED', 'Direct customer signature, undamaged', '2026-02-23 09:50:00', 3, 450.00),
(5, 2, 1005, '2026-02-24 13:30:00', 'DELIVERED', 'Delivered to loading dock 2, Pettah', '2026-02-24 09:50:00', 3, 800.00),
(6, 3, 1006, '2026-03-10 16:00:00', 'DELIVERED', 'Proof slip signed by Galle retail mgr', '2026-03-10 11:50:00', 19, 350.00),
(7, 2, 1007, '2026-03-14 13:00:00', 'DELIVERED', 'Customer verified all crates intact', '2026-03-14 09:50:00', 3, 620.00),
(8, 3, 1008, '2026-03-18 16:15:00', 'DELIVERED', 'Southern Mart receiving dock, stamp confirmed', '2026-03-18 11:50:00', 19, 580.00),
(9, 1, 1009, '2026-03-23 13:30:00', 'DELIVERED', 'Pettah Main St signed by cashier', '2026-03-23 09:50:00', 3, 400.00),
(10, 2, 1010, '2026-03-28 13:30:00', 'DELIVERED', 'Kelaniya hub receipt verified', '2026-03-28 09:50:00', 3, 720.00),
(11, 4, 1011, '2026-05-15 13:45:00', 'DELIVERED', 'Negombo cold store gate 1 signed', '2026-05-15 10:20:00', 3, 650.00),
(12, 4, 1012, '2026-05-15 13:30:00', 'DELIVERED', 'Katunayake FTZ customs cleared & signed', '2026-05-15 10:20:00', 3, 850.00),
(13, 5, 1013, '2026-05-16 16:15:00', 'DELIVERED', 'Matara wholesale store stamp & signature', '2026-05-16 12:20:00', 3, 540.00),
(14, 6, 1014, '2026-05-17 17:00:00', 'DELIVERED', 'Jaffna Hospital Rd receiving verified', '2026-05-17 12:50:00', 3, 680.00),
(15, 7, 1015, '2026-05-18 16:15:00', 'DELIVERED', 'Trincomalee harbour warehouse verified', '2026-05-18 12:20:00', 3, 490.00),
(16, 8, 1023, '2026-08-10 13:45:00', 'DELIVERED', 'Pettah main street receipt verified', '2026-08-10 09:50:00', 3, 500.00),
(17, 9, 1024, '2026-08-10 22:15:00', 'DELIVERED', 'Industrial zone delivery signed by manager', '2026-08-10 17:50:00', 3, 750.00),
(18, 10, 1025, '2026-08-11 16:15:00', 'DELIVERED', 'Galle Fort retail receipt confirmed', '2026-08-11 11:50:00', 19, 600.00),
(19, 11, 1026, '2026-08-12 13:45:00', 'DELIVERED', 'Negombo seafood depot stamp', '2026-08-12 10:20:00', 3, 650.00),
(20, 12, 1027, '2026-08-13 16:15:00', 'DELIVERED', 'Matara express store received', '2026-08-13 12:20:00', 3, 540.00),
(21, 13, 1028, '2026-08-14 17:00:00', 'DELIVERED', 'Jaffna northern peninsula verified', '2026-08-14 12:50:00', 3, 680.00),
(22, 14, 1029, '2026-08-15 16:15:00', 'DELIVERED', 'Trincomalee port road signed', '2026-08-15 12:20:00', 3, 490.00),
(23, 15, 1030, '2026-08-18 13:15:00', 'DELIVERED', 'Kelaniya retail receiving stamp', '2026-08-18 09:50:00', 3, 420.00),
(24, 16, 1031, '2026-08-20 16:45:00', 'DELIVERED', 'Galle inland store signature', '2026-08-20 11:50:00', 19, 390.00),
(25, 17, 1032, '2026-08-23 11:15:00', 'DELIVERED', 'Katunayake cargo bay 4 signature', '2026-08-23 08:50:00', 3, 810.00),
(26, 18, 1033, '2026-09-10 13:45:00', 'DELIVERED', 'Colombo central signed', '2026-09-10 09:50:00', 3, 510.00),
(27, 19, 1034, '2026-09-14 15:15:00', 'DELIVERED', 'Greater colombo signed', '2026-09-14 09:50:00', 3, 670.00),
(28, 20, 1035, NULL, 'IN_TRANSIT', 'Dispatched on SP-CAB-2001 (Driver Ruwan)', '2026-10-18 08:50:00', 19, 580.00),
(29, 21, 1036, NULL, 'IN_TRANSIT', 'Dispatched on WP-CAB-1003 (Driver Nimal)', '2026-10-18 09:50:00', 3, 610.00);

-- 17. AUDIT_LOG (Initial Audit Trail for Dispatches)
INSERT INTO audit_log (audit_id, user_id, action, entity_id, outcome, occurred_at, entity_name, roster_id) VALUES
(1, 3, 'ASSIGN_ROSTER', 1, 'ACCEPTED', '2026-02-10 09:50:00', 'roster_assignment', 1),
(2, 3, 'ASSIGN_ROSTER', 2, 'ACCEPTED', '2026-02-10 17:50:00', 'roster_assignment', 2),
(3, 19, 'ASSIGN_ROSTER', 3, 'ACCEPTED', '2026-02-11 11:50:00', 'roster_assignment', 3),
(4, 3, 'ASSIGN_ROSTER', 8, 'ACCEPTED', '2026-08-10 09:50:00', 'roster_assignment', 8),
(5, 3, 'ASSIGN_ROSTER', 9, 'ACCEPTED', '2026-08-10 17:50:00', 'roster_assignment', 9),
(6, 19, 'ASSIGN_ROSTER', 10, 'ACCEPTED', '2026-08-11 11:50:00', 'roster_assignment', 10);
