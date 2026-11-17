import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'beacon_parser.dart';

class BleService {
  final StreamController<String> _codes = StreamController<String>.broadcast();
  Stream<String> get codes => _codes.stream;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('This phone does not support Bluetooth Low Energy.');
    }

    final android = await DeviceInfoPlugin().androidInfo;
    if (android.version.sdkInt >= 31) {
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      if (!scan.isGranted || !connect.isGranted) {
        throw StateError('Nearby devices permission is required. Grant it in Android settings.');
      }
    } else {
      final location = await Permission.locationWhenInUse.request();
      if (!location.isGranted) {
        throw StateError('Location permission is required for BLE scanning on this Android version.');
      }
    }

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      throw StateError('Turn on Bluetooth, then tap Retry scanning.');
    }

    _scanSubscription ??= FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final code = BeaconParser.parse(result.advertisementData.manufacturerData);
        if (code != null && !_codes.isClosed) {
          _codes.add(code);
        }
      }
    });

    // Start once and keep scanning while the student Home screen is open.
    // continuousUpdates allows advertisements to be heard again for re-checks.
    await FlutterBluePlus.startScan(continuousUpdates: true);
    _started = true;
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await FlutterBluePlus.stopScan();
  }

  Future<void> dispose() async {
    await stop();
    await _scanSubscription?.cancel();
    await _codes.close();
  }
}
