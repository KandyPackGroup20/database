USE kandypack_db;

CREATE SQL SECURITY INVOKER VIEW v_roster_duty_intervals AS
    SELECT
        roster_id,
        route_id,
        truck_id,
        driver_id AS staff_id,
        'DRIVER' AS duty_type,
        start_time,
        end_time,
        status,
        CASE
            WHEN status = 'CANCELLED' THEN 0
            WHEN status IN ('SCHEDULED', 'IN_TRANSIT', 'COMPLETED') THEN 1
            ELSE NULL
        END AS is_counted
    FROM roster_assignment

    UNION ALL

    SELECT
        roster_id,
        route_id,
        truck_id,
        assistant_id AS staff_id,
        'ASSISTANT' AS duty_type,
        start_time,
        end_time,
        status,
        CASE
            WHEN status = 'CANCELLED' THEN 0
            WHEN status IN ('SCHEDULED', 'IN_TRANSIT', 'COMPLETED') THEN 1
            ELSE NULL
        END AS is_counted
    FROM roster_assignment;
