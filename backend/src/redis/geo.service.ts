import { redis } from './client';
import { env } from '../config/env';
import { NearbyDriver } from '../types';

const GEO_KEY = 'drivers:geo';
const lastSeenKey = (driverId: string) => `driver:last_seen:${driverId}`;
const statusKey = (driverId: string) => `driver:status:${driverId}`;

export async function upsertDriverLocation(
  driverId: string,
  lat: number,
  lng: number
): Promise<void> {
  const pipeline = redis.pipeline();
  pipeline.geoadd(GEO_KEY, lng, lat, driverId);
  pipeline.set(lastSeenKey(driverId), Date.now().toString(), 'EX', env.DRIVER_STALE_SECONDS);
  await pipeline.exec();
}

export async function setDriverStatus(
  driverId: string,
  status: 'ONLINE' | 'OFFLINE' | 'ON_TRIP'
): Promise<void> {
  if (status === 'OFFLINE') {
    await Promise.all([
      redis.zrem(GEO_KEY, driverId),
      redis.del(statusKey(driverId)),
      redis.del(lastSeenKey(driverId)),
    ]);
    return;
  }
  await redis.set(statusKey(driverId), status);
}

export async function getDriverStatus(driverId: string): Promise<string | null> {
  return redis.get(statusKey(driverId));
}

async function isDriverFresh(driverId: string): Promise<boolean> {
  const seen = await redis.exists(lastSeenKey(driverId));
  return seen === 1;
}

export async function findNearbyDrivers(
  lat: number,
  lng: number,
  radiusKm: number = env.MATCH_RADIUS_KM,
  limit: number = env.MATCH_LIMIT
): Promise<NearbyDriver[]> {
  const raw = (await redis.call(
    'GEOSEARCH',
    GEO_KEY,
    'FROMLONLAT',
    lng.toString(),
    lat.toString(),
    'BYRADIUS',
    radiusKm.toString(),
    'km',
    'ASC',
    'COUNT',
    (limit * 3).toString(),
    'WITHCOORD',
    'WITHDIST'
  )) as any[];

  const candidates: NearbyDriver[] = raw.map((entry) => {
    const [driverId, distanceStr, coords] = entry;
    const [lngStr, latStr] = coords as [string, string];
    return {
      driver_id: driverId as string,
      distance_km: parseFloat(distanceStr as string),
      lat: parseFloat(latStr),
      lng: parseFloat(lngStr),
    };
  });

  const result: NearbyDriver[] = [];
  for (const candidate of candidates) {
    if (result.length >= limit) break;
    const [status, fresh] = await Promise.all([
      getDriverStatus(candidate.driver_id),
      isDriverFresh(candidate.driver_id),
    ]);
    if (status === 'ONLINE' && fresh) {
      result.push(candidate);
    }
  }
  return result;
}

export async function removeDriver(driverId: string): Promise<void> {
  await Promise.all([
    redis.zrem(GEO_KEY, driverId),
    redis.del(statusKey(driverId)),
    redis.del(lastSeenKey(driverId)),
  ]);
}

/**
 * Returns live positions for every driver currently in the geo set,
 * annotated with their ONLINE/ON_TRIP status and freshness. Used by the
 * admin panel's live map - not on the matching hot path, so a full scan
 * of the geo set is acceptable here (fine up to a few thousand drivers).
 */
export async function getAllDriverPositions(): Promise<
  { driver_id: string; lat: number; lng: number; status: string | null; fresh: boolean }[]
> {
  const driverIds = await redis.zrange(GEO_KEY, 0, -1);
  if (driverIds.length === 0) return [];

  const positions = (await redis.geopos(GEO_KEY, ...driverIds)) as (
    | [string, string]
    | null
  )[];

  const results = await Promise.all(
    driverIds.map(async (driverId, i) => {
      const pos = positions[i];
      if (!pos) return null;
      const [status, fresh] = await Promise.all([
        getDriverStatus(driverId),
        isDriverFresh(driverId),
      ]);
      return {
        driver_id: driverId,
        lng: parseFloat(pos[0]),
        lat: parseFloat(pos[1]),
        status,
        fresh,
      };
    })
  );

  return results.filter((r): r is NonNullable<typeof r> => r !== null);
}
