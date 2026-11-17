import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ble_service.dart';

/// Hardware-only diagnostic tool: every code shown here came from a real
/// Android BLE scan. No simulator, Firebase, or attendance recording.
class HardwareTestScreen extends StatefulWidget {
  const HardwareTestScreen({super.key});

  @override
  State<HardwareTestScreen> createState() => _HardwareTestScreenState();
}

class _HardwareTestScreenState extends State<HardwareTestScreen>
    with WidgetsBindingObserver {
  final _ble = BleService();
  final Map<String, BeaconDetection> _hits = {};
  StreamSubscription<BeaconDetection>? _hitsSub;
  StreamSubscription<ScannerStatus>? _stateSub;
  String _status = 'Starting Bluetooth scan…';
  DateTime? _lastRepaint;
  int _totalPackets = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hitsSub = _ble.detections.listen((hit) {
      if (!mounted) return;
      _hits[hit.code] = hit;
      _totalPackets++;
      if (_hits.length > 30) {
        final oldest = _hits.entries.reduce((a, b) =>
            a.value.seenAt.isBefore(b.value.seenAt) ? a : b).key;
        _hits.remove(oldest);
      }
      final now = DateTime.now();
      if (_lastRepaint == null ||
          now.difference(_lastRepaint!) > const Duration(milliseconds: 500)) {
        _lastRepaint = now;
        setState(() {});
      }
    });
    _stateSub = _ble.statuses.listen((value) {
      if (mounted) setState(() => _status = value.message);
    });
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ble.start();
    } catch (e) {
      if (mounted) setState(() => _status = 'Scanner error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else if (state == AppLifecycleState.paused) {
      unawaited(_ble.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hitsSub?.cancel();
    _stateSub?.cancel();
    unawaited(_ble.dispose());
    super.dispose();
  }

  String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hits = _hits.values.toList()
      ..sort((a, b) => b.seenAt.compareTo(a.seenAt));
    return Scaffold(
      appBar: AppBar(
        title: const Text('AttendGuard • BLE Test'),
        backgroundColor: const Color(0xFFF6F8F8),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Card(
              child: ListTile(
                leading: Icon(Icons.verified_outlined, color: Color(0xFF00866B)),
                title: Text('REAL ESP32 HARDWARE SCAN'),
                subtitle: Text('Offline test: no Firebase, no simulated codes, no attendance records.'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Scanner status',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    const Text('Expected manufacturer ID 0xFFFF; byte 0 = A7; next 4 bytes = 8-digit code.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: Text(_busy ? 'Starting…' : 'Check Bluetooth / Retry Scan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Real broadcasts received: $_totalPackets',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (hits.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.radar),
                  title: Text('No AttendGuard beacon detected'),
                  subtitle: Text('Turn on the ESP32 and set a code using USB Serial. Keep this screen open and enable Nearby Devices permission.'),
                ),
              ),
            for (final hit in hits)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected, color: Color(0xFF00866B)),
                  title: Text(hit.code,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text('${hit.deviceName}\n'
                      'RSSI: ${hit.rssi == null ? 'unavailable' : '${hit.rssi} dBm'}  •  '
                      'Last seen: ${_clock(hit.seenAt)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.check_circle, color: Color(0xFF00866B)),
                ),
              ),
            const SizedBox(height: 16),
            const Text('This screen verifies reception of the exact ESP32 advertisement format. '
                'It does not prove that a code belongs to an active class. '
                'Only the Firebase-enabled student app can perform attendance.'),
          ],
        ),
      ),
    );
  }
}
