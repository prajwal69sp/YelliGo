import 'package:flutter/material.dart';
import '../models/captain_state.dart';

class IncomingRideSheet extends StatelessWidget {
  final IncomingRequest state;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingRideSheet({
    super.key,
    required this.state,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final ride = state.ride;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Countdown bar - auto-declines when it hits zero (mirrors the
          // backend's dispatch timeout before trying the next driver ring).
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.secondsRemaining / 15,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                state.secondsRemaining <= 5 ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Ride Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${state.secondsRemaining}s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 14),
          _addressRow(Icons.my_location, Colors.blue, ride.pickup.address,
              '${ride.distanceToPickupKm.toStringAsFixed(1)} km away'),
          const SizedBox(height: 8),
          _addressRow(Icons.location_on, Colors.red, ride.dropoff.address,
              '${(ride.distanceMeters / 1000).toStringAsFixed(1)} km trip'),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimated fare', style: TextStyle(color: Colors.grey.shade600)),
              Text('₹${ride.fareEstimated.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String address, String meta) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(address, style: const TextStyle(fontWeight: FontWeight.w500))),
        Text(meta, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }
}
