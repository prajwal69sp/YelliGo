import { v4 as uuidv4 } from 'uuid';
import { pool } from '../db/pool';
import { redis } from '../redis/client';
import { env } from '../config/env';
import { RideRecord, RideRequestPayload } from '../types';

// In-memory cache of in-flight ride requests for fast socket lookups.
// For multi-instance deployments, replace with a Redis hash (ride:{id} -> JSON).
const activeRides = new Map<string, RideRecord>();

export function getActiveRide(rideId: string): RideRecord | undefined {
  return activeRides.get(rideId);
}

export async function createRideRequest(
  payload: RideRequestPayload,
  distanceMeters: number,
  durationSeconds: number,
  fareEstimated: number
): Promise<RideRecord> {
  const rideId = uuidv4();
  const otp = String(Math.floor(1000 + Math.random() * 9000));

  const dbResult = await pool.query(
    `INSERT INTO rides (
       id, passenger_id, pickup_geom, pickup_address, drop_geom, drop_address,
       distance_meters, duration_seconds, fare_estimated, payment_method,
       otp_code, status, requested_at
     )
     VALUES (
       $1, $2,
       ST_SetSRID(ST_MakePoint($3, $4), 4326), $5,
       ST_SetSRID(ST_MakePoint($6, $7), 4326), $8,
       $9, $10, $11, $12, $13, 'REQUESTED', now()
     )
     RETURNING id`,
    [
      rideId,
      payload.rider_id,
      payload.pickup.lng,
      payload.pickup.lat,
      payload.pickup.address ?? null,
      payload.dropoff.lng,
      payload.dropoff.lat,
      payload.dropoff.address ?? null,
      distanceMeters,
      durationSeconds,
      fareEstimated,
      payload.payment_method ?? 'CASH',
      otp,
    ]
  );

  const ride: RideRecord = {
    id: dbResult.rows[0].id,
    rider_id: payload.rider_id,
    driver_id: null,
    pickup: payload.pickup,
    dropoff: payload.dropoff,
    distance_meters: distanceMeters,
    duration_seconds: durationSeconds,
    fare_estimated: fareEstimated,
    status: 'REQUESTED',
    created_at: Date.now(),
  };

  activeRides.set(rideId, ride);
  return ride;
}

export async function tryClaimRide(rideId: string, driverId: string): Promise<boolean> {
  const lockKey = `ride:lock:${rideId}`;
  const result = await redis.set(lockKey, driverId, 'PX', env.RIDE_LOCK_TTL_MS, 'NX');
  return result === 'OK';
}

export async function confirmRideAssignment(
  rideId: string,
  driverId: string
): Promise<RideRecord | null> {
  const dbResult = await pool.query(
    `UPDATE rides
     SET driver_id = $1,
         vehicle_id = (SELECT id FROM vehicles WHERE driver_id = $1 AND is_active = true),
         status = 'ACCEPTED',
         accepted_at = now()
     WHERE id = $2 AND status = 'REQUESTED'
     RETURNING id`,
    [driverId, rideId]
  );

  if (dbResult.rowCount === 0) {
    return null;
  }

  await pool.query(`UPDATE drivers SET status = 'ON_TRIP' WHERE id = $1`, [driverId]);

  const ride = activeRides.get(rideId);
  if (ride) {
    ride.driver_id = driverId;
    ride.status = 'ACCEPTED';
    activeRides.set(rideId, ride);
  }
  return ride ?? null;
}

export async function releaseRideLock(rideId: string): Promise<void> {
  await redis.del(`ride:lock:${rideId}`);
}

export function removeActiveRide(rideId: string): void {
  activeRides.delete(rideId);
}
