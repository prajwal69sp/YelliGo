import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/ride_state.dart';
import '../providers/location_provider.dart';
import '../providers/ride_provider.dart';
import '../widgets/ride_bottom_sheet.dart';

class PassengerHomeScreen extends ConsumerWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(currentLocationProvider);
    final rideState = ref.watch(rideControllerProvider);

    return Scaffold(
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Location error: $err')),
        data: (currentLocation) {
          final route = _extractRoute(rideState);
          final destination = _extractDestination(rideState);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: currentLocation,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yelligo.app',
                  ),
                  if (route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route.geometry,
                          strokeWidth: 5,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation,
                        width: 40,
                        height: 40,
                        child: const _PulsingLocationDot(),
                      ),
                      if (destination != null)
                        Marker(
                          point: destination.latLng,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                        ),
                    ],
                  ),
                ],
              ),
              const Positioned(
                top: 16,
                left: 16,
                child: _AppLogoBadge(),
              ),
              if (rideState is! SelectingDestination)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 72,
                  left: 16,
                  right: 16,
                  child: _StatusBanner(rideState: rideState),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: RideBottomSheet(currentLocation: currentLocation),
              ),
            ],
          );
        },
      ),
    );
  }

  RouteInfo? _extractRoute(RideState state) => switch (state) {
        SelectingDestination s => s.route,
        FindingDriver f => f.route,
        RideAccepted a => a.route,
        InTransit t => t.route,
      };

  dynamic _extractDestination(RideState state) => switch (state) {
        SelectingDestination s => s.destination,
        FindingDriver f => f.destination,
        RideAccepted a => a.destination,
        InTransit t => t.destination,
      };
}

class _AppLogoBadge extends StatelessWidget {
  const _AppLogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Image.asset('assets/logo.png', width: 32, height: 32),
    );
  }
}

class _PulsingLocationDot extends StatelessWidget {
  const _PulsingLocationDot();

  @override
  Widget build(BuildContext context) {
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withOpacity(0.25),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final RideState rideState;

  const _StatusBanner({required this.rideState});

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (rideState) {
      FindingDriver() => ('Looking for a driver...', Colors.orange),
      RideAccepted() => ('Driver is on the way', Colors.green),
      InTransit() => ('Trip in progress', Colors.blue),
      SelectingDestination() => ('', Colors.transparent),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
