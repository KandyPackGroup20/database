-- small self contained demo data for the viva (uses "F42" names)
USE kandypack_db;

INSERT INTO station_store (city, address) VALUES ('F42-Origin', 'Colombo Fort'), ('F42-Kandy', 'Kandy Hub');
SET @origin := LAST_INSERT_ID();  SET @kandy := @origin + 1;

INSERT INTO delivery_route (station_id, route_name, max_delivery_time) VALUES (@kandy, 'F42 Kandy North', '08:00:00');
SET @route := LAST_INSERT_ID();

INSERT INTO user (name, role, email, password_hash) VALUES ('F42 Customer', 'CUSTOMER', CONCAT('f42-', UUID(), '@example.com'), 'x');
SET @user := LAST_INSERT_ID();
INSERT INTO customer (user_id, customer_name, route_id, phone, address_line, city, postal_code)
VALUES (@user, 'F42 Customer', @route, '0771234567', 'Peradeniya Rd', 'Kandy', '20000');
SET @cust := LAST_INSERT_ID();

INSERT INTO product (product_name, unit_price, space_consumption_rate) VALUES ('F42 Tea Box', 500.00, 1.0000);
SET @prod := LAST_INSERT_ID();

-- three trips of 10 space units each
INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity) VALUES
 (@origin, @kandy, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 1 DAY + INTERVAL 4 HOUR, 10),
 (@origin, @kandy, NOW() + INTERVAL 2 DAY, NOW() + INTERVAL 2 DAY + INTERVAL 4 HOUR, 10),
 (@origin, @kandy, NOW() + INTERVAL 3 DAY, NOW() + INTERVAL 3 DAY + INTERVAL 4 HOUR, 10);

-- order A: 8 units (fits one trip) | order B: 15 units (spills over) | order C: 100 units (too big)
INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (@cust, CURDATE(), CURDATE() + INTERVAL 7 DAY);
SET @oa := LAST_INSERT_ID();
INSERT INTO order_item (order_id, product_id, quantity) VALUES (@oa, @prod, 8);

INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (@cust, CURDATE(), CURDATE() + INTERVAL 7 DAY);
SET @ob := LAST_INSERT_ID();
INSERT INTO order_item (order_id, product_id, quantity) VALUES (@ob, @prod, 15);

INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (@cust, CURDATE(), CURDATE() + INTERVAL 7 DAY);
SET @oc := LAST_INSERT_ID();
INSERT INTO order_item (order_id, product_id, quantity) VALUES (@oc, @prod, 100);

SELECT @oa AS order_a_single, @ob AS order_b_spillover, @oc AS order_c_too_big;