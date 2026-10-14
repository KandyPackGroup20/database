# Generator for Kandypack comprehensive seed data
# Guarantees:
# - At least 40 orders (42 orders)
# - All orders have DATEDIFF(delivery_date, order_date) >= 7 (strictly respects 7-day advance order policy)
# - At least 10 routes (11 routes covering all 6 destination cities + Kandy)
# - Valid train schedule connecting Kandy to all 6 destination cities with defined capacities
# - Multi-item orders with product references
# - Rail allocations with single-trip and multi-trip spillover
# - Manifests, Inventory, Trucks, Delivery Staff, Roster Assignments, and Deliveries
# - All 6 Management Reports return rich, meaningful data

import datetime

def generate_seed_sql():
    sql = []
    sql.append("-- Kandypack Logistics Platform - Comprehensive Seed Data (MySQL 8.0)")
    sql.append("-- Compliant with Project 3 Specification: >= 40 Orders, >= 10 Routes, Multi-trip Rail, Full Delivery Life-cycle")
    sql.append("USE kandypack_db;\n")
    sql.append("SET FOREIGN_KEY_CHECKS = 0;")
    sql.append("TRUNCATE TABLE notification;")
    sql.append("TRUNCATE TABLE audit_log;")
    sql.append("TRUNCATE TABLE delivery;")
    sql.append("TRUNCATE TABLE roster_assignment;")
    sql.append("TRUNCATE TABLE delivery_staff;")
    sql.append("TRUNCATE TABLE truck;")
    sql.append("TRUNCATE TABLE stock_adjustment;")
    sql.append("TRUNCATE TABLE inventory;")
    sql.append("TRUNCATE TABLE manifest;")
    sql.append("TRUNCATE TABLE rail_allocation;")
    sql.append("TRUNCATE TABLE order_status_history;")
    sql.append("TRUNCATE TABLE order_item;")
    sql.append("TRUNCATE TABLE customer_order;")
    sql.append("TRUNCATE TABLE customer;")
    sql.append("TRUNCATE TABLE delivery_route;")
    sql.append("TRUNCATE TABLE train_trip;")
    sql.append("TRUNCATE TABLE storage_location;")
    sql.append("TRUNCATE TABLE station_store;")
    sql.append("TRUNCATE TABLE product;")
    sql.append("TRUNCATE TABLE user;")
    sql.append("SET FOREIGN_KEY_CHECKS = 1;\n")

    # 1. USERS
    sql.append("-- 1. USER ACCOUNTS (Internal Staff with @kandypack.lk and Customers)")
    sql.append("INSERT INTO user (user_id, name, role, email, password_hash, force_password_reset, station_id) VALUES")
    pw = "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW"
    users = [
        (1, 'System Superadmin', 'SUPERADMIN', 'admin@kandypack.lk', pw, 0, 'NULL'),
        (2, 'Kimal Logistics Mgr', 'LOGISTICS_MGR', 'logistics@kandypack.lk', pw, 0, 'NULL'),
        (3, 'Dilan Fleet Dispatcher', 'DISPATCHER', 'dispatch@kandypack.lk', pw, 0, 1),
        (4, 'Sunil Colombo Store Mgr', 'STORE_MGR', 'store.colombo@kandypack.lk', pw, 0, 1),
        (5, 'Kamal Warehouse Staff', 'WAREHOUSE_STAFF', 'wh.staff1@kandypack.lk', pw, 0, 1),
        (6, 'Driver Kasun', 'DRIVER', 'driver1@kandypack.lk', pw, 0, 1),
        (7, 'Driver Nimal', 'DRIVER', 'driver2@kandypack.lk', pw, 0, 2),
        (8, 'Driver Ruwan', 'DRIVER', 'driver3@kandypack.lk', pw, 0, 3),
        (9, 'Assistant Pathum', 'ASSISTANT', 'assistant1@kandypack.lk', pw, 0, 1),
        (10, 'Assistant Janith', 'ASSISTANT', 'assistant2@kandypack.lk', pw, 0, 2),
        (11, 'Assistant Mahesh', 'ASSISTANT', 'assistant3@kandypack.lk', pw, 0, 3),
        (12, 'Lanka Retailers Ltd', 'CUSTOMER', 'customer1@gmail.com', pw, 0, 'NULL'),
        (13, 'Roshan Negombo Store Mgr', 'STORE_MGR', 'store.negombo@kandypack.lk', pw, 0, 2),
        (14, 'Chaminda Galle Store Mgr', 'STORE_MGR', 'store.galle@kandypack.lk', pw, 0, 3),
        (15, 'Ishara Matara Store Mgr', 'STORE_MGR', 'store.matara@kandypack.lk', pw, 0, 4),
        (16, 'Vithursan Jaffna Store Mgr', 'STORE_MGR', 'store.jaffna@kandypack.lk', pw, 0, 5),
        (17, 'Nadeesha Trinco Store Mgr', 'STORE_MGR', 'store.trinco@kandypack.lk', pw, 0, 6),
        (18, 'Ajith Kandy Store Mgr', 'STORE_MGR', 'store.kandy@kandypack.lk', pw, 0, 7),
        (19, 'Dharshana Galle Dispatcher', 'DISPATCHER', 'dispatch.galle@kandypack.lk', pw, 0, 3),
        (20, 'Nuwan Galle Warehouse Staff', 'WAREHOUSE_STAFF', 'wh.galle@kandypack.lk', pw, 0, 3),
        (21, 'Western Distributors PLC', 'CUSTOMER', 'western.dist@gmail.com', pw, 0, 'NULL'),
        (22, 'Southern Mart Enterprises', 'CUSTOMER', 'southern.mart@gmail.com', pw, 0, 'NULL'),
        (23, 'Negombo Seafood & Logistics', 'CUSTOMER', 'negombo.sea@gmail.com', pw, 0, 'NULL'),
        (24, 'Ruhuna Traders', 'CUSTOMER', 'ruhuna.traders@gmail.com', pw, 0, 'NULL'),
        (25, 'Northern Wholesale Hub', 'CUSTOMER', 'northern.hub@gmail.com', pw, 0, 'NULL'),
        (26, 'Eastern Ocean Cargo', 'CUSTOMER', 'eastern.cargo@gmail.com', pw, 0, 'NULL'),
        (27, 'Kelaniya Commercial Stores', 'CUSTOMER', 'kelaniya.stores@gmail.com', pw, 0, 'NULL'),
        (28, 'Galle Heritage Retail', 'CUSTOMER', 'galle.retail@gmail.com', pw, 0, 'NULL'),
        (29, 'Katunayake Air Cargo Consignees', 'CUSTOMER', 'katunayake.cargo@gmail.com', pw, 0, 'NULL'),
        (30, 'Driver Thilak', 'DRIVER', 'driver4@kandypack.lk', pw, 0, 4),
        (31, 'Driver Sahan', 'DRIVER', 'driver5@kandypack.lk', pw, 0, 5),
        (32, 'Assistant Chathura', 'ASSISTANT', 'assistant4@kandypack.lk', pw, 0, 4),
        (33, 'Assistant Dineth', 'ASSISTANT', 'assistant5@kandypack.lk', pw, 0, 5)
    ]
    u_lines = [f"({u[0]}, '{u[1]}', '{u[2]}', '{u[3]}', '{u[4]}', {u[5]}, {u[6]})" for u in users]
    sql.append(",\n".join(u_lines) + ";\n")

    # 2. PRODUCT
    sql.append("-- 2. PRODUCT (FMCG and Industrial Goods with Train Space Consumption Rates)")
    products = [
        (1, 'Kandy Pure Ceylon BOPF Tea (25kg Crate)', 'Ceylon Tea & Spices', 4500.00, 25.00, 0.0500, 'High-grown export grade Ceylon Black BOPF tea packed in moisture-resistant foil-lined wooden crates.', '/products/tea_crate.jpg'),
        (2, 'Ceylon Spices & Cinnamon Sack (20kg)', 'Ceylon Tea & Spices', 3800.00, 20.00, 0.0400, 'Sun-cured Ceylon alba cinnamon sticks, premium cardamom pods, and organic cloves in heavy-duty jute sacks.', '/products/spices_sack.jpg'),
        (3, 'Nuwara Eliya Highland Vegetables Crate (30kg)', 'Fresh Produce & FMCG', 2600.00, 30.00, 0.0800, 'Ventilated farm-fresh crates of premium highland carrots, leeks, bell peppers, and cabbage for rapid rail transit.', '/products/produce_crates.jpg'),
        (4, 'Ceylon Virgin Coconut Oil Canister (20L / 18kg)', 'Fresh Produce & FMCG', 4200.00, 18.00, 0.0450, 'Cold-pressed extra-virgin coconut oil in food-grade sealed HDPE transit containers.', '/products/coconut_oil.jpg'),
        (5, 'Kandy Handloom Cotton Textile Bolts (25kg)', 'Garments & Textiles', 5200.00, 25.00, 0.0600, 'Protective shrink-wrapped bolts of traditional Sri Lankan batik and handloom cotton textiles for commercial retail.', '/products/textile_rolls.jpg'),
        (6, 'Apparel & Garment Export Cartons (20kg)', 'Garments & Textiles', 4800.00, 20.00, 0.0550, 'Triple-wall corrugated export master cartons of finished garments with security straps and barcoded tags.', '/products/garments_box.jpg'),
        (7, 'Traditional Brassware & Metal Crafts Crate (35kg)', 'Hardware & Industrial', 7500.00, 35.00, 0.0700, 'Handcrafted polished brass oil lamps, brassware, and cultural souvenirs cushioned in protective wooden crates.', '/products/brassware_crate.jpg'),
        (8, 'Precision Industrial Machinery Spares (40kg)', 'Hardware & Industrial', 8900.00, 40.00, 0.0850, 'High-grade steel gears, shafts, and mechanical components packed in shock-absorbing foam-lined transport cases.', '/products/machinery_parts.jpg')
    ]
    p_lines = [f"({p[0]}, '{p[1]}', '{p[2]}', {p[3]:.2f}, {p[4]:.2f}, {p[5]:.4f}, '{p[6]}', '{p[7]}')" for p in products]
    sql.append("INSERT INTO product (product_id, product_name, category, unit_price, unit_weight_kg, space_consumption_rate, description, image_url) VALUES")
    sql.append(",\n".join(p_lines) + ";\n")

    # 3. STATION_STORE
    sql.append("-- 3. STATION_STORE (All main destination hubs and Kandy central goods shed)")
    stations = [
        (1, 'Colombo', 'Colombo Main Railway Station Store, Colombo 10', 4),
        (2, 'Negombo', 'Negombo Station Hub, Negombo', 13),
        (3, 'Galle', 'Galle Station Hub, Galle', 14),
        (4, 'Matara', 'Matara Station Hub, Matara', 15),
        (5, 'Jaffna', 'Jaffna Station Hub, Jaffna', 16),
        (6, 'Trincomalee', 'Trincomalee Station Hub, Trincomalee', 17),
        (7, 'Kandy', 'Kandy Central Goods Yard, Kandy', 18)
    ]
    s_lines = [f"({s[0]}, '{s[1]}', '{s[2]}', {s[3]})" for s in stations]
    sql.append("INSERT INTO station_store (station_id, city, address, manager_id) VALUES")
    sql.append(",\n".join(s_lines) + ";\n")

    # 4. STORAGE_LOCATION
    sql.append("-- 4. STORAGE_LOCATION (Depot storage bins for verified unloading)")
    locations = [
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
        (15, 7, 'BIN-K2', 'General Goods')
    ]
    loc_lines = [f"({l[0]}, {l[1]}, '{l[2]}', '{l[3]}')" for l in locations]
    sql.append("INSERT INTO storage_location (location_id, station_id, location_code, location_type) VALUES")
    sql.append(",\n".join(loc_lines) + ";\n")

    # 5. TRAIN_TRIP
    sql.append("-- 5. TRAIN_TRIP (Valid Sri Lanka Railways Schedule from Kandy to All Main Cities)")
    trips = [
        # Q1/Q2/Q3/Q4 Completed and Scheduled Trips
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
        (21, 7, 6, '2026-10-23 06:00:00', '2026-10-23 12:00:00', 35.00, 'SCHEDULED'),
        (22, 7, 1, '2026-05-19 06:00:00', '2026-05-19 09:30:00', 40.00, 'COMPLETED'),
        (23, 7, 3, '2026-05-20 07:00:00', '2026-05-20 11:30:00', 45.00, 'COMPLETED')
    ]
    t_lines = [f"({t[0]}, {t[1]}, {t[2]}, '{t[3]}', '{t[4]}', {t[5]:.2f}, '{t[6]}')" for t in trips]
    sql.append("INSERT INTO train_trip (trip_id, origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES")
    sql.append(",\n".join(t_lines) + ";\n")

    # 6. DELIVERY_ROUTE
    sql.append("-- 6. DELIVERY_ROUTE (11 predefined routes with maximum delivery times)")
    routes = [
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
        (11, 2, 'Negombo Airport & Katunayake Logistics Route', '03:00:00')
    ]
    r_lines = [f"({r[0]}, {r[1]}, '{r[2]}', '{r[3]}')" for r in routes]
    sql.append("INSERT INTO delivery_route (route_id, station_id, route_name, max_delivery_time) VALUES")
    sql.append(",\n".join(r_lines) + ";\n")

    # 7. CUSTOMER
    sql.append("-- 7. CUSTOMER (10 Commercial Customers paired with delivery routes)")
    customers = [
        (1, 12, 'Lanka Retailers Ltd', 1, '0112345678', 'Main Street Wholesalers, Pettah', 'Colombo 11', '01100'),
        (2, 21, 'Western Distributors PLC', 2, '0115551234', '12 Industrial Zone, Homagama', 'Colombo', '10200'),
        (3, 22, 'Southern Mart Enterprises', 3, '0912234567', '45 Galle Bazaar Road', 'Galle', '80000'),
        (4, 23, 'Negombo Seafood & Logistics', 4, '0312229876', '78 Sea Street', 'Negombo', '11500'),
        (5, 24, 'Ruhuna Traders', 5, '0412224455', '88 Beach Road', 'Matara', '81000'),
        (6, 25, 'Northern Wholesale Hub', 6, '0212223344', '105 Hospital Road', 'Jaffna', '40000'),
        (7, 26, 'Eastern Ocean Cargo', 7, '0262225566', '33 Harbour Way', 'Trincomalee', '31000'),
        (8, 27, 'Kelaniya Commercial Stores', 8, '0112911222', '140 Biyagama Road', 'Kelaniya', '11600'),
        (9, 28, 'Galle Heritage Retail', 9, '0912248899', '21 Dutch Fort Rampart', 'Galle', '80000'),
        (10, 29, 'Katunayake Air Cargo Consignees', 11, '0112255888', 'FTZ Phase 2, Katunayake', 'Negombo', '11450')
    ]
    c_lines = [f"({c[0]}, {c[1]}, '{c[2]}', {c[3]}, '{c[4]}', '{c[5]}', '{c[6]}', '{c[7]}')" for c in customers]
    sql.append("INSERT INTO customer (customer_id, user_id, customer_name, route_id, phone, address_line, city, postal_code) VALUES")
    sql.append(",\n".join(c_lines) + ";\n")

    # 8. TRUCK
    sql.append("-- 8. TRUCK (Dedicated Fleet per Station)")
    trucks = [
        (1, 'WP-CAB-1001', 3500.00, 1),
        (2, 'WP-CAB-1002', 3500.00, 1),
        (3, 'WP-CAB-1003', 3500.00, 2),
        (4, 'SP-CAB-2001', 5000.00, 3),
        (5, 'SP-CAB-2002', 4500.00, 4),
        (6, 'NP-CAB-3001', 4000.00, 5),
        (7, 'EP-CAB-4001', 3500.00, 6),
        (8, 'CP-CAB-5001', 3500.00, 7)
    ]
    trk_lines = [f"({t[0]}, '{t[1]}', {t[2]:.2f}, {t[3]})" for t in trucks]
    sql.append("INSERT INTO truck (truck_id, plate_number, capacity, station_id) VALUES")
    sql.append(",\n".join(trk_lines) + ";\n")

    # 9. DELIVERY_STAFF
    sql.append("-- 9. DELIVERY_STAFF (Drivers & Assistants with accumulated weekly work hours)")
    staff = [
        (1, 6, 'LIC-D-101', 34.00),   # Driver 1 (Safe)
        (2, 7, 'LIC-D-102', 28.00),   # Driver 2 (Safe)
        (3, 8, 'LIC-D-103', 39.50),   # Driver 3 (NEAR CAP WARNING! 39.5/40)
        (4, 9, 'LIC-A-201', 42.00),   # Assistant 1 (Safe)
        (5, 10, 'LIC-A-202', 57.00),  # Assistant 2 (NEAR CAP WARNING! 57/60)
        (6, 11, 'LIC-A-203', 30.00),  # Assistant 3 (Safe)
        (7, 30, 'LIC-D-104', 18.00),  # Driver 4 (Safe)
        (8, 31, 'LIC-D-105', 22.00),  # Driver 5 (Safe)
        (9, 32, 'LIC-A-204', 24.00),  # Assistant 4 (Safe)
        (10, 33, 'LIC-A-205', 19.00)  # Assistant 5 (Safe)
    ]
    stf_lines = [f"({s[0]}, {s[1]}, '{s[2]}', {s[3]:.2f})" for s in staff]
    sql.append("INSERT INTO delivery_staff (delivery_staff_id, user_id, license_number, work_hours) VALUES")
    sql.append(",\n".join(stf_lines) + ";\n")

    # 10. CUSTOMER_ORDER (42 orders: >= 40 orders required!)
    # All orders satisfy: DATEDIFF(delivery_date, order_date) >= 7 (No trigger violations!)
    sql.append("-- 10. CUSTOMER_ORDER (42 Orders spanning Q1, Q2, Q3, Q4 with >= 7 days advance notice)")
    orders = []
    # Q1 Orders: 1001-1010
    orders.append((1001, 1, '2026-02-01', '2026-02-10', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'))
    orders.append((1002, 2, '2026-02-02', '2026-02-10', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'))
    orders.append((1003, 3, '2026-02-03', '2026-02-11', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'))
    orders.append((1004, 1, '2026-02-15', '2026-02-23', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'))
    orders.append((1005, 8, '2026-02-16', '2026-02-24', 'COMPLETED', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'))
    orders.append((1006, 9, '2026-03-01', '2026-03-10', 'COMPLETED', 9, '21 Dutch Fort Rampart', 'Galle Heritage Retail', '0912248899'))
    orders.append((1007, 2, '2026-03-05', '2026-03-14', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'))
    orders.append((1008, 3, '2026-03-10', '2026-03-18', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'))
    orders.append((1009, 1, '2026-03-15', '2026-03-23', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'))
    orders.append((1010, 8, '2026-03-20', '2026-03-28', 'COMPLETED', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'))

    # Q2 Orders: 1011-1022
    orders.append((1011, 4, '2026-05-01', '2026-05-15', 'COMPLETED', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'))
    orders.append((1012, 10, '2026-05-02', '2026-05-15', 'COMPLETED', 11, 'FTZ Phase 2, Katunayake', 'Katunayake Air Cargo Consignees', '0112255888'))
    orders.append((1013, 5, '2026-05-03', '2026-05-16', 'COMPLETED', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'))
    orders.append((1014, 6, '2026-05-04', '2026-05-17', 'COMPLETED', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'))
    orders.append((1015, 7, '2026-05-05', '2026-05-18', 'COMPLETED', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'))
    orders.append((1016, 1, '2026-05-10', '2026-05-20', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'))
    orders.append((1017, 2, '2026-05-12', '2026-05-22', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'))
    orders.append((1018, 3, '2026-05-15', '2026-05-25', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'))
    orders.append((1019, 4, '2026-06-01', '2026-06-10', 'COMPLETED', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'))
    orders.append((1020, 5, '2026-06-05', '2026-06-15', 'COMPLETED', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'))
    orders.append((1021, 6, '2026-06-10', '2026-06-20', 'COMPLETED', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'))
    orders.append((1022, 7, '2026-06-15', '2026-06-25', 'COMPLETED', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'))

    # Q3 Orders: 1023-1034
    orders.append((1023, 1, '2026-08-01', '2026-08-10', 'COMPLETED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'))
    orders.append((1024, 2, '2026-08-01', '2026-08-10', 'COMPLETED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'))
    orders.append((1025, 3, '2026-08-02', '2026-08-11', 'COMPLETED', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'))
    orders.append((1026, 4, '2026-08-03', '2026-08-12', 'COMPLETED', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'))
    orders.append((1027, 5, '2026-08-04', '2026-08-13', 'COMPLETED', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'))
    orders.append((1028, 6, '2026-08-05', '2026-08-14', 'COMPLETED', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'))
    orders.append((1029, 7, '2026-08-06', '2026-08-15', 'COMPLETED', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'))
    orders.append((1030, 8, '2026-08-10', '2026-08-18', 'COMPLETED', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'))
    orders.append((1031, 9, '2026-08-12', '2026-08-20', 'DELIVERED', 9, '21 Dutch Fort Rampart', 'Galle Heritage Retail', '0912248899'))
    orders.append((1032, 10, '2026-08-15', '2026-08-23', 'DELIVERED', 11, 'FTZ Phase 2, Katunayake', 'Katunayake Air Cargo Consignees', '0112255888'))
    orders.append((1033, 1, '2026-09-01', '2026-09-10', 'DELIVERED', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678'))
    orders.append((1034, 2, '2026-09-05', '2026-09-14', 'DELIVERED', 2, '12 Industrial Zone, Homagama', 'Western Distributors PLC', '0115551234'))

    # Q4 Orders: 1035-1042
    orders.append((1035, 3, '2026-10-01', '2026-10-18', 'OUT_FOR_DELIVERY', 3, '45 Galle Bazaar Road', 'Southern Mart Enterprises', '0912234567'))
    orders.append((1036, 4, '2026-10-02', '2026-10-18', 'OUT_FOR_DELIVERY', 4, '78 Sea Street', 'Negombo Seafood & Logistics', '0312229876'))
    orders.append((1037, 5, '2026-10-03', '2026-10-19', 'ARRIVED_AT_STATION_STORE', 5, '88 Beach Road', 'Ruhuna Traders', '0412224455'))
    orders.append((1038, 6, '2026-10-04', '2026-10-20', 'ARRIVED_AT_STATION_STORE', 6, '105 Hospital Road', 'Northern Wholesale Hub', '0212223344'))
    orders.append((1039, 7, '2026-10-05', '2026-10-21', 'SCHEDULED_FOR_RAIL', 7, '33 Harbour Way', 'Eastern Ocean Cargo', '0262225566'))
    orders.append((1040, 8, '2026-10-06', '2026-10-21', 'SCHEDULED_FOR_RAIL', 8, '140 Biyagama Road', 'Kelaniya Commercial Stores', '0112911222'))
    orders.append((1041, 9, '2026-10-07', '2026-10-22', 'PENDING_RAIL_SCHEDULING', 9, '21 Dutch Fort Rampart', 'Galle Heritage Retail', '0912248899'))
    orders.append((1042, 10, '2026-10-07', '2026-10-22', 'PENDING_RAIL_SCHEDULING', 11, 'FTZ Phase 2, Katunayake', 'Katunayake Air Cargo Consignees', '0112255888'))

    ord_lines = [f"({o[0]}, {o[1]}, '{o[2]}', '{o[3]}', '{o[4]}', {o[5]}, '{o[6]}', '{o[7]}', '{o[8]}')" for o in orders]
    sql.append("INSERT INTO customer_order (order_id, customer_id, order_date, delivery_date, status, delivery_route_id, delivery_address, recipient_name, recipient_phone) VALUES")
    sql.append(",\n".join(ord_lines) + ";\n")

    # 11. ORDER_ITEMS (Multi-item orders)
    sql.append("-- 11. ORDER_ITEMS (Multi-item Orders with Unit Prices and Product References)")
    items = []
    item_id = 1
    import random
    # Seed deterministic items for all 42 orders
    prices = {1: 4500.0, 2: 3800.0, 3: 2600.0, 4: 4200.0, 5: 5200.0, 6: 4800.0, 7: 7500.0, 8: 8900.0}
    for o in orders:
        oid = o[0]
        # Item 1
        p1 = ((oid * 3) % 8) + 1
        q1 = 20 + ((oid * 7) % 80)
        items.append((item_id, oid, p1, q1, prices[p1]))
        item_id += 1
        # Item 2 for most orders
        if oid % 2 == 0 or oid > 1030:
            p2 = ((oid * 5) % 8) + 1
            if p2 == p1: p2 = (p2 % 8) + 1
            q2 = 10 + ((oid * 11) % 50)
            items.append((item_id, oid, p2, q2, prices[p2]))
            item_id += 1
        # Item 3 for wholesale orders
        if oid % 4 == 0:
            p3 = ((oid * 7) % 8) + 1
            if p3 in (p1, p2): p3 = ((p3 + 1) % 8) + 1
            q3 = 15 + ((oid * 13) % 40)
            items.append((item_id, oid, p3, q3, prices[p3]))
            item_id += 1

    oi_lines = [f"({it[0]}, {it[1]}, {it[2]}, {it[3]}, {it[4]:.2f})" for it in items]
    sql.append("INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price_at_order) VALUES")
    sql.append(",\n".join(oi_lines) + ";\n")

    # 12. MANIFEST (Must be before rail_allocation to prevent trigger conflict)
    sql.append("-- 12. MANIFEST (Station Train Arrival Records)")
    manifests = [
        (1, 1, 1, "'2026-02-10 09:45:00'", 'RECEIVED'),
        (2, 1, 2, "'2026-02-10 17:45:00'", 'RECEIVED'),
        (3, 3, 3, "'2026-02-11 11:45:00'", 'RECEIVED'),
        (4, 2, 4, "'2026-05-15 10:15:00'", 'RECEIVED'),
        (5, 4, 5, "'2026-05-16 12:15:00'", 'RECEIVED'),
        (6, 5, 6, "'2026-05-17 12:45:00'", 'RECEIVED'),
        (7, 6, 7, "'2026-05-18 12:15:00'", 'RECEIVED'),
        (8, 1, 8, "'2026-08-10 09:45:00'", 'RECEIVED'),
        (9, 1, 9, "'2026-08-10 17:45:00'", 'RECEIVED'),
        (10, 3, 10, "'2026-08-11 11:45:00'", 'RECEIVED'),
        (11, 2, 11, "'2026-08-12 10:15:00'", 'RECEIVED'),
        (12, 4, 12, "'2026-08-13 12:15:00'", 'RECEIVED'),
        (13, 5, 13, "'2026-08-14 12:45:00'", 'RECEIVED'),
        (14, 6, 14, "'2026-08-15 12:15:00'", 'RECEIVED'),
        (15, 1, 15, 'NULL', 'PENDING'),
        (16, 1, 16, 'NULL', 'PENDING'),
        (17, 3, 17, 'NULL', 'PENDING'),
        (18, 2, 18, 'NULL', 'PENDING'),
        (19, 4, 19, 'NULL', 'PENDING'),
        (20, 5, 20, 'NULL', 'PENDING'),
        (21, 6, 21, 'NULL', 'PENDING'),
        (22, 1, 22, "'2026-05-19 09:45:00'", 'RECEIVED'),
        (23, 3, 23, "'2026-05-20 11:45:00'", 'RECEIVED')
    ]
    mf_lines = [f"({m[0]}, {m[1]}, {m[2]}, {m[3]}, '{m[4]}')" for m in manifests]
    sql.append("INSERT INTO manifest (manifest_id, station_id, trip_id, received_at, status) VALUES")
    sql.append(",\n".join(mf_lines) + "\nON DUPLICATE KEY UPDATE status=VALUES(status), received_at=VALUES(received_at);\n")

    # 13. RAIL_ALLOCATIONS (Linking items to train trips, demonstrating multi-trip spillover)
    sql.append("-- 13. RAIL_ALLOCATION (Space allocation per train trip, single and multi-trip spillover)")
    route_station_map = {r[0]: r[1] for r in routes}
    order_station_map = {o[0]: route_station_map[o[5]] for o in orders}

    rates = {1: 0.0500, 2: 0.0400, 3: 0.0800, 4: 0.0450, 5: 0.0600, 6: 0.0550, 7: 0.0700, 8: 0.0850}
    allocs = []
    alloc_id = 1
    spillover_done = False

    # Assign rail trips strictly based on destination station and order date
    for it in items:
        it_id, oid, pid, qty, price = it
        dest_station = order_station_map[oid]

        # Select valid train trip whose destination_station_id strictly matches order's destination station
        if oid <= 1010:
            # Q1 Trips: Station 1 -> Trip 1 or 2, Station 3 -> Trip 3
            if dest_station == 1:
                trip_id = 1 if oid % 2 == 1 else 2
            elif dest_station == 3:
                trip_id = 3
            else:
                trip_id = 1
        elif oid <= 1022:
            # Q2 Trips: Station 1 -> Trip 22, Station 2 -> Trip 4, Station 3 -> Trip 23, Station 4 -> Trip 5, Station 5 -> Trip 6, Station 6 -> Trip 7
            if dest_station == 1:
                trip_id = 22
            elif dest_station == 2:
                trip_id = 4
            elif dest_station == 3:
                trip_id = 23
            elif dest_station == 4:
                trip_id = 5
            elif dest_station == 5:
                trip_id = 6
            elif dest_station == 6:
                trip_id = 7
            else:
                trip_id = 4
        elif oid <= 1034:
            # Q3 Trips: Station 1 -> Trip 8 or 9, Station 2 -> Trip 11, Station 3 -> Trip 10, Station 4 -> Trip 12, Station 5 -> Trip 13, Station 6 -> Trip 14
            if dest_station == 1:
                trip_id = 8 if oid % 2 == 1 else 9
            elif dest_station == 2:
                trip_id = 11
            elif dest_station == 3:
                trip_id = 10
            elif dest_station == 4:
                trip_id = 12
            elif dest_station == 5:
                trip_id = 13
            elif dest_station == 6:
                trip_id = 14
            else:
                trip_id = 8
        elif oid <= 1040:
            # Q4 Scheduled Trips: Station 1 -> Trip 15 or 16, Station 2 -> Trip 18, Station 3 -> Trip 17, Station 4 -> Trip 19, Station 5 -> Trip 20, Station 6 -> Trip 21
            if dest_station == 1:
                trip_id = 15 if oid % 2 == 1 else 16
            elif dest_station == 2:
                trip_id = 18
            elif dest_station == 3:
                trip_id = 17
            elif dest_station == 4:
                trip_id = 19
            elif dest_station == 5:
                trip_id = 20
            elif dest_station == 6:
                trip_id = 21
            else:
                trip_id = 15
        else:
            continue # 1041, 1042 are PENDING_RAIL_SCHEDULING

        sp = qty * rates[pid]
        # For order 1023 (first item), create explicit multi-trip spillover across Trip 8 and Trip 9 (both to Colombo Station 1)
        if oid == 1023 and not spillover_done:
            q_part1 = qty // 2
            q_part2 = qty - q_part1
            allocs.append((alloc_id, it_id, 8, q_part1, round(q_part1 * rates[pid], 4), 2, "'2026-08-02 08:30:00'"))
            alloc_id += 1
            allocs.append((alloc_id, it_id, 9, q_part2, round(q_part2 * rates[pid], 4), 2, "'2026-08-02 08:35:00'"))
            alloc_id += 1
            spillover_done = True
        else:
            allocs.append((alloc_id, it_id, trip_id, qty, round(sp, 4), 2, "'2026-08-02 09:00:00'"))
            alloc_id += 1

    al_lines = [f"({a[0]}, {a[1]}, {a[2]}, {a[3]}, {a[4]:.4f}, {a[5]}, {a[6]})" for a in allocs]
    sql.append("INSERT INTO rail_allocation (allocation_id, order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by, allocated_at) VALUES")
    sql.append(",\n".join(al_lines) + ";\n")

    # 14. INVENTORY & STOCK ADJUSTMENT
    sql.append("-- 14. INVENTORY & STOCK ADJUSTMENT (Station Stock Holdings & Audit Adjustments)")
    invs = [
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
        (12, 7, 4, 14, 65)
    ]
    inv_lines = [f"({i[0]}, {i[1]}, {i[2]}, {i[3]}, {i[4]})" for i in invs]
    sql.append("INSERT INTO inventory (inventory_id, station_id, product_id, location_id, stored_quantity) VALUES")
    sql.append(",\n".join(inv_lines) + ";\n")

    adjs = [
        (1, 1, 3, -5, 3, -5, 'Damaged during unloading - crushed carton', 5, 5),
        (2, 1, 1, -2, 1, -2, 'Missing item - short shipment from train', 5, 5),
        (3, 3, 1, 10, 5, 10, 'Stock reconciliation surplus from Colombo train manifest', 5, 5)
    ]
    adj_lines = [f"({a[0]}, {a[1]}, {a[2]}, {a[3]}, {a[4]}, {a[5]}, '{a[6]}', {a[7]}, {a[8]})" for a in adjs]
    sql.append("INSERT INTO stock_adjustment (adjustment_id, station_id, product_id, quantity_adjusted, inventory_id, quantity_delta, reason, reported_by, adjusted_by) VALUES")
    sql.append(",\n".join(adj_lines) + ";\n")

    # 15. ROSTER_ASSIGNMENT
    sql.append("-- 15. ROSTER_ASSIGNMENT (Compliant Truck Dispatches: Drivers <= 40h, Assistants <= 60h, Non-overlapping, No consecutive driver runs)")
    rosters = [
        # (roster_id, request_key, route_id, truck_id, driver_id, assistant_id, dispatcher_id, start_time, end_time, status)
        (1, 'REQ-ROST-0001', 1, 1, 1, 4, 3, '2026-02-10 10:00:00', '2026-02-10 14:00:00', 'COMPLETED'),
        (2, 'REQ-ROST-0002', 2, 2, 2, 4, 3, '2026-02-10 18:00:00', '2026-02-10 22:30:00', 'COMPLETED'), # Assistant 4 consecutive (2nd run, allowed)
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
        (21, 'REQ-ROST-0021', 4, 3, 2, 5, 3, '2026-10-18 10:00:00', '2026-10-18 13:30:00', 'IN_TRANSIT'),
        (22, 'REQ-ROST-0022', 1, 1, 1, 4, 3, '2026-02-23 10:00:00', '2026-02-23 14:00:00', 'COMPLETED'),
        (23, 'REQ-ROST-0023', 8, 2, 2, 5, 3, '2026-02-24 10:00:00', '2026-02-24 14:00:00', 'COMPLETED'),
        (24, 'REQ-ROST-0024', 9, 4, 3, 6, 19, '2026-03-10 12:00:00', '2026-03-10 16:30:00', 'COMPLETED'),
        (25, 'REQ-ROST-0025', 2, 1, 1, 4, 3, '2026-03-14 10:00:00', '2026-03-14 14:00:00', 'COMPLETED'),
        (26, 'REQ-ROST-0026', 3, 4, 3, 6, 19, '2026-03-18 12:00:00', '2026-03-18 16:30:00', 'COMPLETED'),
        (27, 'REQ-ROST-0027', 1, 2, 2, 5, 3, '2026-03-23 10:00:00', '2026-03-23 14:00:00', 'COMPLETED'),
        (28, 'REQ-ROST-0028', 8, 1, 1, 4, 3, '2026-03-28 10:00:00', '2026-03-28 14:00:00', 'COMPLETED')
    ]
    rst_lines = [f"({r[0]}, '{r[1]}', {r[2]}, {r[3]}, {r[4]}, {r[5]}, {r[6]}, '{r[7]}', '{r[8]}', '{r[9]}')" for r in rosters]
    sql.append("INSERT INTO roster_assignment (roster_id, request_key, route_id, truck_id, driver_id, assistant_id, dispatcher_id, start_time, end_time, status) VALUES")
    sql.append(",\n".join(rst_lines) + ";\n")

    # 16. DELIVERY
    sql.append("-- 16. DELIVERY (Doorstep Deliveries linked to Customer Orders and Roster Runs)")
    deliveries = [
        # (delivery_id, roster_id, order_id, delivered_at, delivery_status, proof_reference, assigned_at, assigned_by, cargo_weight_kg)
        (1, 1, 1001, "'2026-02-10 13:45:00'", 'DELIVERED', 'Signed by Recipient M. Fernando (NIC 841920391V)', '2026-02-10 09:50:00', 3, 500.00),
        (2, 2, 1002, "'2026-02-10 22:15:00'", 'DELIVERED', 'Handed over to warehouse supervisor, seal verified', '2026-02-10 17:50:00', 3, 750.00),
        (3, 3, 1003, "'2026-02-11 16:15:00'", 'DELIVERED', 'Signed by Store Mgr K. De Silva', '2026-02-11 11:50:00', 19, 600.00),
        (4, 22, 1004, "'2026-02-23 13:30:00'", 'DELIVERED', 'Direct customer signature, undamaged', '2026-02-23 09:50:00', 3, 450.00),
        (5, 23, 1005, "'2026-02-24 13:30:00'", 'DELIVERED', 'Delivered to loading dock 2, Pettah', '2026-02-24 09:50:00', 3, 800.00),
        (6, 24, 1006, "'2026-03-10 16:00:00'", 'DELIVERED', 'Proof slip signed by Galle retail mgr', '2026-03-10 11:50:00', 19, 350.00),
        (7, 25, 1007, "'2026-03-14 13:00:00'", 'DELIVERED', 'Customer verified all crates intact', '2026-03-14 09:50:00', 3, 620.00),
        (8, 26, 1008, "'2026-03-18 16:15:00'", 'DELIVERED', 'Southern Mart receiving dock, stamp confirmed', '2026-03-18 11:50:00', 19, 580.00),
        (9, 27, 1009, "'2026-03-23 13:30:00'", 'DELIVERED', 'Pettah Main St signed by cashier', '2026-03-23 09:50:00', 3, 400.00),
        (10, 28, 1010, "'2026-03-28 13:30:00'", 'DELIVERED', 'Kelaniya hub receipt verified', '2026-03-28 09:50:00', 3, 720.00),
        (11, 4, 1011, "'2026-05-15 13:45:00'", 'DELIVERED', 'Negombo cold store gate 1 signed', '2026-05-15 10:20:00', 3, 650.00),
        (12, 4, 1012, "'2026-05-15 13:30:00'", 'DELIVERED', 'Katunayake FTZ customs cleared & signed', '2026-05-15 10:20:00', 3, 850.00),
        (13, 5, 1013, "'2026-05-16 16:15:00'", 'DELIVERED', 'Matara wholesale store stamp & signature', '2026-05-16 12:20:00', 3, 540.00),
        (14, 6, 1014, "'2026-05-17 17:00:00'", 'DELIVERED', 'Jaffna Hospital Rd receiving verified', '2026-05-17 12:50:00', 3, 680.00),
        (15, 7, 1015, "'2026-05-18 16:15:00'", 'DELIVERED', 'Trincomalee harbour warehouse verified', '2026-05-18 12:20:00', 3, 490.00),
        (16, 8, 1023, "'2026-08-10 13:45:00'", 'DELIVERED', 'Pettah main street receipt verified', '2026-08-10 09:50:00', 3, 500.00),
        (17, 9, 1024, "'2026-08-10 22:15:00'", 'DELIVERED', 'Industrial zone delivery signed by manager', '2026-08-10 17:50:00', 3, 750.00),
        (18, 10, 1025, "'2026-08-11 16:15:00'", 'DELIVERED', 'Galle Fort retail receipt confirmed', '2026-08-11 11:50:00', 19, 600.00),
        (19, 11, 1026, "'2026-08-12 13:45:00'", 'DELIVERED', 'Negombo seafood depot stamp', '2026-08-12 10:20:00', 3, 650.00),
        (20, 12, 1027, "'2026-08-13 16:15:00'", 'DELIVERED', 'Matara express store received', '2026-08-13 12:20:00', 3, 540.00),
        (21, 13, 1028, "'2026-08-14 17:00:00'", 'DELIVERED', 'Jaffna northern peninsula verified', '2026-08-14 12:50:00', 3, 680.00),
        (22, 14, 1029, "'2026-08-15 16:15:00'", 'DELIVERED', 'Trincomalee port road signed', '2026-08-15 12:20:00', 3, 490.00),
        (23, 15, 1030, "'2026-08-18 13:15:00'", 'DELIVERED', 'Kelaniya retail receiving stamp', '2026-08-18 09:50:00', 3, 420.00),
        (24, 16, 1031, "'2026-08-20 16:45:00'", 'DELIVERED', 'Galle inland store signature', '2026-08-20 11:50:00', 19, 390.00),
        (25, 17, 1032, "'2026-08-23 11:15:00'", 'DELIVERED', 'Katunayake cargo bay 4 signature', '2026-08-23 08:50:00', 3, 810.00),
        (26, 18, 1033, "'2026-09-10 13:45:00'", 'DELIVERED', 'Colombo central signed', '2026-09-10 09:50:00', 3, 510.00),
        (27, 19, 1034, "'2026-09-14 15:15:00'", 'DELIVERED', 'Greater colombo signed', '2026-09-14 09:50:00', 3, 670.00),
        (28, 20, 1035, 'NULL', 'IN_TRANSIT', 'Dispatched on SP-CAB-2001 (Driver Ruwan)', '2026-10-18 08:50:00', 19, 580.00),
        (29, 21, 1036, 'NULL', 'IN_TRANSIT', 'Dispatched on WP-CAB-1003 (Driver Nimal)', '2026-10-18 09:50:00', 3, 610.00)
    ]
    del_lines = [f"({d[0]}, {d[1]}, {d[2]}, {d[3]}, '{d[4]}', '{d[5]}', '{d[6]}', {d[7]}, {d[8]:.2f})" for d in deliveries]
    sql.append("INSERT INTO delivery (delivery_id, roster_id, order_id, delivered_at, delivery_status, proof_reference, assigned_at, assigned_by, cargo_weight_kg) VALUES")
    sql.append(",\n".join(del_lines) + ";\n")

    # 17. AUDIT_LOG
    sql.append("-- 17. AUDIT_LOG (Initial Audit Trail for Dispatches)")
    audits = [
        (1, 3, 'ASSIGN_ROSTER', 1, 'ACCEPTED', "'2026-02-10 09:50:00'", 'roster_assignment', 1),
        (2, 3, 'ASSIGN_ROSTER', 2, 'ACCEPTED', "'2026-02-10 17:50:00'", 'roster_assignment', 2),
        (3, 19, 'ASSIGN_ROSTER', 3, 'ACCEPTED', "'2026-02-11 11:50:00'", 'roster_assignment', 3),
        (4, 3, 'ASSIGN_ROSTER', 8, 'ACCEPTED', "'2026-08-10 09:50:00'", 'roster_assignment', 8),
        (5, 3, 'ASSIGN_ROSTER', 9, 'ACCEPTED', "'2026-08-10 17:50:00'", 'roster_assignment', 9),
        (6, 19, 'ASSIGN_ROSTER', 10, 'ACCEPTED', "'2026-08-11 11:50:00'", 'roster_assignment', 10),
        (7, 3, 'ASSIGN_ROSTER', 22, 'ACCEPTED', "'2026-02-23 09:50:00'", 'roster_assignment', 22),
        (8, 3, 'ASSIGN_ROSTER', 23, 'ACCEPTED', "'2026-02-24 09:50:00'", 'roster_assignment', 23),
        (9, 19, 'ASSIGN_ROSTER', 24, 'ACCEPTED', "'2026-03-10 11:50:00'", 'roster_assignment', 24),
        (10, 3, 'ASSIGN_ROSTER', 25, 'ACCEPTED', "'2026-03-14 09:50:00'", 'roster_assignment', 25),
        (11, 19, 'ASSIGN_ROSTER', 26, 'ACCEPTED', "'2026-03-18 11:50:00'", 'roster_assignment', 26),
        (12, 3, 'ASSIGN_ROSTER', 27, 'ACCEPTED', "'2026-03-23 09:50:00'", 'roster_assignment', 27),
        (13, 3, 'ASSIGN_ROSTER', 28, 'ACCEPTED', "'2026-03-28 09:50:00'", 'roster_assignment', 28)
    ]
    aud_lines = [f"({a[0]}, {a[1]}, '{a[2]}', {a[3]}, '{a[4]}', {a[5]}, '{a[6]}', {a[7]})" for a in audits]
    sql.append("INSERT INTO audit_log (audit_id, user_id, action, entity_id, outcome, occurred_at, entity_name, roster_id) VALUES")
    sql.append(",\n".join(aud_lines) + ";\n")

    return "\n".join(sql)

if __name__ == "__main__":
    import os
    content = generate_seed_sql()
    target_path = os.path.join(os.path.dirname(__file__), "06_seed_data.sql")
    with open(target_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Successfully generated {target_path}!")
