-- 1. SCHEMA & TABLES
CREATE DATABASE IF NOT EXISTS kandypack_db;
USE kandypack_db;

-- Drop existing tables in reverse dependency order if resetting
DROP TABLE IF EXISTS notification;
DROP TABLE IF EXISTS stock_adjustment;
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS delivery;
DROP TABLE IF EXISTS roster_assignment;
DROP TABLE IF EXISTS delivery_staff;
DROP TABLE IF EXISTS truck;
DROP TABLE IF EXISTS stock_adjustment;
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
    category VARCHAR(100) NOT NULL DEFAULT 'Ceylon Tea & Spices',
    unit_price DECIMAL(10, 2) NOT NULL,
    unit_weight_kg DECIMAL(8, 2) NOT NULL DEFAULT 25.00,
    space_consumption_rate DECIMAL(6, 4) NOT NULL,
    description VARCHAR(500) NULL,
    image_url VARCHAR(500) NULL,
    is_active TINYINT DEFAULT 1
) ENGINE=InnoDB;

-- 3. STATION_STORE
CREATE TABLE station_store (
    station_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    address VARCHAR(500) NOT NULL,
    is_active TINYINT DEFAULT 1,
    manager_id INT NULL,
    FOREIGN KEY (manager_id) REFERENCES user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 4. STORAGE_LOCATION
ALTER TABLE user ADD COLUMN station_id INT NULL,
    ADD CONSTRAINT fk_user_station FOREIGN KEY (station_id) REFERENCES station_store(station_id);

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
    delivery_route_id INT NOT NULL,
    delivery_address VARCHAR(500) NOT NULL,
    recipient_name VARCHAR(255) NOT NULL,
    recipient_phone VARCHAR(30) NOT NULL,
    CONSTRAINT fk_order_delivery_route FOREIGN KEY (delivery_route_id) REFERENCES delivery_route(route_id) ON DELETE RESTRICT,
    CONSTRAINT chk_order_delivery_address CHECK (CHAR_LENGTH(TRIM(delivery_address)) > 0),
    CONSTRAINT chk_order_recipient_name CHECK (CHAR_LENGTH(TRIM(recipient_name)) > 0),
    CONSTRAINT chk_order_recipient_phone CHECK (CHAR_LENGTH(TRIM(recipient_phone)) > 0),
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
    unit_price_at_order DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    FOREIGN KEY (order_id)
        REFERENCES customer_order(order_id)
        ON DELETE CASCADE,

    FOREIGN KEY (product_id)
        REFERENCES product(product_id)
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
    CONSTRAINT uq_manifest_station_trip UNIQUE (station_id, trip_id),
    CONSTRAINT chk_manifest_status CHECK (status IN ('PENDING', 'RECEIVED')),
    FOREIGN KEY (station_id) REFERENCES station_store(station_id),
    FOREIGN KEY (trip_id) REFERENCES train_trip(trip_id)
) ENGINE=InnoDB;

-- 13. INVENTORY (Feature 4.4 - one stock row per station + product)
CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NOT NULL,
    product_id INT NOT NULL,
    location_id INT NULL,
    stored_quantity INT NOT NULL DEFAULT 0,
    last_updated DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_inventory_station_product UNIQUE (station_id, product_id),
    CONSTRAINT chk_inventory_qty_nonneg CHECK (stored_quantity >= 0),
    FOREIGN KEY (station_id) REFERENCES station_store(station_id),
    FOREIGN KEY (product_id) REFERENCES product(product_id),
    FOREIGN KEY (location_id) REFERENCES storage_location(location_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 13b. STOCK_ADJUSTMENT (Feature 4.4 - damaged / missing / manual stock changes)
CREATE TABLE stock_adjustment (
    adjustment_id INT AUTO_INCREMENT PRIMARY KEY,
    request_key VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NULL,
    CONSTRAINT uq_stock_adjustment_request UNIQUE (request_key),
    station_id INT NULL,
    product_id INT NULL,
    quantity_adjusted INT NULL DEFAULT 0,
    inventory_id INT NULL,
    quantity_delta INT NULL DEFAULT 0,
    reason VARCHAR(255) NOT NULL,
    reported_by INT NULL,
    adjusted_by INT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    adjusted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (station_id) REFERENCES station_store(station_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE,
    FOREIGN KEY (inventory_id) REFERENCES inventory(inventory_id) ON DELETE SET NULL,
    FOREIGN KEY (reported_by) REFERENCES user(user_id) ON DELETE SET NULL,
    FOREIGN KEY (adjusted_by) REFERENCES user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 14. TRUCK
CREATE TABLE truck (
    truck_id INT AUTO_INCREMENT PRIMARY KEY,
    plate_number VARCHAR(50) NOT NULL,
    capacity DECIMAL(10, 2) NOT NULL,
    capacity_unit VARCHAR(16) NULL DEFAULT NULL,
    CONSTRAINT chk_truck_capacity CHECK (capacity > 0),
    CONSTRAINT chk_truck_capacity_unit CHECK (capacity_unit IS NULL OR capacity_unit = 'KG'),
    is_active TINYINT DEFAULT 1,
    CONSTRAINT uq_truck_plate UNIQUE (plate_number)
) ENGINE=InnoDB;

-- 15. DELIVERY_STAFF
CREATE TABLE delivery_staff (
    delivery_staff_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    license_number VARCHAR(100) NOT NULL,
    work_hours DECIMAL(5, 2) DEFAULT 0.00,
    CONSTRAINT uq_delivery_staff_user UNIQUE (user_id),
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 16. ROSTER_ASSIGNMENT
CREATE TABLE roster_assignment (
    roster_id INT AUTO_INCREMENT PRIMARY KEY,
    request_key VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_bin NOT NULL,
    CONSTRAINT uq_roster_assignment_request_key UNIQUE (request_key),
    CONSTRAINT chk_roster_assignment_request_key CHECK (CHAR_LENGTH(request_key) > 0),
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
    delivery_status VARCHAR(50) NOT NULL DEFAULT 'ASSIGNED',
    proof_reference VARCHAR(500) NULL,
    assigned_at DATETIME NOT NULL,
    assigned_by INT NOT NULL,
    cargo_weight_kg DECIMAL(14,2) NOT NULL,
    active_order_id INT GENERATED ALWAYS AS (CASE WHEN delivery_status = 'CANCELLED' THEN NULL ELSE order_id END) STORED,
    CONSTRAINT uq_delivery_active_order UNIQUE (active_order_id),
    CONSTRAINT chk_delivery_cargo_weight CHECK (cargo_weight_kg > 0),
    CONSTRAINT fk_delivery_actor FOREIGN KEY (assigned_by) REFERENCES user(user_id) ON DELETE RESTRICT,
    FOREIGN KEY (roster_id) REFERENCES roster_assignment(roster_id) ON DELETE RESTRICT,
    FOREIGN KEY (order_id) REFERENCES customer_order(order_id) ON DELETE RESTRICT
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
    -- Unrelated explicit-column audit inserts leave the roster link NULL.
    roster_id INT NULL,
    CONSTRAINT uq_audit_log_roster UNIQUE (roster_id),
    INDEX idx_audit_log_action_time (action, occurred_at DESC, audit_id DESC),
    INDEX idx_audit_log_user (user_id),
    CONSTRAINT fk_audit_log_user FOREIGN KEY (user_id) REFERENCES user(user_id),
    CONSTRAINT fk_audit_log_roster FOREIGN KEY (roster_id) REFERENCES roster_assignment(roster_id),
    CONSTRAINT chk_audit_log_roster_accepted CHECK (
        roster_id IS NULL OR (
            action = 'ASSIGN_ROSTER' AND outcome = 'ACCEPTED'
            AND entity_name = 'roster_assignment' AND entity_id = roster_id
            AND occurred_at IS NOT NULL
        )
    )
) ENGINE=InnoDB;

-- 19. STOCK_ADJUSTMENT (Feature 4.4 / Store Manager & Warehouse Staff)
CREATE TABLE IF NOT EXISTS stock_adjustment (
    adjustment_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id INT NULL,
    product_id INT NULL,
    quantity_adjusted INT NULL DEFAULT 0,
    inventory_id INT NULL,
    quantity_delta INT NULL DEFAULT 0,
    reason VARCHAR(255) NOT NULL,
    reported_by INT NULL,
    adjusted_by INT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    adjusted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (station_id) REFERENCES station_store(station_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE,
    FOREIGN KEY (inventory_id) REFERENCES inventory(inventory_id) ON DELETE SET NULL,
    FOREIGN KEY (reported_by) REFERENCES user(user_id) ON DELETE SET NULL,
    FOREIGN KEY (adjusted_by) REFERENCES user(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 20. NOTIFICATION (Real-time Logistics Alerts & Notification History)
CREATE TABLE IF NOT EXISTS notification (
    notification_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    recipient_email VARCHAR(255) NOT NULL,
    notification_type VARCHAR(50) NOT NULL DEFAULT 'NEW_CONSIGNMENT',
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    order_id INT NULL,
    is_read TINYINT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_notification_user (user_id),
    INDEX idx_notification_order (order_id),
    INDEX idx_notification_read (is_read),
    INDEX idx_notification_time (created_at DESC),
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE SET NULL,
    FOREIGN KEY (order_id) REFERENCES customer_order(order_id) ON DELETE CASCADE
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

-- 4. Station Warehouse Stock Inventory View (Feature 4.1 / 4.4)
CREATE OR REPLACE VIEW v_station_inventory AS
SELECT 
    inv.inventory_id,
    ss.station_id,
    ss.city AS station_city,
    p.product_id,
    p.product_name,
    p.unit_price,
    p.space_consumption_rate,
    inv.stored_quantity,
    sl.location_code AS bin_code,
    sl.location_type AS bin_type,
    inv.last_updated
FROM inventory inv
JOIN station_store ss ON inv.station_id = ss.station_id
JOIN product p ON inv.product_id = p.product_id
LEFT JOIN storage_location sl ON inv.location_id = sl.location_id;

-- 5. Incoming Train Manifests View (Feature 4.1 / 4.4)
CREATE OR REPLACE VIEW v_incoming_train_manifests AS
SELECT 
    m.manifest_id,
    m.station_id,
    ss.city AS destination_station,
    tt.trip_id,
    tt.departure_datetime,
    tt.arrival_datetime,
    tt.status AS train_status,
    m.status AS manifest_status,
    m.received_at
FROM manifest m
JOIN train_trip tt ON m.trip_id = tt.trip_id
JOIN station_store ss ON m.station_id = ss.station_id;

-- 5b. Incoming Train Cargo Items View (Feature 4.4 - Store Manager Cargo Inspection)
CREATE OR REPLACE VIEW v_trip_manifest_items AS
SELECT 
    ra.trip_id,
    ra.order_item_id,
    oi.order_id,
    p.product_id,
    p.product_name,
    ra.allocated_quantity,
    ra.allocated_space,
    p.space_consumption_rate,
    tt.destination_station_id AS station_id
FROM rail_allocation ra
JOIN order_item oi ON ra.order_item_id = oi.order_item_id
JOIN product p ON oi.product_id = p.product_id
JOIN train_trip tt ON ra.trip_id = tt.trip_id;

-- 6. Station Inventory & Stock Adjustment Summary View (Feature 4.4 / Report 6)
CREATE OR REPLACE VIEW v_stock_adjustment_summary AS
SELECT 
    ss.station_id,
    ss.city AS station_city,
    p.product_id,
    p.product_name,
    p.unit_price,
    sa.reason,
    COUNT(sa.adjustment_id) AS total_adjustment_events,
    SUM(sa.quantity_delta) AS net_quantity_delta,
    SUM(CASE WHEN sa.quantity_delta < 0 THEN ABS(sa.quantity_delta) ELSE 0 END) AS total_units_damaged_or_lost,
    SUM(CASE WHEN sa.quantity_delta < 0 THEN ABS(sa.quantity_delta) * p.unit_price ELSE 0.00 END) AS total_loss_value,
    MIN(sa.adjusted_at) AS first_adjustment_at,
    MAX(sa.adjusted_at) AS latest_adjustment_at
FROM stock_adjustment sa
JOIN inventory inv ON sa.inventory_id = inv.inventory_id
JOIN station_store ss ON inv.station_id = ss.station_id
JOIN product p ON inv.product_id = p.product_id
GROUP BY ss.station_id, ss.city, p.product_id, p.product_name, p.unit_price, sa.reason;


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
LEFT JOIN delivery_route dr ON co.delivery_route_id = dr.route_id
LEFT JOIN station_store ss ON dr.station_id = ss.station_id
JOIN order_item oi ON co.order_id = oi.order_id
JOIN rail_allocation ra ON oi.order_item_id = ra.order_item_id
GROUP BY ss.city, YEAR(co.order_date), QUARTER(co.order_date);

CREATE OR REPLACE VIEW v_trip_capacity_usage AS
SELECT 
    tt.trip_id,
    tt.origin_station_id,
    tt.destination_station_id,
    tt.departure_datetime,
    tt.status,
    tt.total_capacity,
    COALESCE(SUM(ra.allocated_space), 0) AS used_space,
    tt.total_capacity - COALESCE(SUM(ra.allocated_space), 0) AS remaining_space,
    ROUND((COALESCE(SUM(ra.allocated_space), 0) / tt.total_capacity) * 100, 2) AS utilisation_pct
FROM train_trip tt
LEFT JOIN rail_allocation ra ON tt.trip_id = ra.trip_id
GROUP BY tt.trip_id, tt.origin_station_id, tt.destination_station_id, tt.departure_datetime, tt.status, tt.total_capacity;


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
    JOIN delivery_route dr ON co.delivery_route_id = dr.route_id
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
    DECLARE v_roster_id INT;
    DECLARE v_overlap_count INT DEFAULT 0;
    DECLARE v_driver_hours DECIMAL(5,2);
    DECLARE v_assistant_hours DECIMAL(5,2);
    DECLARE v_driver_last_end DATETIME;
    DECLARE v_assistant_last_end DATETIME;
    DECLARE v_assistant_consec_count INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
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
        SET p_result_code = 'REJECTED_CHECK_A_OVERLAP';
        LEAVE PROC_BODY;
    END IF;

    SELECT MAX(end_time) INTO v_driver_last_end
    FROM roster_assignment
    WHERE driver_id = p_driver_id AND status != 'CANCELLED' AND end_time <= p_start_time;

    IF v_driver_last_end IS NOT NULL AND TIMESTAMPDIFF(HOUR, v_driver_last_end, p_start_time) < 8 THEN
        ROLLBACK;
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
        SET p_result_code = 'REJECTED_CHECK_C_ASSISTANT_REST';
        LEAVE PROC_BODY;
    END IF;

    IF (v_driver_hours + p_duration_hours) > 40.00 THEN
        ROLLBACK;
        SET p_result_code = 'REJECTED_CHECK_D_DRIVER_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    IF (v_assistant_hours + p_duration_hours) > 60.00 THEN
        ROLLBACK;
        SET p_result_code = 'REJECTED_CHECK_D_ASSISTANT_HOURS_EXCEEDED';
        LEAVE PROC_BODY;
    END IF;

    INSERT INTO roster_assignment(request_key, route_id, truck_id, driver_id, assistant_id, dispatcher_id, start_time, end_time, status)
    VALUES (UUID(), p_route_id, p_truck_id, p_driver_id, p_assistant_id, p_dispatcher_id, p_start_time, p_end_time, 'SCHEDULED');
    SET v_roster_id = LAST_INSERT_ID();

    UPDATE delivery_staff SET work_hours = work_hours + p_duration_hours WHERE delivery_staff_id = p_driver_id;
    UPDATE delivery_staff SET work_hours = work_hours + p_duration_hours WHERE delivery_staff_id = p_assistant_id;

    INSERT INTO audit_log(user_id, action, entity_id, outcome, entity_name, roster_id)
    VALUES (p_dispatcher_id, 'ASSIGN_ROSTER', v_roster_id, 'ACCEPTED', 'roster_assignment', v_roster_id);

    COMMIT;
    SET p_result_code = 'SUCCESS';
END //

-- PROCEDURE 3: Station Cargo Receiving Engine (Feature 4.4)
DROP PROCEDURE IF EXISTS sp_receive_manifest//
CREATE PROCEDURE sp_receive_manifest(
    IN p_station_id INT,
    IN p_trip_id INT,
    IN p_user_id INT,
    OUT p_result_code VARCHAR(50)
)
PROC_BODY: BEGIN
    DECLARE v_manifest_id INT;
    DECLARE v_manifest_status VARCHAR(50);
    DECLARE v_destination INT;
    DECLARE v_origin VARCHAR(100);
    DECLARE v_trip_status VARCHAR(50);
    DECLARE v_arrival DATETIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result_code = 'ERROR_TRANSACTION_FAILED';
    END;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    START TRANSACTION;

    SELECT t.destination_station_id, s.city, t.status, t.arrival_datetime
    INTO v_destination, v_origin, v_trip_status, v_arrival
    FROM train_trip t JOIN station_store s ON s.station_id=t.origin_station_id
    WHERE t.trip_id=p_trip_id FOR UPDATE;
    IF v_destination IS NULL OR v_destination<>p_station_id OR v_origin<>'Kandy' THEN
        ROLLBACK;
        SET p_result_code='INVALID_TRIP_DESTINATION';
        LEAVE PROC_BODY;
    END IF;

    -- 1. Lock and validate the manifest (stops two managers receiving it at once)
    SELECT manifest_id, status INTO v_manifest_id, v_manifest_status
    FROM manifest
    WHERE station_id = p_station_id AND trip_id = p_trip_id
    FOR UPDATE;

    IF v_manifest_id IS NULL THEN
        ROLLBACK;
        SET p_result_code = 'MANIFEST_NOT_FOUND';
        LEAVE PROC_BODY;
    END IF;

    IF v_manifest_status <> 'PENDING' THEN
        ROLLBACK;
        SET p_result_code = 'MANIFEST_ALREADY_RECEIVED';
        LEAVE PROC_BODY;
    END IF;

    IF v_trip_status IS NULL OR v_trip_status<>'ARRIVED' OR v_arrival>NOW() THEN
        ROLLBACK;
        SET p_result_code='TRIP_NOT_ARRIVED';
        LEAVE PROC_BODY;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM rail_allocation WHERE trip_id=p_trip_id) THEN
        ROLLBACK;
        SET p_result_code='MANIFEST_EMPTY';
        LEAVE PROC_BODY;
    END IF;
    IF EXISTS (SELECT 1 FROM rail_allocation a JOIN order_item i ON i.order_item_id=a.order_item_id
               JOIN customer_order o ON o.order_id=i.order_id JOIN delivery_route r ON r.route_id=o.delivery_route_id
               WHERE a.trip_id=p_trip_id AND (a.allocated_quantity<=0 OR r.station_id<>p_station_id)) THEN
        ROLLBACK;
        SET p_result_code='INVALID_MANIFEST_CARGO';
        LEAVE PROC_BODY;
    END IF;

    -- 2. Add every allocated product/quantity into this station's stock
    add_stock: BEGIN
        DECLARE v_product_id INT;
        DECLARE v_qty INT;
        DECLARE done INT DEFAULT FALSE;

        DECLARE cur_items CURSOR FOR
            SELECT oi.product_id, SUM(ra.allocated_quantity)
            FROM rail_allocation ra
            JOIN order_item oi ON ra.order_item_id = oi.order_item_id
            WHERE ra.trip_id = p_trip_id GROUP BY oi.product_id ORDER BY oi.product_id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

        OPEN cur_items;
        item_loop: LOOP
            FETCH cur_items INTO v_product_id, v_qty;
            IF done THEN LEAVE item_loop; END IF;

            INSERT INTO inventory (station_id, product_id, stored_quantity)
            VALUES (p_station_id, v_product_id, v_qty)
            ON DUPLICATE KEY UPDATE stored_quantity = stored_quantity + v_qty;

        END LOOP;
        CLOSE cur_items;
    END add_stock;

    -- 3. Mark the manifest as received
    UPDATE manifest
    SET status = 'RECEIVED', received_at = NOW()
    WHERE manifest_id = v_manifest_id;

    -- 4. For every order that had items on this trip, move it forward, but only
    --    once ALL of that order's trips (in case it spilled over onto several) have arrived.
    advance_orders: BEGIN
        DECLARE v_order_id INT;
        DECLARE v_remaining_trips INT;
        DECLARE v_order_status VARCHAR(50);
        DECLARE done2 INT DEFAULT FALSE;

        DECLARE cur_orders CURSOR FOR
            SELECT DISTINCT oi.order_id
            FROM rail_allocation ra
            JOIN order_item oi ON ra.order_item_id = oi.order_item_id
            WHERE ra.trip_id = p_trip_id ORDER BY oi.order_id;
        DECLARE CONTINUE HANDLER FOR NOT FOUND SET done2 = TRUE;

        OPEN cur_orders;
        order_loop: LOOP
            FETCH cur_orders INTO v_order_id;
            IF done2 THEN LEAVE order_loop; END IF;

            SELECT status INTO v_order_status FROM customer_order
            WHERE order_id=v_order_id FOR UPDATE;
            IF v_order_status IS NULL OR v_order_status NOT IN ('SCHEDULED_FOR_RAIL','SCHEDULED_MULTI_TRIP') THEN
                ROLLBACK;
                SET p_result_code='INVALID_ORDER_STATE';
                LEAVE PROC_BODY;
            END IF;

            SELECT COUNT(*) INTO v_remaining_trips
            FROM rail_allocation ra2
            JOIN order_item oi2 ON ra2.order_item_id = oi2.order_item_id
            JOIN train_trip tt2 ON ra2.trip_id = tt2.trip_id
            LEFT JOIN manifest m2 ON m2.trip_id = tt2.trip_id AND m2.station_id = tt2.destination_station_id
            WHERE oi2.order_id = v_order_id
              AND (m2.status IS NULL OR m2.status <> 'RECEIVED' OR m2.received_at IS NULL);

            IF v_remaining_trips = 0 AND NOT EXISTS (
                SELECT 1 FROM order_item oi WHERE oi.order_id=v_order_id
                AND oi.quantity<>(SELECT COALESCE(SUM(a.allocated_quantity),0)
                                  FROM rail_allocation a WHERE a.order_item_id=oi.order_item_id)
            ) THEN
                UPDATE customer_order
                SET status = 'ARRIVED_AT_STATION_STORE'
                WHERE order_id = v_order_id;

                INSERT INTO order_status_history (status, order_id, changed_by)
                VALUES ('ARRIVED_AT_STATION_STORE', v_order_id, p_user_id);
            END IF;

        END LOOP;
        CLOSE cur_orders;
    END advance_orders;

    COMMIT;
    SET p_result_code = 'SUCCESS';
END //

     
-- 4. TRIGGERS
     
DROP TRIGGER IF EXISTS trg_prevent_audit_log_modification//
CREATE TRIGGER trg_prevent_audit_log_modification BEFORE UPDATE ON audit_log FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs immutable'; END //

DROP TRIGGER IF EXISTS trg_prevent_audit_log_deletion//
CREATE TRIGGER trg_prevent_audit_log_deletion BEFORE DELETE ON audit_log FOR EACH ROW BEGIN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs immutable'; END //

-- Feature 4.4: Keep station stock in sync with the stock_adjustment log
DROP TRIGGER IF EXISTS trg_apply_stock_adjustment//
CREATE TRIGGER trg_apply_stock_adjustment
AFTER INSERT ON stock_adjustment
FOR EACH ROW
BEGIN
    UPDATE inventory
    SET stored_quantity = stored_quantity + NEW.quantity_delta
    WHERE inventory_id = NEW.inventory_id;
END //

DROP TRIGGER IF EXISTS trg_user_account_creation_policy//
CREATE TRIGGER trg_user_account_creation_policy
BEFORE INSERT ON user
FOR EACH ROW
BEGIN
    -- Force staff accounts to reset password on first login
    IF NEW.role != 'CUSTOMER' THEN
        SET NEW.force_password_reset = 1;

        -- Enforce company domain for internal staff roles
        IF NEW.email NOT LIKE '%@kandypack.lk' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Internal staff users must have an email ending with @kandypack.lk';
        END IF;
    ELSE
        -- Customers default to not forcing reset unless explicitly specified
        IF NEW.force_password_reset IS NULL THEN
            SET NEW.force_password_reset = 0;
        END IF;
    END IF;

    -- Validate role is in allowed set
    IF NEW.role NOT IN ('SUPERADMIN', 'LOGISTICS_MGR', 'DISPATCHER', 'STORE_MGR', 'WAREHOUSE_STAFF', 'DRIVER', 'ASSISTANT', 'CUSTOMER') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Invalid user role specified.';
    END IF;
END //

DROP TRIGGER IF EXISTS trg_roster_assignment_request_immutable//
CREATE TRIGGER trg_roster_assignment_request_immutable
BEFORE UPDATE ON roster_assignment
FOR EACH ROW
BEGIN
    IF NOT (OLD.roster_id <=> NEW.roster_id)
       OR NOT (OLD.request_key <=> NEW.request_key)
       OR NOT (OLD.route_id <=> NEW.route_id)
       OR NOT (OLD.truck_id <=> NEW.truck_id)
       OR NOT (OLD.driver_id <=> NEW.driver_id)
       OR NOT (OLD.assistant_id <=> NEW.assistant_id)
       OR NOT (OLD.dispatcher_id <=> NEW.dispatcher_id)
       OR NOT (OLD.start_time <=> NEW.start_time)
       OR NOT (OLD.end_time <=> NEW.end_time)
       OR NOT (OLD.created_at <=> NEW.created_at) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Roster assignment request facts are immutable';
    END IF;
END //

DELIMITER ;

     
-- 5. INDEXES
     
CREATE INDEX idx_train_trip_alloc ON train_trip (destination_station_id, status, departure_datetime);
CREATE INDEX idx_customer_order_status_date ON customer_order (status, order_date);
CREATE INDEX idx_roster_time_overlap ON roster_assignment (status, start_time, end_time, truck_id, driver_id, assistant_id);
CREATE INDEX idx_storage_loc_search ON storage_location (station_id, location_code);

     
-- 6. SEED DATA
     
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE audit_log; TRUNCATE TABLE delivery; TRUNCATE TABLE roster_assignment; TRUNCATE TABLE delivery_staff; TRUNCATE TABLE truck; TRUNCATE TABLE stock_adjustment; TRUNCATE TABLE inventory; TRUNCATE TABLE manifest; TRUNCATE TABLE rail_allocation; TRUNCATE TABLE order_status_history; TRUNCATE TABLE order_item; TRUNCATE TABLE customer_order; TRUNCATE TABLE customer; TRUNCATE TABLE delivery_route; TRUNCATE TABLE train_trip; TRUNCATE TABLE storage_location; TRUNCATE TABLE station_store; TRUNCATE TABLE product; TRUNCATE TABLE user;
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
INSERT INTO customer_order (order_id, customer_id, order_date, delivery_date, status, delivery_route_id, delivery_address, recipient_name, recipient_phone) VALUES
(1001, 1, '2026-08-08', '2026-08-15', 'PENDING_RAIL_SCHEDULING', 1, 'Main Street Wholesalers, Pettah', 'Lanka Retailers Ltd', '0112345678');

-- 9. ORDER_ITEM
INSERT INTO order_item (order_item_id, order_id, product_id, quantity, unit_price_at_order) VALUES
(1, 1001, 3, 200, 2600.00);

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

SOURCE 02_views.sql
SOURCE 09_roster_assignment.sql
SOURCE 10_roster_reporting.sql


DELIMITER //
DROP TRIGGER IF EXISTS trg_order_destination_immutable//
CREATE TRIGGER trg_order_destination_immutable BEFORE UPDATE ON customer_order FOR EACH ROW
BEGIN
    IF (NOT (OLD.delivery_route_id <=> NEW.delivery_route_id)
        OR NOT (OLD.delivery_address <=> NEW.delivery_address)
        OR NOT (OLD.recipient_name <=> NEW.recipient_name)
        OR NOT (OLD.recipient_phone <=> NEW.recipient_phone))
       AND (EXISTS(SELECT 1 FROM rail_allocation ra JOIN order_item oi ON oi.order_item_id=ra.order_item_id WHERE oi.order_id=OLD.order_id)
            OR EXISTS(SELECT 1 FROM delivery WHERE order_id=OLD.order_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Allocated order destinations are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_route_station_immutable//
CREATE TRIGGER trg_route_station_immutable BEFORE UPDATE ON delivery_route FOR EACH ROW
BEGIN
    IF OLD.station_id<>NEW.station_id AND
       (EXISTS(SELECT 1 FROM customer_order WHERE delivery_route_id=OLD.route_id)
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
DROP TRIGGER IF EXISTS trg_assigned_item_insert//
CREATE TRIGGER trg_assigned_item_insert BEFORE INSERT ON order_item FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=NEW.order_id FOR UPDATE;
    IF EXISTS(SELECT 1 FROM delivery WHERE order_id=NEW.order_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order items are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_assigned_item_update//
CREATE TRIGGER trg_assigned_item_update BEFORE UPDATE ON order_item FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=LEAST(OLD.order_id,NEW.order_id) FOR UPDATE;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=GREATEST(OLD.order_id,NEW.order_id) FOR UPDATE;
    IF (NOT (OLD.order_id <=> NEW.order_id) OR NOT (OLD.product_id <=> NEW.product_id)
        OR NOT (OLD.quantity <=> NEW.quantity) OR NOT (OLD.order_item_id <=> NEW.order_item_id))
       AND EXISTS(SELECT 1 FROM delivery WHERE order_id IN (OLD.order_id,NEW.order_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order items are immutable';
    END IF;
END //
DROP TRIGGER IF EXISTS trg_assigned_item_delete//
CREATE TRIGGER trg_assigned_item_delete BEFORE DELETE ON order_item FOR EACH ROW
BEGIN
    DECLARE v_order INT;
    SELECT order_id INTO v_order FROM customer_order WHERE order_id=OLD.order_id FOR UPDATE;
    IF EXISTS(SELECT 1 FROM delivery WHERE order_id=OLD.order_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Assigned order items are immutable';
    END IF;
END //
DELIMITER ;

CREATE INDEX idx_order_destination_date ON customer_order (delivery_route_id, delivery_date, status);
CREATE INDEX idx_delivery_run_status ON delivery (roster_id, delivery_status, delivery_id);

CREATE INDEX idx_manifest_station_status ON manifest (station_id, status);

CREATE INDEX idx_stock_adjust_inv_date ON stock_adjustment (inventory_id, adjusted_at);
