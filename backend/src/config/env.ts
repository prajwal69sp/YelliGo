import dotenv from 'dotenv';
dotenv.config();

function required(name: string, fallback?: string): string {
  const val = process.env[name] ?? fallback;
  if (val === undefined) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return val;
}

export const env = {
  PORT: Number(required('PORT', '4000')),
  REDIS_URL: required('REDIS_URL', 'redis://localhost:6379'),
  OSRM_BASE_URL: required('OSRM_BASE_URL', 'http://localhost:5000'),
  DATABASE_URL: required('DATABASE_URL'),
  BASE_FARE: Number(required('BASE_FARE', '25')),
  RATE_PER_KM: Number(required('RATE_PER_KM', '8')),
  RATE_PER_MIN: Number(required('RATE_PER_MIN', '1.5')),
  DRIVER_STALE_SECONDS: Number(required('DRIVER_STALE_SECONDS', '90')),
  RIDE_LOCK_TTL_MS: Number(required('RIDE_LOCK_TTL_MS', '10000')),
  MATCH_RADIUS_KM: Number(required('MATCH_RADIUS_KM', '3')),
  MATCH_LIMIT: Number(required('MATCH_LIMIT', '5')),
};
