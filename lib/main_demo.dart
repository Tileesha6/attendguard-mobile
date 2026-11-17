import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

// Build this entrypoint FIRST: no Firebase project or ESP32 required.
// This is only a local interface demonstration; never claim it recorded attendance.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AttendanceApp(demo: true)));
}
