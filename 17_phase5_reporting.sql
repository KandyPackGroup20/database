-- Non-destructive MySQL 8 reporting migration. Select the target schema first.
-- Requires the existing roster reporting migration (10). No data is seeded here.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_report_quarterly_sales AS
SELECT YEAR(o.order_date) AS sales_year, QUARTER(o.order_date) AS sales_quarter,
       o.delivery_route_id AS route_id, i.product_id,
       CASE WHEN GROUPING(o.delivery_route_id) THEN 'ALL ROUTES' ELSE MAX(r.route_name) END AS route_name,
       CASE WHEN GROUPING(i.product_id) THEN 'ALL PRODUCTS' ELSE MAX(p.product_name) END AS product_name,
       SUM(i.quantity) AS total_quantity,
       ROUND(SUM(i.quantity * i.unit_price_at_order),2) AS total_sales,
       CASE WHEN GROUPING(YEAR(o.order_date)) THEN 'grand_total'
            WHEN GROUPING(QUARTER(o.order_date)) THEN 'year_total'
            WHEN GROUPING(o.delivery_route_id) THEN 'quarter_total'
            WHEN GROUPING(i.product_id) THEN 'route_total' ELSE 'detail' END AS row_level
FROM customer_order o JOIN order_item i ON i.order_id=o.order_id
JOIN delivery_route r ON r.route_id=o.delivery_route_id
JOIN product p ON p.product_id=i.product_id
WHERE o.status <> 'CANCELLED'
GROUP BY YEAR(o.order_date), QUARTER(o.order_date), o.delivery_route_id, i.product_id WITH ROLLUP;

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_report_top_products AS
WITH sales AS (
 SELECT YEAR(o.order_date) AS sales_year, QUARTER(o.order_date) AS sales_quarter,
        i.product_id, MAX(p.product_name) AS product_name, SUM(i.quantity) AS total_quantity,
        ROUND(SUM(i.quantity*i.unit_price_at_order),2) AS total_sales
 FROM customer_order o JOIN order_item i ON i.order_id=o.order_id
 JOIN product p ON p.product_id=i.product_id WHERE o.status <> 'CANCELLED'
 GROUP BY YEAR(o.order_date), QUARTER(o.order_date), i.product_id
)
SELECT sales.*, DENSE_RANK() OVER (PARTITION BY sales_year,sales_quarter ORDER BY total_quantity DESC) AS product_rank
FROM sales;

-- MySQL 8 has no native CUBE: UNION ALL implements all four grouping sets
-- for station x calendar month. Aggregate allocations before joining capacity.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_report_rail_capacity AS
WITH facts AS (
 SELECT t.destination_station_id AS station_id, s.city AS destination_hub,
        EXTRACT(YEAR_MONTH FROM t.departure_datetime) AS period,
        t.total_capacity, COALESCE(a.space,0) AS allocated_capacity
 FROM train_trip t JOIN station_store s ON s.station_id=t.destination_station_id
 JOIN station_store origin ON origin.station_id=t.origin_station_id
 LEFT JOIN (SELECT trip_id,SUM(allocated_space) AS space FROM rail_allocation GROUP BY trip_id) a ON a.trip_id=t.trip_id
 WHERE t.status <> 'CANCELLED' AND origin.city='Kandy'
), cube_rows AS (
 SELECT station_id,MAX(destination_hub) AS destination_hub,period,SUM(total_capacity) AS total_capacity,
        SUM(allocated_capacity) AS allocated_capacity,'detail' AS row_level FROM facts GROUP BY station_id,period
 UNION ALL
 SELECT station_id,MAX(destination_hub),NULL,SUM(total_capacity),SUM(allocated_capacity),'station_total' FROM facts GROUP BY station_id
 UNION ALL
 SELECT NULL,'ALL STATIONS',period,SUM(total_capacity),SUM(allocated_capacity),'month_total' FROM facts GROUP BY period
 UNION ALL
 SELECT NULL,'ALL STATIONS',NULL,SUM(total_capacity),SUM(allocated_capacity),'grand_total' FROM facts HAVING COUNT(*)>0
)
SELECT station_id,destination_hub,period DIV 100 AS dep_year,MOD(period,100) AS dep_month,
       total_capacity,allocated_capacity,total_capacity-allocated_capacity AS remaining_capacity,
       ROUND(100*allocated_capacity/NULLIF(total_capacity,0),2) AS utilization_percentage,row_level
FROM cube_rows;

-- Months and weeks use the stored Asia/Colombo wall-clock roster times.
-- A crossing duty contributes only its intersection with each month.
CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_report_truck_utilisation AS
WITH RECURSIVE segments AS (
 SELECT roster_id,route_id,truck_id,start_time,end_time,
        CAST(DATE_FORMAT(start_time,'%Y-%m-01') AS DATE) AS month_start
 FROM roster_assignment WHERE status IN ('SCHEDULED','IN_TRANSIT','COMPLETED')
 UNION ALL
 SELECT roster_id,route_id,truck_id,start_time,end_time,DATE_ADD(month_start,INTERVAL 1 MONTH)
 FROM segments WHERE DATE_ADD(month_start,INTERVAL 1 MONTH)<end_time
)
SELECT YEAR(s.month_start) AS usage_year,MONTH(s.month_start) AS usage_month,s.truck_id,
       CASE WHEN GROUPING(s.truck_id) THEN 'ALL TRUCKS' ELSE MAX(t.plate_number) END AS plate_number,
       COUNT(DISTINCT s.roster_id) AS total_delivery_runs,COUNT(DISTINCT s.route_id) AS total_routes,
       ROUND(SUM(TIMESTAMPDIFF(SECOND,GREATEST(s.start_time,s.month_start),
                 LEAST(s.end_time,DATE_ADD(s.month_start,INTERVAL 1 MONTH))))/3600,4) AS total_operating_hours,
       CASE WHEN GROUPING(YEAR(s.month_start)) THEN 'grand_total'
            WHEN GROUPING(MONTH(s.month_start)) THEN 'year_total'
            WHEN GROUPING(s.truck_id) THEN 'month_total' ELSE 'detail' END AS row_level
FROM segments s JOIN truck t ON t.truck_id=s.truck_id
GROUP BY YEAR(s.month_start),MONTH(s.month_start),s.truck_id WITH ROLLUP;

CREATE OR REPLACE SQL SECURITY INVOKER VIEW v_report_station_inventory AS
WITH receipts AS (
 SELECT m.station_id,i.product_id,SUM(a.allocated_quantity) AS received_quantity
 FROM manifest m JOIN rail_allocation a ON a.trip_id=m.trip_id
 JOIN order_item i ON i.order_item_id=a.order_item_id
 WHERE m.status='RECEIVED' AND m.received_at IS NOT NULL
 GROUP BY m.station_id,i.product_id
), adjustments AS (
 SELECT inventory_id,SUM(GREATEST(quantity_delta,0)) AS positive_adjustments,
        SUM(GREATEST(-quantity_delta,0)) AS negative_adjustments,SUM(quantity_delta) AS net_adjustment,
        SUM(CASE WHEN reason='DAMAGED' THEN GREATEST(-quantity_delta,0) ELSE 0 END) AS damaged_quantity
 FROM stock_adjustment GROUP BY inventory_id
)
SELECT v.inventory_id,v.station_id,s.city AS station,v.product_id,p.product_name,l.location_code,
       v.stored_quantity,v.stored_quantity AS adjusted_stock,
       COALESCE(r.received_quantity,0) AS received_quantity,
       COALESCE(a.positive_adjustments,0) AS positive_adjustments,
       COALESCE(a.negative_adjustments,0) AS negative_adjustments,
       COALESCE(a.net_adjustment,0) AS net_adjustment,COALESCE(a.damaged_quantity,0) AS damaged_quantity,
       COALESCE(r.received_quantity,0)+COALESCE(a.net_adjustment,0) AS net_receipts
FROM inventory v JOIN station_store s ON s.station_id=v.station_id
JOIN product p ON p.product_id=v.product_id LEFT JOIN storage_location l ON l.location_id=v.location_id
LEFT JOIN receipts r ON r.station_id=v.station_id AND r.product_id=v.product_id
LEFT JOIN adjustments a ON a.inventory_id=v.inventory_id;
