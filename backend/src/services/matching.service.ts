import { findNearbyDrivers } from '../redis/geo.service';
import { NearbyDriver } from '../types';

export async function matchDrivers(
  pickupLat: number,
  pickupLng: number
): Promise<NearbyDriver[]> {
  return findNearbyDrivers(pickupLat, pickupLng);
}
