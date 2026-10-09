-- small self contained demo data for the viva (uses "F42" names)
USE kandypack_db;

-- 1. Resolve existing Kandy origin station
SELECT station_id INTO @kandy FROM station_store WHERE city = 'Kandy' LIMIT 1;

-- 2. Create dedicated destination station and route
INSERT INTO station_store (city, address) VALUES ('F42-Dest', 'Colombo Fort Commercial Hub');
SET @dest := LAST_INSERT_ID();

INSERT INTO delivery_route (station_id, route_name, max_delivery_time) VALUES (@dest, 'F42 Fort Delivery Route', '08:00:00');
SET @route := LAST_INSERT_ID();

-- 3. Dedicated customer
INSERT INTO user (name, role, email, password_hash) VALUES ('F42 Customer', 'CUSTOMER', CONCAT('f42-', UUID(), '@example.com'), 'x');
SET @user := LAST_INSERT_ID();
INSERT INTO customer (user_id, customer_name, route_id, phone, address_line, city, postal_code)
VALUES (@user, 'F42 Customer', @route, '0771234567', 'York Street', 'Colombo', '00100');
SET @cust := LAST_INSERT_ID();

-- 4. Dedicated product
INSERT INTO product (product_name, unit_price, space_consumption_rate) VALUES ('F42 Tea Box', 500.00, 1.0000);
SET @prod := LAST_INSERT_ID();

-- 5. LM-03 proof trip: non-Kandy origin (station 1 Colombo -> @dest)
INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity) VALUES
 (1, @dest, NOW() + INTERVAL 12 HOUR, NOW() + INTERVAL 16 HOUR, 10);
SET @non_kandy_trip := LAST_INSERT_ID();

-- 6. Three valid trips departing FROM Kandy to @dest (10 space units each)
INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity) VALUES
 (@kandy, @dest, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 1 DAY + INTERVAL 4 HOUR, 10),
 (@kandy, @dest, NOW() + INTERVAL 2 DAY, NOW() + INTERVAL 2 DAY + INTERVAL 4 HOUR, 10),
 (@kandy, @dest, NOW() + INTERVAL 3 DAY, NOW() + INTERVAL 3 DAY + INTERVAL 4 HOUR, 10);

-- order A: 8 units (fits one trip) | order B: 15 units (spills over) | order C: 100 units (too big)
INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (@cust, CURDATE(), CURDATE() + INTERVAL 7 DAY);
SET @oa := LAST_INSERT_ID();
INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (@oa, @prod, 8, 500.00);

INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (@cust, CURDATE(), CURDATE() + INTERVAL 7 DAY);
SET @ob := LAST_INSERT_ID();
INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (@ob, @prod, 15, 500.00);

INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (@cust, CURDATE(), CURDATE() + INTERVAL 7 DAY);
SET @oc := LAST_INSERT_ID();
INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (@oc, @prod, 100, 500.00);

SELECT @oa AS order_a_single, @ob AS order_b_spillover, @oc AS order_c_too_big, @non_kandy_trip AS trip_non_kandy;