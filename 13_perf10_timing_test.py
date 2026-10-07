import mysql.connector
import os
import time
import statistics

DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "AAAaaa#22"),
    "database": os.getenv("MYSQL_DATABASE", "kandypack_db")
}

NUM_RUNS = 20


def create_test_order(conn):
    cursor = conn.cursor()

    # Create a small temporary order
    cursor.execute("""
        INSERT INTO customer_order (
            customer_id,
            order_date,
            delivery_date,
            status
        )
        SELECT
            customer_id,
            CURDATE(),
            DATE_ADD(CURDATE(), INTERVAL 7 DAY),
            'PENDING_RAIL_SCHEDULING'
        FROM customer_order
        WHERE order_id = 1001
    """)

    order_id = cursor.lastrowid

    cursor.execute("""
        INSERT INTO order_item (
            order_id,
            product_id,
            quantity
        )
        SELECT
            %s,
            product_id,
            10
        FROM order_item
        WHERE order_id = 1001
        LIMIT 1
    """, (order_id,))

    conn.commit()

    return order_id


def run_test_order(order_id):
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    start = time.perf_counter()

    result_args = cursor.callproc(
        "sp_allocate_rail_capacity",
        (order_id, "")
    )

    elapsed = time.perf_counter() - start

    result_code = result_args[-1]

    cursor.close()
    conn.close()

    return elapsed, result_code


def delete_test_order(order_id):
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute(
        "DELETE FROM customer_order WHERE order_id = %s",
        (order_id,)
    )

    conn.commit()

    cursor.close()
    conn.close()


times = []

print("=" * 60)
print("PERF-10: 95th Percentile Allocation Response Time")
print("=" * 60)

for i in range(NUM_RUNS):

    conn = mysql.connector.connect(**DB_CONFIG)

    order_id = create_test_order(conn)

    conn.close()

    elapsed, result = run_test_order(order_id)

    times.append(elapsed)

    print(
        f"Run {i + 1:02d}: "
        f"{elapsed:.4f} sec | "
        f"{result}"
    )

    delete_test_order(order_id)


sorted_times = sorted(times)

# nearest-rank 95th percentile
index_95 = int(0.95 * len(sorted_times)) - 1
p95 = sorted_times[index_95]

print("=" * 60)
print(f"Average time      : {statistics.mean(times):.4f} sec")
print(f"Maximum time      : {max(times):.4f} sec")
print(f"95th percentile   : {p95:.4f} sec")

if p95 <= 10:
    print("PERF-10 PASS")
else:
    print("PERF-10 FAIL")

print("=" * 60)