-- TRAIN_TRIP integrity rules at the DB layer
USE kandypack_db;

ALTER TABLE train_trip
  ADD CONSTRAINT chk_trip_capacity_positive CHECK (total_capacity > 0),
  ADD CONSTRAINT chk_trip_time_order        CHECK (arrival_datetime > departure_datetime),
  ADD CONSTRAINT chk_trip_distinct_stations CHECK (origin_station_id <> destination_station_id),
  ADD CONSTRAINT chk_trip_status            CHECK (status IN ('SCHEDULED','IN_TRANSIT','ARRIVED','CANCELLED'));