import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

// Firebase project identifiers are supplied to the build through dart-defines.
// They are deliberately NOT committed into this public repository.
// Firebase Android API keys are *client identifiers*, not server secrets.
// Security comes from Auth, Firestore Rules, Cloud Functions, and App Check.
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (firebaseApiKey.isEmpty || firebaseAppId.isEmpty ||
      firebaseMessagingSenderId.isEmpty || firebaseProjectId.isEmpty) {
    runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Live attendance is not configured. Ask the team to add the '
              'Firebase project settings to GitHub Actions secrets and rebuild.\n\n'
              'For offline UI testing, install the demo APK instead.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
    return;
  }

  await Firebase.initializeApp(options: const FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
  ));
  runApp(const ProviderScope(child: AttendanceApp(demo: false)));
}
