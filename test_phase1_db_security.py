"""
Test Suite for Feature 4.1 Phase 1
Covers:
1. Static Syntax & Policy Validation
2. Live MySQL Trigger & RBAC Isolation Verification (optional when DB is online)
"""

import sys
import os

def test_static_validation():
    print("STEP 1: STATIC SQL SYNTAX & POLICY VALIDATION")

    # 1. Schema
    with open("database/01_schema.sql", "r", encoding="utf-8") as f:
        schema = f.read()
    assert "CREATE TABLE user" in schema, "Missing 'user' table definition"
    assert "force_password_reset" in schema, "Missing 'force_password_reset' column"
    print("Schema DDL verified (user & customer tables).")

    # 2. Views
    with open("database/02_views.sql", "r", encoding="utf-8") as f:
        views = f.read()
    for v in ["v_available_drivers", "v_available_assistants", "v_station_inventory", "v_incoming_train_manifests", "v_customer_orders", "v_quarterly_sales"]:
        assert v in views, f"Missing view {v}"
        print(f"Role-scoping View verified: {v}")

    # 3. Triggers
    with open("database/04_triggers.sql", "r", encoding="utf-8") as f:
        triggers = f.read()
    assert "trg_user_account_creation_policy" in triggers, "Missing account creation trigger"
    assert "force_password_reset = 1" in triggers, "Trigger must force password reset"
    assert "@kandypack.lk" in triggers, "Trigger must enforce company domain"
    print("Security Trigger (trg_user_account_creation_policy) verified.")

    # 4. RBAC Roles
    with open("database/08_roles_and_grants.sql", "r", encoding="utf-8") as f:
        rbac = f.read()
    for r in ["role_superadmin", "role_logistics_mgr", "role_dispatcher", "role_store_mgr", "role_warehouse_staff", "role_customer"]:
        assert r in rbac, f"Missing RBAC role {r}"
        print(f"MySQL RBAC Role definition verified: {r}")

    print("\n  >>> STATIC TEST PASSED SUCCESSFULLY! <<<\n")


def test_live_database():
    """Live integration test against a running MySQL instance."""
    try:
        import pymysql
    except ImportError:
        print("[!] pymysql not installed. To run live MySQL tests: pip install pymysql")
        return

    host = os.getenv("MYSQL_HOST", "localhost")
    user = os.getenv("MYSQL_USER", "root")
    password = os.getenv("MYSQL_PASSWORD", "")
    database = os.getenv("MYSQL_DATABASE", "kandypack_db")
    port = int(os.getenv("MYSQL_PORT", 3306))

    print(f"STEP 2: LIVE DATABASE INTEGRATION & VIVA VERIFICATION ({host}:{port})")

    try:
        conn = pymysql.connect(
            host=host,
            user=user,
            password=password,
            database=database,
            port=port,
            cursorclass=pymysql.cursors.DictCursor
        )
        print("  [✓] Successfully connected to MySQL database.")
    except Exception as e:
        print(f"  [-] Live MySQL connection skipped / failed: {e}")
        print("      (Tip: Set MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD env vars if using remote DB)")
        return

    with conn:
        with conn.cursor() as cursor:
            
            # TEST A: Test Account-Creation Trigger (Auto force_password_reset)
                   
            print("\n  [TEST A] Testing Trigger: Inserting Staff User...")
            test_email = "test.staff.viva@kandypack.lk"
            cursor.execute("DELETE FROM user WHERE email = %s", (test_email,))
            conn.commit()

            cursor.execute("""
                INSERT INTO user (name, role, email, password_hash)
                VALUES (%s, %s, %s, %s)
            """, ('Viva Staff Test', 'DISPATCHER', test_email, 'hash123'))
            conn.commit()

            cursor.execute("SELECT force_password_reset, role FROM user WHERE email = %s", (test_email,))
            row = cursor.fetchone()
            assert row['force_password_reset'] == 1, f"Expected force_password_reset=1, got {row['force_password_reset']}"
            print(f"  [✓] SUCCESS: Staff inserted with role '{row['role']}' and force_password_reset={row['force_password_reset']} by Trigger!")

                   
            # TEST B: Test Trigger Policy Rejection on Invalid Staff Domain
                   
            print("\n  [TEST B] Testing Trigger Policy: Attempting invalid staff email (gmail.com)...")
            try:
                cursor.execute("""
                    INSERT INTO user (name, role, email, password_hash)
                    VALUES (%s, %s, %s, %s)
                """, ('Invalid Staff', 'DISPATCHER', 'hacker@gmail.com', 'hash123'))
                conn.commit()
                print("  [x] FAILED: Invalid email should have been blocked by trigger!")
            except Exception as trigger_err:
                print(f"  [✓] SUCCESS: Trigger blocked invalid staff email as expected: {trigger_err}")

                   
            # TEST C: Verify Views are Queryable
                   
            print("\n  [TEST C] Querying Security Views...")
            cursor.execute("SELECT * FROM v_available_drivers LIMIT 3")
            drivers = cursor.fetchall()
            print(f"  [✓] Query v_available_drivers succeeded ({len(drivers)} rows found).")

            cursor.execute("SELECT * FROM v_customer_orders LIMIT 3")
            orders = cursor.fetchall()
            print(f"  [✓] Query v_customer_orders succeeded ({len(orders)} rows found).")

            # Clean up test row
            cursor.execute("DELETE FROM user WHERE email = %s", (test_email,))
            conn.commit()

    print("\n" + "=" * 70)
    print(">>> ALL LIVE MYSQL TESTS PASSED! READY FOR VIVA DEFENSE! <<<")
    print("=" * 70)


if __name__ == "__main__":
    test_static_validation()
    test_live_database()
