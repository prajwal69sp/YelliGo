import Redis from 'ioredis';
import { env } from '../config/env';

// Two separate connections: one for normal commands, one dedicated to blocking/pubsub
// if you extend this later (e.g. driver status change notifications).
export const redis = new Redis(env.REDIS_URL);
export const redisPub = new Redis(env.REDIS_URL);

redis.on('error', (err) => console.error('[Redis] connection error:', err));
redis.on('connect', () => console.log('[Redis] connected'));
