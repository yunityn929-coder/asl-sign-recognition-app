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
