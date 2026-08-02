export interface DriverLocationPayload {
  driver_id: string;
  lat: number;
  lng: number;
  heading?: number;
  speed?: number;
}

export interface RideRequestPayload {
  rider_id: string;
  pickup: { lat: number; lng: number; address?: string };
  dropoff: { lat: number; lng: number; address?: string };
  payment_method?: 'CASH' | 'UPI';
}

export interface NearbyDriver {
  driver_id: string;
  distance_km: number;
  lat: number;
  lng: number;
}

export interface RideAcceptPayload {
  ride_id: string;
  driver_id: string;
}

export type RideStatus =
  | 'REQUESTED'
  | 'ACCEPTED'
  | 'ARRIVED'
  | 'STARTED'
  | 'COMPLETED'
  | 'CANCELLED';

export interface RideRecord {
  id: string;
  rider_id: string;
  driver_id: string | null;
  pickup: { lat: number; lng: number };
  dropoff: { lat: number; lng: number };
  distance_meters: number;
  duration_seconds: number;
  fare_estimated: number;
  status: RideStatus;
  created_at: number;
}
