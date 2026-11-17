import 'package:attendguard/screens/beacon_test_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline BLE tester identifies simulated readings', (tester) async {
    String? enteredCode;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BeaconTestPanel(
            detections: const [],
            status: 'Scanning for classroom beacons…',
            onSimulate: (code) => enteredCode = code,
          ),
        ),
      ),
    ));

    expect(find.text('No matching beacon detected yet'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '87654321');
    await tester.ensureVisible(find.text('Simulate received code'));
    await tester.tap(find.text('Simulate received code'));
    await tester.pump();
    expect(enteredCode, '87654321');
  });

  testWidgets('simulator rejects short codes', (tester) async {
    String? enteredCode;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BeaconTestPanel(
            detections: const [],
            status: 'Scanner ready',
            onSimulate: (code) => enteredCode = code,
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '123');
    await tester.ensureVisible(find.text('Simulate received code'));
    await tester.tap(find.text('Simulate received code'));
    await tester.pump();
    expect(enteredCode, isNull);
    expect(find.text('Enter exactly eight digits.'), findsOneWidget);
  });
}
