# Workflow verification log

## Member: Phase 1 — Identity, RBAC and subdomain security — 2026-10-10

Scope: verify existing identity schema and SQL role definitions, prevent customer creation through staff provisioning, and connect provisioned delivery personnel to the existing roster identity. Only this supplied prompt was handled. Branch was `fullworkflow`, initially clean. No README or original prompt was changed; nothing was pushed or merged.

### Baseline and requirement conflicts

- Existing `user`, `customer`, `delivery_staff`, unique email/customer-user constraints, foreign keys and InnoDB tables are reused. No plural duplicate tables were added.
- Existing `delivery_staff_id`, `license_number`, `work_hours`, `user.role` and `user.is_active` remain authoritative. Driver/assistant roles belong to `user`; roster reporting derives weekly hours. The proposed `staff_type`, `weekly_hours`, `status` and renamed identifiers were not duplicated.
- The existing `trg_user_account_creation_policy` already validates staff email domains, recognized roles and initial password reset. It was extended instead of adding a competing differently named trigger.
- Existing MySQL roles `role_superadmin`, `role_logistics_mgr`, `role_dispatcher`, `role_store_mgr`, `role_warehouse_staff`, `role_customer` are retained. Role names and grants were inspected statically, not recreated on the shared server.
- The schema models customer ownership and staff roles, not separate organizations/tenants. No unrequested tenant schema was invented. Station assignment remains another member's existing responsibility.

### Defects and files changed

- `04_triggers.sql`: staff provisioning had no customer-rejection guard. It now signals SQLSTATE 45000 when `@kandypack_staff_provisioning = 1` and a CUSTOMER insert is attempted.
- `14_phase1_identity_guard.sql`: selected-database migration that replaces only the existing identity trigger. No database selection, table resets, seed writes, role/account changes or unrelated trigger changes.
- `workflow-test.md`: this record.

### Initialization / migration

For an existing target database, select that database explicitly, then run `14_phase1_identity_guard.sql` using the MySQL client (`SOURCE /absolute/path/14_phase1_identity_guard.sql`). Do not use `01_schema.sql`, `00_master_init.sql` or `clean_master.sql` to upgrade an existing database: they contain reset/initialization operations. Trigger replacement uses MySQL DDL and is not transactionally rolled back; schedule it appropriately.

No migration was applied to any existing database during this task. The backend test harness creates a unique `kandypack_phase1_test_<uuid>` database, strips database-selection/reset statements from initialization, loads the real schema and triggers plus the migration, and removes only the database it created. No global grants or database accounts are created by the test.

### Tests and results

- Existing `test_phase1_db_security.test_static_validation()` — passed. This checks text/policy presence, not live SQL privilege isolation.
- Backend `tests/test_phase1_workflow.py` — 13 real FastAPI/MySQL tests passed, including actual trigger rejection, customer/user transaction rollback, concurrent registration uniqueness, staff/delivery_staff creation, password reset and order ownership. Both fresh trigger installation and the selected-database migration executed successfully.
- Disposable databases were cleaned up by the harness, including failed preliminary runs. Initial harness path and endpoint-regression failures were corrected before the passing run.
- Live SQL role impersonation/grant-isolation testing was not run: it would require server-global role/user operations outside the disposable schema. Existing role/grant scripts were not executed.

### Cross-repository dependencies and remaining work

Backend provisioning sets the guard variable on its dedicated connection and creates delivery_staff atomically for DRIVER/ASSISTANT. That connection is closed after each request. Apply this migration with the backend changes. Staff reset and active status are checked by the shared backend dependency used by rail, inventory, roster and reporting.

This verifies Phase 1 identity integration, not successful rail spillover, receipt, dispatch, delivery completion or business reports. Their business transitions remain with the respective members. No public completion/dispatch transition endpoint was found in the inspected roster router; that is a lifecycle dependency, not a Phase 1 feature added here.

Approval: SQL changes are ready for code review; target-database migration and deployment approval are still separate actions.
