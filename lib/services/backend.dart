import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SessionLookup {
  const SessionLookup({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.hallName,
    required this.alreadyMarked,
  });

  final String sessionId;
  final String courseCode;
  final String courseName;
  final String hallName;
  final bool alreadyMarked;
}

class RecheckRound {
  const RecheckRound({
    required this.id,
    required this.openedAt,
    required this.closesAt,
  });

  final String id;
  final DateTime openedAt;
  final DateTime closesAt;
}

abstract class AttendanceBackend {
  Future<SessionLookup?> lookupSession(String code, {String? deviceId});
  Future<String> markPresent({
    required String sessionId,
    required String code,
    required String deviceId,
    String studentName = '',
    String studentId = '',
  });
  Stream<List<RecheckRound>> watchRounds(String sessionId);
  Future<void> confirmRecheck({
    required String sessionId,
    required String roundId,
    required String code,
    required String deviceId,
  });
}

/// Original authenticated callable backend, retained for a future Blaze setup.
/// This is NOT selected by the default Spark build.
class FirebaseAttendanceBackend implements AttendanceBackend {
  FirebaseAttendanceBackend({FirebaseFunctions? functions, FirebaseFirestore? db})
      : _functions = functions ?? FirebaseFunctions.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  Map<String, dynamic> _map(dynamic data) => Map<String, dynamic>.from(data as Map);

  @override
  Future<SessionLookup?> lookupSession(String code, {String? deviceId}) async {
    final result = await _functions.httpsCallable('lookupSession').call({'code': code});
    final data = _map(result.data);
    if (data['found'] != true) return null;
    return SessionLookup(
      sessionId: data['sessionId'] as String,
      courseCode: data['courseCode'] as String,
      courseName: data['courseName'] as String,
      hallName: data['hallName'] as String,
      alreadyMarked: data['alreadyMarked'] == true,
    );
  }

  @override
  Future<String> markPresent({
    required String sessionId,
    required String code,
    required String deviceId,
    String studentName = '',
    String studentId = '',
  }) async {
    final result = await _functions.httpsCallable('markPresent').call({
      'sessionId': sessionId,
      'code': code,
      'deviceId': deviceId,
    });
    return (_map(result.data)['status'] ?? 'present').toString();
  }

  @override
  Stream<List<RecheckRound>> watchRounds(String sessionId) {
    return _db.collection('sessions').doc(sessionId).collection('rounds').snapshots().map((snap) {
      final rounds = <RecheckRound>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['finalized'] == true) continue;
        final opened = data['openedAt'];
        final closes = data['closesAt'];
        if (opened is! Timestamp || closes is! Timestamp) continue;
        rounds.add(RecheckRound(id: doc.id, openedAt: opened.toDate(), closesAt: closes.toDate()));
      }
      rounds.sort((a, b) => a.openedAt.compareTo(b.openedAt));
      return rounds;
    });
  }

  @override
  Future<void> confirmRecheck({
    required String sessionId,
    required String roundId,
    required String code,
    required String deviceId,
  }) async {
    await _functions.httpsCallable('confirmRecheck').call({
      'sessionId': sessionId,
      'roundId': roundId,
      'code': code,
      'deviceId': deviceId,
    });
  }
}

/// Compatible with the team leader's `iteration-346ad` Spark schema.
/// This is a convenience check-in, NOT cryptographic proof of presence/identity.
/// Firestore rules MUST enforce all data validation and authorization.
class DirectFirestoreAttendanceBackend implements AttendanceBackend {
  DirectFirestoreAttendanceBackend({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static bool _validCode(String code) =>
      RegExp(r'^\d{8}$').hasMatch(code) && code != '00000000';

  static bool _validDeviceId(String id) => id.isNotEmpty &&
      id != '.' && id != '..' && !id.contains('/') && id.length <= 256;

  DocumentReference<Map<String, dynamic>> _sessionRef(String code) =>
      _db.collection('sessions').doc(code);

  @override
  Future<SessionLookup?> lookupSession(String code, {String? deviceId}) async {
    if (!_validCode(code)) return null;
    // Never query/list sessions: the team leader's Firestore rules deny list.
    final snap = await _sessionRef(code).get(const GetOptions(source: Source.server));
    final data = snap.data();
    if (!snap.exists || data == null || data['status'] != 'live') return null;

    var alreadyMarked = false;
    if (deviceId != null && _validDeviceId(deviceId)) {
      final existing = await _sessionRef(code)
          .collection('attendance')
          .doc(deviceId)
          .get(const GetOptions(source: Source.server));
      alreadyMarked = existing.exists;
    }
    // The handoff's minimal session document does not include course/hall.
    // Use metadata if the dashboard provides it; otherwise be truthful.
    final courseCode = (data['courseCode'] as String?)?.trim();
    final courseName = (data['courseName'] as String?)?.trim();
    final hallName = (data['hallName'] as String?)?.trim();
    return SessionLookup(
      sessionId: code,
      courseCode: (courseCode?.isNotEmpty ?? false) ? courseCode! : 'LIVE SESSION',
      courseName: (courseName?.isNotEmpty ?? false) ? courseName! : 'Attendance session',
      hallName: (hallName?.isNotEmpty ?? false) ? hallName! : 'Room not specified',
      alreadyMarked: alreadyMarked,
    );
  }

  @override
  Future<String> markPresent({
    required String sessionId,
    required String code,
    required String deviceId,
    String studentName = '',
    String studentId = '',
  }) async {
    final name = studentName.trim();
    if (!_validCode(code) || sessionId != code) {
      throw ArgumentError('Invalid session code.');
    }
    if (!_validDeviceId(deviceId)) {
      throw ArgumentError('Device identifier is missing or invalid.');
    }
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Enter a valid student name (1–100 characters).');
    }
    if (studentId.length > 60) {
      throw ArgumentError('Student ID is too long.');
    }

    final session = _sessionRef(code);
    final live = await session.get(const GetOptions(source: Source.server));
    if (!live.exists || live.data()?['status'] != 'live') {
      throw StateError('Attendance is not currently open.');
    }

    final record = session.collection('attendance').doc(deviceId);
    // A transaction prevents accidental duplicate writes from the stock client.
    // It DOES NOT prevent modified clients from submitting another deviceId;
    // only stronger identity/device attestation can meaningfully mitigate that.
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(record);
      if (existing.exists) {
        throw StateError('This phone has already been used for this session.');
      }
      transaction.set(record, {
        'code': code,
        'studentName': name,
        'studentId': studentId.trim(),
        'deviceId': deviceId,
        'status': 'present',
        'checkedInAt': FieldValue.serverTimestamp(),
      });
    });
    return 'present';
  }

  // The team's new Spark handoff has no rounds subcollection or re-check APIs.
  @override
  Stream<List<RecheckRound>> watchRounds(String sessionId) =>
      Stream.value(const <RecheckRound>[]);

  @override
  Future<void> confirmRecheck({
    required String sessionId,
    required String roundId,
    required String code,
    required String deviceId,
  }) => Future.error(UnsupportedError('Re-check is unavailable in Spark direct mode.'));
}

/// LOCAL UI preview only. Never writes attendance to Firestore.
class DemoAttendanceBackend implements AttendanceBackend {
  @override
  Future<SessionLookup?> lookupSession(String code, {String? deviceId}) async =>
      const SessionLookup(
        sessionId: 'local-demo-session',
        courseCode: 'CS101',
        courseName: 'Introduction to Computing',
        hallName: 'Demo Hall',
        alreadyMarked: false,
      );

  @override
  Future<String> markPresent({
    required String sessionId,
    required String code,
    required String deviceId,
    String studentName = '',
    String studentId = '',
  }) async => 'present';

  @override
  Stream<List<RecheckRound>> watchRounds(String sessionId) => const Stream.empty();

  @override
  Future<void> confirmRecheck({
    required String sessionId,
    required String roundId,
    required String code,
    required String deviceId,
  }) async {}
}
