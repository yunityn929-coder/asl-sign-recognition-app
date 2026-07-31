/// Appends captured feature-vector samples to per-mode JSON Lines files for
/// the debug data-collection tool
/// (lib/screens/debug/data_collection_screen.dart). NOT used by any
/// production screen. See
/// docs/superpowers/specs/2026-07-31-debug-data-collection-design.md.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum CaptureMode { train, test }

extension CaptureModeWireName on CaptureMode {
  String get wireName => this == CaptureMode.train ? 'train' : 'test';
}

class FeatureVectorExportService {
  FeatureVectorExportService({Directory? overrideDirectory, int? sessionTimestampMs})
      : _overrideDirectory = overrideDirectory,
        sessionTimestampMs = sessionTimestampMs ?? DateTime.now().millisecondsSinceEpoch;

  final Directory? _overrideDirectory;
  final int sessionTimestampMs;
  final Map<CaptureMode, File> _files = {};

  /// Files created so far this session, keyed by mode. A mode with zero
  /// captures has no entry — files are created lazily on first capture.
  Map<CaptureMode, File> get files => Map.unmodifiable(_files);

  String fileNameFor(CaptureMode mode) =>
      'hiasl_datacollect_${mode.wireName}_${sessionTimestampMs}.jsonl';

  Future<Directory> _resolveDirectory() async {
    final override = _overrideDirectory;
    if (override != null) return override;
    try {
      return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      return getApplicationDocumentsDirectory();
    }
  }

  Future<File> _fileFor(CaptureMode mode) async {
    final existing = _files[mode];
    if (existing != null) return existing;
    final dir = await _resolveDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/${fileNameFor(mode)}');
    _files[mode] = file;
    return file;
  }

  /// Appends one sample as a JSON line. [features] must have exactly 80
  /// elements (63 normalized landmarks + 17 engineered features, matching
  /// RecognitionControllerImpl._infer's input layout exactly).
  Future<File> appendSample({
    required CaptureMode mode,
    required String label,
    required List<double> features,
    DateTime? timestamp,
  }) async {
    if (features.length != 80) {
      throw ArgumentError.value(features.length, 'features.length', 'must be exactly 80');
    }
    final line = jsonEncode({
      'label': label,
      'mode': mode.wireName,
      'timestamp_ms': (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
      'features': features,
    });
    final file = await _fileFor(mode);
    await file.writeAsString('$line\n', mode: FileMode.append);
    return file;
  }
}
