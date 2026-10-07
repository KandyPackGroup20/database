-- View: v_trip_capacity_usage (Feature 4.2: Rail Allocation Capacity Analytics)
USE kandypack_db;

CREATE OR REPLACE VIEW v_trip_capacity_usage AS
SELECT 
    tt.trip_id,
    tt.origin_station_id,
    tt.destination_station_id,
    tt.departure_datetime,
    tt.status,
    tt.total_capacity,
    COALESCE(SUM(ra.allocated_space), 0) AS used_space,
    tt.total_capacity - COALESCE(SUM(ra.allocated_space), 0) AS remaining_space,
    ROUND((COALESCE(SUM(ra.allocated_space), 0) / tt.total_capacity) * 100, 2) AS utilisation_pct
FROM train_trip tt
LEFT JOIN rail_allocation ra ON tt.trip_id = ra.trip_id
GROUP BY tt.trip_id, tt.origin_station_id, tt.destination_station_id, tt.departure_datetime, tt.status, tt.total_capacity;
