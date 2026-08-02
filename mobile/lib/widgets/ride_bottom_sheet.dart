import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/place.dart';
import '../models/ride_state.dart';
import '../providers/ride_provider.dart';
import 'vehicle_selector.dart';

class RideBottomSheet extends ConsumerStatefulWidget {
  final LatLng? currentLocation;

  const RideBottomSheet({super.key, required this.currentLocation});

  @override
  ConsumerState<RideBottomSheet> createState() => _RideBottomSheetState();
}

class _RideBottomSheetState extends ConsumerState<RideBottomSheet> {
  final _destinationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideControllerProvider);
    final controller = ref.read(rideControllerProvider.notifier);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: switch (rideState) {
          SelectingDestination s => _buildSelecting(s, controller),
          FindingDriver f => _buildFindingDriver(f, controller),
          RideAccepted a => _buildRideAccepted(a, controller),
          InTransit t => _buildInTransit(t),
        },
      ),
    );
  }

  Widget _buildSelecting(SelectingDestination s, RideController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        _AddressField(
          icon: Icons.my_location,
          iconColor: Colors.blue,
          hint: 'Pickup location',
          value: s.pickup?.address,
          onTap: () {
            if (widget.currentLocation != null) {
              controller.setPickup(Place(
                latLng: widget.currentLocation!,
                address: 'Current location',
              ));
            }
          },
        ),
        const SizedBox(height: 8),
        _AddressField(
          icon: Icons.location_on,
          iconColor: Colors.red,
          hint: 'Where to?',
          value: s.destination?.address,
          controller: _destinationController,
          onSubmitted: (query) async {
            if (widget.currentLocation == null) return;
            final osrm = ref.read(osrmServiceProvider);
            final place = await osrm.mockGeocode(query, widget.currentLocation!);
            controller.setDestination(place);
          },
        ),
        if (s.isLoadingRoute) ...[
          const SizedBox(height: 16),
          const CircularProgressIndicator(strokeWidth: 2),
        ],
        if (s.route != null) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(s.route!.distanceMeters / 1000).toStringAsFixed(1)} km · '
                '${(s.route!.durationSeconds / 60).round()} min',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                '₹${s.route!.fareByVehicle[s.selectedVehicle]?.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          VehicleSelector(
            selected: s.selectedVehicle,
            fares: s.route!.fareByVehicle,
            onSelect: controller.selectVehicle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: s.isReadyToConfirm ? controller.confirmRide : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Confirm Ride',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFindingDriver(FindingDriver f, RideController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Finding a nearby driver...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('${f.vehicle == VehicleType.bike ? "Bike" : "Auto"} · ₹${f.route.fareByVehicle[f.vehicle]?.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        TextButton(onPressed: controller.cancelAndReset, child: const Text('Cancel')),
      ],
    );
  }

  Widget _buildRideAccepted(RideAccepted a, RideController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 26, child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(a.vehicleNumber, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${a.etaMinutes} min', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('away', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Driver is on the way to your pickup point', style: TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _buildInTransit(InTransit t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.two_wheeler, size: 32),
        const SizedBox(height: 8),
        Text('En route with ${t.driverName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Heading to ${t.destination.address}', style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }
}

class _AddressField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String hint;
  final String? value;
  final TextEditingController? controller;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;

  const _AddressField({
    required this.icon,
    required this.iconColor,
    required this.hint,
    this.value,
    this.controller,
    this.onTap,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: onTap != null
                ? GestureDetector(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        value ?? hint,
                        style: TextStyle(color: value == null ? Colors.grey.shade500 : Colors.black87),
                      ),
                    ),
                  )
                : TextField(
                    controller: controller,
                    decoration: InputDecoration(hintText: hint, border: InputBorder.none),
                    onSubmitted: onSubmitted,
                  ),
          ),
        ],
      ),
    );
  }
}
