import 'dart:convert';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// The identifier is hashed and never shown as a raw Android ID.
/// Reinstalling or changing APK signing keys may require an admin reset.
class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'attendance_install_uuid_v1';

  static Future<String> getId() async {
    var installId = await _storage.read(key: _key);
    if (installId == null) {
      installId = const Uuid().v4();
      await _storage.write(key: _key, value: installId);
    }

    String? androidId;
    try {
      androidId = await const AndroidId().getId();
    } catch (_) {
      // The private installation UUID remains available as a fallback.
    }
    return sha256.convert(utf8.encode('$installId:${androidId ?? 'unknown'}')).toString();
  }
}
