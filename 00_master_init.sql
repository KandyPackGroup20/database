-- 1. SCHEMA & TABLES
CREATE DATABASE IF NOT EXISTS kandypack_db;
USE kandypack_db;

-- Drop existing tables in reverse dependency order if resetting
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS delivery;
DROP TABLE IF EXISTS roster_assignment;
DROP TABLE IF EXISTS delivery_staff;
DROP TABLE IF EXISTS truck;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS manifest;
DROP TABLE IF EXISTS rail_allocation;
DROP TABLE IF EXISTS order_status_history;
DROP TABLE IF EXISTS order_item;
DROP TABLE IF EXISTS customer_order;
DROP TABLE IF EXISTS customer;
DROP TABLE IF EXISTS delivery_route;
DROP TABLE IF EXISTS train_trip;
DROP TABLE IF EXISTS storage_location;
DROP TABLE IF EXISTS station_store;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS user;

-- 1. USER
CREATE TABLE user (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    role VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    force_password_reset TINYINT DEFAULT 0,
    is_active TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_email UNIQUE (email)
) ENGINE=InnoDB;

-- 2. PRODUCT
CREATE TABLE product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    space_consumption_rate DECIMAL(6, 4) NOT NULL,
    is_active TINYINT DEFAULT 1
) ENGINE=InnoDB;

-- 3. STATION_STORE
CREATE TABLE station_store (
    station_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    address VARCHAR(500) NOT NULL,
    is_active TINYINT DEFAULT 1
) ENGINE=InnoDB;

-- 4. STORAGE_LOCATION
CREATE TABLE storage_location (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    location_code VARCHAR(100) NOT NULL,
    location_type VARCHAR(50) NOT NULL,
    CONSTRAINT uq_storage_loc UNIQUE (station_id, location_code),
    FOREIGN KEY (station_id) REFERENCES station_store(station_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5. TRAIN_TRIP
CREATE TABLE train_trip (
    trip_id INT AUTO_INCREMENT PRIMARY KEY,
    origin_station_id INT NOT NULL,
    destination_station_id INT NOT NULL,
    departure_datetime DATETIME NOT NULL,
    arrival_datetime DATETIME NOT NULL,
    total_capacity DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'SCHEDULED',
    FOREIGN KEY (origin_station_id) REFERENCES station_store(station_id),
    FOREIGN KEY (destination_station_id) REFERENCES station_store(station_id)
) ENGINE=InnoDB;

-- 6. DELIVERY_ROUTE
CREATE TABLE delivery_route (
    route_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    route_name VARCHAR(150) NOT NULL,
    max_delivery_time TIME NOT NULL,
    FOREIGN KEY (station_id) REFERENCES station_store(station_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7. CUSTOMER
CREATE TABLE customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    route_id INT NULL,
    phone VARCHAR(30) NOT NULL,
    address_line VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    CONSTRAINT uq_customer_user UNIQUE (user_id),
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE,
    FOREIGN KEY (route_id) REFERENCES delivery_route(route_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 8. CUSTOMER_ORDER
CREATE TABLE customer_order (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    delivery_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING_RAIL_SCHEDULING',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB;

-- 9. ORDER_ITEM
CREATE TABLE order_item (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES customer_order(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES product(product_id)
) ENGINE=InnoDB;

-- 10. ORDER_STATUS_HISTORY
CREATE TABLE order_status_history (
    status_history_id INT AUTO_INCREMENT PRIMARY KEY,
    status VARCHAR(50) NOT NULL,
    order_id INT NOT NULL,
    changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    changed_by INT NULL,
    FOREIGN KEY (order_id) REFERENCES customer_order(order_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 11. RAIL_ALLOCATION
CREATE TABLE rail_allocation (
    allocation_id INT AUTO_INCREMENT PRIMARY KEY,
    order_item_id INT NOT NULL,
    trip_id INT NOT NULL,
    allocated_quantity INT NOT NULL,
    allocated_space DECIMAL(10, 2) NOT NULL,
    allocated_by INT NULL,
    allocated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_item_id) REFERENCES order_item(order_item_id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES train_trip(trip_id),
    FOREIGN KEY (allocated_by) REFERENCES user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 12. MANIFEST
CREATE TABLE manifest (
    manifest_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    trip_id INT NOT NULL,
    received_at DATETIME NULL,
    status VARCHAR(50) DEFAULT 'PENDING',
    FOREIGN KEY (station_id) REFERENCES station_store(station_id),
    FOREIGN KEY (trip_id) REFERENCES train_trip(trip_id)
) ENGINE=InnoDB;

-- 13. INVENTORY
CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    order_item_id INT NOT NULL,
    manifest_id INT NOT NULL,
    stored_quantity INT NOT NULL,
    FOREIGN KEY (order_item_id) REFERENCES order_item(order_item_id),
    FOREIGN KEY (manifest_id) REFERENCES manifest(manifest_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 14. TRUCK
CREATE TABLE truck (
    truck_id INT AUTO_INCREMENT PRIMARY KEY,
    plate_number VARCHAR(50) NOT NULL,
    capacity DECIMAL(10, 2) NOT NULL,
    is_active TINYINT DEFAULT 1,
    CONSTRAINT uq_truck_plate UNIQUE (plate_number)
) ENGINE=InnoDB;

-- 15. DELIVERY_STAFF
CREATE TABLE delivery_staff (
    delivery_staff_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    license_number VARCHAR(100) NOT NULL,
    work_hours DECIMAL(5, 2) DEFAULT 0.00,
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 16. ROSTER_ASSIGNMENT
CREATE TABLE roster_assignment (
    roster_id INT AUTO_INCREMENT PRIMARY KEY,
    route_id INT NOT NULL,
    truck_id INT NOT NULL,
    driver_id INT NOT NULL,
    assistant_id INT NOT NULL,
    dispatcher_id INT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status VARCHAR(50) DEFAULT 'SCHEDULED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (route_id) REFERENCES delivery_route(route_id),
    FOREIGN KEY (truck_id) REFERENCES truck(truck_id),
    FOREIGN KEY (driver_id) REFERENCES delivery_staff(delivery_staff_id),
    FOREIGN KEY (assistant_id) REFERENCES delivery_staff(delivery_staff_id),
    FOREIGN KEY (dispatcher_id) REFERENCES user(user_id)
) ENGINE=InnoDB;

-- 17. DELIVERY
CREATE TABLE delivery (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,
    roster_id INT NOT NULL,
    order_id INT NOT NULL,
    delivered_at DATETIME NULL,
    delivery_status VARCHAR(50) DEFAULT 'PENDING',
    proof_reference VARCHAR(500) NULL,
    FOREIGN KEY (roster_id) REFERENCES roster_assignment(roster_id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES customer_order(order_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 18. AUDIT_LOG
CREATE TABLE audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity_id INT NOT NULL,
    outcome VARCHAR(50) NOT NULL,
    occurred_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    entity_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

     
-- 2. VIEWS
     
CREATE OR REPLACE VIEW v_available_drivers AS
SELECT 
    ds.delivery_staff_id AS driver_id,
    u.name AS full_name,
    ds.license_number AS license_no,
    ds.work_hours AS accumulated_weekly_hours,
    40.00 - ds.work_hours AS remaining_hours_allowed
FROM delivery_staff ds
JOIN user u ON ds.user_id = u.user_id
WHERE u.role = 'DRIVER' AND ds.work_hours < 40.00;

CREATE OR REPLACE VIEW v_available_assistants AS
SELECT 
    ds.delivery_staff_id AS assistant_id,
    u.name AS full_name,
    ds.work_hours AS accumulated_weekly_hours,
    60.00 - ds.work_hours AS remaining_hours_allowed
FROM delivery_staff ds
JOIN user u ON ds.user_id = u.user_id
WHERE u.role = 'ASSISTANT' AND ds.work_hours < 60.00;

CREATE OR REPLACE VIEW v_drivers_near_cap AS
SELECT 
    ds.delivery_staff_id AS driver_id,
    u.name AS full_name,
    ds.work_hours AS accumulated_weekly_hours,
    40.00 AS cap_hours,
    ROUND((ds.work_hours / 40.00) * 100, 1) AS utilization_pct,
    CASE 
        WHEN ds.work_hours >= 40.00 THEN 'CAP_REACHED'
        WHEN ds.work_hours >= 36.00 THEN 'WARNING_NEAR_CAP'
        ELSE 'SAFE'
    END AS status_flag
FROM delivery_staff ds
JOIN user u ON ds.user_id = u.user_id
WHERE u.role = 'DRIVER';

CREATE OR REPLACE VIEW v_station_inventory_overview AS
SELECT 
    ss.station_id,
    ss.city AS city_name,
    p.product_id,
    p.product_name,
    inv.stored_quantity AS quantity_available,
    sl.location_code AS bin_location
FROM inventory inv
JOIN order_item oi ON inv.order_item_id = oi.order_item_id
JOIN product p ON oi.product_id = p.product_id
JOIN manifest m ON inv.manifest_id = m.manifest_id
JOIN station_store ss ON m.station_id = ss.station_id
LEFT JOIN storage_location sl ON ss.station_id = sl.station_id;

CREATE OR REPLACE VIEW v_quarterly_rail_analytics AS
SELECT 
    ss.city AS destination_hub,
    YEAR(co.order_date) AS order_year,
    QUARTER(co.order_date) AS order_quarter,
    COUNT(DISTINCT co.order_id) AS total_orders,
    SUM(ra.allocated_quantity) AS total_units_shipped,
    SUM(ra.allocated_space) AS total_cubic_meters_shipped
FROM customer_order co
JOIN customer c ON co.customer_id = c.customer_id
LEFT JOIN delivery_route dr ON c.route_id = dr.route_id
LEFT JOIN station_store ss ON dr.station_id = ss.station_id
JOIN order_item oi ON co.order_id = oi.order_id
JOIN rail_allocation ra ON oi.order_item_id = ra.order_item_id
GROUP BY ss.city, YEAR(co.order_date), QUARTER(co.order_date);

     
-- 3. STORED PROCEDURES
     
DELIMITER //

DROP PROCEDURE IF EXISTS sp_allocate_rail_capacity//
CREATE PROCEDURE sp_allocate_rail_capacity(
    IN p_order_id INT,
    OUT p_status_result VARCHAR(50)
)
PROC_BODY: BEGIN
    DECLARE v_dest_hub INT;
    DECLARE v_order_status VARCHAR(50);
    DECLARE v_item_id INT;
    DECLARE v_product_id INT;
    DECLARE v_ordered_qty INT;
    DECLARE v_space_per_unit DECIMAL(6,4);
    DECLARE v_remaining_item_qty INT;
    
    DECLARE v_trip_id INT;
    DECLARE v_trip_rem_cap DECIMAL(10,2);
    DECLARE v_max_units_fit INT;
    DECLARE v_qty_to_alloc INT;
    DECLARE v_space_to_alloc DECIMAL(10,2);
    
    DECLARE v_trip_count INT DEFAULT 0;
    DECLARE done INT DEFAULT FALSE;
    
    DECLARE cur_items CURSOR FOR 
        SELECT oi.order_item_id, oi.product_id, oi.quantity, p.space_consumption_rate
        FROM order_item oi
        JOIN product p ON oi.product_id = p.product_id
        WHERE oi.order_id = p_order_id;
        
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status_result = 'ERROR_TRANSACTION_FAILED';
    END;

    START TRANSACTION;

    SELECT status INTO v_order_status
    FROM customer_order WHERE order_id = p_order_id FOR UPDATE;

    IF v_order_status != 'PENDING_RAIL_SCHEDULING' THEN
        ROLLBACK;
        SET p_status_result = 'INVALID_ORDER_STATUS';
        LEAVE PROC_BODY;
    END IF;

    SELECT dr.station_id INTO v_dest_hub
    FROM customer_order co
    JOIN customer c ON co.customer_id = c.customer_id
    JOIN delivery_route dr ON c.route_id = dr.route_id
    WHERE co.order_id = p_order_id;

    IF v_dest_hub IS NULL THEN
        ROLLBACK;
        SET p_status_result = 'DESTINATION_HUB_NOT_RESOLVED';
        LEAVE PROC_BODY;
    END IF;

    OPEN cur_items;
    
    item_loop: LOOP
        FETCH cur_items INTO v_item_id, v_product_id, v_ordered_qty, v_space_per_unit;
        IF done THEN LEAVE item_loop; END IF;
        
        SET v_remaining_item_qty = v_ordered_qty;
        
        find_trips: WHILE v_remaining_item_qty > 0 DO
            SET v_trip_id = NULL;
            
            SELECT tt.trip_id, 
                   tt.total_capacity - COALESCE((SELECT SUM(allocated_space) FROM rail_allocation WHERE trip_id = tt.trip_id), 0)
            INTO v_trip_id, v_trip_rem_cap
            FROM train_trip tt
            WHERE tt.destination_station_id = v_dest_hub 
              AND tt.status = 'SCHEDULED' 
              AND (tt.total_capacity - COALESCE((SELECT SUM(allocated_space) FROM rail_allocation WHERE trip_id = tt.trip_id), 0)) > 0
            ORDER BY tt.departure_datetime ASC 
            LIMIT 1
            FOR UPDATE;
            
            IF v_trip_id IS NULL THEN
                LEAVE find_trips;
            END IF;
            
            SET v_max_units_fit = FLOOR(v_trip_rem_cap / v_space_per_unit);
            
            IF v_max_units_fit >= v_remaining_item_qty THEN
                SET v_qty_to_alloc = v_remaining_item_qty;
            ELSE
                SET v_qty_to_alloc = v_max_units_fit;
            END IF;
            
            IF v_qty_to_alloc > 0 THEN
                SET v_space_to_alloc = v_qty_to_alloc * v_space_per_unit;
                
                INSERT INTO rail_allocation(order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
                VALUES (v_item_id, v_trip_id, v_qty_to_alloc, v_space_to_alloc, NULL);
                
                SET v_remaining_item_qty = v_remaining_item_qty - v_qty_to_alloc;
                SET v_trip_count = v_trip_count + 1;
            ELSE
                LEAVE find_trips;
            END IF;
            
        END WHILE;

        IF v_remaining_item_qty > 0 THEN
            ROLLBACK;
            SET p_status_result = 'INSUFFICIENT_RAIL_CAPACITY';
            LEAVE PROC_BODY;
        END IF;

    END LOOP;
    CLOSE cur_items;

    IF v_trip_count = 1 THEN
        UPDATE customer_order SET status = 'SCHEDULED_FOR_RAIL' WHERE order_id = p_order_id;
        INSERT INTO order_status_history (status, order_id, changed_by) VALUES ('SCHEDULED_FOR_RAIL', p_order_id, NULL);
        SET p_status_result = 'SUCCESS_SINGLE_TRIP';
    ELSE
        UPDATE customer_order SET status = 'SCHEDULED_MULTI_TRIP' WHERE order_id = p_order_id;
        INSERT INTO order_status_history (status, order_id, changed_by) VALUES ('SCHEDULED_MULTI_TRIP', p_order_id, NULL);
        SET p_status_result = 'SUCCESS_MULTI_TRIP_SPILLOVER';
    END IF;

    COMMIT;
END //

DROP PROCEDURE IF EXISTS sp_assign_truck_roster//
CREATE PROCEDURE sp_assign_truck_roster(
    IN p_route_id INT, IN p_truck_id INT, IN p_driver_id INT, IN p_assistant_id INT, IN p_dispatcher_id INT,
    IN p_start_time DATETIME, IN p_end_time DATETIME, IN p_duration_hours DECIMAL(4,2), OUT p_result_code VARCHAR(50)
)
PROC_BODY: BEGIN
    DECLARE v_overlap_count INT DEFAULT 0;
    DECLARE v_driver_hours DECIMAL(5,2);
    DECLARE v_assistant_hours DECIMAL(5,2);
    DECLARE v_driver_last_end DATETIME;
    DECLARE v_assistant_last_end DATETIME;
    DECLARE v_assistant_consec_count INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'ASSIGN_ROSTER', p_route_id, 'SYSTEM_ERROR', 'roster_assignment');
        SET p_result_code = 'SYSTEM_ERROR';
    END;

    START TRANSACTION;

    SELECT work_hours INTO v_driver_hours FROM delivery_staff WHERE delivery_staff_id = p_driver_id FOR UPDATE;
    SELECT work_hours INTO v_assistant_hours FROM delivery_staff WHERE delivery_staff_id = p_assistant_id FOR UPDATE;
    SELECT truck_id FROM truck WHERE truck_id = p_truck_id FOR UPDATE;

    SELECT COUNT(*) INTO v_overlap_count
    FROM roster_assignment
    WHERE status IN ('SCHEDULED', 'IN_TRANSIT')
      AND (truck_id = p_truck_id OR driver_id = p_driver_id OR assistant_id = p_assistant_id)
      AND (p_start_time < end_time AND p_end_time > start_time);

    IF v_overlap_count > 0 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_A_OVERLAP', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_A_OVERLAP';
        LEAVE PROC_BODY;
    END IF;

    SELECT MAX(end_time) INTO v_driver_last_end
    FROM roster_assignment
    WHERE driver_id = p_driver_id AND status != 'CANCELLED' AND end_time <= p_start_time;

    IF v_driver_last_end IS NOT NULL AND TIMESTAMPDIFF(HOUR, v_driver_last_end, p_start_time) < 8 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_B_DRIVER_REST', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_B_DRIVER_REST';
        LEAVE PROC_BODY;
    END IF;

    SELECT MAX(end_time) INTO v_assistant_last_end
    FROM roster_assignment
    WHERE assistant_id = p_assistant_id AND status != 'CANCELLED' AND end_time <= p_start_time;

    IF v_assistant_last_end IS NOT NULL AND TIMESTAMPDIFF(HOUR, v_assistant_last_end, p_start_time) < 8 THEN
        SET v_assistant_consec_count = 1;
        SELECT COUNT(*) INTO v_overlap_count
        FROM (
            SELECT end_time FROM roster_assignment
            WHERE assistant_id = p_assistant_id AND status != 'CANCELLED' AND end_time <= v_assistant_last_end
            ORDER BY end_time DESC LIMIT 2
        ) t;
        IF v_overlap_count >= 2 THEN
            SET v_assistant_consec_count = 2;
        END IF;
    END IF;

    IF v_assistant_consec_count >= 2 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_C_ASSISTANT_REST', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_C_ASSISTANT_REST';
        LEAVE PROC_BODY;
    END IF;

    IF (v_driver_hours + p_duration_hours) > 40.00 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_D_DRIVER_HOURS_EXCEEDED', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_D_DRIVER_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    IF (v_assistant_hours + p_duration_hours) > 60.00 THEN
        ROLLBACK;
        INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
        VALUES (p_dispatcher_id, 'REJECTED_CHECK_D_ASSISTANT_HOURS_EXCEEDED', p_route_id, 'FAILURE', 'roster_assignment');
        SET p_result_code = 'REJECTED_CHECK_D_ASSISTANT_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    INSERT INTO roster_assignment(route_id, truck_id, driver_id, assistant_id, dispatcher_id, start_time, end_time, status)
    VALUES (p_route_id, p_truck_id, p_driver_id, p_assistant_id, p_dispatcher_id, p_start_time, p_end_time, 'SCHEDULED');

    UPDATE delivery_staff SET work_hours = work_hours + p_duration_hours WHERE delivery_staff_id = p_driver_id;
    UPDATE delivery_staff SET work_hours = work_hours + p_duration_hours WHERE delivery_staff_id = p_assistant_id;

    INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name)
    VALUES (p_dispatcher_id, 'ASSIGN_ROSTER', p_route_id, 'SUCCESS', 'roster_assignment');

    COMMIT;
    SET p_result_code = 'SUCCESS';
END //

     
-- 4. TRIGGERS
     
DROP TRIGGER IF EXISTS trg_prevent_audit_log_modification//
CREATE TRIGGER trg_prevent_audit_log_modification BEFORE UPDATE ON audit_log FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs immutable'; END //

DROP TRIGGER IF EXISTS trg_prevent_audit_log_deletion//
CREATE TRIGGER trg_prevent_audit_log_deletion BEFORE DELETE ON audit_log FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs immutable'; END //

DELIMITER ;

     
-- 5. INDEXES
     
CREATE INDEX idx_train_trip_alloc ON train_trip (destination_station_id, status, departure_datetime);
CREATE INDEX idx_customer_order_status_date ON customer_order (status, order_date);
CREATE INDEX idx_roster_time_overlap ON roster_assignment (status, start_time, end_time, truck_id, driver_id, assistant_id);
CREATE INDEX idx_storage_loc_search ON storage_location (station_id, location_code);

     
-- 6. SEED DATA
     
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE audit_log; TRUNCATE TABLE delivery; TRUNCATE TABLE roster_assignment; TRUNCATE TABLE delivery_staff; TRUNCATE TABLE truck; TRUNCATE TABLE inventory; TRUNCATE TABLE manifest; TRUNCATE TABLE rail_allocation; TRUNCATE TABLE order_status_history; TRUNCATE TABLE order_item; TRUNCATE TABLE customer_order; TRUNCATE TABLE customer; TRUNCATE TABLE delivery_route; TRUNCATE TABLE train_trip; TRUNCATE TABLE storage_location; TRUNCATE TABLE station_store; TRUNCATE TABLE product; TRUNCATE TABLE user;
SET FOREIGN_KEY_CHECKS = 1;

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

INSERT INTO product (product_id, product_name, unit_price, space_consumption_rate) VALUES
(1, 'Kandy Pure Ceylon Tea 500g Pack', 450.00, 0.0500),
(2, 'Kandy Spice Mixture Box (12 Units)', 850.00, 0.1200),
(3, 'FMCG Biscuits Master Carton (24 Packs)', 1200.00, 0.2500),
(4, 'Coconut Oil 5L Container', 2400.00, 0.1800);

INSERT INTO station_store (station_id, city, address) VALUES
(1, 'Colombo', 'Colombo Main Railway Station Store, Colombo 10'),
(2, 'Negombo', 'Negombo Station Hub, Negombo'),
(3, 'Galle', 'Galle Station Hub, Galle'),
(4, 'Matara', 'Matara Station Hub, Matara'),
(5, 'Jaffna', 'Jaffna Station Hub, Jaffna'),
(6, 'Trincomalee', 'Trincomalee Station Hub, Trincomalee'),
(7, 'Kandy', 'Kandy Central Goods Yard, Kandy');

INSERT INTO storage_location (location_id, station_id, location_code, location_type) VALUES
(1, 1, 'BIN-A1', 'General Goods'),
(2, 1, 'BIN-A2', 'General Goods'),
(3, 3, 'BIN-G1', 'General Goods');

INSERT INTO train_trip (trip_id, origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES
(1, 7, 1, '2026-08-10 06:00:00', '2026-08-10 09:30:00', 30.00, 'SCHEDULED'),
(2, 7, 1, '2026-08-10 14:00:00', '2026-08-10 17:30:00', 40.00, 'SCHEDULED'),
(3, 7, 3, '2026-08-11 07:00:00', '2026-08-11 11:30:00', 50.00, 'SCHEDULED');

INSERT INTO delivery_route (route_id, station_id, route_name, max_delivery_time) VALUES
(1, 1, 'Colombo Central Commercial Route', '04:30:00'),
(2, 1, 'Greater Colombo Industrial Hub Route', '06:00:00'),
(3, 3, 'Galle Coastal Route', '05:00:00');

INSERT INTO customer (customer_id, user_id, customer_name, route_id, phone, address_line, city, postal_code) VALUES
(1, 12, 'Lanka Retailers Ltd', 1, '0112345678', 'Main Street Wholesalers, Pettah', 'Colombo 11', '01100');

INSERT INTO customer_order (order_id, customer_id, order_date, delivery_date, status) VALUES
(1001, 1, '2026-08-08', '2026-08-15', 'PENDING_RAIL_SCHEDULING');

INSERT INTO order_item (order_item_id, order_id, product_id, quantity) VALUES
(1, 1001, 3, 200);

INSERT INTO truck (truck_id, plate_number, capacity) VALUES
(1, 'WP-CAB-1001', 3500.00),
(2, 'WP-CAB-1002', 3500.00),
(3, 'SP-CAB-2001', 5000.00);

INSERT INTO delivery_staff (delivery_staff_id, user_id, license_number, work_hours) VALUES
(1, 6, 'LIC-D-101', 38.00),
(2, 7, 'LIC-D-102', 27.00),
(3, 8, 'LIC-D-103', 40.00),
(4, 9, 'LIC-A-201', 45.00),
(5, 10, 'LIC-A-202', 58.00),
(6, 11, 'LIC-A-203', 33.00);
