"""Opt-in destructive checks, restricted to a separately initialized MySQL instance.

Run with backend/.venv Python. Set ROSTER_MYSQL_TEST_PORT to the isolated port.
The server must have server_id=43317 and a datadir containing roster-audit-mysql.
Never uses application .env credentials or the normal MySQL port.
"""

import os
from pathlib import Path
import shutil
import subprocess
import unittest

import pymysql


ROOT = Path(__file__).resolve().parent
PATHS = {
    "standalone": ["01_schema.sql", "02_views.sql", "03_procedures.sql", "04_triggers.sql",
                   "05_indexes.sql", "06_seed_data.sql", "09_roster_assignment.sql", "10_roster_reporting.sql"],
    "master": ["00_master_init.sql"],
}


def isolated_connection(*, database=True):
    port = int(os.environ["ROSTER_MYSQL_TEST_PORT"])
    if port == 3306 or port < 1024:
        raise RuntimeError("Refusing normal/default MySQL port")
    connection = pymysql.connect(host="127.0.0.1", port=port, user="root",
                                 database="kandypack_db" if database else None,
                                 cursorclass=pymysql.cursors.DictCursor, autocommit=False)
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT @@server_id AS server_id, @@datadir AS datadir")
            identity = cursor.fetchone()
        if identity["server_id"] != 43317 or "roster-audit-mysql" not in identity["datadir"]:
            raise RuntimeError("Refusing a server without the isolated audit-test identity")
        connection.rollback()
        return connection
    except Exception:
        connection.close()
        raise


def rebuild(path):
    with isolated_connection(database=False) as connection:
        with connection.cursor() as cursor:
            cursor.execute("DROP DATABASE IF EXISTS kandypack_db")
    client = shutil.which("mysql")
    if not client:
        raise RuntimeError("mysql CLI is required to interpret DELIMITER correctly")
    supplements = sorted((ROOT / "feature_4_2_rail_allocation").glob("0[1-9]_*.sql"))
    script = "\n".join((ROOT / name).read_text(encoding="utf-8") for name in PATHS[path]) + "\n" + "\n".join(p.read_text(encoding="utf-8") for p in supplements)
    subprocess.run([client, "--no-defaults", "--protocol=TCP", "--host=127.0.0.1",
                    "--port=" + os.environ["ROSTER_MYSQL_TEST_PORT"], "--user=root", "--batch"],
                   input=script, text=True, encoding="utf-8", capture_output=True, check=True,
                   cwd=ROOT)


@unittest.skipUnless(os.environ.get("ROSTER_MYSQL_TEST_PORT"), "isolated MySQL opt-in is not set")
class RosterAuditSchemaTests(unittest.TestCase):
    def test_both_setup_paths_and_live_constraints(self):
        definitions = []
        for path in PATHS:
            with self.subTest(path=path):
                rebuild(path)
                with isolated_connection() as connection:
                    with connection.cursor() as cursor:
                        cursor.execute("SHOW CREATE TABLE audit_log")
                        audit_ddl = cursor.fetchone()["Create Table"]
                        cursor.execute("SHOW CREATE TABLE roster_assignment")
                        definitions.append((audit_ddl, cursor.fetchone()["Create Table"]))
                        self.check_schema(cursor)
                        self.check_rows(cursor)
                    connection.rollback()
                    self.check_procedure(connection)
        self.assertEqual(definitions[0], definitions[1])

    def check_schema(self, cursor):
        cursor.execute("SHOW TABLES LIKE 'roster_assignment_audit_detail'")
        self.assertIsNone(cursor.fetchone())
        cursor.execute("SHOW COLUMNS FROM audit_log")
        columns = {row["Field"]: row for row in cursor.fetchall()}
        self.assertEqual(columns["entity_id"]["Null"], "NO")
        self.assertEqual(columns["user_id"]["Null"], "NO")
        self.assertEqual(set(columns), {"audit_id", "user_id", "action", "entity_id",
                                        "outcome", "occurred_at", "entity_name", "roster_id"})
        self.assertEqual(columns["roster_id"]["Null"], "YES")
        cursor.execute("SHOW FULL COLUMNS FROM roster_assignment")
        assignments = {row["Field"]: row for row in cursor.fetchall()}
        self.assertEqual(len(assignments), 11)
        self.assertEqual(assignments["request_key"]["Null"], "NO")
        self.assertEqual(assignments["request_key"]["Collation"], "utf8mb4_0900_bin")
        cursor.execute("SHOW INDEX FROM audit_log")
        indexes = {row["Key_name"]: row for row in cursor.fetchall()}
        self.assertEqual(indexes["uq_audit_log_roster"]["Non_unique"], 0)
        self.assertNotIn("uq_audit_log_request_key", indexes)
        self.assertNotIn("idx_audit_log_roster", indexes)
        self.assertIn("idx_audit_log_action_time", indexes)
        cursor.execute("SHOW INDEX FROM roster_assignment")
        self.assertTrue({"idx_roster_time_overlap", "idx_roster_truck_window", "idx_roster_driver_window",
                         "idx_roster_assistant_window"}.issubset({row["Key_name"] for row in cursor.fetchall()}))
        cursor.execute("SHOW CREATE TABLE roster_assignment")
        assignment_ddl = cursor.fetchone()["Create Table"]
        self.assertIn("uq_roster_assignment_request_key", assignment_ddl)
        self.assertIn("chk_roster_assignment_request_key", assignment_ddl)
        self.assertIn("chk_roster_assignment_interval", assignment_ddl)
        self.assertIn("chk_roster_assignment_people", assignment_ddl)
        cursor.execute("SELECT DELETE_RULE, UPDATE_RULE FROM information_schema.REFERENTIAL_CONSTRAINTS "
                       "WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='audit_log'")
        fks = cursor.fetchall()
        self.assertEqual(len(fks), 2)
        self.assertTrue(all(row["DELETE_RULE"] in {"RESTRICT", "NO ACTION"} for row in fks))
        cursor.execute("SHOW TRIGGERS")
        triggers = {row["Trigger"] for row in cursor.fetchall()}
        self.assertTrue({"trg_prevent_audit_log_modification", "trg_prevent_audit_log_deletion",
                         "trg_user_account_creation_policy", "trg_roster_assignment_request_immutable"}.issubset(triggers))
        self.assertFalse(any("roster_audit_detail" in name for name in triggers))
        cursor.execute("SHOW CREATE VIEW v_roster_duty_intervals")
        self.assertIn("SQL SECURITY INVOKER", cursor.fetchone()["Create View"])
        for view in ("v_available_drivers", "v_available_assistants", "v_drivers_near_cap",
                     "v_station_inventory", "v_customer_orders", "v_quarterly_sales"):
            cursor.execute("SELECT * FROM " + view + " LIMIT 1")  # fixed allowlist above
            cursor.fetchall()

    def check_procedure(self, connection):
        """Both installed procedure copies log only accepted assignments."""
        with connection.cursor() as cursor:
            cursor.execute("UPDATE delivery_staff SET work_hours=0")
        connection.commit()
        with connection.cursor() as cursor:
            def call(route, start, end):
                cursor.execute("CALL sp_assign_truck_roster(%s,1,1,4,3,%s,%s,1,@roster_result)",
                               (route, start, end))
                while cursor.nextset():
                    pass
                cursor.execute("SELECT @roster_result AS result")
                return cursor.fetchone()["result"]

            self.assertEqual(call(1, "2026-09-22 09:00:00", "2026-09-22 10:00:00"), "SUCCESS")
            self.assertEqual(call(1, "2026-09-22 09:00:00", "2026-09-22 10:00:00"),
                             "REJECTED_CHECK_A_OVERLAP")
            # A missing route fails insertion after checks and must not log SYSTEM_ERROR.
            self.assertEqual(call(99999, "2026-09-23 09:00:00", "2026-09-23 10:00:00"), "SYSTEM_ERROR")
            cursor.execute("CREATE TRIGGER test_fail_procedure_audit BEFORE INSERT ON audit_log FOR EACH ROW "
                           "SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='controlled procedure audit failure'")
            try:
                self.assertEqual(call(1, "2026-09-24 09:00:00", "2026-09-24 10:00:00"), "SYSTEM_ERROR")
            finally:
                cursor.execute("DROP TRIGGER test_fail_procedure_audit")
            cursor.execute("SELECT ra.request_key,ra.roster_id,a.entity_id,a.outcome "
                           "FROM roster_assignment ra JOIN audit_log a ON a.roster_id=ra.roster_id")
            rows = cursor.fetchall()
            self.assertEqual(len(rows), 1)
            self.assertTrue(rows[0]["request_key"])
            self.assertEqual(rows[0]["roster_id"], rows[0]["entity_id"])
            self.assertEqual(rows[0]["outcome"], "ACCEPTED")
            cursor.execute("SELECT COUNT(*) AS n FROM audit_log")
            self.assertEqual(cursor.fetchone()["n"], 1)
            cursor.execute("SELECT work_hours FROM delivery_staff WHERE delivery_staff_id IN (1,4)")
            self.assertEqual([row["work_hours"] for row in cursor.fetchall()], [1, 1])
        connection.rollback()

    def check_rows(self, cursor):
        base = "INSERT INTO audit_log(user_id,action,entity_id,outcome,entity_name) VALUES (%s,%s,%s,%s,%s)"
        for action, outcome, entity in (("OTHER_FEATURE", "CUSTOM_OUTCOME", "customer_order"),
                                        ("ASSIGN_ROSTER", "SUCCESS", "roster_assignment"),
                                        ("REJECTED_CHECK_A_OVERLAP", "FAILURE", "roster_assignment")):
            cursor.execute(base, (3, action, 1, outcome, entity))
        assignment = ("INSERT INTO roster_assignment(request_key,route_id,truck_id,driver_id,assistant_id,"
                      "dispatcher_id,start_time,end_time) "
                      "VALUES (%s,1,1,1,4,3,'2026-09-22 09:00:00','2026-09-22 10:00:00')")
        ids = []
        for key in ("CaseKey", "casekey", "CaseKey "):
            cursor.execute(assignment, (key,))
            ids.append(cursor.lastrowid)
        for key in ("CaseKey", None, "", "x" * 129):
            with self.subTest(key=key), self.assertRaises(pymysql.MySQLError):
                cursor.execute(assignment, (key,))
        with self.assertRaises(pymysql.MySQLError):
            cursor.execute(assignment.replace("request_key,", "").replace("(%s,1", "(1"))

        accepted = ("INSERT INTO audit_log(user_id,action,entity_id,outcome,entity_name,roster_id) "
                    "VALUES (3,'ASSIGN_ROSTER',%s,'ACCEPTED','roster_assignment',%s)")
        cursor.execute(accepted, (ids[0], ids[0]))
        with self.assertRaises(pymysql.IntegrityError):
            cursor.execute(accepted, (ids[0], ids[0]))
        for sql, params in (
            (accepted.replace("'ACCEPTED'", "'REJECTED'"), (ids[1], ids[1])),
            (accepted.replace("'ASSIGN_ROSTER'", "'OTHER_FEATURE'"), (ids[1], ids[1])),
            (accepted.replace("'roster_assignment'", "'delivery_route'"), (ids[1], ids[1])),
            (accepted, (ids[0], ids[1])), (accepted, (99999, 99999)),
            (accepted.replace("roster_id)", "roster_id,occurred_at)").replace("%s)", "%s,NULL)"),
             (ids[1], ids[1])),
        ):
            with self.subTest(sql=sql), self.assertRaises(pymysql.MySQLError):
                cursor.execute(sql, params)

        changes = {"roster_id": 999, "request_key": "CASEKEY", "route_id": 2,
                   "truck_id": 2, "driver_id": 2, "assistant_id": 5, "dispatcher_id": 1,
                   "start_time": "2026-09-22 09:01:00", "end_time": "2026-09-22 10:01:00",
                   "created_at": None}
        for field, value in changes.items():
            with self.subTest(field=field), self.assertRaises(pymysql.MySQLError) as caught:
                cursor.execute("UPDATE roster_assignment SET " + field + "=%s WHERE roster_id=%s", (value, ids[0]))
            self.assertIn("immutable", str(caught.exception))
        cursor.execute("UPDATE roster_assignment SET request_key=request_key,route_id=route_id WHERE roster_id=%s", (ids[0],))
        cursor.execute("UPDATE roster_assignment SET status='CANCELLED' WHERE roster_id=%s", (ids[0],))
        with self.assertRaises(pymysql.IntegrityError):
            cursor.execute("DELETE FROM roster_assignment WHERE roster_id=%s", (ids[0],))

        # Isolate actor protection from assignment dispatcher FKs.
        cursor.execute(base, (12, "OTHER_FEATURE", 1, "CUSTOM_OUTCOME", "customer_order"))
        with self.assertRaises(pymysql.IntegrityError):
            cursor.execute("DELETE FROM user WHERE user_id=12")
        cursor.execute("UPDATE user SET is_active=0 WHERE user_id=12")
        for statement in ("UPDATE audit_log SET outcome='CHANGED' WHERE user_id=12",
                          "DELETE FROM audit_log WHERE user_id=12"):
            with self.assertRaises(pymysql.MySQLError):
                cursor.execute(statement)
        cursor.execute("SELECT COUNT(*) AS count FROM audit_log WHERE roster_id IS NOT NULL")
        self.assertEqual(cursor.fetchone()["count"], 1)
        cursor.execute("SELECT COUNT(*) AS count FROM audit_log WHERE roster_id IS NULL")
        self.assertEqual(cursor.fetchone()["count"], 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
