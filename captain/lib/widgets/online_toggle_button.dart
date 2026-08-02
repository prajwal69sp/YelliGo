import 'package:flutter/material.dart';

class OnlineToggleButton extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;

  const OnlineToggleButton({super.key, required this.isOnline, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isOnline ? Colors.green : Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isOnline ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              isOnline ? "You're Online" : "Go Online",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
