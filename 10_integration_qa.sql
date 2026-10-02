USE kandypack_db;

-- =====================================================
-- KANDYPACK INTEGRATION & QA TESTS
-- =====================================================

-- =====================================================
-- TEST 1: Customer -> Order -> Order Item Integration
-- =====================================================

SELECT
    co.order_id,
    c.customer_name,
    co.order_date,
    co.delivery_date,
    co.status,
    p.product_name,
    oi.quantity
FROM customer_order co
JOIN customer c
    ON co.customer_id = c.customer_id
JOIN order_item oi
    ON co.order_id = oi.order_id
JOIN product p
    ON oi.product_id = p.product_id
ORDER BY co.order_id;


-- =====================================================
-- TEST 2: Customer Order -> Rail Allocation Integration
-- =====================================================

SELECT
    co.order_id,
    c.customer_name,
    p.product_name,
    oi.quantity AS ordered_quantity,
    ra.allocated_quantity,
    ra.allocated_space,
    tt.trip_id,
    ss.city AS destination_station,
    tt.departure_datetime
FROM customer_order co
JOIN customer c
    ON co.customer_id = c.customer_id
JOIN order_item oi
    ON co.order_id = oi.order_id
JOIN product p
    ON oi.product_id = p.product_id
LEFT JOIN rail_allocation ra
    ON oi.order_item_id = ra.order_item_id
LEFT JOIN train_trip tt
    ON ra.trip_id = tt.trip_id
LEFT JOIN station_store ss
    ON tt.destination_station_id = ss.station_id
ORDER BY co.order_id;


-- =====================================================
-- TEST 3: Train -> Manifest -> Inventory Integration
-- =====================================================

SELECT
    m.manifest_id,
    ss.city AS station,
    tt.trip_id,
    tt.departure_datetime,
    m.status AS manifest_status,
    p.product_name,
    inv.stored_quantity
FROM manifest m
JOIN station_store ss
    ON m.station_id = ss.station_id
JOIN train_trip tt
    ON m.trip_id = tt.trip_id
LEFT JOIN inventory inv
    ON m.manifest_id = inv.manifest_id
LEFT JOIN order_item oi
    ON inv.order_item_id = oi.order_item_id
LEFT JOIN product p
    ON oi.product_id = p.product_id
ORDER BY m.manifest_id;


-- =====================================================
-- TEST 4: Roster -> Truck -> Driver -> Assistant
-- =====================================================

SELECT
    ra.roster_id,
    dr.route_name,
    t.plate_number,

    driver_user.name AS driver_name,
    assistant_user.name AS assistant_name,

    ra.start_time,
    ra.end_time,
    ra.status

FROM roster_assignment ra

JOIN delivery_route dr
    ON ra.route_id = dr.route_id

JOIN truck t
    ON ra.truck_id = t.truck_id

JOIN delivery_staff driver_staff
    ON ra.driver_id = driver_staff.delivery_staff_id

JOIN user driver_user
    ON driver_staff.user_id = driver_user.user_id

JOIN delivery_staff assistant_staff
    ON ra.assistant_id = assistant_staff.delivery_staff_id

JOIN user assistant_user
    ON assistant_staff.user_id = assistant_user.user_id

ORDER BY ra.roster_id;


-- =====================================================
-- TEST 5: Full Delivery Integration
-- =====================================================

SELECT
    d.delivery_id,
    co.order_id,
    c.customer_name,
    dr.route_name,
    t.plate_number,
    d.delivery_status,
    d.delivered_at,
    d.proof_reference
FROM delivery d

JOIN customer_order co
    ON d.order_id = co.order_id

JOIN customer c
    ON co.customer_id = c.customer_id

JOIN roster_assignment ra
    ON d.roster_id = ra.roster_id

JOIN delivery_route dr
    ON ra.route_id = dr.route_id

JOIN truck t
    ON ra.truck_id = t.truck_id

ORDER BY d.delivery_id;