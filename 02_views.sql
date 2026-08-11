-- Kandypack Logistics Platform - Database Views (MySQL 8.0)
USE kandypack_db;

-- 1. Available Drivers View (Feature 4.1 / 4.3)
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

-- 2. Available Assistants View (Feature 4.1 / 4.3)
CREATE OR REPLACE VIEW v_available_assistants AS
SELECT 
    ds.delivery_staff_id AS assistant_id,
    u.name AS full_name,
    ds.work_hours AS accumulated_weekly_hours,
    60.00 - ds.work_hours AS remaining_hours_allowed
FROM delivery_staff ds
JOIN user u ON ds.user_id = u.user_id
WHERE u.role = 'ASSISTANT' AND ds.work_hours < 60.00;

-- 3. Driver Working Hours Warning View (SR-5.2.4 Visual Warnings near 10% threshold)
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
    ss.station_id,
    ss.city AS station_city,
    p.product_id,
    p.product_name,
    p.unit_price,
    p.space_consumption_rate,
    inv.stored_quantity,
    sl.location_code AS bin_code,
    sl.location_type AS bin_type
FROM inventory inv
JOIN order_item oi ON inv.order_item_id = oi.order_item_id
JOIN product p ON oi.product_id = p.product_id
JOIN manifest m ON inv.manifest_id = m.manifest_id
JOIN station_store ss ON m.station_id = ss.station_id
LEFT JOIN storage_location sl ON ss.station_id = sl.station_id;

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

-- 6. Customer Orders View (Feature 4.1 - Customer Portal scoping)
CREATE OR REPLACE VIEW v_customer_orders AS
SELECT 
    co.order_id,
    co.customer_id,
    c.customer_name,
    u.email AS customer_email,
    co.order_date,
    co.delivery_date,
    co.status AS order_status,
    dr.route_name AS destination_route,
    ss.city AS arrival_hub,
    co.created_at
FROM customer_order co
JOIN customer c ON co.customer_id = c.customer_id
JOIN user u ON c.user_id = u.user_id
LEFT JOIN delivery_route dr ON c.route_id = dr.route_id
LEFT JOIN station_store ss ON dr.station_id = ss.station_id;

-- 7. Quarterly Sales Summary View (Feature 4.1 / Report 1)
CREATE OR REPLACE VIEW v_quarterly_sales AS
SELECT 
    IFNULL(dr.route_name, 'TOTAL_ALL_ROUTES') AS route_name,
    IFNULL(p.product_name, 'TOTAL_ALL_PRODUCTS') AS product_name,
    YEAR(co.order_date) AS order_year,
    QUARTER(co.order_date) AS order_quarter,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * p.unit_price) AS total_revenue
FROM customer_order co
JOIN order_item oi ON co.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
JOIN customer c ON co.customer_id = c.customer_id
LEFT JOIN delivery_route dr ON c.route_id = dr.route_id
GROUP BY dr.route_name, p.product_name, YEAR(co.order_date), QUARTER(co.order_date) WITH ROLLUP;

-- 8. Top Quarterly Selling Products View (Feature 4.1 / Report 2)
CREATE OR REPLACE VIEW v_top_quarterly_items AS
SELECT 
    YEAR(co.order_date) AS order_year,
    QUARTER(co.order_date) AS order_quarter,
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * p.unit_price) AS total_revenue,
    DENSE_RANK() OVER (
        PARTITION BY YEAR(co.order_date), QUARTER(co.order_date) 
        ORDER BY SUM(oi.quantity) DESC
    ) AS sales_rank
FROM customer_order co
JOIN order_item oi ON co.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
GROUP BY YEAR(co.order_date), QUARTER(co.order_date), p.product_id, p.product_name;
