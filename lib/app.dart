import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/backend.dart';

final authStateProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

/// The hackathon's Spark build defaults to the team leader's direct Firestore
/// contract. Set --dart-define=ATTENDANCE_BACKEND_MODE=callable to use the
/// original authenticated Cloud Functions backend on a compatible project.
const directFirestoreMode =
    String.fromEnvironment('ATTENDANCE_BACKEND_MODE', defaultValue: 'direct') == 'direct';

class AttendanceApp extends ConsumerWidget {
  const AttendanceApp({super.key, required this.demo});
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00866B)),
      scaffoldBackgroundColor: const Color(0xFFF6F8F8),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return MaterialApp(
      title: 'AttendGuard',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: demo
          ? StudentHomeScreen(backend: DemoAttendanceBackend(), demo: true)
          : directFirestoreMode
              ? StudentHomeScreen(
                  backend: DirectFirestoreAttendanceBackend(),
                  demo: false,
                  directMode: true,
                )
              : ref.watch(authStateProvider).when(
                  loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Scaffold(body: Center(child: Text('Authentication error: $e'))),
                  data: (user) => user == null
                      ? const LoginScreen()
                      : StudentHomeScreen(backend: FirebaseAttendanceBackend(), demo: false),
                ),
    );
  }
}
