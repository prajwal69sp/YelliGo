import 'package:flutter/material.dart';
import '../models/ride_state.dart';

class VehicleSelector extends StatelessWidget {
  final VehicleType selected;
  final Map<VehicleType, double> fares;
  final ValueChanged<VehicleType> onSelect;

  const VehicleSelector({
    super.key,
    required this.selected,
    required this.fares,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: VehicleType.values.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(type),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    type == VehicleType.bike
                        ? Icons.two_wheeler
                        : Icons.electric_rickshaw,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type == VehicleType.bike ? 'Bike' : 'Auto',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${fares[type]?.toStringAsFixed(0) ?? '--'}',
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
