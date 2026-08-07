-- Kandypack Logistics Platform - Performance B-Tree Indexes (MySQL 8.0)
USE kandypack_db;

-- 1. Optimizing lookup for available train trips (PERF-02, PERF-11)
CREATE INDEX idx_train_trips_alloc 
ON train_trips (destination_hub, status, remaining_capacity_cubic_m, departure_time);

-- 2. Optimizing lookup for pending rail scheduling orders (PERF-01)
CREATE INDEX idx_orders_status_dest 
ON orders (status, destination_hub, order_date);

-- 3. Optimizing overlap checking in truck rosters (FR-4.3.4)
CREATE INDEX idx_roster_time_overlap 
ON roster_assignments (status, scheduled_start, scheduled_end, truck_id, driver_id, assistant_id);

-- 4. Optimizing inventory search by station and product
CREATE INDEX idx_station_inv_search 
ON station_inventory (station_id, product_id, quantity_available);
