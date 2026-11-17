import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../services/ble_service.dart';

/// Visible in the LOCAL DEMO APK only. Never expose raw codes in the live app.
class BeaconTestPanel extends StatefulWidget {
  const BeaconTestPanel({
    super.key,
    required this.detections,
    required this.status,
    required this.onSimulate,
  });

  final List<BeaconDetection> detections;
  final String status;
  final ValueChanged<String> onSimulate;

  @override
  State<BeaconTestPanel> createState() => _BeaconTestPanelState();
}

class _BeaconTestPanelState extends State<BeaconTestPanel> {
  final _testCode = TextEditingController(text: '12345678');
  String? _error;

  @override
  void dispose() {
    _testCode.dispose();
    super.dispose();
  }

  void _simulate() {
    final code = _testCode.text.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(code)) {
      setState(() => _error = 'Enter exactly eight digits.');
      return;
    }
    setState(() => _error = null);
    widget.onSimulate(code);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ESP32 BLE tester', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Offline hardware diagnostics. No Firebase login or internet needed.'),
      const SizedBox(height: 14),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('LIVE SCAN', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.status),
          const SizedBox(height: 8),
          const Text('Expected: manufacturer 0xFFFF, marker 0xA7, four big-endian code bytes.'),
          const SizedBox(height: 6),
          const Text('Detected codes are NOT proof of enrollment or attendance.',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
      )),
      const SizedBox(height: 14),
      if (widget.detections.isEmpty)
        const Card(child: ListTile(
          leading: Icon(Icons.radar),
          title: Text('No matching beacon detected yet'),
          subtitle: Text('Keep the app open near your ESP32. Check its advertised manufacturer bytes.'),
        ))
      else ...[
        Text('Detected codes (${widget.detections.length} unique)',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final hit in widget.detections) Card(child: ListTile(
          leading: Icon(hit.simulated ? Icons.science : Icons.bluetooth_searching,
              color: hit.simulated ? Colors.orange : const Color(0xFF00866B)),
          title: Text(hit.code, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()])),
          subtitle: Text('${hit.simulated ? 'SIMULATED — not a real broadcast' : hit.deviceName}\n'
              '${hit.rssi == null ? 'Signal: n/a' : 'Signal: ${hit.rssi} dBm'}  •  '
              '${_time(hit.seenAt)}'),
          isThreeLine: true,
          trailing: Icon(hit.simulated ? Icons.science_outlined : Icons.check_circle,
              color: hit.simulated ? Colors.orange : Colors.green),
        )),
      ],
      const SizedBox(height: 18),
      const Text('Local code simulator (TEST ONLY)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      const Text('Enter any 8-digit code to test the app interface. This does NOT change the ESP32 broadcast.'),
      const SizedBox(height: 10),
      TextField(
        controller: _testCode,
        maxLength: 8,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Simulated session code', errorText: _error),
      ),
      FilledButton.icon(onPressed: _simulate, icon: const Icon(Icons.science_outlined),
          label: const Text('Simulate received code')),
      const SizedBox(height: 12),
      const Text('In the real system, the lecturer dashboard sends a server-generated code to the ESP32 over USB.',
          style: TextStyle(color: Colors.black54, fontSize: 12)),
    ]);
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}
