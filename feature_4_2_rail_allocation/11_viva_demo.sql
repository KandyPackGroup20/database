-- ==============================================================================
-- KANDYPACK FEATURE 4.2: RAIL CAPACITY ALLOCATION & SCHEDULING VIVA DEMO SCRIPT
-- ==============================================================================
-- Run sequentially in MySQL workbench or mysql CLI to demonstrate all requirements.
-- ==============================================================================

USE kandypack_db;

-- ------------------------------------------------------------------------------
-- SETUP VIVA CLEAN SANDBOX
-- ------------------------------------------------------------------------------
SELECT station_id INTO @kandy_id FROM station_store WHERE city = 'Kandy' LIMIT 1;
SELECT station_id INTO @colombo_id FROM station_store WHERE city = 'Colombo' LIMIT 1;

-- Dedicated Destination & Route for Viva
INSERT INTO station_store (city, address) VALUES ('VIVA-Dest', 'Viva Station Hub Colombo');
SET @viva_dest := LAST_INSERT_ID();

INSERT INTO delivery_route (station_id, route_name, max_delivery_time)
VALUES (@viva_dest, 'Viva Test Route', '08:00:00');
SET @viva_route := LAST_INSERT_ID();

-- Customer & User
INSERT INTO user (name, role, email, password_hash)
VALUES ('Viva Customer', 'CUSTOMER', CONCAT('viva-', SUBSTRING(UUID(), 1, 8), '@example.com'), '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeg6Lruj3vjPGga31lW');
SET @viva_user := LAST_INSERT_ID();

INSERT INTO customer (user_id, customer_name, route_id, phone, address_line, city, postal_code)
VALUES (@viva_user, 'Viva Ceylon Exporters', @viva_route, '0771234567', 'Viva Port Yard', 'Colombo', '00100');
SET @viva_cust := LAST_INSERT_ID();

-- Product with 1.0 Space Rate
INSERT INTO product (product_name, category, unit_price, unit_weight_kg, space_consumption_rate, is_active)
VALUES ('Viva Standard Crate', 'Spices', 2500.00, 20.0, 1.0000, 1);
SET @viva_prod := LAST_INSERT_ID();

-- ------------------------------------------------------------------------------
-- DEMO 1: TOO-BIG ORDER ROLLBACK (Transactional integrity)
-- ------------------------------------------------------------------------------
-- Create Trip 1 with capacity 10
INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status)
VALUES (@kandy_id, @viva_dest, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 1 DAY + INTERVAL 4 HOUR, 10.0, 'SCHEDULED');
SET @trip_1 := LAST_INSERT_ID();

-- Create Order 1 needing 50 space units (far exceeds 10)
INSERT INTO customer_order (customer_id, order_date, delivery_date, status)
VALUES (@viva_cust, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING');
SET @order_too_big := LAST_INSERT_ID();

INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order)
VALUES (@order_too_big, @viva_prod, 50, 2500.00);

-- CALL sp_schedule_train_order -> Expect INSUFFICIENT_RAIL_CAPACITY & zero allocations
CALL sp_schedule_train_order(@order_too_big, 2, @status_too_big);
SELECT @status_too_big AS demo1_result_expected_INSUFFICIENT_RAIL_CAPACITY;

-- Verify 0 allocations created and order status remains PENDING_RAIL_SCHEDULING
SELECT COUNT(*) AS demo1_allocations_count_expected_0 FROM rail_allocation WHERE trip_id = @trip_1;
SELECT status AS demo1_order_status_expected_PENDING FROM customer_order WHERE order_id = @order_too_big;


-- ------------------------------------------------------------------------------
-- DEMO 2: SINGLE TRIP ALLOCATION
-- ------------------------------------------------------------------------------
-- Create Order 2 needing 6 units space (fits into Trip 1 having capacity 10)
INSERT INTO customer_order (customer_id, order_date, delivery_date, status)
VALUES (@viva_cust, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING');
SET @order_single := LAST_INSERT_ID();

INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order)
VALUES (@order_single, @viva_prod, 6, 2500.00);

CALL sp_schedule_train_order(@order_single, 2, @status_single);
SELECT @status_single AS demo2_result_expected_SUCCESS_SINGLE_TRIP;

-- Verify trip remaining capacity is now 4.0 (10 - 6)
SELECT trip_id, used_space, remaining_space, utilisation_pct
FROM v_trip_capacity_usage WHERE trip_id = @trip_1;


-- ------------------------------------------------------------------------------
-- DEMO 3: MULTI-TRIP SPILLOVER ALLOCATION
-- ------------------------------------------------------------------------------
-- Trip 1 only has 4.0 remaining. Create Trip 2 with capacity 10.0
INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status)
VALUES (@kandy_id, @viva_dest, NOW() + INTERVAL 2 DAY, NOW() + INTERVAL 2 DAY + INTERVAL 4 HOUR, 10.0, 'SCHEDULED');
SET @trip_2 := LAST_INSERT_ID();

-- Create Order 3 needing 8 units space (4 will go to Trip 1, 4 will spill into Trip 2)
INSERT INTO customer_order (customer_id, order_date, delivery_date, status)
VALUES (@viva_cust, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING');
SET @order_spillover := LAST_INSERT_ID();

INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order)
VALUES (@order_spillover, @viva_prod, 8, 2500.00);

CALL sp_schedule_train_order(@order_spillover, 2, @status_spillover);
SELECT @status_spillover AS demo3_result_expected_SUCCESS_MULTI_TRIP_SPILLOVER;

-- Verify Order 3 breakdown across the two trips
SELECT ra.allocation_id, ra.trip_id, tt.departure_datetime, ra.allocated_quantity, ra.allocated_space
FROM rail_allocation ra
JOIN train_trip tt ON ra.trip_id = tt.trip_id
JOIN order_item oi ON oi.order_item_id = ra.order_item_id
WHERE oi.order_id = @order_spillover;


-- ------------------------------------------------------------------------------
-- DEMO 4: DUPLICATE ALLOCATION REJECTED AT DB LEVEL
-- ------------------------------------------------------------------------------
-- Calling schedule on an already allocated order (status SCHEDULED_FOR_RAIL)
CALL sp_schedule_train_order(@order_spillover, 2, @status_duplicate);
SELECT @status_duplicate AS demo4_result_expected_INVALID_ORDER_STATUS;


-- ------------------------------------------------------------------------------
-- DEMO 5: DIRECT OVER-CAPACITY INSERT REJECTED BY TRIGGER
-- ------------------------------------------------------------------------------
-- Trip 1 is at 10.0 / 10.0 capacity (used: 6 + 4 = 10.0). Attempting manual insert:
-- Trigger `trg_rail_alloc_capacity_bi` will signal 45000 and reject!
-- Expected output: Error 1644 (45000): Rail allocation exceeds trip capacity
/*
SELECT order_item_id INTO @oi_sample FROM order_item WHERE order_id = @order_single LIMIT 1;
INSERT INTO rail_allocation (order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
VALUES (@oi_sample, @trip_1, 5, 5.0, 2);
*/


-- ------------------------------------------------------------------------------
-- DEMO 6: NON-KANDY ORIGIN REJECTED BY TRIGGER
-- ------------------------------------------------------------------------------
-- Trip originating in Colombo instead of Kandy
INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status)
VALUES (@colombo_id, @viva_dest, NOW() + INTERVAL 3 DAY, NOW() + INTERVAL 3 DAY + INTERVAL 4 HOUR, 20.0, 'SCHEDULED');
SET @trip_non_kandy := LAST_INSERT_ID();

-- Trigger `trg_rail_alloc_origin_bi` enforces all allocations must originate from Kandy station
/*
INSERT INTO rail_allocation (order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
VALUES (@oi_sample, @trip_non_kandy, 1, 1.0, 2);
-- Expected output: Error 1644 (45000): Rail allocation policy strictly mandates origin station must be Kandy
*/


-- ------------------------------------------------------------------------------
-- REVERSE ALLOCATION DEMO (LM-18)
-- ------------------------------------------------------------------------------
CALL sp_reverse_rail_allocation(@order_spillover, 2, @status_reversed);
SELECT @status_reversed AS demo_reversal_expected_SUCCESS_REVERSED;

-- Verify capacity was freed back up on Trip 1 and Trip 2
SELECT trip_id, used_space, remaining_space FROM v_trip_capacity_usage WHERE trip_id IN (@trip_1, @trip_2);
