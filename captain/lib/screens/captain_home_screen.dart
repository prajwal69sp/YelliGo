import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/captain_state.dart';
import '../providers/captain_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/earnings_card.dart';
import '../widgets/incoming_ride_sheet.dart';
import '../widgets/online_toggle_button.dart';

class CaptainHomeScreen extends ConsumerWidget {
  const CaptainHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(currentLocationProvider);
    final captainState = ref.watch(captainControllerProvider);
    final controller = ref.read(captainControllerProvider.notifier);

    return Scaffold(
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Location error: $err')),
        data: (currentLocation) {
          final activeRide = _extractRide(captainState);

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(initialCenter: currentLocation, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.yelligo.captain',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation,
                        width: 44,
                        height: 44,
                        child: const _CaptainVehicleMarker(),
                      ),
                      if (activeRide != null)
                        Marker(
                          point: captainState is OnTrip
                              ? activeRide.dropoff.latLng
                              : activeRide.pickup.latLng,
                          width: 36,
                          height: 36,
                          child: Icon(
                            captainState is OnTrip ? Icons.flag : Icons.person_pin_circle,
                            color: captainState is OnTrip ? Colors.red : Colors.blue,
                            size: 34,
                          ),
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
              if (captainState is Offline || captainState is OnlineSearching)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: OnlineToggleButton(
                          isOnline: captainState is OnlineSearching,
                          onToggle: () {
                            if (captainState is OnlineSearching) {
                              controller.goOffline();
                            } else {
                              controller.goOnline(currentLocation);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      EarningsCard(earnings: captainState.earnings),
                    ],
                  ),
                ),

              // Bottom sheet content per state
              Align(
                alignment: Alignment.bottomCenter,
                child: switch (captainState) {
                  Offline() || OnlineSearching() => const SizedBox.shrink(),
                  IncomingRequest s => IncomingRideSheet(
                      state: s,
                      onAccept: controller.acceptRide,
                      onDecline: controller.declineRide,
                    ),
                  EnRouteToPickup s => _EnRouteSheet(
                      ride: s.ride,
                      onArrived: controller.markArrivedAtPickup,
                    ),
                  ArrivedAtPickup s => _OtpEntrySheet(
                      state: s,
                      onSubmit: controller.verifyOtpAndStart,
                    ),
                  OnTrip s => _OnTripSheet(
                      ride: s.ride,
                      onComplete: controller.completeTrip,
                    ),
                  TripCompleted s => _TripCompletedSheet(
                      state: s,
                      onContinue: controller.confirmPaymentAndContinue,
                    ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  IncomingRide? _extractRide(CaptainState state) => switch (state) {
        EnRouteToPickup s => s.ride,
        ArrivedAtPickup s => s.ride,
        OnTrip s => s.ride,
        TripCompleted s => s.ride,
        _ => null,
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

class _CaptainVehicleMarker extends StatelessWidget {
  const _CaptainVehicleMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      child: const Icon(Icons.two_wheeler, color: Colors.white, size: 24),
    );
  }
}

class _EnRouteSheet extends StatelessWidget {
  final IncomingRide ride;
  final VoidCallback onArrived;

  const _EnRouteSheet({required this.ride, required this.onArrived});

  @override
  Widget build(BuildContext context) {
    return _sheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Heading to pickup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(ride.pickup.address, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          _fullWidthButton('Arrived at Pickup', onArrived),
        ],
      ),
    );
  }
}

class _OtpEntrySheet extends ConsumerStatefulWidget {
  final ArrivedAtPickup state;
  final ValueChanged<String> onSubmit;

  const _OtpEntrySheet({required this.state, required this.onSubmit});

  @override
  ConsumerState<_OtpEntrySheet> createState() => _OtpEntrySheetState();
}

class _OtpEntrySheetState extends ConsumerState<_OtpEntrySheet> {
  final _otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return _sheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter Rider OTP to Start Trip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              errorText: widget.state.otpError,
            ),
          ),
          const SizedBox(height: 12),
          _fullWidthButton('Start Trip', () => widget.onSubmit(_otpController.text)),
        ],
      ),
    );
  }
}

class _OnTripSheet extends StatelessWidget {
  final IncomingRide ride;
  final VoidCallback onComplete;

  const _OnTripSheet({required this.ride, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return _sheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Trip in Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Heading to ${ride.dropoff.address}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          _fullWidthButton('Complete Trip', onComplete),
        ],
      ),
    );
  }
}

class _TripCompletedSheet extends StatelessWidget {
  final TripCompleted state;
  final VoidCallback onContinue;

  const _TripCompletedSheet({required this.state, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return _sheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(height: 8),
          const Text('Trip Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 6),
          Text('Collect ₹${state.fareCollected.toStringAsFixed(0)} (Cash / UPI)',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          _fullWidthButton('Payment Collected', onContinue),
        ],
      ),
    );
  }
}

Widget _sheetContainer({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
    ),
    child: SafeArea(top: false, child: child),
  );
}

Widget _fullWidthButton(String label, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );
}
