-- Kandypack Logistics Platform - Performance B-Tree Indexes (MySQL 8.0)
USE kandypack_db;

-- 1. Optimizing lookup for available train trips (PERF-02, PERF-11)
CREATE INDEX idx_train_trip_alloc 
ON train_trip (destination_station_id, status, departure_datetime);

-- 2. Optimizing lookup for pending rail scheduling orders (PERF-01)
CREATE INDEX idx_customer_order_status_date 
ON customer_order (status, order_date);

-- 3. Optimizing overlap checking in truck rosters (FR-4.3.4)
CREATE INDEX idx_roster_time_overlap 
ON roster_assignment (status, start_time, end_time, truck_id, driver_id, assistant_id);

-- 4. Optimizing storage location search
CREATE INDEX idx_storage_loc_search 
ON storage_location (station_id, location_code);

--roster indexes
CREATE INDEX idx_roster_truck_window
    ON roster_assignment (truck_id, status, start_time, end_time);
CREATE INDEX idx_roster_driver_window
    ON roster_assignment (driver_id, status, start_time, end_time);
CREATE INDEX idx_roster_assistant_window
    ON roster_assignment (assistant_id, status, start_time, end_time);