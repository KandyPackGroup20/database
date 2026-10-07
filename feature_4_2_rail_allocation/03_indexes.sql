-- indexes for trip search + capacity SUM
USE kandypack_db;

CREATE INDEX idx_f42_trip_search ON train_trip (destination_station_id, status, departure_datetime);
CREATE INDEX idx_f42_alloc_trip_space ON rail_allocation (trip_id, allocated_space);