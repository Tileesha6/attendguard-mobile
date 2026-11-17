import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'beacon_parser.dart';

/// A *received advertisement*, not a BLE connection. Debug information is
/// displayed only in the offline test build; live student UI hides the code.
class BeaconDetection {
  const BeaconDetection({
    required this.code,
    required this.seenAt,
    required this.deviceName,
    required this.simulated,
    this.rssi,
  });

  final String code;
  final DateTime seenAt;
  final String deviceName;
  final int? rssi;
  final bool simulated;
}

enum ScannerState { starting, scanning, bluetoothOff, permissionDenied, unsupported, stopped, error }

class ScannerStatus {
  const ScannerStatus(this.state, this.message);
  final ScannerState state;
  final String message;
}

class BleService {
  final _detections = StreamController<BeaconDetection>.broadcast();
  final _status = StreamController<ScannerStatus>.broadcast();

  Stream<BeaconDetection> get detections => _detections.stream;
  Stream<ScannerStatus> get statuses => _status.stream;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  Future<void>? _starting;
  Future<void>? _scanStarting;
  bool _permissionsGranted = false;
  bool _shouldScan = false;
  bool _started = false;
  bool _disposed = false;

  void _emit(ScannerState state, String message) {
    if (!_status.isClosed) _status.add(ScannerStatus(state, message));
  }

  /// Starts one continuous foreground scan. If Bluetooth is off, Android's
  /// system permission dialog requests that the user enable it. The app does
  /// not silently change the Bluetooth state.
  Future<void> start() {
    if (_disposed) return Future.error(StateError('Scanner has been disposed.'));
    _shouldScan = true;
    if (_started) return Future.value();
    return _starting ??= _startInternal().whenComplete(() => _starting = null);
  }

  Future<void> _startInternal() async {
    _emit(ScannerState.starting, 'Preparing Bluetooth scanner…');
    if (!await FlutterBluePlus.isSupported) {
      _emit(ScannerState.unsupported, 'This phone does not support Bluetooth Low Energy.');
      return;
    }

    if (!_permissionsGranted) {
      final android = await DeviceInfoPlugin().androidInfo;
      if (android.version.sdkInt >= 31) {
        final scan = await Permission.bluetoothScan.request();
        final connect = await Permission.bluetoothConnect.request();
        _permissionsGranted = scan.isGranted && connect.isGranted;
      } else {
        final location = await Permission.locationWhenInUse.request();
        _permissionsGranted = location.isGranted;
      }
      if (!_permissionsGranted) {
        _emit(ScannerState.permissionDenied, 'Bluetooth permission denied. Allow Nearby devices in Android settings, then retry.');
        return;
      }
    }

    _scanSubscription ??= FlutterBluePlus.onScanResults.listen((results) {
      if (!_shouldScan || _disposed) return;
      for (final result in results) {
        final code = BeaconParser.parse(result.advertisementData.manufacturerData);
        if (code == null || _detections.isClosed) continue;
        _detections.add(BeaconDetection(
          code: code,
          seenAt: DateTime.now(),
          deviceName: result.advertisementData.advName.isEmpty
              ? 'Unnamed BLE beacon' : result.advertisementData.advName,
          rssi: result.rssi,
          simulated: false,
        ));
      }
    }, onError: (Object e) => _emit(ScannerState.error, 'BLE scan error: $e'));

    _adapterSubscription ??= FlutterBluePlus.adapterState.listen((state) {
      if (_disposed || !_shouldScan) return;
      if (state == BluetoothAdapterState.on) {
        unawaited(_startScanIfNeeded());
      } else if (state == BluetoothAdapterState.off) {
        _started = false;
        _emit(ScannerState.bluetoothOff, 'Bluetooth is off. Enable it to resume scanning.');
      }
    });

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _emit(ScannerState.bluetoothOff, 'Waiting for Android Bluetooth enable confirmation…');
      try {
        await FlutterBluePlus.turnOn(); // Android system enable dialog.
        await FlutterBluePlus.adapterState
            .where((s) => s == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        _emit(ScannerState.bluetoothOff,
            'Bluetooth is off or the request was declined. Turn Bluetooth on, then retry.');
        return;
      }
    }
    await _startScanIfNeeded();
  }

  Future<void> _startScanIfNeeded() {
    if (_disposed || !_shouldScan || _started ||
        FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      return Future.value();
    }
    return _scanStarting ??= _beginScan().whenComplete(() => _scanStarting = null);
  }

  Future<void> _beginScan() async {
    try {
      // Keep a SINGLE continuous scan; restarting rapidly is throttled by Android.
      await FlutterBluePlus.startScan(continuousUpdates: true);
      _started = true;
      _emit(ScannerState.scanning, 'Scanning for ESP32 attendance beacons…');
    } catch (e) {
      _emit(ScannerState.error, 'Unable to start BLE scan: $e');
    }
  }

  /// Called when the student app goes to the background. No background
  /// attendance tracking is promised by this hackathon build.
  Future<void> stop() async {
    _shouldScan = false;
    if (_started) {
      _started = false;
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Bluetooth may have switched off while stopping.
      }
    }
    _emit(ScannerState.stopped, 'Scanning paused.');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _adapterSubscription?.cancel();
    await _scanSubscription?.cancel();
    await _detections.close();
    await _status.close();
  }
}
