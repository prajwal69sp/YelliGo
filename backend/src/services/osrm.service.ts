import axios from 'axios';
import { env } from '../config/env';

export interface RouteResult {
  distanceMeters: number;
  durationSeconds: number;
  geometry: any;
}

export async function getRoute(
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number
): Promise<RouteResult> {
  const url = `${env.OSRM_BASE_URL}/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}`;

  const { data } = await axios.get(url, {
    params: { overview: 'full', geometries: 'geojson' },
    timeout: 5000,
  });

  if (data.code !== 'Ok' || !data.routes?.length) {
    throw new Error(`OSRM routing failed: ${data.code ?? 'unknown error'}`);
  }

  const route = data.routes[0];
  return {
    distanceMeters: route.distance,
    durationSeconds: route.duration,
    geometry: route.geometry,
  };
}
