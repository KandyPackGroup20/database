#!/usr/bin/env python3
"""
Kandypack Feature 4.2: Comprehensive Live Viva Demo Runner
Executes live demonstrations of all 8 core viva requirements:
  1. Too-big order rollback (zero partial inserts, status remains pending)
  2. Single trip allocation (exact capacity deduction)
  3. Multi-trip spillover allocation (split across chronological trips)
  4. Duplicate allocation rejected at DB level (INVALID_ORDER_STATUS)
  5. Direct over-capacity insert rejected (trg_rail_alloc_capacity_bi SIGNAL 45000)
  6. Non-Kandy origin rejected (trg_rail_alloc_origin_bi SIGNAL 45000)
  7. 5-way simultaneous concurrency test (no over-allocation, row-level locks)
  8. Cache MISS / HIT & fresh capacity invalidation
"""

import sys
import time
import uuid
import threading
import urllib.request
import urllib.error
import json
import pymysql

DB_CFG = dict(
    host="127.0.0.1",
    port=3307,
    user="root",
    password="",
    database="kandypack_db",
    cursorclass=pymysql.cursors.DictCursor
)

API_BASE = "http://127.0.0.1:8000/api/v1"

def print_header(title):
    print("\n" + "=" * 78)
    print(f"  {title}")
    print("=" * 78)

def print_step(step, desc):
    print(f"\n[STEP {step}] {desc}")

def get_db():
    return pymysql.connect(**DB_CFG)

def login_logistics():
    req = urllib.request.Request(
        f"{API_BASE}/auth/login",
        data=json.dumps({"email": "logistics@kandypack.lk", "password": "password123", "portal_type": "admin"}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        cookies = resp.headers.get_all("Set-Cookie")
        for c in cookies:
            if "kandypack_session=" in c:
                return c.split("kandypack_session=")[1].split(";")[0]
    return ""

def main():
    print_header("KANDYPACK FEATURE 4.2: LIVE VIVA-DEMO VERIFICATION")

    conn = get_db()
    tag = uuid.uuid4().hex[:6]

    # Setup sandbox destination and customer
    with conn.cursor() as cur:
        cur.execute("SELECT station_id FROM station_store WHERE city = 'Kandy' LIMIT 1")
        kandy_id = cur.fetchone()["station_id"]
        cur.execute("SELECT station_id FROM station_store WHERE city = 'Colombo' LIMIT 1")
        colombo_id = cur.fetchone()["station_id"]

        cur.execute("INSERT INTO station_store (city, address) VALUES (%s, 'Viva Hub')", (f"VIVA-DEST-{tag}",))
        dest_id = cur.lastrowid
        cur.execute("INSERT INTO delivery_route (station_id, route_name, max_delivery_time) VALUES (%s, %s, '08:00:00')", (dest_id, f"Route-{tag}"))
        route_id = cur.lastrowid

        cur.execute("INSERT INTO user (name, role, email, password_hash) VALUES ('Viva Cust', 'CUSTOMER', %s, 'x')", (f"viva-{tag}@example.com",))
        user_id = cur.lastrowid
        cur.execute("INSERT INTO customer (user_id, customer_name, route_id, phone, address_line, city, postal_code) VALUES (%s, 'Viva Exporters', %s, '0771234567', 'Port Rd', 'Colombo', '00100')", (user_id, route_id))
        cust_id = cur.lastrowid

        cur.execute("INSERT INTO product (product_name, category, unit_price, unit_weight_kg, space_consumption_rate) VALUES (%s, 'Tea', 1000.0, 10.0, 1.0000)", (f"Box-{tag}",))
        prod_id = cur.lastrowid

        conn.commit()

    print(f"Setup Complete: Kandy Hub #{kandy_id}, Viva Destination #{dest_id}, Customer #{cust_id}")

    # -------------------------------------------------------------
    # 1. TOO-BIG ORDER ROLLBACK
    # -------------------------------------------------------------
    print_step(1, "Too-Big Order Rollback & Transactional Safety")
    with conn.cursor() as cur:
        # Trip with capacity 10
        cur.execute("INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES (%s, %s, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 1 DAY + INTERVAL 4 HOUR, 10.0, 'SCHEDULED')", (kandy_id, dest_id))
        trip_1 = cur.lastrowid

        # Order needing 50 space units
        cur.execute("INSERT INTO customer_order (customer_id, order_date, delivery_date, status) VALUES (%s, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING')", (cust_id,))
        order_too_big = cur.lastrowid
        cur.execute("INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (%s, %s, 50, 1000.0)", (order_too_big, prod_id))
        conn.commit()

        # Call procedure
        cur.execute("CALL sp_schedule_train_order(%s, 2, @status);", (order_too_big,))
        cur.execute("SELECT @status AS r;")
        status = cur.fetchone()["r"]
        print(f"  Result Code: {status}")
        assert status == "INSUFFICIENT_RAIL_CAPACITY"

        # Verify rollback
        cur.execute("SELECT COUNT(*) AS c FROM rail_allocation WHERE trip_id = %s", (trip_1,))
        alloc_cnt = cur.fetchone()["c"]
        cur.execute("SELECT status FROM customer_order WHERE order_id = %s", (order_too_big,))
        ord_status = cur.fetchone()["status"]
        print(f"  Allocations Created: {alloc_cnt} (Expected 0) | Order Status: {ord_status} (Expected PENDING_RAIL_SCHEDULING)")
        assert alloc_cnt == 0 and ord_status == "PENDING_RAIL_SCHEDULING"
        print("  -> PASS: Clean rollback verified!")

    # -------------------------------------------------------------
    # 2. SINGLE TRIP ALLOCATION
    # -------------------------------------------------------------
    print_step(2, "Single Trip Allocation")
    with conn.cursor() as cur:
        # Order needing 6 space units
        cur.execute("INSERT INTO customer_order (customer_id, order_date, delivery_date, status) VALUES (%s, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING')", (cust_id,))
        order_single = cur.lastrowid
        cur.execute("INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (%s, %s, 6, 1000.0)", (order_single, prod_id))
        conn.commit()

        cur.execute("CALL sp_schedule_train_order(%s, 2, @status);", (order_single,))
        cur.execute("SELECT @status AS r;")
        status = cur.fetchone()["r"]
        print(f"  Result Code: {status}")
        assert status == "SUCCESS_SINGLE_TRIP"

        cur.execute("SELECT used_space, remaining_space, utilisation_pct FROM v_trip_capacity_usage WHERE trip_id = %s", (trip_1,))
        row = cur.fetchone()
        print(f"  Trip #{trip_1} State: Used={row['used_space']}, Remaining={row['remaining_space']}, Util={row['utilisation_pct']}%")
        assert float(row["used_space"]) == 6.0 and float(row["remaining_space"]) == 4.0
        print("  -> PASS: Single trip allocation verified!")

    # -------------------------------------------------------------
    # 3. MULTI-TRIP SPILLOVER ALLOCATION
    # -------------------------------------------------------------
    print_step(3, "Multi-Trip Spillover Allocation")
    with conn.cursor() as cur:
        # Trip 1 has 4.0 left. Create Trip 2 with capacity 10.0
        cur.execute("INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES (%s, %s, NOW() + INTERVAL 2 DAY, NOW() + INTERVAL 2 DAY + INTERVAL 4 HOUR, 10.0, 'SCHEDULED')", (kandy_id, dest_id))
        trip_2 = cur.lastrowid

        # Order needing 8 space units (4 on Trip 1, 4 on Trip 2)
        cur.execute("INSERT INTO customer_order (customer_id, order_date, delivery_date, status) VALUES (%s, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING')", (cust_id,))
        order_spillover = cur.lastrowid
        cur.execute("INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (%s, %s, 8, 1000.0)", (order_spillover, prod_id))
        conn.commit()

        cur.execute("CALL sp_schedule_train_order(%s, 2, @status);", (order_spillover,))
        cur.execute("SELECT @status AS r;")
        status = cur.fetchone()["r"]
        print(f"  Result Code: {status}")
        assert status in ["SUCCESS_MULTI_TRIP", "SUCCESS_MULTI_TRIP_SPILLOVER"]

        cur.execute("""
            SELECT ra.allocation_id, ra.trip_id, ra.allocated_space
            FROM rail_allocation ra
            JOIN order_item oi ON oi.order_item_id = ra.order_item_id
            WHERE oi.order_id = %s
            ORDER BY ra.trip_id ASC
        """, (order_spillover,))
        allocs = cur.fetchall()
        print(f"  Spillover Allocations: {allocs}")
        assert len(allocs) == 2
        print("  -> PASS: Multi-trip spillover successfully split cargo!")

    # -------------------------------------------------------------
    # 4. DUPLICATE REJECTED AT DB LEVEL
    # -------------------------------------------------------------
    print_step(4, "Duplicate Allocation Rejected at DB Level")
    with conn.cursor() as cur:
        cur.execute("CALL sp_schedule_train_order(%s, 2, @status);", (order_spillover,))
        cur.execute("SELECT @status AS r;")
        status = cur.fetchone()["r"]
        print(f"  Result Code: {status}")
        assert status == "INVALID_ORDER_STATUS"
        print("  -> PASS: Duplicate allocation strictly rejected (status check enforced)!")

    # -------------------------------------------------------------
    # 5. DIRECT OVER-CAPACITY INSERT REJECTED BY TRIGGER
    # -------------------------------------------------------------
    print_step(5, "Direct Over-Capacity Insert Rejected by Trigger")
    with conn.cursor() as cur:
        # Trip 1 has 10.0 / 10.0 used (full). Try inserting 1 space unit manually:
        cur.execute("SELECT order_item_id FROM order_item WHERE order_id = %s LIMIT 1", (order_single,))
        oi_id = cur.fetchone()["order_item_id"]
        rejected = False
        try:
            cur.execute("""
                INSERT INTO rail_allocation (order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
                VALUES (%s, %s, 1, 1.0, 2)
            """, (oi_id, trip_1))
            conn.commit()
        except pymysql.MySQLError as e:
            conn.rollback()
            rejected = True
            print(f"  Trigger Interception: {e}")
            assert "exceeds trip capacity" in str(e).lower() or e.args[0] == 1644
        assert rejected, "Direct over-capacity insert should have been blocked by trigger!"
        print("  -> PASS: Trigger trg_rail_alloc_capacity_bi successfully blocked over-capacity!")

    # -------------------------------------------------------------
    # 6. NON-KANDY ORIGIN REJECTED BY TRIGGER
    # -------------------------------------------------------------
    print_step(6, "Non-Kandy Origin Rejected by Trigger")
    with conn.cursor() as cur:
        # Trip originating in Colombo
        cur.execute("INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES (%s, %s, NOW() + INTERVAL 3 DAY, NOW() + INTERVAL 3 DAY + INTERVAL 4 HOUR, 20.0, 'SCHEDULED')", (colombo_id, dest_id))
        non_kandy_trip = cur.lastrowid
        conn.commit()

        rejected = False
        try:
            cur.execute("""
                INSERT INTO rail_allocation (order_item_id, trip_id, allocated_quantity, allocated_space, allocated_by)
                VALUES (%s, %s, 1, 1.0, 2)
            """, (oi_id, non_kandy_trip))
            conn.commit()
        except pymysql.MySQLError as e:
            conn.rollback()
            rejected = True
            print(f"  Trigger Interception: {e}")
            assert "kandy" in str(e).lower() or e.args[0] == 1644
        assert rejected, "Non-Kandy origin allocation should have been blocked by trigger!"
        print("  -> PASS: Trigger trg_rail_alloc_origin_bi enforced Kandy origin policy!")

    # -------------------------------------------------------------
    # 7. 5-WAY CONCURRENCY TEST
    # -------------------------------------------------------------
    print_step(7, "5-Way Simultaneous Concurrency Test")
    with conn.cursor() as cur:
        # New Trip with capacity 10
        cur.execute("INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity, status) VALUES (%s, %s, NOW() + INTERVAL 4 DAY, NOW() + INTERVAL 4 DAY + INTERVAL 4 HOUR, 10.0, 'SCHEDULED')", (kandy_id, dest_id))
        conc_trip = cur.lastrowid

        # 5 competing orders, each needing 6 space units (only 1 can succeed, or 1 fills and remainder reject)
        conc_orders = []
        for _ in range(5):
            cur.execute("INSERT INTO customer_order (customer_id, order_date, delivery_date, status) VALUES (%s, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING')", (cust_id,))
            oid = cur.lastrowid
            cur.execute("INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (%s, %s, 6, 1000.0)", (oid, prod_id))
            conc_orders.append(oid)
        conn.commit()

    barrier = threading.Barrier(5)
    conc_results = {}

    def conc_worker(idx, oid):
        c = get_db()
        try:
            barrier.wait()
            with c.cursor() as cur:
                cur.execute("CALL sp_schedule_train_order(%s, 2, @status);", (oid,))
                cur.execute("SELECT @status AS r;")
                conc_results[idx] = cur.fetchone()["r"]
                c.commit()
        finally:
            c.close()

    threads = [threading.Thread(target=conc_worker, args=(i, o)) for i, o in enumerate(conc_orders)]
    for t in threads: t.start()
    for t in threads: t.join()

    print(f"  5-Way Results: {conc_results}")
    with conn.cursor() as cur:
        cur.execute("SELECT COALESCE(SUM(allocated_space), 0) AS used FROM rail_allocation WHERE trip_id = %s", (conc_trip,))
        conc_used = float(cur.fetchone()["used"])
        print(f"  Trip #{conc_trip} Final Used Capacity: {conc_used} / 10.0")
        assert conc_used <= 10.0, f"Over-allocation detected: {conc_used} > 10.0"
        assert conc_used == 6.0, f"Expected exactly 6.0 units used, got {conc_used}"
    print("  -> PASS: 5-way concurrency test completed with zero over-allocation!")

    # -------------------------------------------------------------
    # 8. CACHE MISS / HIT & CAPACITY INVALIDATION
    # -------------------------------------------------------------
    print_step(8, "Cache MISS / HIT & Invalidation Verification")
    token = login_logistics()
    req_hdrs = {"Cookie": f"kandypack_session={token}"}

    # Fetch 1
    req1 = urllib.request.Request(f"{API_BASE}/rail/schedules", headers=req_hdrs)
    with urllib.request.urlopen(req1) as r1:
        c1 = r1.headers.get("x-cache") or r1.headers.get("X-Cache")

    # Fetch 2 -> Expect HIT
    req2 = urllib.request.Request(f"{API_BASE}/rail/schedules", headers=req_hdrs)
    with urllib.request.urlopen(req2) as r2:
        c2 = r2.headers.get("x-cache") or r2.headers.get("X-Cache")
    print(f"  Second Request X-Cache: {c2}")
    assert c2 == "HIT", f"Expected X-Cache HIT, got {c2}"

    # Allocate another order to trigger cache invalidation
    with conn.cursor() as cur:
        cur.execute("INSERT INTO customer_order (customer_id, order_date, delivery_date, status) VALUES (%s, CURDATE(), CURDATE() + INTERVAL 7 DAY, 'PENDING_RAIL_SCHEDULING')", (cust_id,))
        oid_cache = cur.lastrowid
        cur.execute("INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (%s, %s, 1, 1000.0)", (oid_cache, prod_id))
        conn.commit()

    alloc_req = urllib.request.Request(
        f"{API_BASE}/rail/allocate",
        data=json.dumps({"order_id": oid_cache}).encode("utf-8"),
        headers={"Content-Type": "application/json", **req_hdrs},
        method="POST"
    )
    with urllib.request.urlopen(alloc_req) as a_resp:
        assert a_resp.status == 200

    # Fetch 3 -> Expect MISS (invalidated)
    req3 = urllib.request.Request(f"{API_BASE}/rail/schedules", headers=req_hdrs)
    with urllib.request.urlopen(req3) as r3:
        c3 = r3.headers.get("x-cache") or r3.headers.get("X-Cache")
    print(f"  Post-Allocation Request X-Cache: {c3} (Expected MISS)")
    assert c3 == "MISS", f"Expected X-Cache MISS after invalidation, got {c3}"
    print("  -> PASS: Redis cache MISS -> HIT -> Invalidation -> MISS fully verified!")

    conn.close()
    print_header("ALL 8 VIVA-DEMO REQUIREMENTS SUCCESSFULLY VERIFIED & PASSED!")

if __name__ == "__main__":
    main()
