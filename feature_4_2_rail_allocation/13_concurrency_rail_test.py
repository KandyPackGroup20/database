import os, threading, uuid
import mysql.connector

CFG = dict(host="127.0.0.1", port=int(os.getenv("MYSQL_PORT", "3307")),
           user="root", password="", database="kandypack_db")
N = int(os.getenv("CONC_N", "5"))          # simultaneous allocation attempts
LM_ID = 2      # logistics@kandypack.lk

def setup():
    c = mysql.connector.connect(**CFG); cur = c.cursor()
    tag = uuid.uuid4().hex[:6]
    cur.execute("SELECT station_id FROM station_store WHERE city = 'Kandy' LIMIT 1")
    row = cur.fetchone()
    if not row:
        raise RuntimeError("Kandy station not found")
    origin = row[0]
    cur.execute("INSERT INTO station_store (city, address) VALUES (%s, 'conc dest')", ("CONC-D-" + tag,))
    dest = cur.lastrowid
    cur.execute("INSERT INTO delivery_route (station_id, route_name, max_delivery_time) VALUES (%s, %s, '08:00:00')", (dest, "CONC route " + tag))
    route = cur.lastrowid
    cur.execute("INSERT INTO user (name, role, email, password_hash) VALUES ('Conc Customer', 'CUSTOMER', %s, 'x')", ("conc-" + tag + "@example.com",))
    uid = cur.lastrowid
    cur.execute("INSERT INTO customer (user_id, customer_name, route_id, phone, address_line, city, postal_code) VALUES (%s, 'Conc Customer', %s, '0771234567', 'Test Rd', 'Kandy', '20000')", (uid, route))
    cust = cur.lastrowid
    cur.execute("INSERT INTO product (product_name, unit_price, space_consumption_rate) VALUES (%s, 100.00, 1.0000)", ("Conc Box " + tag,))
    prod = cur.lastrowid
    cur.execute("INSERT INTO train_trip (origin_station_id, destination_station_id, departure_datetime, arrival_datetime, total_capacity) VALUES (%s, %s, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 1 DAY + INTERVAL 4 HOUR, 10)", (origin, dest))
    trip = cur.lastrowid
    orders = []
    for _ in range(N):
        cur.execute("INSERT INTO customer_order (customer_id, order_date, delivery_date) VALUES (%s, CURDATE(), CURDATE() + INTERVAL 7 DAY)", (cust,))
        oid = cur.lastrowid
        cur.execute("INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_order) VALUES (%s, %s, 6, 100.00)", (oid, prod))
        orders.append(oid)
    c.commit(); cur.close(); c.close()
    return trip, orders

results = {}
barrier = threading.Barrier(N)

def worker(i, oid):
    try:
        c = mysql.connector.connect(**CFG); cur = c.cursor()
        barrier.wait()   # everyone fires at the same moment
        cur.execute("CALL sp_schedule_train_order(%s, %s, @r)", (oid, LM_ID))
        cur.execute("SELECT @r")
        results[i] = cur.fetchone()[0]
        c.commit(); cur.close(); c.close()
    except Exception as e:
        results[i] = "EXCEPTION: " + str(e)

trip, orders = setup()
print("Trip", trip, "capacity 10. Orders:", orders, "(6 units each)")
threads = [threading.Thread(target=worker, args=(i, o)) for i, o in enumerate(orders)]
[t.start() for t in threads]; [t.join() for t in threads]
for i in sorted(results): print("Session", i + 1, "->", results[i])

c = mysql.connector.connect(**CFG); cur = c.cursor()
cur.execute("SELECT COALESCE(SUM(allocated_space), 0), COUNT(*) FROM rail_allocation WHERE trip_id = %s", (trip,))
used, rows = cur.fetchone()
ok = list(results.values()).count("SUCCESS_SINGLE_TRIP")
print("Successful allocations:", ok, "(expected 1)")
print("Trip used space:", used, "of 10 | allocation rows:", rows, "(expected 6.00 and 1)")
passed = ok == 1 and float(used) <= 10 and rows == 1
print("RESULT:", "PASS - no over-allocation" if passed else "FAIL - check output above")
