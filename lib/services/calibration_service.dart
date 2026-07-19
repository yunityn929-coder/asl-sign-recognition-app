/// Local, on-device storage for per-user sign calibration samples.
///
/// Stores a few normalized landmark vectors per class label, captured by
/// the user during an optional calibration flow. Used to boost recognition
/// confidence for signs where the generic model's decision boundary
/// doesn't match this specific user's hand/camera/lighting.
library;

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CalibrationService {
  CalibrationService._();
  static final CalibrationService instance = CalibrationService._();

  static const int maxSamplesPerClass = 5;

  final Map<String, List<List<double>>> _samples = {};
  bool _loaded = false;

  bool get hasAnyCalibration => _samples.values.any((s) => s.isNotEmpty);

  List<List<double>> samplesFor(String label) => _samples[label] ?? const [];

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/calibration_samples.json');
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        raw.forEach((label, samples) {
          _samples[label] = (samples as List)
              .map((s) => (s as List).cast<double>())
              .toList();
        });
      }
    } catch (_) {
      _samples.clear();
    }
  }

  Future<void> addSample(String label, List<double> normalised) async {
    await ensureLoaded();
    final list = _samples.putIfAbsent(label, () => []);
    list.add(List<double>.from(normalised));
    if (list.length > maxSamplesPerClass) {
      list.removeAt(0);
    }
    await _save();
  }

  Future<void> clearClass(String label) async {
    await ensureLoaded();
    _samples.remove(label);
    await _save();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    _samples.clear();
    await _save();
  }

  Future<void> _save() async {
    final file = await _file();
    await file.writeAsString(jsonEncode(_samples));
  }
}
