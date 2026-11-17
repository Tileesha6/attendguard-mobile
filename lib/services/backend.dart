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
  Future<SessionLookup?> lookupSession(String code);
  Future<String> markPresent({
    required String sessionId,
    required String code,
    required String deviceId,
  });
  Stream<List<RecheckRound>> watchRounds(String sessionId);
  Future<void> confirmRecheck({
    required String sessionId,
    required String roundId,
    required String code,
    required String deviceId,
  });
}

class FirebaseAttendanceBackend implements AttendanceBackend {
  FirebaseAttendanceBackend({FirebaseFunctions? functions, FirebaseFirestore? db})
      : _functions = functions ?? FirebaseFunctions.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  Map<String, dynamic> _map(dynamic data) => Map<String, dynamic>.from(data as Map);

  @override
  Future<SessionLookup?> lookupSession(String code) async {
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

/// LOCAL UI preview only. It never writes actual attendance.
class DemoAttendanceBackend implements AttendanceBackend {
  @override
  Future<SessionLookup?> lookupSession(String code) async => const SessionLookup(
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
