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

## Member: Phase 2 — Rail Capacity Allocation and Spillover (Feature 4.2) — 2026-10-10

Scope: verify and complete the existing rail allocator, capacity/quantity integrity and handoff to station receipt. At the start all three repositories were clean on `fullworkflow`; Phase 1 was already present in the branch baseline. Its entries and implementation were preserved. No push, merge, main change, README edit, existing-database reset or prompt edit.

### Working baseline and contract conflicts

The existing scheduler already locks the order and candidate trips, allocates whole product quantities in departure/trip-ID order, spills across trips, rolls back an insufficient allocation, records history/audit, and exposes capacity through `fn_trip_remaining_capacity` / `v_trip_capacity_usage`. Real tests confirmed those working paths; they were not rebuilt.

Existing station foreign keys, `departure_datetime`, `arrival_datetime`, `allocated_by`, and `allocated_at` remain authoritative. `fn_order_item_space(order_item_id, quantity)` retains its existing signature and upward two-decimal rounding. `sp_schedule_train_order(order_id, actor_id, OUT result)` retains its audit/result contract. The prompt's renamed parameters/columns were not duplicated.

Remaining capacity remains derived from total capacity minus committed allocations. A second stored counter and a superficial CHECK on it would create another source of truth. The aggregate invariant is instead enforced by trip row locks plus current shared locking reads in the existing triggers. A repeatable-read stale-snapshot test initially reproduced overbooking in the original plain-SUM trigger; the corrected guard rejects it without adding a column. MySQL trigger restrictions were checked against the [official stored-program documentation](https://dev.mysql.com/doc/mysql-reslimits-excerpt/8.0/en/stored-program-restrictions.html), and the actual `FOR SHARE` behavior was verified against the test server.

### Defects / changed files

- `feature_4_2_rail_allocation/06_trg_capacity_check.sql`: current shared reads prevent stale-snapshot capacity bypass; derive inserted/updated space from the existing function; prevent changes to received cargo; create a unique pending station manifest in the allocation transaction. This closes the verified gap where successful allocations were invisible in the incoming-manifest view.
- `07_trg_trip_capacity_shrink.sql`: current shared read when validating a capacity decrease.
- `08_sp_schedule_train_order.sql`: reject nonpositive order quantities, require active supported destination/origin hubs, skip received manifests, and compare departures using explicit Sri Lanka time.
- `12_trg_allocation_quantity_guard.sql`: serialize on the order item and use a current shared read, preventing stale-snapshot duplicate quantities across trips.
- `15_sp_reverse_rail_allocation.sql`: reject reversal once any trip manifest has been received; use the same Sri Lanka departure-time boundary.
- `16_trip_hub_guard.sql`: insert/update guards for active Kandy-to-supported-hub connections; allocated trip endpoints cannot be changed.
- `build_phase2_migration.py`, `15_phase2_rail_workflow.sql`: generated, repeatable selected-database migration. `python build_phase2_migration.py --check` detects drift from source artifacts.
- `workflow-test.md`: this appended member section.

### Initialization and migration

For an existing initialized target, explicitly select its database in the MySQL client, then `SOURCE /absolute/path/15_phase2_rail_workflow.sql`. Do not run the resetting base schema/master files to upgrade it. Run with rail writers paused: DDL commits independently, so the complete migration is not one atomic DDL transaction.

The migration checks existing capacity/quantity over-allocation before proceeding, adds missing existing named constraints/indexes, replaces only rail functions/procedures/triggers/view, and backfills missing manifests only for future scheduled trips with still-scheduled orders. Existing manifest rows are not reset and inventory is never rewritten. Historical missing manifests require receipt/inventory reconciliation and are deliberately not fabricated. No global users/roles or table resets are involved. A missing or inconsistent baseline must be resolved explicitly rather than overwritten.

No migration was applied to any existing database during this task. Tests create a fresh UUID database through the Phase 1 harness, install the real schema and feature SQL, then remove only that database. The migration regression applies the generated script twice to populated disposable data, restores a simulated missing future manifest exactly once, preserves allocations, and successfully allocates more cargo afterward.

### Validation and dependencies

The backend rail suite includes 15 rail tests plus 13 inherited identity regressions. It verifies single/multi-trip results, upward rounding, whole-order rollback, concurrent same-order and competing-order submissions, stale capacity/quantity snapshots, selected-trip route/cutoff rules, capacity reduction, supported hubs, role restrictions, reversal, and migration preservation. The station handoff test runs the existing real `sp_receive_manifest`: partial receipt leaves the split order scheduled; final receipt advances it to `ARRIVED_AT_STATION_STORE`; stock equals the allocated quantity; duplicate receipt is rejected.

Preliminary tests exposed the missing manifest and stale-read defects. Test tuple/list expectations and a migration backfill's ambiguous column reference were also corrected; these earlier failures are not counted as passes.

Deploy this SQL together with the backend/Frontend Phase 2 changes. Truck assignment, dispatch, completion and business report correctness are not certified by this rail suite. Reversal intentionally retains a pending trip manifest when its cargo becomes empty; the station-receipt member must verify empty/premature-receipt policy. Historical missing manifests also remain an operational reconciliation dependency. Browser verification is blocked by no connected browser.

Approval: ready for Phase 2 code review subject to the recorded final test results and deployment/browser checks; no merge or deployment authorization is implied.

Phase 2 completion result: **28/28 backend/MySQL tests passed** in the final complete run, including the corrected future-manifest backfill. Disposable schema cleanup completed. Migration source consistency and all repository diff checks passed. Existing-database deployment and browser verification remain pending.

## Phase 4 member — Station Inventory & Regional Warehouse Operations (2026-10-10)

All three repositories started clean on `fullworkflow`; earlier phases were preserved. No applicable AGENTS.md exists outside the unrelated archived checkout. Project-plan PDF text (§2.1, §3.4) confirms station/product inventory, location_id bins, manager_id station scoping and lightweight adjustments. No README, original prompt, commit, push, merge or main changes.

### Reused contracts and verified defects

Reused `station_store`, `inventory`, `storage_location`, `stock_adjustment`, `manifest`, existing views and `trg_apply_stock_adjustment`. Kept `sp_receive_manifest(station_id, trip_id, user_id, OUT result_code)` and versioned inventory endpoints. Prompt plural names, location_code column and two-argument procedure are conceptual targets, not replacements for working schema/contracts. Existing free-text reason supports recount corrections; DAMAGED/LOST/EXPIRED codes are supported without renaming the column or removing historical reasons.

Receipt previously accepted empty/unarrived/wrong-destination cargo and could regress a closed order. It now locks the trip/manifest, validates Kandy origin and destination, ARRIVED status and elapsed arrival time, nonempty valid cargo, and locks affected orders. Product upserts are grouped and ordered. READ COMMITTED and order locks support spillover receipt: order/history advance only after all quantities are allocated and all related manifests are received. Closed/null order states roll back intake. No delivery completion or inventory deduction at dispatch was added.

The project plan requires staff department scoping, but no warehouse assignment existed. The clarification question received no answer; explicit station assignment was selected from the plan rather than granting all-station access. Added nullable `user.station_id` FK for warehouse staff; managers keep `station_store.manager_id`. Existing accounts are not guessed/backfilled. Added nullable unique `stock_adjustment.request_key` to support retry-safe adjustments without changing existing callers or rows.

### Changed files and deployment

- `01_schema.sql`: warehouse assignment FK and optional adjustment request key for fresh initialization.
- `03_procedures.sql`: receipt validation, locking, complete-order advancement and rollback guards.
- `00_master_init.sql`: synchronized canonical schema/procedure changes.
- `build_phase4_migration.py`: generates selected-database migration; `--check` verifies source consistency.
- `16_phase4_station_workflow.sql`: repeatable, non-destructive additions plus procedure replacement.
- `workflow-test.md`: this record.

Before deploying matching backend/frontend, select the intended database and run `16_phase4_station_workflow.sql` during a pause in station writes (MySQL DDL commits independently). Do NOT rerun `01_schema.sql` or `00_master_init.sql` on an existing database. Migration does not reset stock, seed data or invent receipts. It was executed only in disposable test schemas here.

Assign existing managers using `station_store.manager_id`. For existing warehouse staff, an administrator must explicitly set `user.station_id` to an approved active station, verifying user role and IDs first. New warehouse accounts can use the existing SuperAdmin provisioning form's station selector, backed by optional `station_id` in the staff API. Null/unassigned staff are denied station data. No extra account provisioning system was created.

### Actual verification and remaining issues

Backend command: `.venv/Scripts/python.exe -m unittest discover -s tests -p test_phase4_inventory.py -v` from backend: **43/43 passed**, 69.267 seconds, comprising 9 Phase 4 tests plus 34 inherited identity/rail/roster tests. Uses real FastAPI and MySQL in generated `kandypack_phase1_test_92efcbb5e14549b3905d4e7b08759b04`, then drops only that schema. Tests cover scoping, duplicate/concurrent intake, injected late failure rollback, empty/premature/wrong destination rejection, closed-order rejection, adjustment replay/conflict/underflow/concurrency, report totals, bin replay/cross-station rejection and warehouse provisioning. Migration tested twice, including adding fields to a simulated pre-Phase-4 shape inside the disposable schema while preserving stock. After the final null-status guard refinement, the affected receipt subset was rerun; result recorded below.

`build_phase4_migration.py --check` and all repository `git diff --check` passed. Existing adjustment trigger and nonnegative constraint were reused and exercised. The routine owns its transaction; backend explicitly ends its authorization-read transaction before calling it. An expected injected failure in the inherited roster test is logged but passes rollback assertions.

Remaining deployment prerequisites: apply migration, populate approved legacy warehouse assignments, deploy all matching repositories. Browser runtime has no connected browser, so interactive UI/live proxy verification remains pending. Customer delivery completion and broader reporting certification remain outside this member's scope. No existing database was reset or modified.

Phase 4 completion: final affected receipt rerun (`-k receipt`) **4/4 passed** in 9.531 seconds after null-state hardening, including spillover receipt, concurrent/rollback receipt, cancelled/null order rejection and roster receipt handoff. Disposable schema `kandypack_phase1_test_d73d287f4e874099be301d3368684a12` was cleaned up. Migration generation check passed. Full suite result remains the 43/43 run above; the four tests are a rerun, not four additional distinct tests.
