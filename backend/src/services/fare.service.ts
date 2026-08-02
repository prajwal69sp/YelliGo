import { env } from '../config/env';

export function estimateFare(distanceMeters: number, durationSeconds: number): number {
  const distanceKm = distanceMeters / 1000;
  const durationMin = durationSeconds / 60;

  const fare =
    env.BASE_FARE + distanceKm * env.RATE_PER_KM + durationMin * env.RATE_PER_MIN;

  return Math.round(fare);
}
