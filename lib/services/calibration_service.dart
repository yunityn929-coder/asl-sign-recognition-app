/// Firestore-backed storage for per-user sign calibration samples.
///
/// Stores a few normalized landmark vectors per class label, captured by
/// the user during an optional calibration flow. Used to boost recognition
/// confidence for signs where the generic model's decision boundary
/// doesn't match this specific user's hand/camera/lighting.
library;

import 'firestore_service.dart';

class CalibrationService {
  CalibrationService._();
  static final CalibrationService instance = CalibrationService._();

  static const int maxSamplesPerClass = 5;

  final FirestoreService _firestoreService = FirestoreService();

  final Map<String, List<List<double>>> _samples = {};
  String? _loadedUid;
  final Map<String, Future<void>> _pendingWrites = {};

  bool get hasAnyCalibration => _samples.values.any((s) => s.isNotEmpty);

  // In-memory only, not persisted — A/B toggle for calibration blending.
  bool enabled = true;

  List<List<double>> samplesFor(String label) => _samples[label] ?? const [];

  Future<void> ensureLoaded(String uid) async {
    if (_loadedUid == uid) return;
    try {
      final loaded = await _firestoreService.loadAllCalibration(uid);
      _samples
        ..clear()
        ..addAll(loaded);
      _loadedUid = uid;
    } catch (_) {
      // Leave any samples already captured this session intact; only
      // treat this as "loaded" once a real fetch succeeds, so we keep
      // retrying, but don't destroy in-progress capture work in the meantime.
    }
  }

  Future<void> addSample(String uid, String label, List<double> normalised) async {
    if (_loadedUid != uid) {
      await ensureLoaded(uid);
    }
    final list = _samples.putIfAbsent(label, () => []);
    list.add(List<double>.from(normalised));
    if (list.length > maxSamplesPerClass) {
      list.removeAt(0);
    }
    final samplesSnapshot = List<List<double>>.from(list);
    final previous = _pendingWrites[label] ?? Future.value();
    final write = previous.catchError((_) {}).then((_) =>
        _firestoreService.saveCalibrationSample(uid, label, samplesSnapshot));
    _pendingWrites[label] = write;
    await write;
  }

  Future<void> clearClass(String uid, String label) async {
    await ensureLoaded(uid);
    _samples.remove(label);
    await _firestoreService.clearCalibrationClass(uid, label);
  }

  Future<void> clearAll(String uid) async {
    await ensureLoaded(uid);
    _samples.clear();
    await _firestoreService.clearAllCalibration(uid);
  }
}
