USE kandypack_db;

-- =====================================================
-- PERF-01
-- Pending rail-scheduling order list should load
-- within 3 seconds
-- =====================================================

SELECT
    co.order_id,
    c.customer_name,
    co.order_date,
    co.delivery_date,
    co.status
FROM customer_order co
JOIN customer c
    ON co.customer_id = c.customer_id
WHERE co.status = 'PENDING_RAIL_SCHEDULING';


-- =====================================================
-- PERF-02
-- Suitable train trips and remaining capacities
-- should be retrieved within 3 seconds
-- =====================================================

SELECT
    tt.trip_id,
    ss.city AS destination,
    tt.departure_datetime,
    tt.arrival_datetime,
    tt.total_capacity,
    tt.status
FROM train_trip tt
JOIN station_store ss
    ON tt.destination_station_id = ss.station_id
WHERE tt.status = 'SCHEDULED'
ORDER BY tt.departure_datetime;


-- =====================================================
-- PERF-03
-- Calculate total space for an order within 2 seconds
-- =====================================================

SELECT
    co.order_id,
    SUM(
        oi.quantity * p.space_consumption_rate
    ) AS total_required_space
FROM customer_order co
JOIN order_item oi
    ON co.order_id = oi.order_id
JOIN product p
    ON oi.product_id = p.product_id
GROUP BY co.order_id;


-- =====================================================
-- PERF-06
-- Capacity updates should be visible immediately
-- after transaction commit
-- =====================================================

SELECT
    tt.trip_id,
    tt.total_capacity,
    COALESCE(SUM(ra.allocated_space), 0) AS allocated_space,
    tt.total_capacity
        - COALESCE(SUM(ra.allocated_space), 0)
        AS remaining_capacity
FROM train_trip tt
LEFT JOIN rail_allocation ra
    ON tt.trip_id = ra.trip_id
WHERE tt.trip_id IN (1, 2)
GROUP BY
    tt.trip_id,
    tt.total_capacity
ORDER BY tt.trip_id;


-- PERF-09A: Quarterly Sales Report

SELECT
    sales_year,
    sales_quarter,
    IFNULL(route_name, 'ALL_ROUTES') AS route_name,
    IFNULL(product_name, 'ALL_PRODUCTS') AS product_name,
    total_quantity,
    total_sales
FROM (
    SELECT
        YEAR(co.order_date) AS sales_year,
        QUARTER(co.order_date) AS sales_quarter,
        dr.route_name,
        p.product_name,
        SUM(oi.quantity) AS total_quantity,
        ROUND(SUM(oi.quantity * p.unit_price), 2) AS total_sales
    FROM customer_order co
    JOIN customer c
        ON co.customer_id = c.customer_id
    LEFT JOIN delivery_route dr
        ON c.route_id = dr.route_id
    JOIN order_item oi
        ON co.order_id = oi.order_id
    JOIN product p
        ON oi.product_id = p.product_id
    GROUP BY
        YEAR(co.order_date),
        QUARTER(co.order_date),
        dr.route_name,
        p.product_name
    WITH ROLLUP
) AS quarterly_sales;


-- =====================================================
-- PERF-09B: Rail Capacity Utilization Report
-- Target: <= 10 seconds
-- =====================================================

WITH trip_capacity AS (
    SELECT
        tt.trip_id,
        tt.destination_station_id,
        YEAR(tt.departure_datetime) AS dep_year,
        MONTH(tt.departure_datetime) AS dep_month,
        tt.total_capacity
    FROM train_trip tt
),

trip_allocations AS (
    SELECT
        trip_id,
        SUM(allocated_space) AS allocated_space
    FROM rail_allocation
    GROUP BY trip_id
)

SELECT
    ss.city AS destination_hub,
    tc.dep_year,
    tc.dep_month,

    ROUND(SUM(tc.total_capacity), 2)
        AS total_capacity,

    ROUND(
        SUM(COALESCE(ta.allocated_space, 0)),
        2
    ) AS allocated_capacity,

    ROUND(
        SUM(tc.total_capacity)
        - SUM(COALESCE(ta.allocated_space, 0)),
        2
    ) AS remaining_capacity,

    ROUND(
        (
            SUM(COALESCE(ta.allocated_space, 0))
            / NULLIF(SUM(tc.total_capacity), 0)
        ) * 100,
        2
    ) AS utilization_percentage

FROM trip_capacity tc
JOIN station_store ss
    ON tc.destination_station_id = ss.station_id
LEFT JOIN trip_allocations ta
    ON tc.trip_id = ta.trip_id

GROUP BY
    ss.city,
    tc.dep_year,
    tc.dep_month

ORDER BY
    tc.dep_year,
    tc.dep_month,
    ss.city;