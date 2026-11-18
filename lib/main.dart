import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

// These MUST be Android app credentials issued for iteration-346ad.
// Do not use the team's provided Firebase WEB appId (contains ':web:') for Android.
// The existing GitHub Actions workflow supplies them via dart-defines.
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID',
    defaultValue: 'iteration-346ad');

void _showConfigurationError(String message) {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      )),
    ),
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (firebaseApiKey.isEmpty || firebaseAppId.isEmpty ||
      firebaseMessagingSenderId.isEmpty) {
    _showConfigurationError('Firebase Android configuration is missing. Register an Android app '
        'in Firebase project iteration-346ad and supply FIREBASE_API_KEY, '
        'FIREBASE_APP_ID and FIREBASE_SENDER_ID to the APK build.');
    return;
  }
  if (firebaseProjectId != 'iteration-346ad') {
    _showConfigurationError('Wrong Firebase project: $firebaseProjectId. '
        'The team leader dashboard uses iteration-346ad.');
    return;
  }
  if (!firebaseAppId.contains(':android:')) {
    _showConfigurationError('The Firebase App ID is not an Android App ID. '
        'Register the Android package in iteration-346ad. '
        'Do not paste the Firebase web appId into the Android build.');
    return;
  }

  try {
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: firebaseApiKey,
      appId: firebaseAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
    ));
  } catch (error) {
    _showConfigurationError('Firebase could not start. Check the Android Firebase App ID, '
        'API key, project ID and network connection.\n\n$error');
    return;
  }

  // This entrypoint never selects DemoAttendanceBackend.
  runApp(const ProviderScope(child: AttendanceApp(demo: false)));
}
