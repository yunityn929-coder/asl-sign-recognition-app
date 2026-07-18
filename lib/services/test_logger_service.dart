/// Opt-in logger for physical-device gesture-recognition testing.
///
/// NOT used by any production screen — only wired into
/// lib/screens/debug/recognition_test_screen.dart. Buffers one row per
/// processed frame in memory (a test session is a few minutes of ~10fps
/// frames, well within memory limits) and flushes to a CSV file on
/// [exportCsv]. See docs/GESTURE_TESTING_PROTOCOL.md for how this is used.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class TestLogEntry {
  final DateTime timestamp;
  final String targetLetter;
  final String topLabel;
  final double topConfidence;
  final String secondLabel;
  final double secondConfidence;
  final bool handDetected;
  final bool isConfident;
  final int latencyMs;

  const TestLogEntry({
    required this.timestamp,
    required this.targetLetter,
    required this.topLabel,
    required this.topConfidence,
    required this.secondLabel,
    required this.secondConfidence,
    required this.handDetected,
    required this.isConfident,
    required this.latencyMs,
  });

  static const csvHeader =
      'timestamp_ms,target_letter,top_label,top_confidence,second_label,'
      'second_confidence,hand_detected,is_confident,correct,latency_ms';

  /// correct = the model's top prediction matched the tester-declared
  /// ground-truth target for this frame. Ground truth is set by the tester
  /// selecting a letter on screen, NOT derived from the model itself.
  String toCsvRow() {
    final correct = handDetected && topLabel == targetLetter;
    return [
      timestamp.millisecondsSinceEpoch,
      _esc(targetLetter),
      _esc(topLabel),
      topConfidence.toStringAsFixed(4),
      _esc(secondLabel),
      secondConfidence.toStringAsFixed(4),
      handDetected,
      isConfident,
      correct,
      latencyMs,
    ].join(',');
  }

  static String _esc(String s) => s.isEmpty ? '-' : s;
}

class TestLoggerService {
  final List<TestLogEntry> _entries = [];
  String? _sessionName;
  DateTime? _sessionStart;

  bool get isActive => _sessionName != null;
  int get entryCount => _entries.length;
  String? get sessionName => _sessionName;

  void startSession(String sessionName) {
    _sessionName = sessionName;
    _sessionStart = DateTime.now();
    _entries.clear();
  }

  void log(TestLogEntry entry) {
    if (!isActive) return;
    _entries.add(entry);
  }

  /// Running per-letter accuracy for the on-screen HUD: label -> [correct, total].
  /// Frames with no hand detected are excluded (not attempts).
  Map<String, List<int>> get perLetterStats {
    final map = <String, List<int>>{};
    for (final e in _entries) {
      if (!e.handDetected) continue;
      final stats = map.putIfAbsent(e.targetLetter, () => [0, 0]);
      stats[1] += 1;
      if (e.topLabel == e.targetLetter) stats[0] += 1;
    }
    return map;
  }

  /// Writes the buffered session to a CSV file and returns it. On desktop
  /// (Windows/macOS/Linux), writes to a `test_logs/` dir under the current
  /// working directory. On Android/iOS, unchanged: prefers the app's
  /// external files dir (adb-pullable without `run-as` on most devices),
  /// falling back to the internal app documents dir.
  /// Does NOT clear the buffer or end the session — call [endSession] after.
  Future<File> exportCsv() async {
    final name = _sessionName;
    if (name == null) {
      throw StateError('No active test session to export.');
    }
    Directory dir;
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      dir = Directory('${Directory.current.path}/test_logs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      try {
        dir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
    }
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final ts = (_sessionStart ?? DateTime.now()).millisecondsSinceEpoch;
    final file = File('${dir.path}/hiasl_recotest_${safeName}_$ts.csv');
    final buffer = StringBuffer()..writeln(TestLogEntry.csvHeader);
    for (final e in _entries) {
      buffer.writeln(e.toCsvRow());
    }
    await file.writeAsString(buffer.toString());
    debugPrint('[TestLogger] wrote ${_entries.length} rows to ${file.path}');
    return file;
  }

  void endSession() {
    _sessionName = null;
    _sessionStart = null;
    _entries.clear();
  }
}

final testLoggerServiceProvider = Provider<TestLoggerService>((ref) {
  return TestLoggerService();
});
