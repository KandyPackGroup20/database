-- Kandypack Logistics Platform - Database Views (MySQL 8.0)
USE kandypack_db;

-- 1. Available Drivers View (Filters out drivers reaching cap or needing rest)
CREATE OR REPLACE VIEW v_available_drivers AS
SELECT 
    d.driver_id,
    d.full_name,
    d.license_no,
    d.accumulated_weekly_hours,
    40.00 - d.accumulated_weekly_hours AS remaining_hours_allowed,
    d.consecutive_routes_count,
    d.last_trip_end_time
FROM drivers d
WHERE d.accumulated_weekly_hours < 40.00;

-- 2. Available Assistants View (Filters out assistants reaching cap)
CREATE OR REPLACE VIEW v_available_assistants AS
SELECT 
    a.assistant_id,
    a.full_name,
    a.accumulated_weekly_hours,
    60.00 - a.accumulated_weekly_hours AS remaining_hours_allowed,
    a.consecutive_routes_count,
    a.last_trip_end_time
FROM assistants a
WHERE a.accumulated_weekly_hours < 60.00;

-- 3. Driver Working Hours Warning View (SR-5.2.4 Visual Warnings near 10% threshold)
CREATE OR REPLACE VIEW v_drivers_near_cap AS
SELECT 
    d.driver_id,
    d.full_name,
    d.accumulated_weekly_hours,
    40.00 AS cap_hours,
    ROUND((d.accumulated_weekly_hours / 40.00) * 100, 1) AS utilization_pct,
    CASE 
        WHEN d.accumulated_weekly_hours >= 40.00 THEN 'CAP_REACHED'
        WHEN d.accumulated_weekly_hours >= 36.00 THEN 'WARNING_NEAR_CAP' -- 10% remaining threshold (36h+)
        ELSE 'SAFE'
    END AS status_flag
FROM drivers d;

-- 4. Station Warehouse Stock Inventory View
CREATE OR REPLACE VIEW v_station_inventory_overview AS
SELECT 
    s.station_id,
    s.city_name,
    p.product_id,
    p.name AS product_name,
    p.unit_sku,
    si.quantity_available,
    si.bin_location,
    si.last_scanned_at
FROM station_inventory si
JOIN station_stores s ON si.station_id = s.station_id
JOIN products p ON si.product_id = p.product_id;

-- 5. Quarterly Rail Sales & Capacity Analytics View (PERF-09)
CREATE OR REPLACE VIEW v_quarterly_rail_analytics AS
SELECT 
    s.city_name AS destination_hub,
    YEAR(o.order_date) AS order_year,
    QUARTER(o.order_date) AS order_quarter,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(ota.allocated_quantity) AS total_units_shipped,
    SUM(ota.allocated_space) AS total_cubic_meters_shipped
FROM orders o
JOIN station_stores s ON o.destination_hub = s.station_id
JOIN order_trip_allocations ota ON o.order_id = ota.order_id
GROUP BY s.city_name, YEAR(o.order_date), QUARTER(o.order_date);
