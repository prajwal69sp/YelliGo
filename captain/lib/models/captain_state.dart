import 'package:latlong2/latlong.dart';

enum CaptainVehicleType { bike, auto }

class RidePoint {
  final LatLng latLng;
  final String address;

  const RidePoint({required this.latLng, required this.address});
}

class IncomingRide {
  final String rideId;
  final RidePoint pickup;
  final RidePoint dropoff;
  final double distanceToPickupKm;
  final double distanceMeters;
  final double durationSeconds;
  final double fareEstimated;

  const IncomingRide({
    required this.rideId,
    required this.pickup,
    required this.dropoff,
    required this.distanceToPickupKm,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fareEstimated,
  });
}

class EarningsSummary {
  final double todayEarnings;
  final int todayTrips;
  final double rating;

  const EarningsSummary({
    required this.todayEarnings,
    required this.todayTrips,
    required this.rating,
  });

  EarningsSummary addCompletedTrip(double fare) {
    return EarningsSummary(
      todayEarnings: todayEarnings + fare,
      todayTrips: todayTrips + 1,
      rating: rating,
    );
  }
}

/// Sealed state machine mirroring the ride lifecycle from the backend:
/// OFFLINE -> ONLINE(searching) -> IncomingRequest -> EnRouteToPickup
/// -> ArrivedAtPickup -> OnTrip -> TripCompleted -> back to Online
sealed class CaptainState {
  final EarningsSummary earnings;
  const CaptainState({required this.earnings});
}

class Offline extends CaptainState {
  const Offline({required super.earnings});
}

class OnlineSearching extends CaptainState {
  const OnlineSearching({required super.earnings});
}

class IncomingRequest extends CaptainState {
  final IncomingRide ride;
  final int secondsRemaining;
  const IncomingRequest({
    required this.ride,
    required this.secondsRemaining,
    required super.earnings,
  });
}

class EnRouteToPickup extends CaptainState {
  final IncomingRide ride;
  const EnRouteToPickup({required this.ride, required super.earnings});
}

class ArrivedAtPickup extends CaptainState {
  final IncomingRide ride;
  final String? otpError;
  const ArrivedAtPickup({
    required this.ride,
    required super.earnings,
    this.otpError,
  });
}

class OnTrip extends CaptainState {
  final IncomingRide ride;
  const OnTrip({required this.ride, required super.earnings});
}

class TripCompleted extends CaptainState {
  final IncomingRide ride;
  final double fareCollected;
  const TripCompleted({
    required this.ride,
    required this.fareCollected,
    required super.earnings,
  });
}
