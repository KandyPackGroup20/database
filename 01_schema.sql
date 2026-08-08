-- Kandypack Logistics Platform - Database Schema DDL (MySQL 8.0 / InnoDB)
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
