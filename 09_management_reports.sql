USE kandypack_db;

-- =======================================================
-- REPORT 1: Quarterly Sales by Route and Product
-- Uses ROLLUP for subtotal / grand-total reporting
-- =======================================================

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


-- =======================================================
-- REPORT 2: Top-Selling Products per Quarter
-- Uses DENSE_RANK window function
-- =======================================================

WITH quarterly_product_sales AS (
    SELECT
        YEAR(co.order_date) AS sales_year,
        QUARTER(co.order_date) AS sales_quarter,
        p.product_id,
        p.product_name,
        SUM(oi.quantity) AS total_quantity,
        ROUND(SUM(oi.quantity * p.unit_price), 2) AS total_sales
    FROM customer_order co
    JOIN order_item oi
        ON co.order_id = oi.order_id
    JOIN product p
        ON oi.product_id = p.product_id
    GROUP BY
        YEAR(co.order_date),
        QUARTER(co.order_date),
        p.product_id,
        p.product_name
)

SELECT
    sales_year,
    sales_quarter,
    product_id,
    product_name,
    total_quantity,
    total_sales,
    DENSE_RANK() OVER (
        PARTITION BY sales_year, sales_quarter
        ORDER BY total_quantity DESC
    ) AS product_rank
FROM quarterly_product_sales
ORDER BY
    sales_year,
    sales_quarter,
    product_rank;


-- =======================================================
-- REPORT 3: Rail Capacity Utilization by Station & Month
-- =======================================================

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

    ROUND(SUM(tc.total_capacity), 2) AS total_capacity,

    ROUND(
        SUM(COALESCE(ta.allocated_space, 0)),
        2
    ) AS allocated_capacity,

    ROUND(
        SUM(tc.total_capacity)
        -
        SUM(COALESCE(ta.allocated_space, 0)),
        2
    ) AS remaining_capacity,

    ROUND(
        (
            SUM(COALESCE(ta.allocated_space, 0))
            /
            NULLIF(SUM(tc.total_capacity), 0)
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


-- =======================================================
-- REPORT 4: Workforce Hours vs. 40h / 60h Cap
-- DRIVER = 40 hours
-- ASSISTANT = 60 hours
-- =======================================================

SELECT
    ds.delivery_staff_id,
    u.name AS staff_name,
    u.role AS staff_role,
    ds.work_hours AS accumulated_hours,

    CASE
        WHEN u.role = 'DRIVER' THEN 40.00
        WHEN u.role = 'ASSISTANT' THEN 60.00
        ELSE NULL
    END AS weekly_cap,

    ROUND(
        (
            ds.work_hours /
            NULLIF(
                CASE
                    WHEN u.role = 'DRIVER' THEN 40.00
                    WHEN u.role = 'ASSISTANT' THEN 60.00
                    ELSE NULL
                END,
                0
            )
        ) * 100,
        1
    ) AS utilization_pct,

    CASE
        WHEN u.role = 'DRIVER'
             AND ds.work_hours >= 40
            THEN 'CAP_REACHED'

        WHEN u.role = 'ASSISTANT'
             AND ds.work_hours >= 60
            THEN 'CAP_REACHED'

        WHEN u.role = 'DRIVER'
             AND ds.work_hours >= 36
            THEN 'NEAR_CAP_WARNING'

        WHEN u.role = 'ASSISTANT'
             AND ds.work_hours >= 54
            THEN 'NEAR_CAP_WARNING'

        ELSE 'SAFE'
    END AS status_flag

FROM delivery_staff ds

JOIN user u
    ON ds.user_id = u.user_id

WHERE u.role IN ('DRIVER', 'ASSISTANT')

ORDER BY utilization_pct DESC;


-- =======================================================
-- REPORT 5: Truck Utilization
-- Number of routes + total working hours per truck
-- =======================================================

SELECT
    t.truck_id,
    t.plate_number,

    COUNT(ra.roster_id) AS total_delivery_runs,

    ROUND(
        COALESCE(
            SUM(
                TIMESTAMPDIFF(
                    MINUTE,
                    ra.start_time,
                    ra.end_time
                )
            ) / 60.0,
            0
        ),
        2
    ) AS total_operating_hours

FROM truck t

LEFT JOIN roster_assignment ra
    ON t.truck_id = ra.truck_id

GROUP BY
    t.truck_id,
    t.plate_number

ORDER BY
    total_delivery_runs DESC;


-- =======================================================
-- REPORT 6: Station Inventory & Stock Adjustment Summary
-- =======================================================

WITH inventory_summary AS (

    SELECT
        m.station_id,
        oi.product_id,
        SUM(inv.stored_quantity) AS stored_quantity

    FROM inventory inv

    JOIN order_item oi
        ON inv.order_item_id = oi.order_item_id

    JOIN manifest m
        ON inv.manifest_id = m.manifest_id

    GROUP BY
        m.station_id,
        oi.product_id
),

adjustment_summary AS (

    SELECT
        station_id,
        product_id,

        SUM(
            CASE
                WHEN quantity_adjusted > 0
                THEN quantity_adjusted
                ELSE 0
            END
        ) AS positive_adjustments,

        SUM(
            CASE
                WHEN quantity_adjusted < 0
                THEN ABS(quantity_adjusted)
                ELSE 0
            END
        ) AS negative_adjustments,

        SUM(quantity_adjusted) AS net_adjustment

    FROM stock_adjustment

    GROUP BY
        station_id,
        product_id
)

SELECT
    ss.station_id,
    ss.city AS station,
    p.product_id,
    p.product_name,

    COALESCE(i.stored_quantity, 0) AS stored_quantity,

    COALESCE(a.positive_adjustments, 0)
        AS positive_adjustments,

    COALESCE(a.negative_adjustments, 0)
        AS negative_adjustments,

    COALESCE(a.net_adjustment, 0)
        AS net_adjustment,

    COALESCE(i.stored_quantity, 0)
        +
    COALESCE(a.net_adjustment, 0)
        AS adjusted_stock

FROM inventory_summary i

JOIN station_store ss
    ON i.station_id = ss.station_id

JOIN product p
    ON i.product_id = p.product_id

LEFT JOIN adjustment_summary a
    ON i.station_id = a.station_id
    AND i.product_id = a.product_id

ORDER BY
    ss.city,
    p.product_name;