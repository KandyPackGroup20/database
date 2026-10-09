"""Fresh-schema checks restricted to the existing isolated MySQL test server."""
import unittest
import os

import pymysql
import test_roster_audit_schema as schema


@unittest.skipUnless(os.environ.get("ROSTER_MYSQL_TEST_PORT"), "isolated MySQL opt-in is not set")
class TruckSchemaTests(unittest.TestCase):
    def test_fresh_paths_have_equivalent_cargo_tables_and_required_objects(self):
        definitions = []
        for path in ("master", "standalone"):
            schema.rebuild(path)
            with schema.isolated_connection() as connection:
                with connection.cursor() as cursor:
                    ddl = []
                    for table in ("product", "customer_order", "truck", "delivery", "inventory", "stock_adjustment"):
                        cursor.execute("SHOW CREATE TABLE " + table)
                        ddl.append(cursor.fetchone()["Create Table"])
                    definitions.append(ddl)
                    cursor.execute("SHOW CREATE PROCEDURE sp_schedule_train_order")
                    self.assertIn("co.delivery_route_id", cursor.fetchone()["Create Procedure"])
                    cursor.execute("SHOW CREATE VIEW v_customer_orders")
                    self.assertIn("delivery_route_id", cursor.fetchone()["Create View"])
                    cursor.execute("SHOW TRIGGERS")
                    self.assertIn("trg_assigned_item_update", {r["Trigger"] for r in cursor.fetchall()})
                    with self.assertRaises(pymysql.MySQLError):
                        cursor.execute("INSERT INTO customer_order(customer_id,order_date,delivery_date) VALUES(1,'2026-11-01','2026-11-03')")
                    with self.assertRaises(pymysql.MySQLError):
                        cursor.execute("UPDATE truck SET capacity_unit='TON' WHERE truck_id=1")
                    cursor.execute("SELECT capacity_unit FROM truck")
                    self.assertTrue(all(r["capacity_unit"] is None for r in cursor.fetchall()))
        self.assertEqual(definitions[0], definitions[1])


if __name__ == "__main__":
    unittest.main(verbosity=2)
