import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

import 'beacon_test_panel.dart';
import '../services/backend.dart';
import '../services/ble_service.dart';
import '../services/device_id_service.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key, required this.backend, required this.demo, this.directMode = false});
  final AttendanceBackend backend;
  final bool demo;
  final bool directMode;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> with WidgetsBindingObserver {
  final BleService _ble = BleService();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _profileStorage = const FlutterSecureStorage();
  StreamSubscription<BeaconDetection>? _beaconSub;
  StreamSubscription<ScannerStatus>? _scannerStatusSub;
  final Map<String, BeaconDetection> _recentDetections = {};
  final Map<String, DateTime> _heardCodes = {};
  DateTime? _lastDiagnosticsRefresh;
  DateTime? _lastLookupStartedAt;
  StreamSubscription<List<RecheckRound>>? _roundSub;
  Timer? _clock;

  final Map<String, DateTime> _lastLookups = {};
  final Set<String> _passedRounds = {};
  String? _deviceId;
  String? _currentCode;
  DateTime? _lastHeardAt;
  SessionLookup? _session;
  RecheckRound? _round;
  String? _scanError;
  String _scanStatus = 'Starting Bluetooth scanner…';
  String? _message;
  int _tab = 0;
  bool _marked = false;
  bool _flagged = false;
  bool _markBusy = false;
  bool _lookupBusy = false;
  bool _recheckBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _beaconSub = _ble.detections.listen(_onBeaconDetection);
    _scannerStatusSub = _ble.statuses.listen((status) {
      if (!mounted) return;
      setState(() {
        _scanStatus = status.message;
        _scanError = switch (status.state) {
          ScannerState.error || ScannerState.bluetoothOff ||
          ScannerState.permissionDenied || ScannerState.unsupported => status.message,
          _ => null,
        };
      });
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_startScanner());
    } else if (state == AppLifecycleState.paused) {
      unawaited(_ble.stop());
    }
  }

  Future<void> _boot() async {
    if (widget.directMode) {
      try {
        final name = await _profileStorage.read(key: 'spark_student_name');
        final studentId = await _profileStorage.read(key: 'spark_student_id');
        if (!mounted) return;
        _nameController.text = name ?? '';
        _studentIdController.text = studentId ?? '';
      } catch (_) {
        // Storage is optional; input fields still work if storage is unavailable.
      }
    }
    try {
      final id = await DeviceIdService.getId();
      if (!mounted) return;
      setState(() => _deviceId = id);
    } catch (e) {
      if (mounted) setState(() => _message = 'Device ID error: $e');
    }
    await _startScanner();
  }

  Future<void> _startScanner() async {
    if (mounted) {
      setState(() {
        _scanError = null;
        _scanStatus = 'Scanning for classroom beacons…';
      });
    }
    try {
      await _ble.start();
    } catch (e) {
      if (mounted) setState(() {
        _scanError = e.toString();
        _scanStatus = 'Scanner unavailable';
      });
    }
  }

  void _onBeaconDetection(BeaconDetection detection) {
    if (!mounted) return;
    final code = detection.code;
    final now = detection.seenAt;
    _heardCodes[code] = now;
    _recentDetections[code] = detection;
    // Bound memory in a noisy classroom; the BLE marker is not authenticated.
    if (_recentDetections.length > 40) {
      final oldest = _recentDetections.entries.reduce((a, b) =>
        a.value.seenAt.isBefore(b.value.seenAt) ? a : b).key;
      _recentDetections.remove(oldest);
    }
    _heardCodes.removeWhere((_, seen) => now.difference(seen) > const Duration(minutes: 5));
    _lastLookups.removeWhere((_, seen) => now.difference(seen) > const Duration(minutes: 5));
    // Show recent live advertisements without rebuilding the UI every 100ms.
    if (widget.demo &&
        (_lastDiagnosticsRefresh == null ||
            now.difference(_lastDiagnosticsRefresh!) > const Duration(milliseconds: 500))) {
      _lastDiagnosticsRefresh = now;
      setState(() {});
    }

    if (_currentCode == code) _lastHeardAt = now;

    // The backend also validates the code and round. Never accept an arbitrary
    // nearby beacon as proof of a successful local-demo re-check.
    final r = _round;
    if (r != null && _marked && !_recheckBusy && !_passedRounds.contains(r.id) &&
        !now.isBefore(r.openedAt) && now.isBefore(r.closesAt) &&
        (!widget.demo || code == _currentCode)) {
      _confirmRecheck(r, code);
    }

    if (_marked || _lookupBusy) return;
    // Rate-limit across ALL codes, not only repeat codes, to avoid hammering
    // Firebase when many untrusted beacons are nearby.
    if (_lastLookupStartedAt != null &&
        now.difference(_lastLookupStartedAt!) < const Duration(seconds: 1)) return;
    final last = _lastLookups[code];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) return;
    _lastLookups[code] = now;
    _lastLookupStartedAt = now;
    _lookup(code);
  }

  Future<void> _lookup(String code) async {
    _lookupBusy = true;
    try {
      final result = await widget.backend.lookupSession(code, deviceId: _deviceId);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _session = result;
          _currentCode = code;
          // The first valid advertisement counts; do not require a second hit.
          _lastHeardAt = _heardCodes[code];
          _marked = result.alreadyMarked;
          _flagged = false;
          _message = result.alreadyMarked
              ? (widget.directMode ? 'This phone has already been used for this session.' : 'You have already checked in.')
              : null;
          _scanStatus = 'Classroom beacon detected';
        });
        if (result.alreadyMarked) _listenForRounds(result.sessionId);
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Unable to look up class: $e');
    } finally {
      _lookupBusy = false;
    }
  }

  Future<void> _mark() async {
    if (widget.directMode && _nameController.text.trim().isEmpty) {
      setState(() => _message = 'Enter your student name first.');
      return;
    }
    if (_session == null || _currentCode == null || _deviceId == null || _markBusy) return;
    if (_lastHeardAt == null || DateTime.now().difference(_lastHeardAt!) > const Duration(seconds: 15)) {
      setState(() => _message = 'Beacon signal is outdated. Move closer to the classroom device.');
      return;
    }
    setState(() { _markBusy = true; _message = null; });
    try {
      final status = await widget.backend.markPresent(
        sessionId: _session!.sessionId,
        code: _currentCode!,
        deviceId: _deviceId!,
        studentName: _nameController.text.trim(),
        studentId: _studentIdController.text.trim(),
      );
      if (widget.directMode && status == 'present') {
        try {
          await _profileStorage.write(key: 'spark_student_name', value: _nameController.text.trim());
          await _profileStorage.write(key: 'spark_student_id', value: _studentIdController.text.trim());
        } catch (_) {
          // Check-in has already been committed; local profile storage is optional.
        }
      }
      if (!mounted) return;
      setState(() {
        _flagged = status == 'flagged';
        _marked = status == 'present';
        _message = widget.demo
            ? 'LOCAL DEMO ONLY — no attendance was sent to a server.'
            : status == 'present'
                ? 'Attendance recorded successfully.'
                : 'Server returned: $status. Ask your lecturer to review this record.';
      });
      if (_marked) _listenForRounds(_session!.sessionId);
    } catch (e) {
      if (mounted) setState(() => _message = 'Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _markBusy = false);
    }
  }

  void _listenForRounds(String sessionId) {
    if (widget.directMode) return; // New Spark contract has no re-check rounds.
    _roundSub?.cancel();
    _roundSub = widget.backend.watchRounds(sessionId).listen((rounds) {
      if (!mounted) return;
      final now = DateTime.now();
      RecheckRound? open;
      for (final round in rounds) {
        if (_passedRounds.contains(round.id)) continue;
        if (!now.isBefore(round.openedAt) && now.isBefore(round.closesAt)) {
          open = round;
          break;
        }
      }
      setState(() => _round = open);
    }, onError: (Object e) {
      if (mounted) setState(() => _message = 'Re-check listener error: $e');
    });
  }

  Future<void> _confirmRecheck(RecheckRound round, String code) async {
    if (_deviceId == null || _session == null || _recheckBusy) return;
    _recheckBusy = true;
    try {
      await widget.backend.confirmRecheck(
        sessionId: _session!.sessionId,
        roundId: round.id,
        code: code,
        deviceId: _deviceId!,
      );
      if (!mounted) return;
      setState(() {
        _passedRounds.add(round.id);
        _round = null;
        _message = widget.demo ? 'Local re-check simulation passed.' : 'Re-check confirmed successfully.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Re-check error: $e');
    } finally {
      _recheckBusy = false;
    }
  }

  void _simulateBeacon([String code = '12345678']) {
    // Demo APK ONLY: clearly tagged fake reading; never sent to Firebase.
    if (!widget.demo) return;
    _onBeaconDetection(BeaconDetection(
      code: code,
      seenAt: DateTime.now(),
      deviceName: 'LOCAL SIMULATOR',
      simulated: true,
    ));
  }

  void _simulateRound() {
    if (!widget.demo || !_marked) return;
    final now = DateTime.now();
    setState(() => _round = RecheckRound(
      id: 'local-${now.millisecondsSinceEpoch}',
      openedAt: now,
      closesAt: now.add(const Duration(seconds: 60)),
    ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beaconSub?.cancel();
    _scannerStatusSub?.cancel();
    _roundSub?.cancel();
    _clock?.cancel();
    _nameController.dispose();
    _studentIdController.dispose();
    unawaited(_ble.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final activeRound = _round != null && now.isBefore(_round!.closesAt) &&
        !_passedRounds.contains(_round!.id);
    final secondsLeft = activeRound ? _round!.closesAt.difference(now).inSeconds.clamp(0, 60) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AttendGuard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF6F8F8),
        actions: [
          if (!widget.demo && !widget.directMode)
            IconButton(tooltip: 'Sign out', onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.demo) _notice('LOCAL TEST MODE — no Firebase attendance is recorded.', Colors.orange.shade900),
                if (_tab == 0) _buildHome(context),
                if (widget.demo && _tab == 1) BeaconTestPanel(
                  detections: (_recentDetections.values.toList()
                    ..sort((a, b) => b.seenAt.compareTo(a.seenAt)))
                    .take(15).toList(),
                  status: _scanStatus,
                  onSimulate: _simulateBeacon,
                ),
                if (_tab == (widget.demo ? 2 : 1)) _buildHistory(context),
                if (_tab == (widget.demo ? 3 : 2)) _buildSettings(context),
              ]),
            ),
          ),
          if (activeRound) Positioned.fill(
            child: Container(
              color: Colors.black87,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.radar, size: 82, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text('Confirm you are still here',
                      style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text('Keep Bluetooth on. Your phone must hear the classroom beacon again.',
                      style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 25),
                    Text('${secondsLeft}s', style: const TextStyle(color: Colors.greenAccent,
                      fontSize: 65, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(color: Colors.greenAccent),
                    if (widget.demo) ...[
                      const SizedBox(height: 25),
                      FilledButton(onPressed: () => _simulateBeacon(), child: const Text('Simulate beacon (local only)')),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          if (widget.demo) const NavigationDestination(icon: Icon(Icons.bluetooth_searching), label: 'BLE Test'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'Attendance'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Good to see you', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Find your lecture and verify your attendance.'),
      const SizedBox(height: 24),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_scanError == null ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
              color: _scanError == null ? const Color(0xFF00866B) : Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(_scanStatus, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          if (_scanError != null) ...[
            const SizedBox(height: 12),
            Text(_scanError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _startScanner,
              icon: const Icon(Icons.refresh), label: const Text('Retry Bluetooth scan')),
          ] else ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (widget.demo) ...[
            const SizedBox(height: 15),
            OutlinedButton.icon(onPressed: () => _simulateBeacon(),
              icon: const Icon(Icons.science_outlined), label: const Text('Simulate beacon (test only)')),
          ],
        ],
      ))),
      const SizedBox(height: 18),
      if (widget.directMode) ...[
        Text('Student details', style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Student name *',
            hintText: 'Enter your full name',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _studentIdController,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Student ID (optional)',
            hintText: 'e.g. IT260001',
          ),
        ),
        const SizedBox(height: 8),
        const Text('Spark demonstration mode: attendance uses an editable name and '
            'install-specific device ID. It does not guarantee identity or physical presence.',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 14),
      ],
      if (_session == null)
        Card(child: Padding(padding: const EdgeInsets.all(25), child: Column(children: [
          const Icon(Icons.radar_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('No class detected yet', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          const Text('Keep the app open near the ESP32 attendance beacon.', textAlign: TextAlign.center),
        ])))
      else
        Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _smallTag(_marked ? 'CHECKED IN' : _flagged ? 'REVIEW REQUIRED' : 'CLASS FOUND'),
            const SizedBox(height: 14),
            Text(_session!.courseCode, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold, color: const Color(0xFF00866B))),
            Text(_session!.courseName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 5), Text(_session!.hallName)]),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _marked || _flagged || _markBusy ? null : _mark,
              icon: Icon(_marked ? Icons.check_circle_outline : Icons.how_to_reg),
              label: Text(_marked ? 'Marked present' : _flagged ? 'Flagged for review' :
                _markBusy ? 'Verifying…' : 'Mark me present'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            if (widget.demo && _marked) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _simulateRound, child: const Text('Test 60s re-check prompt')),
            ],
          ],
        ))),
      if (_message != null) ...[
        const SizedBox(height: 16),
        _notice(_message!, _flagged ? Colors.orange.shade900 : const Color(0xFF176F55)),
      ],
    ]);
  }

  Widget _buildHistory(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('My attendance', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      _notice('The handoff specifies per-course percentages and past sessions. '
          'This screen is reserved for the reporting phase and is not connected yet.', Colors.blueGrey),
      const SizedBox(height: 16),
      const Card(child: ListTile(
        leading: Icon(Icons.fact_check_outlined),
        title: Text('Current session'),
        subtitle: Text('Your checked-in state is shown on the Home screen.'),
      )),
    ],
  );

  Widget _buildSettings(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.phone_android), title: const Text('Device identification'),
          subtitle: Text(_deviceId == null ? 'Initializing…' : 'Secure installation identifier ready')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.bluetooth), title: const Text('Bluetooth scanning'),
          subtitle: Text(_scanStatus)),
        const Divider(height: 1),
        const ListTile(leading: Icon(Icons.security), title: Text('Privacy'),
          subtitle: Text('Live student screens hide the code. Firebase must validate attendance.')),
        const Divider(height: 1),
        const ListTile(leading: Icon(Icons.admin_panel_settings_outlined),
          title: Text('Beacon administration'),
          subtitle: Text('Codes are generated by the server and sent by the lecturer dashboard over USB. Phone-based code changes are not supported.')),
      ])),
      const SizedBox(height: 12),
      if (!widget.demo && !widget.directMode)
        OutlinedButton.icon(onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout), label: const Text('Sign out')),
    ],
  );

  Widget _smallTag(String value) => DecoratedBox(
    decoration: BoxDecoration(color: const Color(0xFFE1F3EB), borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Text(value, style: const TextStyle(color: Color(0xFF116B51),
        fontWeight: FontWeight.bold, fontSize: 11))),
  );

  Widget _notice(String value, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
    child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
  );
}
