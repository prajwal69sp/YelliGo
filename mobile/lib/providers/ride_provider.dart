import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/place.dart';
import '../models/ride_state.dart';
import '../services/osrm_service.dart';

final osrmServiceProvider = Provider((ref) => OsrmService(useMock: true));

final rideControllerProvider =
    StateNotifierProvider<RideController, RideState>((ref) {
  return RideController(ref.read(osrmServiceProvider));
});

class RideController extends StateNotifier<RideState> {
  final OsrmService _osrm;

  RideController(this._osrm) : super(const SelectingDestination());

  void setPickup(Place place) {
    final current = state;
    if (current is! SelectingDestination) return;
    state = current.copyWith(pickup: place, clearRoute: true);
    _maybeFetchRoute();
  }

  void setDestination(Place place) {
    final current = state;
    if (current is! SelectingDestination) return;
    state = current.copyWith(destination: place, clearRoute: true);
    _maybeFetchRoute();
  }

  void selectVehicle(VehicleType vehicle) {
    final current = state;
    if (current is! SelectingDestination) return;
    state = current.copyWith(selectedVehicle: vehicle);
  }

  Future<void> _maybeFetchRoute() async {
    final current = state;
    if (current is! SelectingDestination) return;
    if (current.pickup == null || current.destination == null) return;

    state = current.copyWith(isLoadingRoute: true);
    try {
      final route = await _osrm.getRoute(
        current.pickup!.latLng,
        current.destination!.latLng,
      );
      final latest = state;
      if (latest is SelectingDestination) {
        state = latest.copyWith(route: route, isLoadingRoute: false);
      }
    } catch (_) {
      final latest = state;
      if (latest is SelectingDestination) {
        state = latest.copyWith(isLoadingRoute: false);
      }
    }
  }

  Future<void> confirmRide() async {
    final current = state;
    if (current is! SelectingDestination || !current.isReadyToConfirm) return;

    state = FindingDriver(
      pickup: current.pickup!,
      destination: current.destination!,
      route: current.route!,
      vehicle: current.selectedVehicle,
    );

    await Future.delayed(const Duration(seconds: 3));

    final findingState = state;
    if (findingState is! FindingDriver) return;

    state = RideAccepted(
      pickup: findingState.pickup,
      destination: findingState.destination,
      route: findingState.route,
      driverName: 'Suresh K.',
      vehicleNumber: 'KA-19-EF-4521',
      etaMinutes: 4,
    );

    await Future.delayed(const Duration(seconds: 4));
    final acceptedState = state;
    if (acceptedState is! RideAccepted) return;

    state = InTransit(
      pickup: acceptedState.pickup,
      destination: acceptedState.destination,
      route: acceptedState.route,
      driverName: acceptedState.driverName,
    );
  }

  void cancelAndReset() {
    state = const SelectingDestination();
  }
}
