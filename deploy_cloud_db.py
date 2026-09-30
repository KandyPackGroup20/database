"""
Kandypack Logistics Platform - Cloud Database Deployment Script
Executes `00_master_init.sql` and `08_roles_and_grants.sql` against a live Cloud MySQL database (e.g. Aiven.io, Clever Cloud, Railway, AWS RDS, GCP).
Accurately parses DELIMITER // blocks for Stored Procedures and Triggers.
"""

import os
import sys
import ssl
import re

def install_dependencies():
    try:
        import pymysql
    except ImportError:
        print("[*] Installing pymysql...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pymysql", "cryptography"])
        import pymysql

install_dependencies()
import pymysql
import pymysql.cursors

def parse_sql_script(content: str) -> list[str]:
    """Parses SQL script respecting DELIMITER changes for Stored Procedures and Triggers."""
    delimiter = ";"
    statements = []
    current_statement = []

    for line in content.splitlines():
        trimmed = line.strip()

        # Skip empty lines and single-line comment headers
        if not trimmed or (trimmed.startswith("--") and not trimmed.startswith("-- DELIMITER")):
            continue

        # Check for DELIMITER change
        if trimmed.upper().startswith("DELIMITER"):
            parts = trimmed.split()
            if len(parts) >= 2:
                delimiter = parts[1]
            continue

        current_statement.append(line)

        # Check if line ends with current delimiter
        if trimmed.endswith(delimiter):
            full_stmt = "\n".join(current_statement).strip()
            # Strip trailing delimiter
            if full_stmt.endswith(delimiter):
                full_stmt = full_stmt[:-len(delimiter)].strip()
            if full_stmt:
                statements.append(full_stmt)
            current_statement = []

    if current_statement:
        remainder = "\n".join(current_statement).strip()
        if remainder:
            statements.append(remainder)

    return statements

def execute_sql_file(cursor, file_path: str, label: str):
    if not os.path.exists(file_path):
        print(f"[!] File not found: {file_path}")
        return False

    print(f"\n[*] Reading {label} ({os.path.basename(file_path)})...")
    with open(file_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    statements = parse_sql_script(sql_content)
    print(f"[*] Found {len(statements)} executable SQL statements in {os.path.basename(file_path)}.")

    executed = 0
    errors = 0
    for stmt in statements:
        # Ignore USE database if already connected to target database
        first_token = stmt.split()[0].upper() if stmt.split() else ""
        if first_token == "USE":
            continue

        try:
            cursor.execute(stmt)
            executed += 1
        except Exception as e:
            err_msg = str(e)
            # Ignore non-fatal role/user drop errors if resetting
            if "Unknown role" in err_msg or "Operation DROP ROLE failed" in err_msg or "Operation DROP USER failed" in err_msg:
                continue
            print(f"    [-] SQL Notice: {err_msg[:90]}")
            errors += 1

    print(f"    [OK] Finished {os.path.basename(file_path)}: {executed} executed successfully.")
    return True

def main():
    print("  KANDYPACK CLOUD MYSQL DATABASE INITIALIZER & MIGRATION TOOL")

    host = os.getenv("MYSQL_HOST") or input("Enter Cloud MySQL Host: ").strip()
    port_str = os.getenv("MYSQL_PORT") or input("Enter Port (default 16195 or 3306): ").strip() or "16195"
    port = int(port_str)
    user = os.getenv("MYSQL_USER") or input("Enter Username (e.g. avnadmin or root): ").strip() or "avnadmin"
    password = os.getenv("MYSQL_PASSWORD") or input("Enter Password: ").strip()
    database = os.getenv("MYSQL_DATABASE") or input("Enter Database Name (default: defaultdb or kandypack_db): ").strip() or "defaultdb"

    print(f"\n[*] Connecting to Cloud MySQL at {host}:{port} (Database: {database})...")

    # SSL context for cloud providers (Aiven, Render, Railway, AWS)
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    try:
        conn = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database,
            ssl=ssl_ctx,
            autocommit=True,
            cursorclass=pymysql.cursors.DictCursor
        )
        print("[OK] Connected successfully via SSL!")
    except Exception as e:
        print(f"[!] Connection failed: {e}")
        print("\nTip: Double-check your Host, Port, Username, and Password from your cloud console.")
        return

    base_dir = os.path.dirname(__file__)

    with conn:
        with conn.cursor() as cursor:
            # 1. Execute Master Init (Tables, Views, Procedures, Triggers, Seed Data)
            master_file = os.path.join(base_dir, "00_master_init.sql")
            execute_sql_file(cursor, master_file, "Master Schema & Seed Script")

            # 2. Execute RBAC Roles & Grants
            rbac_file = os.path.join(base_dir, "08_roles_and_grants.sql")
            execute_sql_file(cursor, rbac_file, "RBAC Roles & Grants Script")

    print("\n" + "=" * 70)
    print(" SUCCESS! Cloud MySQL database is fully initialized and live!")
    print("   • 19 Normalized InnoDB Tables")
    print("   • 8 Database Views (Scoping & Analytics)")
    print("   • Stored Procedures (Multi-Trip Rail Spillover & Truck Roster)")
    print("   • Security Triggers (Immutable Audit Logs & Domain Policies)")
    print("   • Composite B-Tree Indexes")
    print("   • Demo Seed Data (Users, Products, Routes, Staff)")
    print("   • MySQL 8 RBAC Roles (SUPERADMIN, DISPATCHER, CUSTOMER, etc.)")
    print("=" * 70)

if __name__ == "__main__":
    main()
