import { Server, Socket } from 'socket.io';
import { upsertDriverLocation, setDriverStatus, removeDriver } from '../redis/geo.service';
import {
  tryClaimRide,
  confirmRideAssignment,
  getActiveRide,
  removeActiveRide,
} from '../services/ride.service';
import { DriverLocationPayload, RideAcceptPayload } from '../types';

// Maps driverId <-> socketId so we can target emits without relying purely on rooms.
export const driverSocketMap = new Map<string, string>();

export function registerDriverHandlers(io: Server, socket: Socket) {
  socket.on('driver_online', async ({ driver_id }: { driver_id: string }) => {
    driverSocketMap.set(driver_id, socket.id);
    socket.data.driverId = driver_id;
    socket.join(`driver:${driver_id}`);
    await setDriverStatus(driver_id, 'ONLINE');
    socket.emit('driver_online_ack', { driver_id });
  });

  socket.on('driver_offline', async ({ driver_id }: { driver_id: string }) => {
    await removeDriver(driver_id);
    driverSocketMap.delete(driver_id);
  });

  // Requirement 1: driver sends GPS every 3-5s
  socket.on('location_update', async (payload: DriverLocationPayload) => {
    try {
      const { driver_id, lat, lng } = payload;
      if (!driver_id || lat == null || lng == null) {
        return socket.emit('error', { message: 'Invalid location payload' });
      }
      await upsertDriverLocation(driver_id, lat, lng);

      const rideId = socket.data.activeRideId;
      if (rideId) {
        io.to(`ride:${rideId}`).emit('driver_location_broadcast', {
          driver_id,
          lat,
          lng,
          heading: payload.heading,
        });
      }
    } catch (err) {
      console.error('[location_update] error:', err);
      socket.emit('error', { message: 'Failed to update location' });
    }
  });

  // Requirement 5: race-safe ride acceptance
  socket.on('accept_ride', async (payload: RideAcceptPayload) => {
    const { ride_id, driver_id } = payload;

    const ride = getActiveRide(ride_id);
    if (!ride || ride.status !== 'REQUESTED') {
      return socket.emit('ride_already_taken', { ride_id });
    }

    const claimed = await tryClaimRide(ride_id, driver_id);
    if (!claimed) {
      return socket.emit('ride_already_taken', { ride_id });
    }

    const confirmedRide = await confirmRideAssignment(ride_id, driver_id);
    if (!confirmedRide) {
      return socket.emit('ride_already_taken', { ride_id });
    }

    socket.data.activeRideId = ride_id;
    socket.join(`ride:${ride_id}`);

    socket.emit('ride_confirmed', {
      ride_id,
      pickup: confirmedRide.pickup,
      dropoff: confirmedRide.dropoff,
      fare_estimated: confirmedRide.fare_estimated,
    });

    io.to(`rider:${confirmedRide.rider_id}`).emit('trip_match_found', {
      ride_id,
      driver_id,
    });

    socket.to(`ride_alert:${ride_id}`).emit('ride_taken', { ride_id });
  });

  socket.on('trip_status_update', async ({ ride_id, status }: { ride_id: string; status: string }) => {
    io.to(`ride:${ride_id}`).emit('trip_status_updated', { ride_id, status });
    if (status === 'COMPLETED' || status === 'CANCELLED') {
      removeActiveRide(ride_id);
    }
  });

  socket.on('disconnect', async () => {
    const driverId = socket.data.driverId;
    if (driverId) {
      driverSocketMap.delete(driverId);
    }
  });
}
