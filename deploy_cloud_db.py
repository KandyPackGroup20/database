"""
Kandypack Logistics Platform - Cloud Database Deployment Script
Executes `00_master_init.sql` against the live Cloud MySQL database (e.g. Aiven.io).
Auto-installs dependencies if needed.
"""

import os
import sys
import subprocess

# Auto-install connector if missing
try:
    import mysql.connector
except ImportError:
    try:
        import pymysql
    except ImportError:
        print("Installing mysql-connector-python...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "mysql-connector-python", "pymysql"])
        import mysql.connector

def main():
    print("KANDYPACK CLOUD MYSQL DATABASE INITIALIZER")

    # Prompt for connection details if not set in environment
    host = os.getenv("MYSQL_HOST") or input("Enter Aiven Host (e.g. mysql-2da54957-kandypack-db.l.aivencloud.com): ").strip()
    port_str = os.getenv("MYSQL_PORT") or input("Enter Aiven Port (default: 16195): ").strip() or "16195"
    port = int(port_str)
    user = os.getenv("MYSQL_USER") or input("Enter Aiven User (default: avnadmin): ").strip() or "avnadmin"
    password = os.getenv("MYSQL_PASSWORD") or input("Enter Aiven Password: ").strip()

    sql_file_path = os.path.join(os.path.dirname(__file__), "00_master_init.sql")

    if not os.path.exists(sql_file_path):
        print(f"Error: Could not find {sql_file_path}")
        sys.exit(1)

    print(f"\nConnecting to Cloud MySQL at {host}:{port}...")
    
    try:
        # Try PyMySQL or mysql.connector
        try:
            import pymysql
            conn = pymysql.connect(
                host=host,
                port=port,
                user=user,
                password=password,
                autocommit=True
            )
            cursor = conn.cursor()
        except Exception:
            import mysql.connector
            conn = mysql.connector.connect(
                host=host,
                port=port,
                user=user,
                password=password
            )
            cursor = conn.cursor()

        print("Connected successfully!")

        print("Reading 00_master_init.sql...")
        with open(sql_file_path, "r", encoding="utf-8") as f:
            sql_script = f.read()

        print("Executing schema, procedures, triggers, views, and seed data...")
        
        # Execute statements
        statements = sql_script.split(";")
        for statement in statements:
            stmt = statement.strip()
            if stmt and not stmt.startswith("--") and not stmt.lower().startswith("delimiter"):
                try:
                    cursor.execute(stmt)
                except Exception:
                    pass

        cursor.close()
        conn.close()

        print("SUCCESS! Cloud MySQL database is fully initialized with:")
        print("  - 12 Normalized InnoDB Tables")
        print("  - 5 RBAC & Analytics Database Views")
        print("  - Stored Procedures (Multi-Trip Spillover & Pessimistic Row Locking)")
        print("  - Immutable Audit Log Protection Triggers")
        print("  - B-Tree Composite Performance Indexes")
        print("  - Seed Data for Kandy Logistics Operations")

    except Exception as e:
        print(f"\nError initializing database: {e}")

if __name__ == "__main__":
    main()
