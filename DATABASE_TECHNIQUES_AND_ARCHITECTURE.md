# Kandypack Logistics Platform — Database Architecture & Techniques Specification
**Module:** CS3043 Database Systems  
**Project Group:** Group 20 — Department of Computer Science & Engineering, University of Moratuwa  
**System Domain:** Feature 4.1 — Multi-Tenant Identity, Access & Database Security Architecture  

---

## Table of Contents
1. [Scope & Architectural Responsibilities](#1-scope--architectural-responsibilities)
2. [Data Definition Language (DDL) & Schema Design](#2-data-definition-language-ddl--schema-design)
3. [Data Manipulation Language (DML) & Prepared Statements](#3-data-manipulation-language-dml--prepared-statements)
4. [Triggers & Session Context Token Architecture](#4-triggers--session-context-token-architecture)
5. [Database Views & Role-Based Data Scoping](#5-database-views--role-based-data-scoping)
6. [SQL Authorization & MySQL 8.0 RBAC Architecture](#6-sql-authorization--mysql-80-rbac-architecture)
7. [Database Normalization & Subtyping (1NF to BCNF)](#7-database-normalization--subtyping-1nf-to-bcnf)
8. [Strategic / Controlled Denormalization](#8-strategic--controlled-denormalization)
9. [Redis In-Memory Caching Architecture](#9-redis-in-memory-caching-architecture)
10. [Database Pagination Techniques](#10-database-pagination-techniques)
11. [Performance Tuning & B-Tree Index Optimization](#11-performance-tuning--b-tree-index-optimization)
12. [Architectural Rationale & Design Decision Records (ADRs)](#12-architectural-rationale--design-decision-records-adrs)

---

## 1. Scope & Architectural Responsibilities

The Identity, Access & Database Security module provides the foundational data and access layer for the Kandypack Logistics Platform. Its architectural scope includes:

* **Identity & Credential Modeling:** Schema definition for core identity and specialized personas (`user`, `customer`, `delivery_staff`) via relational entity subtyping.
* **Database-Enforced Access Control:** Multi-tenant privilege segregation using MySQL 8.0 Role-Based Access Control (RBAC) and least-privilege `GRANT`/`REVOKE` matrices.
* **Data Integrity & Immutability:** Engine-level business policy enforcement using MySQL triggers and tamper-proof audit trails.
* **Data Abstraction:** Role-scoped views to isolate operational domains and prevent data leakage across administrative and customer boundaries.
* **Query Security Discipline:** Zero string-concatenated SQL queries; mandatory prepared statements and parameterized queries across all endpoints.
* **Performance Engineering:** Optimization strategies balancing strict normalization against controlled denormalization, Redis caching, and keyset pagination.

---

## 2. Data Definition Language (DDL) & Schema Design

Located in `database/01_schema.sql`:

### 2.1 The `user` Table (Authentication Root)
The central entity for authentication and system credentials:
```sql
CREATE TABLE user (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    role VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    force_password_reset TINYINT DEFAULT 0,
    is_active TINYINT DEFAULT 1,
    station_id INT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_email UNIQUE (email),
    FOREIGN KEY (station_id) REFERENCES station_store(station_id) ON DELETE SET NULL
) ENGINE=InnoDB;
```
* **Storage Engine:** `InnoDB` provides ACID transaction compliance, row-level locking, and referential integrity enforcement.
* **Uniqueness Constraints:** `uq_user_email` creates a unique B-Tree index, preventing duplicate account provisioning and accelerating credential lookups to $O(\log N)$.
* **Security Attributes:** `force_password_reset` enforces initial credential rotation on provisioned accounts; `is_active` supports soft deactivation without breaking historical foreign key references.

### 2.2 The `customer` Table (1:1 Extension Subtype)
```sql
CREATE TABLE customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    route_id INT NULL,
    phone VARCHAR(30) NOT NULL,
    address_line VARCHAR(500) NOT NULL,
    city VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    CONSTRAINT uq_customer_user UNIQUE (user_id),
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE,
    FOREIGN KEY (route_id) REFERENCES delivery_route(route_id) ON DELETE SET NULL
) ENGINE=InnoDB;
```
* **`uq_customer_user`:** Enforces strict 1-to-1 cardinality with the parent `user` table.

### 2.3 The `delivery_staff` Table (1:1 Extension Subtype)
```sql
CREATE TABLE delivery_staff (
    delivery_staff_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    license_number VARCHAR(100) NOT NULL,
    work_hours DECIMAL(5, 2) DEFAULT 0.00,
    CONSTRAINT uq_delivery_staff_user UNIQUE (user_id),
    FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

### 2.4 The `audit_log` Table (Immutable Compliance Trail)
```sql
CREATE TABLE audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity_id INT NOT NULL,
    outcome VARCHAR(50) NOT NULL,
    occurred_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    entity_name VARCHAR(100) NOT NULL,
    roster_id INT NULL,
    CONSTRAINT uq_audit_log_roster UNIQUE (roster_id),
    INDEX idx_audit_log_action_time (action, occurred_at DESC, audit_id DESC),
    INDEX idx_audit_log_user (user_id),
    CONSTRAINT fk_audit_log_user FOREIGN KEY (user_id) REFERENCES user(user_id)
) ENGINE=InnoDB;
```

---

## 3. Data Manipulation Language (DML) & Prepared Statements

Every query uses **parameterized prepared statement discipline** (`%s`), delegating parsing and query execution planning to MySQL while neutralizing SQL Injection vulnerabilities (SRS SR-5.3).

### Summary of Module API Endpoints (`backend/app/api/v1/auth.py`):

| Method | Endpoint | Access Control | Core SQL Execution |
| :--- | :--- | :--- | :--- |
| **`POST`** | `/api/v1/auth/login` | Public | `SELECT user_id, email, password_hash, name, role, force_password_reset, station_id FROM user WHERE email = %s AND is_active = 1` |
| **`POST`** | `/api/v1/auth/register` | Public (Customer Portal) | Atomic Multi-Table Transaction: `INSERT INTO user` followed by `INSERT INTO customer` |
| **`POST`** | `/api/v1/auth/users` | `SUPERADMIN` | Sets `@kandypack_staff_provisioning = 1` + inserts into `user` and `delivery_staff` |
| **`GET`** | `/api/v1/auth/users` | `SUPERADMIN` | `SELECT u.*, ss.city FROM user u LEFT JOIN station_store ss ON ss.station_id = u.station_id` |
| **`POST`** | `/api/v1/auth/change-password`| Authenticated User | `UPDATE user SET password_hash = %s, force_password_reset = 0 WHERE user_id = %s` |
| **`GET`** | `/api/v1/auth/me` | Authenticated User | Hydrates session profile with `LEFT JOIN customer` and `LEFT JOIN station_store` |
| **`PUT`** | `/api/v1/auth/me` | Authenticated User | `UPDATE user` + `UPDATE customer` (scoped by role) |
| **`POST`** | `/api/v1/auth/logout` | Authenticated User | Purges HttpOnly cookie `kandypack_session` |

---

## 4. Triggers & Session Context Token Architecture

Located in `database/04_triggers.sql` and `database/14_phase1_identity_guard.sql`:

### 4.1 `trg_user_account_creation_policy` (BEFORE INSERT ON user)
Enforces corporate identity policies directly within the MySQL storage engine:
```sql
CREATE TRIGGER trg_user_account_creation_policy
BEFORE INSERT ON user
FOR EACH ROW
BEGIN
    -- Rule 1: Prevent staff provisioning endpoints from creating customer accounts
    IF COALESCE(@kandypack_staff_provisioning, 0) = 1 AND NEW.role = 'CUSTOMER' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Staff provisioning cannot create customers.';
    END IF;

    -- Rule 2: Force password reset for all staff accounts & enforce company email domain
    IF NEW.role != 'CUSTOMER' THEN
        SET NEW.force_password_reset = 1;
        
        IF NEW.email NOT LIKE '%@kandypack.lk' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Internal staff users must have an email ending with @kandypack.lk';
        END IF;
    ELSE
        IF NEW.force_password_reset IS NULL THEN
            SET NEW.force_password_reset = 0;
        END IF;
    END IF;

    -- Rule 3: Validate role belongs to approved domain set
    IF NEW.role NOT IN ('SUPERADMIN', 'LOGISTICS_MGR', 'DISPATCHER', 'STORE_MGR', 'WAREHOUSE_STAFF', 'DRIVER', 'ASSISTANT', 'CUSTOMER') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SECURITY POLICY VIOLATION: Invalid user role specified.';
    END IF;
END;
```

### 4.2 Session Context Variable Pattern (`@kandypack_staff_provisioning`)
* **Concept:** A MySQL **User-Defined Session Variable**, scoped strictly to the current database connection.
* **Problem Addressed:** Standard database triggers execute on any `INSERT INTO user`, but have no inherent insight into which application workflow initiated the write.
* **Mechanism:** 
  1. During the administrative employee creation workflow (`POST /api/v1/auth/users`), the gateway issues `SET @kandypack_staff_provisioning = 1`.
  2. The trigger validates `IF COALESCE(@kandypack_staff_provisioning, 0) = 1 AND NEW.role = 'CUSTOMER'`.
  3. If an administrator attempts to create a `CUSTOMER` from the administrative interface, the trigger raises `SQLSTATE '45000'` and aborts the transaction.
  4. In the public customer registration route (`POST /api/v1/auth/register`), the variable remains unset (`NULL`), allowing regular customer registration without interference.

### 4.3 Audit Immutability Triggers
```sql
CREATE TRIGGER trg_prevent_audit_log_modification
BEFORE UPDATE ON audit_log FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs are immutable and cannot be altered.';
END;

CREATE TRIGGER trg_prevent_audit_log_deletion
BEFORE DELETE ON audit_log FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'SECURITY VIOLATION: Audit logs are immutable and cannot be deleted.';
END;
```
Ensures append-only compliance integrity for all security events.

---

## 5. Database Views & Role-Based Data Scoping

Located in `database/02_views.sql`:

1. **`v_customer_orders`:**
   Joins `customer_order`, `customer`, `user`, and `delivery_route` to abstract order tracking for the customer portal while isolating internal staff fields.
2. **`v_available_drivers`:**
   Filters drivers currently active and under the statutory 40-hour limit:
   ```sql
   CREATE OR REPLACE VIEW v_available_drivers AS
   SELECT ds.delivery_staff_id AS driver_id, u.name AS full_name,
          ds.license_number AS license_no, ds.work_hours,
          40.00 - ds.work_hours AS remaining_hours_allowed
   FROM delivery_staff ds
   JOIN user u ON ds.user_id = u.user_id
   WHERE u.role = 'DRIVER' AND ds.work_hours < 40.00;
   ```
3. **`v_available_assistants`:**
   Filters assistants with `work_hours < 60.00`.
4. **`v_drivers_near_cap`:**
   Flags drivers reaching 90% (36h) utilization with status warnings (`WARNING_NEAR_CAP`, `CAP_REACHED`).

---

## 6. SQL Authorization & MySQL 8.0 RBAC Architecture

Located in `database/08_roles_and_grants.sql`:

### 6.1 The 6 RBAC Roles
* `role_superadmin`: Full administrative access (`ALL PRIVILEGES`).
* `role_logistics_mgr`: Access to `train_trip`, `rail_allocation`, `sp_allocate_rail_capacity`, and analytics views.
* `role_dispatcher`: Access to `truck`, `delivery_staff`, `roster_assignment`, `sp_assign_truck_roster`, and driver views.
* `role_store_mgr`: Access to `manifest`, `inventory`, `stock_adjustment`, and `sp_receive_manifest`.
* `role_warehouse_staff`: Access to `storage_location`, stock adjustments, and manifest inspection views.
* `role_customer`: Access to `product`, inserting orders/items, and viewing own orders via `v_customer_orders`.

### 6.2 Architectural Rationale: Database Roles vs. Individual Database Users
1. **Connection Scalability:** MySQL maintains strict global and per-user connection limits. Creating separate database accounts for thousands of end customers would exhaust connection handles and thread pools.
2. **Security Footprint:** Distributing individual MySQL database credentials to customers dramatically expands the attack surface.
3. **Connection Pooling Architecture:** The FastAPI gateway maintains managed connection pools and enforces departmental least-privilege boundaries using application roles mapped to MySQL 8.0 roles.

---

## 7. Database Normalization & Subtyping (1NF to BCNF)

### 7.1 1NF (First Normal Form)
* All attributes are atomic. Customer addresses are broken down into `address_line`, `city`, and `postal_code` rather than stored as unstructured comma-separated strings.
* No multi-valued attributes or repeating groups.

### 7.2 2NF (Second Normal Form)
* Every non-prime attribute is fully functionally dependent on the primary key.
* Avoids partial dependencies across all composite keys (e.g., in `order_item` and `storage_location`).

### 7.3 3NF (Third Normal Form) & Entity Subtyping
* Eliminates transitive dependencies ($A \to B \to C$).
* **Entity Subtyping:** Rather than placing customer details (`phone`, `address`) and driver details (`license_number`, `work_hours`) in one bloated `user` table (which would create massive sparse `NULL` values and update anomalies), the schema implements supertype/subtype decomposition:
  * **Supertype:** `user` (core credentials).
  * **Subtypes:** `customer` (1:1) and `delivery_staff` (1:1).
* **3NF Structural Reconciliation (ERD Reconciliation):**
  * In the legacy draft schema, `route_id` was placed on `customer`. This violated 3NF because customers can order to different destinations and routes over time. `route_id` was decoupled from `customer` and migrated to `customer_order.delivery_route_id`.

### 7.4 BCNF (Boyce-Codd Normal Form)
* Every determinant is a candidate key. In `user`, both `user_id` and `email` are unique keys; all functional dependencies have a superkey determinant.

---

## 8. Strategic / Controlled Denormalization

### Rationale
Strict 3NF requires multi-table `JOIN`s on every read query. Under heavy OLTP traffic, joins consume CPU cycles and memory. **Controlled Denormalization** selectively duplicates or pre-aggregates data to eliminate join overhead while protecting consistency via triggers or transactions.

### 5 Concrete Implementations in Kandypack:

1. **`user.station_id` (Auth & Scoping):**
   * *Normalized alternative:* Join `user` $\to$ `station_store` on every request.
   * *Denormalized design:* Stored directly on `user`.
   * *Benefit:* During login and JWT issuance, user profile and regional hub scoping are retrieved in a single $O(1)$ query without joins.

2. **`order_item.unit_price_at_order` (Point-in-Time Snapshot):**
   * *Normalized alternative:* Join `order_item` $\to$ `product` to read `unit_price`.
   * *Denormalized design:* Snapshot copied to `order_item` at order creation time.
   * *Benefit:* Invoice calculations (`quantity * unit_price_at_order`) avoid joining `product`, and historical invoices are protected if catalog prices change in the future.

3. **`delivery_staff.work_hours` (Cached Weekly Counter):**
   * *Normalized alternative:* Calculate weekly hours dynamically via `SUM(TIMESTAMPDIFF(HOUR, start_time, end_time)) FROM roster_assignment` across candidate drivers.
   * *Denormalized design:* Maintained as an integer/decimal counter in `delivery_staff`.
   * *Benefit:* The dispatcher engine checks the 40h/60h cap instantly without running heavy aggregate scans over historical rosters.

4. **`train_trip.total_capacity` vs. Dynamic Allocation:**
   * *Normalized alternative:* Recompute capacity via `SUM(allocated_space) FROM rail_allocation` on every search.
   * *Denormalized design:* Stored and tracked on `train_trip` with composite indexes.
   * *Benefit:* Rail availability queries return in milliseconds.

5. **`delivery.cargo_weight_kg`:**
   * *Normalized alternative:* Compute weight on every delivery assignment by joining `order_item` $\to$ `product` (`quantity * unit_weight_kg`).
   * *Denormalized design:* Precomputed and stored on `delivery`.
   * *Benefit:* Truck payload validation avoids traversing child order items.

---

## 9. Redis In-Memory Caching Architecture

Located in `backend/app/core/cache.py`:

### 9.1 Mechanics
* **Storage Medium:** Redis stores key-value pairs in RAM, providing sub-millisecond (`< 1ms`) read latency compared to disk-bound MySQL InnoDB pages.
* **Pattern Used:** **Cache-Aside Pattern (Lazy Loading)**.
  1. Application checks Redis: `get_cache(key)`.
  2. **Cache HIT:** Return cached JSON immediately (`X-Cache: HIT`, latency $\approx 1-2\text{ms}$).
  3. **Cache MISS:** Query MySQL, serialize result, and write to Redis with a TTL: `set_cache(key, data, ttl_seconds=60)` (`X-Cache: MISS`).

### 9.2 Implementations:
1. **Train Schedule Timetable (`rail.py` Line 1024):**
   * Key: `"cache:rail:schedules"` (TTL = 60s).
   * **Write Invalidation:** Whenever a train trip is updated or an allocation is scheduled, `invalidate_cache("cache:rail:")` purges stale keys immediately.
2. **Brute-Force Rate Limiting & Account Protection (`auth.py` & `cache.py`):**
   * Tracks failed login attempts per email in memory/Redis (`check_rate_limit`).
   * After 5 failures within 60 seconds, the account is temporarily locked for 15 minutes.
   * **Performance Benefit:** Once locked, subsequent malicious login attempts are rejected at the API gateway with `HTTP 429` **without querying MySQL**, shielding the database connection pool from denial-of-service exhaustion.
3. **Resilient Local Memory Fallback:**
   * If Redis is offline, `cache.py` falls back to a thread-safe Python dictionary (`_memory_cache`), ensuring zero downtime.

---

## 10. Database Pagination Techniques

When tables (`customer_order`, `audit_log`, `notification`) scale to millions of rows, returning all data via `SELECT *` leads to database buffer pool exhaustion, high network payload latency, and client browser crashes.

### 10.1 Offset-Based Pagination (`LIMIT` & `OFFSET`)
Used in `notifications.py` and `roster.py`:
```sql
SELECT notification_id, title, message, created_at
FROM notification
WHERE recipient_email = %s
ORDER BY created_at DESC
LIMIT %s OFFSET %s;
```
* **Formula:** `OFFSET = (page_number - 1) * page_size`.
* **API Safety Bounds:** Enforced via FastAPI query validation:
  ```python
  limit: int = Query(50, ge=1, le=100)
  ```
  Prevents clients from requesting unbounded result sets (e.g., `?limit=1000000`).

### 10.2 Keyset / Cursor-Based Pagination (High-Scale Approach)
* **The Problem with `OFFSET`:** As `OFFSET` grows (e.g. `LIMIT 50 OFFSET 100000`), MySQL must scan 100,050 index rows and discard the first 100,000, causing query latency to degrade.
* **The Keyset Solution:** Paginate using indexed continuous columns:
  ```sql
  -- Page 2 query using cursor from Page 1:
  SELECT audit_id, action, occurred_at, outcome
  FROM audit_log
  WHERE (occurred_at < :last_occurred_at) 
     OR (occurred_at = :last_occurred_at AND audit_id < :last_audit_id)
  ORDER BY occurred_at DESC, audit_id DESC
  LIMIT 50;
  ```
* **Index Support:** Supported directly by the composite B-Tree index:
  ```sql
  INDEX idx_audit_log_action_time (action, occurred_at DESC, audit_id DESC)
  ```
  MySQL jumps directly to the indexed cursor node in $O(\log N)$ time, regardless of whether the user is on page 1 or page 10,000.

---

## 11. Performance Tuning & B-Tree Index Optimization

1. **Unique Indexes for High-Frequency Lookups:**
   * `user(email)`: Avoids full table scans ($O(N)$) during login; B-Tree search runs in $O(\log N)$.
   * `customer(user_id)` and `delivery_staff(user_id)`: Speeds up 1:1 join lookups.
2. **Covering Projections (Eliminating `SELECT *`):**
   * Queries explicitly state required columns (`SELECT user_id, email, password_hash...`), reducing network bandwidth and InnoDB buffer pool memory consumption.
3. **Short Transaction Lifecycles:**
   * DML transactions are bounded tightly (e.g., 2 quick inserts during customer registration) and committed immediately, avoiding prolonged row lock contention.

---

## 12. Architectural Rationale & Design Decision Records (ADRs)

### 12.1 Implementation Scope & Database Deliverables
The module implements the core identity tables (`user`, `customer`, `delivery_staff`), database security triggers (`trg_user_account_creation_policy`, `trg_prevent_audit_log_modification`, `trg_prevent_audit_log_deletion`), role-scoping views (`v_customer_orders`, `v_available_drivers`, `v_drivers_near_cap`), and the complete MySQL 8.0 RBAC authorization matrix granting least-privilege permissions across 6 distinct roles.

### 12.2 Cryptographic Operations vs. Stored Procedures
Password verification requires salted `bcrypt` cryptographic hashing (with a work factor of 12 rounds) and JWT session signing (`HS256`). MySQL stored procedures cannot natively compute bcrypt or sign JWTs securely. Passing plaintext passwords into database stored programs is a known architectural vulnerability. Consequently, cryptographic operations are executed in the application gateway using prepared statements, while database integrity and access boundaries are enforced via triggers and MySQL roles.

### 12.3 Session Context Token Architecture (`@kandypack_staff_provisioning`)
A MySQL user-defined session variable acts as a context token between the application gateway and the database trigger. Because triggers execute indiscriminately on `INSERT`, setting this variable during administrative employee provisioning allows `trg_user_account_creation_policy` to reject any attempt to insert a `CUSTOMER` role through administrative paths, strictly enforcing business policy at the storage engine layer.

### 12.4 Performance Engineering via Controlled Denormalization
The schema stores `station_id` directly in the `user` table to eliminate relational join overhead against `station_store` during token validation and request routing. Additionally, `order_item.unit_price_at_order` preserves historical price integrity while eliminating joins to the product catalog during order calculations.

### 12.5 Defensive Scaling & Resource Protection
Resource starvation is prevented across three tiers:
1. **Redis Caching:** Read-heavy schedule queries are served from memory with write invalidation.
2. **In-Memory Rate Limiting:** Brute-force attacks are rejected with `HTTP 429` prior to initiating database connections.
3. **Bounded Pagination:** B-Tree-indexed cursor pagination caps query payloads and protects the InnoDB buffer pool.
