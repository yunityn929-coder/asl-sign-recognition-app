# Debug Data-Collection Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a temporary, debug-only Flutter screen that captures the exact 80-value feature vector used for live gesture recognition (63 normalized landmarks + 17 engineered features) per sign, split into Train (15 samples/sign) and Held-out Test (10 samples/sign) JSON Lines exports, for offline model fine-tuning.

**Architecture:** Make `recognition_controller.dart`'s private engineered-feature math public so it's reused verbatim (no duplication). A new pure-Dart `FeatureVectorExportService` owns session-file naming and JSONL appending, fully unit-testable via directory injection. A new `DataCollectionScreen`, modeled on `CalibrationScreen`'s camera/capture scaffolding, drives the capture UI and is wired in only behind the same `kDebugMode`-gated Settings entry pattern already used by `RecognitionTestScreen` — never part of the learner-facing flow.

**Tech Stack:** Flutter/Dart, `camera`, `flutter_riverpod`, `go_router`, `path_provider` (already a dependency), `flutter_test` for unit tests.

## Global Constraints

- Package ID (for adb instructions): `com.hiasl.app` (from `android/app/build.gradle.kts`).
- `kSignLabels` (`lib/data/sign_label_map.dart`) has exactly 36 entries: `0`-`9` then `A`-`Z`.
- Train target: 15 samples/sign. Held-out Test target: 10 samples/sign. Both cover all 36 signs.
- Exported feature vector must be exactly `[...normalizedLandmarks(63), ...engineeredFeatures(17)]` = 80 values, computed by the same function `RecognitionControllerImpl._infer` uses for live inference — no reimplementation.
- Output format: JSON Lines, one file per capture mode per screen session, filenames `hiasl_datacollect_train_<sessionTimestampMs>.jsonl` / `hiasl_datacollect_test_<sessionTimestampMs>.jsonl`.
- The screen must only be reachable via a `kDebugMode`-gated entry in Settings (same pattern as "Recognition Test") — never linked from any learner-facing screen.
- Full design spec: `docs/superpowers/specs/2026-07-31-debug-data-collection-design.md`.

---

### Task 1: Expose engineered-feature computation as a public, tested function

**Files:**
- Modify: `lib/controllers/recognition_controller.dart:120` (function declaration), `lib/controllers/recognition_controller.dart:445` (call site)
- Test: `test/controllers/recognition_controller_features_test.dart`

**Interfaces:**
- Produces: `List<double> computeEngineeredFeatures(List<double> n)` — top-level public function in `lib/controllers/recognition_controller.dart`. Input: 63-length normalized landmark vector. Output: 17-length engineered feature vector (10 curl angles, 5 fingertip-to-palm distances, 2 thumb-to-fingertip distances), in that order. Used by Task 3.

- [ ] **Step 1: Write the failing test**

Create `test/controllers/recognition_controller_features_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hiasl/controllers/recognition_controller.dart';

void main() {
  test('computeEngineeredFeatures matches hand-computed values for colinear landmarks', () {
    // 21 landmarks placed at (i, 0, 0) for landmark index i = 0..20, so every
    // finger's joint-to-joint vectors are parallel (curl angle = 0), and
    // fingertip/palm-center distances reduce to simple 1-D differences we
    // can verify by hand.
    final landmarks = List<double>.generate(63, (i) {
      final landmarkIndex = i ~/ 3;
      final axis = i % 3;
      return axis == 0 ? landmarkIndex.toDouble() : 0.0;
    });

    final features = computeEngineeredFeatures(landmarks);

    expect(features.length, 17);

    // 10 curl angles (2 joint-angle pairs x 5 fingers) — all colinear, so
    // ~0. Not exactly 0: _angleBetween adds a 1e-8 epsilon to the
    // denominator before acos(), so perfectly parallel unit vectors give
    // acos(1/(1+1e-8)) ≈ 1.4142e-4 rad, not 0. Tolerance covers that.
    for (var i = 0; i < 10; i++) {
      expect(features[i], closeTo(0.0, 2e-4));
    }

    // Palm center = average of landmarks 5, 9, 13, 17 = (11, 0, 0).
    // Fingertip distances from palm center for tips 4, 8, 12, 16, 20:
    // |4-11|=7, |8-11|=3, |12-11|=1, |16-11|=5, |20-11|=9.
    expect(features.sublist(10, 15), [7.0, 3.0, 1.0, 5.0, 9.0]);

    // Thumb tip (4) to index tip (8) = 4; thumb tip (4) to middle tip (12) = 8.
    expect(features[15], 4.0);
    expect(features[16], 8.0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/recognition_controller_features_test.dart`
Expected: FAIL — compile error, `computeEngineeredFeatures` is undefined (only the private `_computeEngineeredFeatures` exists).

- [ ] **Step 3: Rename the function (public) at both the declaration and call site**

In `lib/controllers/recognition_controller.dart`, change line 120 from:

```dart
List<double> _computeEngineeredFeatures(List<double> n) {
```

to:

```dart
List<double> computeEngineeredFeatures(List<double> n) {
```

And change line 445 (inside `_infer`) from:

```dart
    final engineered = _computeEngineeredFeatures(normalised);
```

to:

```dart
    final engineered = computeEngineeredFeatures(normalised);
```

No other logic changes.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/recognition_controller_features_test.dart`
Expected: PASS (1 test).

Also run the full suite to confirm nothing else references the old private name:
Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/controllers/recognition_controller.dart test/controllers/recognition_controller_features_test.dart
git commit -m "$(cat <<'EOF'
Expose engineered-feature computation as a public function

Makes computeEngineeredFeatures public (was private) so the upcoming
debug data-collection tool can compute the exact same 80-value
feature vector used for live inference, with zero duplicated math.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `FeatureVectorExportService` — session-scoped JSONL writer

**Files:**
- Create: `lib/services/feature_vector_export_service.dart`
- Test: `test/services/feature_vector_export_service_test.dart`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces (used by Task 3):
  - `enum CaptureMode { train, test }`
  - `extension CaptureModeWireName on CaptureMode { String get wireName; }`
  - `class FeatureVectorExportService`
    - `FeatureVectorExportService({Directory? overrideDirectory, int? sessionTimestampMs})`
    - `int get sessionTimestampMs`
    - `Map<CaptureMode, File> get files` — files created so far this session, keyed by mode
    - `String fileNameFor(CaptureMode mode)`
    - `Future<File> appendSample({required CaptureMode mode, required String label, required List<double> features, DateTime? timestamp})` — throws `ArgumentError` if `features.length != 80`

- [ ] **Step 1: Write the failing tests**

Create `test/services/feature_vector_export_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiasl/services/feature_vector_export_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('feature_export_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('appendSample rejects feature vectors that are not length 80', () {
    final service = FeatureVectorExportService(overrideDirectory: tempDir, sessionTimestampMs: 1000);
    expect(
      () => service.appendSample(
        mode: CaptureMode.train,
        label: 'A',
        features: List<double>.filled(63, 0.0),
      ),
      throwsArgumentError,
    );
  });

  test('appendSample writes one JSON line per call, in order, to the correct mode file', () async {
    final service = FeatureVectorExportService(overrideDirectory: tempDir, sessionTimestampMs: 42);

    await service.appendSample(
      mode: CaptureMode.train,
      label: 'A',
      features: List<double>.generate(80, (i) => i.toDouble()),
      timestamp: DateTime.fromMillisecondsSinceEpoch(100),
    );
    await service.appendSample(
      mode: CaptureMode.train,
      label: 'B',
      features: List<double>.generate(80, (i) => -i.toDouble()),
      timestamp: DateTime.fromMillisecondsSinceEpoch(200),
    );

    final file = File('${tempDir.path}/hiasl_datacollect_train_42.jsonl');
    expect(await file.exists(), isTrue);
    final lines = await file.readAsLines();
    expect(lines.length, 2);

    final first = jsonDecode(lines[0]) as Map<String, dynamic>;
    expect(first['label'], 'A');
    expect(first['mode'], 'train');
    expect(first['timestamp_ms'], 100);
    expect((first['features'] as List).length, 80);

    final second = jsonDecode(lines[1]) as Map<String, dynamic>;
    expect(second['label'], 'B');
    expect(second['timestamp_ms'], 200);
  });

  test('train and held-out test samples land in distinctly named files', () async {
    final service = FeatureVectorExportService(overrideDirectory: tempDir, sessionTimestampMs: 7);

    await service.appendSample(mode: CaptureMode.train, label: 'A', features: List<double>.filled(80, 1.0));
    await service.appendSample(mode: CaptureMode.test, label: 'A', features: List<double>.filled(80, 2.0));

    expect(service.files[CaptureMode.train]!.path, endsWith('hiasl_datacollect_train_7.jsonl'));
    expect(service.files[CaptureMode.test]!.path, endsWith('hiasl_datacollect_test_7.jsonl'));
    expect(service.files[CaptureMode.train]!.path, isNot(equals(service.files[CaptureMode.test]!.path)));
  });

  test('no file is created for a mode with zero captures', () async {
    final service = FeatureVectorExportService(overrideDirectory: tempDir, sessionTimestampMs: 9);
    await service.appendSample(mode: CaptureMode.train, label: 'A', features: List<double>.filled(80, 0.0));

    expect(service.files.containsKey(CaptureMode.test), isFalse);
    final testFile = File('${tempDir.path}/hiasl_datacollect_test_9.jsonl');
    expect(await testFile.exists(), isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/feature_vector_export_service_test.dart`
Expected: FAIL — compile error, `package:hiasl/services/feature_vector_export_service.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/services/feature_vector_export_service.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/feature_vector_export_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/feature_vector_export_service.dart test/services/feature_vector_export_service_test.dart
git commit -m "$(cat <<'EOF'
Add FeatureVectorExportService for JSONL sample capture

Session-scoped JSON Lines writer for the upcoming debug
data-collection screen: one file per capture mode (train/test),
created lazily on first capture, distinct filenames per mode so
train and held-out-test data can never be mixed up after adb pull.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `DataCollectionScreen` capture UI

**Files:**
- Create: `lib/screens/debug/data_collection_screen.dart`

**Interfaces:**
- Consumes:
  - `computeEngineeredFeatures(List<double> n) -> List<double>` (Task 1, `recognition_controller.dart`)
  - `FeatureVectorExportService`, `CaptureMode`, `CaptureModeWireName` (Task 2)
  - `recognitionControllerProvider` (existing, `recognition_controller.dart`) — `Stream<RecognitionResult> results`, `void processFrame(CameraImage, [int rotationDegrees])`
  - `kSignLabels` (existing, `lib/data/sign_label_map.dart`)
  - `RecognitionResult.landmarks` (existing, `lib/models/recognition_result.dart`) — 63-length normalized vector
  - `CameraGate.chain` (existing, `lib/services/camera_gate.dart`)
- Produces (used by Task 4): `class DataCollectionScreen extends ConsumerStatefulWidget` with a `const DataCollectionScreen({super.key})` constructor, no required parameters.

There are no camera-independent unit tests for this widget — same as `CalibrationScreen` and `RecognitionTestScreen`, neither of which has tests, since the core behavior depends on live camera frames and native hand tracking. Verification for this task is static analysis; end-to-end verification happens in Task 5.

- [ ] **Step 1: Write the screen**

Create `lib/screens/debug/data_collection_screen.dart`:

```dart
// Debug-only tool for capturing real feature vectors to fine-tune the
// gesture recognition model. NOT part of the learner-facing app flow —
// reached only from a kDebugMode-gated entry in Settings (see
// settings_screen.dart). See
// docs/superpowers/specs/2026-07-31-debug-data-collection-design.md.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/recognition_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../data/sign_label_map.dart';
import '../../models/recognition_result.dart';
import '../../services/camera_gate.dart';
import '../../services/feature_vector_export_service.dart';

class DataCollectionScreen extends ConsumerStatefulWidget {
  const DataCollectionScreen({super.key});

  @override
  ConsumerState<DataCollectionScreen> createState() => _DataCollectionScreenState();
}

class _DataCollectionScreenState extends ConsumerState<DataCollectionScreen> {
  static const Map<CaptureMode, int> _targetPerSign = {
    CaptureMode.train: 15,
    CaptureMode.test: 10,
  };

  final FeatureVectorExportService _exportService = FeatureVectorExportService();

  Completer<void>? _releaseCompleter;
  CameraController? _cameraController;
  final CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _cameraInitialized = false;
  int _rotationDegrees = 0;

  StreamSubscription<RecognitionResult>? _resultSub;
  RecognitionResult? _lastResult;

  CaptureMode _activeMode = CaptureMode.train;
  final Map<CaptureMode, int> _currentIndex = {CaptureMode.train: 0, CaptureMode.test: 0};
  final Map<CaptureMode, Map<String, int>> _capturedCounts = {
    CaptureMode.train: {},
    CaptureMode.test: {},
  };

  int get _target => _targetPerSign[_activeMode]!;
  bool get _sessionComplete => _currentIndex[_activeMode]! >= kSignLabels.length;
  String get _currentLabel =>
      kSignLabels[_sessionComplete ? kSignLabels.length - 1 : _currentIndex[_activeMode]!];
  int get _capturedForCurrent => _capturedCounts[_activeMode]![_currentLabel] ?? 0;

  @override
  void initState() {
    super.initState();
    _resultSub = ref.read(recognitionControllerProvider).results.listen(_onRecognitionResult);
    _initCamera();
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      controller.stopImageStream().catchError((_) {}).whenComplete(() {
        controller.dispose().catchError((_) {}).whenComplete(_completeRelease);
      });
    } else {
      _completeRelease();
    }
    super.dispose();
  }

  void _completeRelease() {
    if (_releaseCompleter != null && !_releaseCompleter!.isCompleted) {
      _releaseCompleter!.complete();
    }
  }

  Future<void> _initCamera() async {
    final previous = CameraGate.chain;
    _releaseCompleter = Completer<void>();
    CameraGate.chain = _releaseCompleter!.future;
    await previous;
    if (!mounted) {
      _completeRelease();
      return;
    }
    try {
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );
      _rotationDegrees = selected.sensorOrientation % 360;
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        _completeRelease();
        return;
      }
      _cameraController = controller;
      await _cameraController!.startImageStream(_onCameraFrame);
      setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('[DataCollectionScreen] camera init error: $e');
      _completeRelease();
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (!mounted) return;
    ref.read(recognitionControllerProvider).processFrame(image, _rotationDegrees);
  }

  void _onRecognitionResult(RecognitionResult result) {
    if (!mounted) return;
    setState(() => _lastResult = result);
  }

  Future<void> _capture() async {
    final result = _lastResult;
    if (result == null || !result.handDetected || result.landmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hold the sign steady, then try again.')),
      );
      return;
    }
    final features = [...result.landmarks, ...computeEngineeredFeatures(result.landmarks)];
    final mode = _activeMode;
    final label = _currentLabel;
    try {
      await _exportService.appendSample(mode: mode, label: label, features: features);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      final counts = _capturedCounts[mode]!;
      counts[label] = (counts[label] ?? 0) + 1;
      if (counts[label]! >= _targetPerSign[mode]!) {
        _goToIndex(mode, _currentIndex[mode]! + 1);
      }
    });
  }

  void _goToIndex(CaptureMode mode, int index) {
    _currentIndex[mode] = index.clamp(0, kSignLabels.length);
  }

  void _skip() {
    setState(() => _goToIndex(_activeMode, _currentIndex[_activeMode]! + 1));
  }

  void _back() {
    setState(() => _goToIndex(_activeMode, _currentIndex[_activeMode]! - 1));
  }

  void _selectMode(CaptureMode mode) {
    setState(() => _activeMode = mode);
  }

  void _jumpTo(int index) {
    setState(() => _goToIndex(_activeMode, index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Data Collection (Debug)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildModeToggle(),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildCameraPreview(),
              ),
            ),
            _buildInstructions(),
            _buildQuickJump(),
            _buildControls(),
            _buildFileInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: CaptureMode.values.map((mode) {
          final selected = mode == _activeMode;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                onPressed: () => _selectMode(mode),
                style: OutlinedButton.styleFrom(
                  backgroundColor: selected ? AppColors.primary : Colors.white,
                  foregroundColor: selected ? Colors.white : AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: Text(mode == CaptureMode.train ? 'Train' : 'Held-out Test'),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraInitialized || _cameraController == null) {
      return const ColoredBox(
        color: Color(0xFF1A1A1A),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    final previewSize = _cameraController!.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final modeLabel = _activeMode == CaptureMode.train ? 'Train' : 'Held-out Test';
    if (_sessionComplete) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          '$modeLabel session complete — all ${kSignLabels.length} signs captured.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        '$modeLabel — hold the sign for "$_currentLabel", then tap Capture.\n'
        'Captured: $_capturedForCurrent/$_target',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildQuickJump() {
    return Container(
      color: Colors.white,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: kSignLabels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            final label = kSignLabels[i];
            final selected = !_sessionComplete && i == _currentIndex[_activeMode];
            final done = (_capturedCounts[_activeMode]![label] ?? 0) >= _target;
            return GestureDetector(
              onTap: () => _jumpTo(i),
              child: Container(
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : (done ? AppColors.success.withOpacity(0.25) : AppColors.primarySoft),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _currentIndex[_activeMode]! > 0 ? _back : null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _sessionComplete ? null : _capture,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Capture'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _sessionComplete ? null : _skip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7C860),
                foregroundColor: Colors.white,
              ),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    final trainFile = _exportService.files[CaptureMode.train];
    final testFile = _exportService.files[CaptureMode.test];
    if (trainFile == null && testFile == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trainFile != null)
            SelectableText(
              'Train file: ${trainFile.path}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          if (testFile != null)
            SelectableText(
              'Test file: ${testFile.path}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles cleanly**

Run: `flutter analyze lib/screens/debug/data_collection_screen.dart`
Expected: No errors. (The file is not yet imported anywhere, so it won't be reachable until Task 4 — this step only checks the file is syntactically and type-correct in isolation.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/debug/data_collection_screen.dart
git commit -m "$(cat <<'EOF'
Add DataCollectionScreen for fine-tuning sample capture

Debug-only capture UI modeled on CalibrationScreen: per-sign camera
capture with a Train/Held-out Test mode toggle, auto-advance once a
sign's quota is reached (15 for train, 10 for test), and on-screen
display of the JSONL file path(s) written so far this session. Not
yet reachable from any route.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Wire the debug-only entry point

**Files:**
- Modify: `lib/core/constants/route_constants.dart:34` area (path constants), `:72` area (name constants)
- Modify: `lib/router.dart:55` area (import), `:327` area (route registration)
- Modify: `lib/screens/settings/settings_screen.dart:168-181` area (kDebugMode Settings section)

**Interfaces:**
- Consumes: `DataCollectionScreen` (Task 3)
- Produces: `kRouteDebugDataCollection`, `kRouteNameDebugDataCollection` string constants usable by any future code.

- [ ] **Step 1: Add route constants**

In `lib/core/constants/route_constants.dart`, add directly below the `kRouteDebugRecognitionTest` line (currently line 34):

```dart
const String kRouteDebugDataCollection         = '/debug/data-collection';
```

And directly below the `kRouteNameDebugRecognitionTest` line (currently line 72):

```dart
const String kRouteNameDebugDataCollection         = 'debug-data-collection';
```

- [ ] **Step 2: Register the route in the router**

In `lib/router.dart`, add the import next to the existing debug import (currently line 55):

```dart
import 'screens/debug/recognition_test_screen.dart';
import 'screens/debug/data_collection_screen.dart';
```

Then add a new `GoRoute` immediately after the existing `kRouteDebugRecognitionTest` route block (currently ending at line 327):

```dart
    // Debug — feature-vector capture for fine-tuning dataset collection
    // (kDebugMode-gated entry point in Settings; see
    // docs/superpowers/specs/2026-07-31-debug-data-collection-design.md)
    GoRoute(
      path: kRouteDebugDataCollection,
      name: kRouteNameDebugDataCollection,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DataCollectionScreen(),
    ),
```

- [ ] **Step 3: Add the Settings entry point**

In `lib/screens/settings/settings_screen.dart`, inside the existing `if (kDebugMode) ...[` block's `_Card(children: [...])` (currently lines 168-181), add a second `ListTile` after the "Recognition Test" one:

```dart
              _Card(
                children: [
                  ListTile(
                    title: const Text(
                      'Recognition Test',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push(kRouteDebugRecognitionTest),
                  ),
                  ListTile(
                    title: const Text(
                      'Data Collection',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => context.push(kRouteDebugDataCollection),
                  ),
                ],
              ),
```

- [ ] **Step 4: Verify the app compiles and analyzes cleanly**

Run: `flutter analyze`
Expected: No errors.

Run: `flutter pub get`
Expected: Resolves cleanly (no new dependencies were added — `path_provider` is already in `pubspec.yaml`).

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/route_constants.dart lib/router.dart lib/screens/settings/settings_screen.dart
git commit -m "$(cat <<'EOF'
Wire DataCollectionScreen behind the kDebugMode Settings entry

Registers /debug/data-collection the same way
/debug/recognition-test is registered: a root-navigator route whose
only entry point is a kDebugMode-gated "Data Collection" tile in
Settings, so it's unreachable in release builds and never touches
the learner-facing navigation flow.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: On-device verification and file retrieval

**Files:** none (manual verification only)

**Interfaces:** none — this task consumes the fully wired feature from Tasks 1-4 and produces a confirmed working end-to-end flow plus the exact adb commands to hand back to the user.

- [ ] **Step 1: Run the app on a physical device or emulator with a working camera**

Run: `flutter run` (select the target device when prompted)

- [ ] **Step 2: Navigate to the debug screen**

In the running app: Settings → scroll to the "Debug" section (only visible because this is a debug build) → tap "Data Collection".

- [ ] **Step 3: Capture a few samples in Train mode**

With the "Train" toggle selected, hold a hand sign in front of the camera and tap Capture 2-3 times for the same sign. Confirm the on-screen counter increments (e.g. "Captured: 3/15") and that after Task 3's Step 1 code path runs, the bottom of the screen shows a "Train file: ..." path once the first sample is written.

- [ ] **Step 4: Capture a few samples in Held-out Test mode**

Tap the "Held-out Test" toggle, capture 2-3 samples. Confirm a separate "Test file: ..." path appears, distinct from the Train file path shown in Step 3.

- [ ] **Step 5: Pull the files off the device and inspect them**

Using the path shown on-screen (format: `/sdcard/Android/data/com.hiasl.app/files/hiasl_datacollect_<mode>_<timestamp>.jsonl` if `getExternalStorageDirectory()` resolved, matching `TestLoggerService`'s same resolution logic):

```bash
adb pull /sdcard/Android/data/com.hiasl.app/files/ ./hiasl_datacollect_pulled/
```

If the on-screen path instead points at the app-internal documents directory (fallback path, only happens if external storage was unavailable):

```bash
adb shell run-as com.hiasl.app ls files
adb shell run-as com.hiasl.app cat files/hiasl_datacollect_train_<timestamp>.jsonl > hiasl_datacollect_train_<timestamp>.jsonl
```

Open one of the pulled `.jsonl` files and confirm each line parses as JSON with `label`, `mode`, `timestamp_ms`, and an 80-element `features` array, e.g.:

```json
{"label":"A","mode":"train","timestamp_ms":1735689600000,"features":[0.0,0.01,...]}
```

- [ ] **Step 6: Cross-check a captured vector against the live-inference debug log**

While still in the Data Collection screen with a sign held steady, note the `[DIAG] Model input:` line `recognition_controller.dart`'s `_infer` prints to the device log (`flutter logs` or `adb logcat`). Confirm the 63 raw values match the first 63 entries of a `features` array captured for the same held pose (values won't be byte-identical across two different frames, but should be in the same range/sign pattern — this confirms the same normalization path is in effect, not a divergent one).

- [ ] **Step 7: Report exact file locations back to the user**

Once confirmed, tell the user:
- The on-device directory (external storage path if resolved, else the internal fallback + note that `run-as` is required)
- The exact filenames observed (`hiasl_datacollect_train_<timestamp>.jsonl`, `hiasl_datacollect_test_<timestamp>.jsonl`)
- The `adb pull` command that worked

No commit for this task — it's verification only, not a code change.
