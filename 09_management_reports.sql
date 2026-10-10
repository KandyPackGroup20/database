-- Read-only report examples. Select the intended schema explicitly.
-- Prerequisites: 10_roster_reporting.sql and 17_phase5_reporting.sql.
-- The HTTP reports preserve /api/v1/reports/* and SUPERADMIN authorization.

-- 1. Quarterly booked sales, route/product ROLLUP, historical prices.
SELECT * FROM v_report_quarterly_sales ORDER BY sales_year,sales_quarter,route_id,product_id;

-- 2. Dense ranks partitioned by BOTH year and quarter (ties retained).
SELECT * FROM v_report_top_products WHERE product_rank=1 ORDER BY sales_year,sales_quarter,product_id;

-- 3. Station x month CUBE equivalent (MySQL 8 UNION ALL grouping sets).
SELECT * FROM v_report_rail_capacity ORDER BY dep_year,dep_month,station_id,row_level;

-- 4. Dated Colombo week, clipped to each boundary, using the existing roster policy.
-- Supply a Monday. The API validates it and also includes active zero-hour staff.
SET @report_week_start = DATE_SUB(CURRENT_DATE, INTERVAL WEEKDAY(CURRENT_DATE) DAY);
SET @report_week_end = DATE_ADD(@report_week_start, INTERVAL 7 DAY);
PREPARE workforce_report FROM '
SELECT staff_id,duty_type,SUM(TIMESTAMPDIFF(SECOND,GREATEST(start_time,?),LEAST(end_time,?)))/3600 AS scheduled_hours,
       CASE WHEN duty_type=''DRIVER'' THEN 40 ELSE 60 END AS weekly_cap
FROM v_roster_duty_intervals
WHERE start_time < ? AND end_time > ? AND is_counted=1
GROUP BY staff_id,duty_type ORDER BY staff_id,duty_type';
EXECUTE workforce_report USING @report_week_start,@report_week_end,@report_week_end,@report_week_start;
DEALLOCATE PREPARE workforce_report;

-- 5. Monthly truck hours ROLLUP; crossing duties are clipped to each month.
SELECT * FROM v_report_truck_utilisation ORDER BY usage_year,usage_month,truck_id;

-- 6. Station-product stock, receipts and adjustments. Stock already includes adjustments.
SELECT * FROM v_report_station_inventory ORDER BY station_id,product_id;

-- Legacy additional reports (city/route sales, customer delivery history) remain
-- available through the existing city-route-sales and customer orders APIs.
