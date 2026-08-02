-- ============================================================
-- Ride lifecycle sample queries
-- ============================================================

-- 1. Create ride (REQUESTED)
INSERT INTO rides (
    passenger_id, pickup_geom, pickup_address, drop_geom, drop_address,
    distance_meters, duration_seconds, fare_estimated, payment_method, otp_code
)
VALUES (
    $1,
    ST_SetSRID(ST_MakePoint($2, $3), 4326),
    $4,
    ST_SetSRID(ST_MakePoint($5, $6), 4326),
    $7,
    $8, $9, $10, $11,
    LPAD((FLOOR(RANDOM() * 10000))::TEXT, 4, '0')
)
RETURNING id, status, otp_code, requested_at;

-- 2. Driver accepts (REQUESTED -> ACCEPTED)
UPDATE rides
SET
    driver_id   = $1,
    vehicle_id  = (SELECT id FROM vehicles WHERE driver_id = $1 AND is_active = true),
    status      = 'ACCEPTED',
    accepted_at = now()
WHERE id = $2
  AND status = 'REQUESTED'
RETURNING id, status, driver_id, accepted_at;

UPDATE drivers SET status = 'ON_TRIP' WHERE id = $1;

-- 3. Driver arrives (ACCEPTED -> ARRIVED)
UPDATE rides
SET status = 'ARRIVED', arrived_at = now()
WHERE id = $1 AND status = 'ACCEPTED'
RETURNING id, status, arrived_at;

-- 4. Trip starts, OTP verified (ARRIVED -> STARTED)
UPDATE rides
SET status = 'STARTED', started_at = now()
WHERE id = $1
  AND status = 'ARRIVED'
  AND otp_code = $2
RETURNING id, status, started_at;

-- 5. Trip completes (STARTED -> COMPLETED)
UPDATE rides
SET
    status         = 'COMPLETED',
    completed_at   = now(),
    fare_final     = $2,
    payment_status = CASE WHEN payment_method = 'CASH' THEN 'PAID' ELSE payment_status END
WHERE id = $1 AND status = 'STARTED'
RETURNING id, status, fare_final, completed_at;

UPDATE drivers
SET status = 'ONLINE', total_rides = total_rides + 1
WHERE id = (SELECT driver_id FROM rides WHERE id = $1);

-- 6. Cancellation (pre-STARTED -> CANCELLED)
UPDATE rides
SET
    status              = 'CANCELLED',
    cancelled_at        = now(),
    cancelled_by        = $2,
    cancellation_reason = $3
WHERE id = $1
  AND status IN ('REQUESTED', 'ACCEPTED', 'ARRIVED')
RETURNING id, status, cancelled_at;

UPDATE drivers SET status = 'ONLINE'
WHERE id = (SELECT driver_id FROM rides WHERE id = $1) AND status = 'ON_TRIP';
