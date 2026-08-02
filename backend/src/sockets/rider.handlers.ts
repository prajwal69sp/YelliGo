import { Server, Socket } from 'socket.io';
import { getRoute } from '../services/osrm.service';
import { estimateFare } from '../services/fare.service';
import { matchDrivers } from '../services/matching.service';
import { createRideRequest } from '../services/ride.service';
import { RideRequestPayload } from '../types';
import { driverSocketMap } from './driver.handlers';

export function registerRiderHandlers(io: Server, socket: Socket) {
  socket.on('rider_connect', ({ rider_id }: { rider_id: string }) => {
    socket.data.riderId = rider_id;
    socket.join(`rider:${rider_id}`);
  });

  // Requirements 2, 3, 4
  socket.on('request_ride', async (payload: RideRequestPayload) => {
    try {
      const { pickup, dropoff, rider_id } = payload;
      if (!pickup || !dropoff || !rider_id) {
        return socket.emit('error', { message: 'Invalid ride request payload' });
      }

      const route = await getRoute(pickup.lat, pickup.lng, dropoff.lat, dropoff.lng);
      const fareEstimated = estimateFare(route.distanceMeters, route.durationSeconds);

      const ride = await createRideRequest(
        payload,
        route.distanceMeters,
        route.durationSeconds,
        fareEstimated
      );

      socket.join(`ride_alert:${ride.id}`);

      socket.emit('ride_estimate', {
        ride_id: ride.id,
        distance_meters: route.distanceMeters,
        duration_seconds: route.durationSeconds,
        fare_estimated: fareEstimated,
        route_geometry: route.geometry,
      });

      const nearbyDrivers = await matchDrivers(pickup.lat, pickup.lng);

      if (nearbyDrivers.length === 0) {
        return socket.emit('no_drivers_available', { ride_id: ride.id });
      }

      for (const driver of nearbyDrivers) {
        const socketId = driverSocketMap.get(driver.driver_id);
        if (socketId) {
          io.sockets.sockets.get(socketId)?.join(`ride_alert:${ride.id}`);
          io.to(socketId).emit('new_ride_alert', {
            ride_id: ride.id,
            pickup,
            dropoff,
            distance_to_pickup_km: driver.distance_km,
            fare_estimated: fareEstimated,
            distance_meters: route.distanceMeters,
            duration_seconds: route.durationSeconds,
          });
        }
      }

      setTimeout(async () => {
        const { getActiveRide } = await import('../services/ride.service');
        const current = getActiveRide(ride.id);
        if (current && current.status === 'REQUESTED') {
          socket.emit('ride_request_timeout', { ride_id: ride.id });
        }
      }, 15000);
    } catch (err) {
      console.error('[request_ride] error:', err);
      socket.emit('error', { message: 'Failed to process ride request' });
    }
  });

  socket.on('cancel_ride', ({ ride_id }: { ride_id: string }) => {
    io.to(`ride:${ride_id}`).emit('trip_cancelled', { ride_id });
  });
}
