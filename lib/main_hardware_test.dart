import 'package:flutter/material.dart';

import 'screens/hardware_test_screen.dart';

/// Genuine offline ESP32 scanner. This entrypoint never generates test codes,
/// accepts simulated attendance, or initializes Firebase.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'AttendGuard ESP32 Diagnostics',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00866B)),
      scaffoldBackgroundColor: const Color(0xFFF6F8F8),
    ),
    home: const HardwareTestScreen(),
  ));
}
