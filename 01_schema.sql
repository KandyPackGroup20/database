-- Kandypack Logistics Platform - Database Schema DDL (MySQL 8.0 / InnoDB)
CREATE DATABASE IF NOT EXISTS kandypack_db;
USE kandypack_db;

-- Drop existing tables in reverse dependency order if resetting
DROP TABLE IF EXISTS roster_audit_logs;
DROP TABLE IF EXISTS roster_assignments;
DROP TABLE IF EXISTS inventory_discrepancies;
DROP TABLE IF EXISTS station_inventory;
DROP TABLE IF EXISTS order_trip_allocations;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS train_trips;
DROP TABLE IF EXISTS trucks;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS assistants;
DROP TABLE IF EXISTS delivery_routes;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS station_stores;
DROP TABLE IF EXISTS users;

-- 1. USERS & ROLES
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role ENUM('SUPERADMIN', 'LOGISTICS_MGR', 'DISPATCHER', 'STORE_MGR', 'WAREHOUSE_STAFF', 'DRIVER', 'CUSTOMER') NOT NULL,
    force_password_reset BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. REGIONAL STATIONS
CREATE TABLE station_stores (
    station_id VARCHAR(10) PRIMARY KEY, -- 'CMB', 'NEG', 'GAL', 'MAT', 'JAF', 'TRIN'
    city_name VARCHAR(100) NOT NULL UNIQUE,
    manager_user_id INT NULL,
    FOREIGN KEY (manager_user_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 3. PRODUCTS
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    unit_sku VARCHAR(50) UNIQUE NOT NULL,
    space_consumption_rate DECIMAL(6, 4) NOT NULL, -- cubic meters per unit quantity
    category VARCHAR(100) DEFAULT 'General Goods'
) ENGINE=InnoDB;

-- 4. TRAIN TRIPS (Kandy -> Destination Hubs)
CREATE TABLE train_trips (
    trip_id INT AUTO_INCREMENT PRIMARY KEY,
    trip_code VARCHAR(20) NOT NULL UNIQUE,
    origin_hub VARCHAR(10) DEFAULT 'KDY',
    destination_hub VARCHAR(10) NOT NULL,
    departure_time DATETIME NOT NULL,
    arrival_time DATETIME NOT NULL,
    total_capacity_cubic_m DECIMAL(10, 2) NOT NULL,
    remaining_capacity_cubic_m DECIMAL(10, 2) NOT NULL,
    status ENUM('SCHEDULED', 'DEPARTED', 'ARRIVED', 'CANCELLED') DEFAULT 'SCHEDULED',
    FOREIGN KEY (destination_hub) REFERENCES station_stores(station_id),
    CONSTRAINT chk_train_capacity CHECK (remaining_capacity_cubic_m >= 0)
) ENGINE=InnoDB;

-- 5. CUSTOMER ORDERS
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    destination_hub VARCHAR(10) NOT NULL,
    delivery_address TEXT NOT NULL,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    delivery_date DATE NOT NULL,
    status ENUM('PENDING_RAIL_SCHEDULING', 'SCHEDULED_FOR_RAIL', 'SCHEDULED_MULTI_TRIP', 'ARRIVED_AT_STATION_STORE', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED') DEFAULT 'PENDING_RAIL_SCHEDULING',
    FOREIGN KEY (customer_id) REFERENCES users(user_id),
    FOREIGN KEY (destination_hub) REFERENCES station_stores(station_id)
) ENGINE=InnoDB;

-- 6. ORDER ITEMS
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    total_space_required DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

-- 7. RAIL ALLOCATIONS (Includes Spillover Mapping)
CREATE TABLE order_trip_allocations (
    allocation_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    order_item_id INT NOT NULL,
    trip_id INT NOT NULL,
    allocated_quantity INT NOT NULL,
    allocated_space DECIMAL(10, 2) NOT NULL,
    allocated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id),
    FOREIGN KEY (trip_id) REFERENCES train_trips(trip_id)
) ENGINE=InnoDB;

-- 8. STATION INVENTORY & WAREHOUSE BINS
CREATE TABLE station_inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id VARCHAR(10) NOT NULL,
    product_id INT NOT NULL,
    quantity_available INT DEFAULT 0,
    bin_location VARCHAR(50) DEFAULT 'UNASSIGNED',
    last_scanned_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (station_id) REFERENCES station_stores(station_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    UNIQUE KEY uq_station_product (station_id, product_id)
) ENGINE=InnoDB;

-- 9. DELIVERY ROUTES & TRUCKS
CREATE TABLE delivery_routes (
    route_id INT AUTO_INCREMENT PRIMARY KEY,
    station_id VARCHAR(10) NOT NULL,
    route_name VARCHAR(100) NOT NULL,
    estimated_duration_hours DECIMAL(4, 2) NOT NULL,
    FOREIGN KEY (station_id) REFERENCES station_stores(station_id)
) ENGINE=InnoDB;

CREATE TABLE trucks (
    truck_id INT AUTO_INCREMENT PRIMARY KEY,
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    station_id VARCHAR(10) NOT NULL,
    capacity_kg DECIMAL(10, 2) NOT NULL,
    status ENUM('AVAILABLE', 'ASSIGNED', 'MAINTENANCE') DEFAULT 'AVAILABLE',
    FOREIGN KEY (station_id) REFERENCES station_stores(station_id)
) ENGINE=InnoDB;

-- 10. DRIVERS & ASSISTANTS (Labor Regulation Tracking)
CREATE TABLE drivers (
    driver_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    license_no VARCHAR(30) UNIQUE NOT NULL,
    accumulated_weekly_hours DECIMAL(5, 2) DEFAULT 0.00, -- Hard Cap: 40.00h
    consecutive_routes_count INT DEFAULT 0,
    last_trip_end_time DATETIME NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE TABLE assistants (
    assistant_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    accumulated_weekly_hours DECIMAL(5, 2) DEFAULT 0.00, -- Hard Cap: 60.00h
    consecutive_routes_count INT DEFAULT 0,
    last_trip_end_time DATETIME NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- 11. TRUCK ROSTER ASSIGNMENTS
CREATE TABLE roster_assignments (
    roster_id INT AUTO_INCREMENT PRIMARY KEY,
    route_id INT NOT NULL,
    truck_id INT NOT NULL,
    driver_id INT NOT NULL,
    assistant_id INT NOT NULL,
    dispatcher_id INT NOT NULL,
    scheduled_start DATETIME NOT NULL,
    scheduled_end DATETIME NOT NULL,
    route_duration_hours DECIMAL(4, 2) NOT NULL,
    status ENUM('SCHEDULED', 'IN_TRANSIT', 'COMPLETED', 'CANCELLED') DEFAULT 'SCHEDULED',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (route_id) REFERENCES delivery_routes(route_id),
    FOREIGN KEY (truck_id) REFERENCES trucks(truck_id),
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    FOREIGN KEY (assistant_id) REFERENCES assistants(assistant_id),
    FOREIGN KEY (dispatcher_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- 12. IMMUTABLE ROSTER AUDIT LOGS
CREATE TABLE roster_audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    dispatcher_id INT NOT NULL,
    attempt_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('SUCCESS', 'REJECTED') NOT NULL,
    violation_rule VARCHAR(50) NULL, -- 'CHECK_A_OVERLAP', 'CHECK_B_DRIVER_REST', 'CHECK_C_ASSISTANT_REST', 'CHECK_D_HOURS_CAP'
    details TEXT NOT NULL,
    FOREIGN KEY (dispatcher_id) REFERENCES users(user_id)
) ENGINE=InnoDB;
