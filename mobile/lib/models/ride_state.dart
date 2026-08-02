import 'package:latlong2/latlong.dart';
import 'place.dart';

enum VehicleType { bike, auto }

class RouteInfo {
  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final Map<VehicleType, double> fareByVehicle;

  const RouteInfo({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fareByVehicle,
  });
}

sealed class RideState {
  const RideState();
}

class SelectingDestination extends RideState {
  final Place? pickup;
  final Place? destination;
  final RouteInfo? route;
  final VehicleType selectedVehicle;
  final bool isLoadingRoute;

  const SelectingDestination({
    this.pickup,
    this.destination,
    this.route,
    this.selectedVehicle = VehicleType.bike,
    this.isLoadingRoute = false,
  });

  SelectingDestination copyWith({
    Place? pickup,
    Place? destination,
    RouteInfo? route,
    VehicleType? selectedVehicle,
    bool? isLoadingRoute,
    bool clearRoute = false,
  }) {
    return SelectingDestination(
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      route: clearRoute ? null : (route ?? this.route),
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
    );
  }

  bool get isReadyToConfirm => pickup != null && destination != null && route != null;
}

class FindingDriver extends RideState {
  final Place pickup;
  final Place destination;
  final RouteInfo route;
  final VehicleType vehicle;

  const FindingDriver({
    required this.pickup,
    required this.destination,
    required this.route,
    required this.vehicle,
  });
}

class RideAccepted extends RideState {
  final Place pickup;
  final Place destination;
  final RouteInfo route;
  final String driverName;
  final String vehicleNumber;
  final int etaMinutes;

  const RideAccepted({
    required this.pickup,
    required this.destination,
    required this.route,
    required this.driverName,
    required this.vehicleNumber,
    required this.etaMinutes,
  });
}

class InTransit extends RideState {
  final Place pickup;
  final Place destination;
  final RouteInfo route;
  final String driverName;

  const InTransit({
    required this.pickup,
    required this.destination,
    required this.route,
    required this.driverName,
  });
}
