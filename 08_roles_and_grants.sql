-- Kandypack Logistics Platform - SQL Authorization & RBAC Roles (MySQL 8.0)
-- Feature 4.1: Multi-Tenant Identity & Access 
USE kandypack_db;

/*
                         KANDYPACK DATABASE
                                │
                    ┌───────────┴───────────┐
                    │                       │
               MYSQL USERS              MYSQL ROLES
                    │                       │
        ┌───────────┼───────────┬───────────┼───────────┐
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
 db_superadmin  db_logistics  db_dispatcher  db_storemgr  db_whstaff
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
 role_superadmin  role_logistics_mgr  role_dispatcher  role_store_mgr  role_warehouse_staff
        │           │           │           │           │
        │           │           │           │           │
        ▼           ▼           ▼           ▼           ▼
   ALL PRIVILEGES  Train/Route   Truck &     Inventory   Warehouse
                   Management    Delivery     Management  Operations
        │          & Analytics   Scheduling       │           │
        │              │             │            │           │
        │              │             │            │           │
        └──────────────┴─────────────┴────────────┴───────────┘
                                │
                                │
                         db_customer
                                │
                                ▼
                         role_customer
                                │
                                ▼
                    Limited Customer Access
                    ├── View Products
                    ├── Create Orders
                    ├── Add Order Items
                    └── View Own Orders


    USER → ROLE → PRIVILEGES

    db_superadmin   → role_superadmin        → ALL PRIVILEGES
    db_logistics    → role_logistics_mgr    → Train / Route / Analytics
    db_dispatcher   → role_dispatcher       → Truck / Staff / Delivery
    db_storemgr     → role_store_mgr        → Manifest / Inventory
    db_whstaff      → role_warehouse_staff  → Warehouse / Stock Adjustments
    db_customer     → role_customer         → Products / Orders / Tracking
*/

-- 1. Create MySQL Roles for each Persona
DROP ROLE IF EXISTS 'role_superadmin';
DROP ROLE IF EXISTS 'role_logistics_mgr';
DROP ROLE IF EXISTS 'role_dispatcher';
DROP ROLE IF EXISTS 'role_store_mgr';
DROP ROLE IF EXISTS 'role_warehouse_staff';
DROP ROLE IF EXISTS 'role_customer';

CREATE ROLE 'role_superadmin';
CREATE ROLE 'role_logistics_mgr';
CREATE ROLE 'role_dispatcher';
CREATE ROLE 'role_store_mgr';
CREATE ROLE 'role_warehouse_staff';
CREATE ROLE 'role_customer';

-- 2. Grant Privileges per RBAC Matrix (SRS 5.3)

-- Role: SUPERADMIN (Unrestricted administrative access)
      
GRANT ALL PRIVILEGES ON kandypack_db.* TO 'role_superadmin';

-- Role: LOGISTICS_MGR (Train capacity planning, route configuration, analytics)

-- The Logistics Manager is responsible for train trip scheduling. 
-- They must create new train schedules (INSERT), monitor existing 
-- schedules (SELECT), and adjust departure/arrival times or statuses (UPDATE). 
-- WHY NOT DELETE PRIVILEGE GRANTED? : Creating or closing physical railway stations is an enterprise infrastructure 
-- change reserved solely for SUPERADMIN
GRANT SELECT ON kandypack_db.train_trip TO 'role_logistics_mgr';
GRANT INSERT, UPDATE ON kandypack_db.train_trip TO 'role_logistics_mgr';

-- WHY DELETE PRIVELEGE IS NOT GRANTED?: DELETE PRIVILEGE IS GRANTED TO THE ADMIN ONLY -- THE SUPERADMIN
-- The product can be added by the superadmin only
GRANT SELECT, INSERT, UPDATE ON kandypack_db.product TO 'role_logistics_mgr';

-- The delivery route can be added or modified by the superadmin only
GRANT SELECT, INSERT, UPDATE ON kandypack_db.delivery_route TO 'role_logistics_mgr';

-- The manager needs read-only access to railway hubs (Colombo, Kandy, Galle, etc.) 
-- to select valid origin and destination stations when scheduling train trips.
GRANT SELECT ON kandypack_db.station_store TO 'role_logistics_mgr';

-- To plan train allocations, the manager must see incoming orders with status 
-- PENDING_RAIL_SCHEDULING and inspect what products/quantities were ordered.
-- Why INSERT/UPDATE is denied: Only the customer can place orders.
GRANT SELECT ON kandypack_db.customer_order TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.order_item TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.rail_allocation TO 'role_logistics_mgr';

-- Why direct INSERT/UPDATE is denied: Manual row editing in rail_allocation could 
-- cause cargo space over-allocation. All allocations must happen strictly through 
-- the concurrency-safe stored procedure.
GRANT EXECUTE ON PROCEDURE kandypack_db.sp_allocate_rail_capacity TO 'role_logistics_mgr';

-- requires strategic reporting for the Logistics Manager. These views utilize advanced 
-- SQL OLAP aggregations (GROUP BY ... WITH ROLLUP and window function DENSE_RANK()) 
-- to help them forecast seasonal freight demand by route and product.
GRANT SELECT ON kandypack_db.v_quarterly_sales TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.v_top_quarterly_items TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.v_stock_adjustment_summary TO 'role_logistics_mgr';



      
-- Role: DISPATCHER (Truck roster scheduling, driver/assistant assignment)
      
GRANT SELECT ON kandypack_db.truck TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.delivery_staff TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.delivery_route TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.customer_order TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.customer TO 'role_dispatcher';
GRANT SELECT, INSERT, UPDATE ON kandypack_db.roster_assignment TO 'role_dispatcher';
GRANT SELECT, INSERT, UPDATE ON kandypack_db.delivery TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.v_available_drivers TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.v_available_assistants TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.v_drivers_near_cap TO 'role_dispatcher';
GRANT EXECUTE ON PROCEDURE kandypack_db.sp_assign_truck_roster TO 'role_dispatcher';

      
-- Role: STORE_MGR (Station inventory management, receiving train manifests)
      
GRANT SELECT ON kandypack_db.station_store TO 'role_store_mgr';
GRANT SELECT ON kandypack_db.storage_location TO 'role_store_mgr';
GRANT SELECT, INSERT, UPDATE ON kandypack_db.manifest TO 'role_store_mgr';
GRANT SELECT, INSERT, UPDATE ON kandypack_db.inventory TO 'role_store_mgr';
GRANT SELECT, INSERT ON kandypack_db.stock_adjustment TO 'role_store_mgr';
GRANT SELECT ON kandypack_db.v_station_inventory TO 'role_store_mgr';
GRANT SELECT ON kandypack_db.v_incoming_train_manifests TO 'role_store_mgr';
GRANT SELECT ON kandypack_db.v_trip_manifest_items TO 'role_store_mgr';
GRANT SELECT ON kandypack_db.v_stock_adjustment_summary TO 'role_store_mgr';
GRANT EXECUTE ON PROCEDURE kandypack_db.sp_receive_manifest TO 'role_store_mgr';

      
-- Role: WAREHOUSE_STAFF (Bin location lookups and damage/stock adjustments)
      
GRANT SELECT ON kandypack_db.storage_location TO 'role_warehouse_staff';
GRANT SELECT ON kandypack_db.v_station_inventory TO 'role_warehouse_staff';
GRANT SELECT ON kandypack_db.v_incoming_train_manifests TO 'role_warehouse_staff';
GRANT SELECT ON kandypack_db.v_trip_manifest_items TO 'role_warehouse_staff';
GRANT INSERT ON kandypack_db.stock_adjustment TO 'role_warehouse_staff';

      
-- Role: CUSTOMER (Order placement, tracking own orders and viewing products)
      
GRANT SELECT ON kandypack_db.product TO 'role_customer';
GRANT SELECT ON kandypack_db.delivery_route TO 'role_customer';
GRANT SELECT ON kandypack_db.v_customer_orders TO 'role_customer';
GRANT INSERT ON kandypack_db.customer_order TO 'role_customer';
GRANT INSERT ON kandypack_db.order_item TO 'role_customer';

-- 3. Demo Database Users for Live Testing & Concurrency Verification

-- Create demo user accounts (using '%' for development/staging access)
CREATE USER IF NOT EXISTS 'db_superadmin'@'%' IDENTIFIED BY 'KandyPackAdmin@2026';
CREATE USER IF NOT EXISTS 'db_logistics'@'%' IDENTIFIED BY 'KandyLogistics@2026';
CREATE USER IF NOT EXISTS 'db_dispatcher'@'%' IDENTIFIED BY 'KandyDispatch@2026';
CREATE USER IF NOT EXISTS 'db_storemgr'@'%' IDENTIFIED BY 'KandyStoreMgr@2026';
CREATE USER IF NOT EXISTS 'db_whstaff'@'%' IDENTIFIED BY 'KandyWHStaff@2026';
CREATE USER IF NOT EXISTS 'db_customer'@'%' IDENTIFIED BY 'KandyCustomer@2026';

-- Grant corresponding roles to users
GRANT 'role_superadmin' TO 'db_superadmin'@'%';
GRANT 'role_logistics_mgr' TO 'db_logistics'@'%';
GRANT 'role_dispatcher' TO 'db_dispatcher'@'%';
GRANT 'role_store_mgr' TO 'db_storemgr'@'%';
GRANT 'role_warehouse_staff' TO 'db_whstaff'@'%';
GRANT 'role_customer' TO 'db_customer'@'%';

-- Activate default roles upon 
SET DEFAULT ROLE 'role_superadmin' TO 'db_superadmin'@'%';
SET DEFAULT ROLE 'role_logistics_mgr' TO 'db_logistics'@'%';
SET DEFAULT ROLE 'role_dispatcher' TO 'db_dispatcher'@'%';
SET DEFAULT ROLE 'role_store_mgr' TO 'db_storemgr'@'%';
SET DEFAULT ROLE 'role_warehouse_staff' TO 'db_whstaff'@'%';
SET DEFAULT ROLE 'role_customer' TO 'db_customer'@'%';

FLUSH PRIVILEGES;

-- Why Can't We Create a MySQL User for Every Customer?
-- 1.MySQL User Limits: MySQL has a maximum connection limit per user and 
--    global connection limit. Creating a user for every customer would 
--    exceed these limits, leading to performance issues and potential crashes.
-- 2.Security Risks: Each user would have their own  credentials, 
--    increasing the attack surface and making it harder to manage and monitor 
--    user access.

-- Planned cargo reads; no warehouse mutation privileges.
GRANT SELECT ON kandypack_db.station_store TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.order_item TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.product TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.train_trip TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.manifest TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.rail_allocation TO 'role_dispatcher';
GRANT SELECT, INSERT ON kandypack_db.audit_log TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.user TO 'role_dispatcher';
GRANT SELECT ON kandypack_db.customer TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.delivery TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.roster_assignment TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.truck TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.delivery_staff TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.user TO 'role_logistics_mgr';
GRANT SELECT ON kandypack_db.manifest TO 'role_logistics_mgr';
