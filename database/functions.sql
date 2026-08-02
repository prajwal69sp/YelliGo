-- ============================================================
-- Nearby drivers KNN + radius search
-- ============================================================
CREATE OR REPLACE FUNCTION find_nearby_drivers(
    p_lat           DOUBLE PRECISION,
    p_lng           DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 3000,
    p_limit         INTEGER DEFAULT 5
)
RETURNS TABLE (
    driver_id       UUID,
    full_name       VARCHAR,
    phone_number    VARCHAR,
    rating_avg      NUMERIC,
    vehicle_type    vehicle_type,
    registration_no VARCHAR,
    distance_meters DOUBLE PRECISION,
    heading         SMALLINT
) AS $$
DECLARE
    passenger_point GEOMETRY := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326);
BEGIN
    RETURN QUERY
    SELECT
        d.id,
        u.full_name,
        u.phone_number,
        d.rating_avg,
        v.vehicle_type,
        v.registration_no,
        ST_Distance(cdl.geom::geography, passenger_point::geography) AS distance_meters,
        cdl.heading
    FROM current_driver_location cdl
    JOIN drivers d   ON d.id = cdl.driver_id
    JOIN users u     ON u.id = d.user_id
    JOIN vehicles v  ON v.driver_id = d.id AND v.is_active = true
    WHERE
        d.status = 'ONLINE'
        AND d.is_document_verified = true
        AND cdl.updated_at > now() - INTERVAL '2 minutes'
        AND ST_DWithin(cdl.geom::geography, passenger_point::geography, p_radius_meters)
    ORDER BY
        cdl.geom <-> passenger_point
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Usage:
-- SELECT * FROM find_nearby_drivers(12.9716, 77.5946, 3000, 5);
