import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/captain_state.dart';

/// Stands in for the real Socket.io `new_ride_alert` event described in the
/// backend module. Swap this for a real socket listener (see
/// socket_service.dart placeholder below) once the backend is wired up -
/// the CaptainController API surface stays identical either way.
class MockDispatchService {
  final Random _rng = Random();

  Stream<IncomingRide> listenForRideAlerts(LatLng driverLocation) async* {
    while (true) {
      await Future.delayed(Duration(seconds: 8 + _rng.nextInt(10)));
      yield _generateMockRide(driverLocation);
    }
  }

  IncomingRide _generateMockRide(LatLng near) {
    final pickupOffset = LatLng(
      near.latitude + (_rng.nextDouble() - 0.5) * 0.01,
      near.longitude + (_rng.nextDouble() - 0.5) * 0.01,
    );
    final dropoffOffset = LatLng(
      pickupOffset.latitude + (_rng.nextDouble() - 0.5) * 0.03,
      pickupOffset.longitude + (_rng.nextDouble() - 0.5) * 0.03,
    );

    const distanceCalc = Distance();
    final distanceMeters = distanceCalc.as(LengthUnit.Meter, pickupOffset, dropoffOffset) * 1.3;
    final distanceToPickupKm = distanceCalc.as(LengthUnit.Meter, near, pickupOffset) / 1000;
    final durationSeconds = (distanceMeters / 1000) * 180;
    final fare = 15 + (distanceMeters / 1000) * 6 + (durationSeconds / 60) * 1.0;

    return IncomingRide(
      rideId: 'ride_${DateTime.now().millisecondsSinceEpoch}',
      pickup: RidePoint(latLng: pickupOffset, address: 'Pickup near you'),
      dropoff: RidePoint(latLng: dropoffOffset, address: 'Nearby destination'),
      distanceToPickupKm: distanceToPickupKm,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      fareEstimated: double.parse(fare.toStringAsFixed(0)),
    );
  }
}
