import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/captain_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: YelliGoCaptainApp()));
}

class YelliGoCaptainApp extends StatelessWidget {
  const YelliGoCaptainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YelliGo Captain',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const CaptainHomeScreen(),
    );
  }
}
