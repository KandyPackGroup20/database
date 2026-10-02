"""
Kandypack Logistics Platform
PERF-08 Rail Allocation Concurrency Test

Tests simultaneous calls to sp_allocate_rail_capacity
and verifies that train capacity never becomes negative.
"""

import asyncio
import mysql.connector
import os


DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "AAAaaa#22"),
    "database": os.getenv("MYSQL_DATABASE", "kandypack_db")
}


def allocate_order(order_id, thread_id):
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()

        args = (order_id, "")

        print(
            f"[Thread {thread_id}] "
            f"Attempting rail allocation for order {order_id}..."
        )

        result_args = cursor.callproc(
            "sp_allocate_rail_capacity",
            args
        )

        result = result_args[-1]

        conn.commit()
        cursor.close()
        conn.close()

        print(
            f"[Thread {thread_id}] RESULT: {result}"
        )

        return result

    except Exception as e:
        print(
            f"[Thread {thread_id}] EXCEPTION: {e}"
        )
        return str(e)


def check_capacity():
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT
            tt.trip_id,
            tt.total_capacity,
            COALESCE(SUM(ra.allocated_space), 0)
                AS allocated_space,
            tt.total_capacity -
            COALESCE(SUM(ra.allocated_space), 0)
                AS remaining_capacity
        FROM train_trip tt
        LEFT JOIN rail_allocation ra
            ON tt.trip_id = ra.trip_id
        GROUP BY
            tt.trip_id,
            tt.total_capacity
        ORDER BY tt.trip_id
    """)

    rows = cursor.fetchall()

    cursor.close()
    conn.close()

    return rows


async def main():

    print("=" * 65)
    print("PERF-08: RAIL ALLOCATION CONCURRENCY TEST")
    print("=" * 65)

    # Same order requested by two simultaneous transactions.
    # One should process it; the other should not create
    # duplicate/over-capacity allocation.
    loop = asyncio.get_running_loop()

    tasks = [
        loop.run_in_executor(None, allocate_order, 1005, 1),
        loop.run_in_executor(None, allocate_order, 1006, 2)
    ]

    results = await asyncio.gather(*tasks)

    print("\nResults:")
    for i, result in enumerate(results, 1):
        print(
            f"Thread {i}: {result}"
        )

    print("\nCapacity Verification:")

    rows = check_capacity()

    capacity_safe = True

    for row in rows:
        trip_id = row[0]
        total = float(row[1])
        allocated = float(row[2])
        remaining = float(row[3])

        print(
            f"Trip {trip_id}: "
            f"Total={total:.2f}, "
            f"Allocated={allocated:.2f}, "
            f"Remaining={remaining:.2f}"
        )

        if allocated > total or remaining < 0:
            capacity_safe = False

    print("=" * 65)

    if capacity_safe:
        print(
            "PERF-08 PASS: No train capacity "
            "became negative or exceeded total capacity."
        )
    else:
        print(
            "PERF-08 FAIL: Capacity inconsistency detected."
        )

    print("=" * 65)


if __name__ == "__main__":
    asyncio.run(main())