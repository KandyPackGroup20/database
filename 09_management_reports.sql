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
        ROUND(
            SUM(oi.quantity * oi.unit_price_at_order),
            2
        ) AS total_sales
    FROM customer_order co
    JOIN customer c
        ON co.customer_id = c.customer_id
    LEFT JOIN delivery_route dr
        ON co.delivery_route_id = dr.route_id
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
        ROUND(
            SUM(oi.quantity * oi.unit_price_at_order),
            2
        ) AS total_sales
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
),
ranked_products AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY sales_year, sales_quarter
            ORDER BY total_quantity DESC
        ) AS product_rank
    FROM quarterly_product_sales
)

SELECT
    sales_year,
    sales_quarter,
    product_id,
    product_name,
    total_quantity,
    total_sales,
    product_rank
FROM ranked_products
WHERE product_rank = 1
ORDER BY
    sales_year,
    sales_quarter;

-- =======================================================
-- REPORT 3: City-wise and Route-wise Sales
-- =======================================================

SELECT
    ss.city AS city_name,
    dr.route_name,
    SUM(oi.quantity) AS total_quantity,
    ROUND(
        SUM(oi.quantity * oi.unit_price_at_order),
        2
    ) AS total_sales
FROM customer_order co

JOIN customer c
    ON co.customer_id = c.customer_id

JOIN delivery_route dr
    ON co.delivery_route_id = dr.route_id

JOIN station_store ss
    ON dr.station_id = ss.station_id

JOIN order_item oi
    ON co.order_id = oi.order_id

GROUP BY
    ss.city,
    dr.route_name

ORDER BY
    ss.city,
    dr.route_name;

-- =======================================================
-- REPORT 4: Driver and Assistant Weekly Working Hours
-- =======================================================

SELECT
    ds.delivery_staff_id,
    u.name AS staff_name,
    u.role AS staff_role,

    YEARWEEK(ra.start_time, 1) AS work_week,

    ROUND(
        SUM(
            TIMESTAMPDIFF(
                MINUTE,
                ra.start_time,
                ra.end_time
            )
        ) / 60.0,
        2
    ) AS scheduled_hours,

    CASE
        WHEN u.role = 'DRIVER' THEN 40.00
        WHEN u.role = 'ASSISTANT' THEN 60.00
    END AS weekly_cap,

    CASE
        WHEN u.role = 'DRIVER'
             AND SUM(TIMESTAMPDIFF(MINUTE,ra.start_time,ra.end_time))/60.0 >= 40
            THEN 'CAP_REACHED'

        WHEN u.role = 'ASSISTANT'
             AND SUM(TIMESTAMPDIFF(MINUTE,ra.start_time,ra.end_time))/60.0 >= 60
            THEN 'CAP_REACHED'

        ELSE 'SAFE'
    END AS status_flag

FROM roster_assignment ra

JOIN delivery_staff ds
    ON (
        ra.driver_id = ds.delivery_staff_id
        OR ra.assistant_id = ds.delivery_staff_id
    )

JOIN user u
    ON ds.user_id = u.user_id

WHERE
    u.role IN ('DRIVER','ASSISTANT')
    AND ra.status <> 'CANCELLED'

GROUP BY
    ds.delivery_staff_id,
    u.name,
    u.role,
    YEARWEEK(ra.start_time,1)

ORDER BY
    work_week,
    staff_name;


-- =======================================================
-- REPORT 5: Monthly Truck Usage
-- =======================================================

SELECT
    t.truck_id,
    t.plate_number,

    YEAR(ra.start_time) AS usage_year,
    MONTH(ra.start_time) AS usage_month,

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

JOIN roster_assignment ra
    ON t.truck_id = ra.truck_id

WHERE ra.status <> 'CANCELLED'

GROUP BY
    t.truck_id,
    t.plate_number,
    YEAR(ra.start_time),
    MONTH(ra.start_time)

ORDER BY
    usage_year,
    usage_month,
    t.truck_id;

-- =======================================================
-- REPORT 6: Customer Order and Delivery History
-- =======================================================

SELECT
    co.order_id,
    c.customer_name,
    co.order_date,
    co.delivery_date,
    co.status AS order_status,

    dr.route_name,

    tt.trip_id,
    tt.departure_datetime,
    tt.arrival_datetime,

    ra.allocated_quantity,
    ra.allocated_space,
    ra.allocated_at,

    m.status AS manifest_status,
    m.received_at,

    t.plate_number,

    d.delivery_status,
    d.delivered_at,
    d.proof_reference

FROM customer_order co

JOIN customer c
    ON co.customer_id = c.customer_id

LEFT JOIN delivery_route dr
    ON co.delivery_route_id = dr.route_id

LEFT JOIN order_item oi
    ON co.order_id = oi.order_id

LEFT JOIN rail_allocation ra
    ON oi.order_item_id = ra.order_item_id

LEFT JOIN train_trip tt
    ON ra.trip_id = tt.trip_id

LEFT JOIN manifest m
    ON tt.trip_id = m.trip_id

LEFT JOIN delivery d
    ON co.order_id = d.order_id

LEFT JOIN roster_assignment r
    ON d.roster_id = r.roster_id

LEFT JOIN truck t
    ON r.truck_id = t.truck_id

ORDER BY
    co.order_id,
    tt.departure_datetime;