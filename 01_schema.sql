-- Kandypack Logistics Platform - Database Schema DDL (MySQL 8.0 / InnoDB)
CREATE DATABASE IF NOT EXISTS kandypack_db;
USE kandypack_db;

-- Drop existing tables in reverse dependency order if resetting
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
    unit_price_at_order DECIMAL(10,2) NOT NULL,

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
    inventory_id INT NOT NULL,
    quantity_delta INT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    adjusted_by INT NULL,
    adjusted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_adjustment_nonzero CHECK (quantity_delta <> 0),
    FOREIGN KEY (inventory_id) REFERENCES inventory(inventory_id),
    FOREIGN KEY (adjusted_by) REFERENCES user(user_id) ON DELETE SET NULL
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
    -- Unrelated column audit inserts leave the roster NULL.
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
    station_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_adjusted INT NOT NULL,
    reason VARCHAR(255) NOT NULL,
    reported_by INT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (station_id) REFERENCES station_store(station_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES product(product_id) ON DELETE CASCADE,
    FOREIGN KEY (reported_by) REFERENCES user(user_id) ON DELETE SET NULL
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

