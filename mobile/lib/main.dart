import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/passenger_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: YelliGoApp()));
}

class YelliGoApp extends StatelessWidget {
  const YelliGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YelliGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.black),
      home: const PassengerHomeScreen(),
    );
  }
}
