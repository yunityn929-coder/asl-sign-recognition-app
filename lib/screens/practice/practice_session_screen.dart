import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// S-18 — Practice Session
//
// TODO(integration): This is the last unwired gesture-recognition consumer.
// APP_FLOW.md S-18 layout: progress+score | "Sign: [LABEL]" (TTS on load) |
// camera preview | timer bar + Skip.
//
// Mirror the pattern already working in lib/screens/lesson/exercise_screen.dart
// (see its _initCamera / _onCameraFrame / _onRecognitionResult):
//   1. CAMERA INIT — own CameraController (ResolutionPreset.medium,
//      ImageFormatGroup.yuv420, front lens), started in initState/_initCamera.
//   2. FEED FRAMES — CameraController.startImageStream(_onCameraFrame), each
//      frame forwarded via ref.read(recognitionControllerProvider).processFrame(image).
//      (MediaPipe hand detection + mlp_model.tflite inference happen inside
//      RecognitionControllerImpl — nothing model-specific belongs in this screen.)
//   3. CONSUME RESULTS — listen to
//      ref.read(recognitionControllerProvider).results (Stream<RecognitionResult>).
//      result.label / result.confidence give the predicted sign; gate on
//      confidence >= kRecognitionConfidenceThreshold (sign_label_map.dart) or the
//      screen's own stricter threshold, same as exercise_screen.dart does with 0.75.
//   4. DIFFICULTY — use `difficulty` (easy/medium/hard) to size
//      kDifficultySeconds (DATA_SCHEMA.md) for the countdown_timer_bar.
//   5. On correct/timeout: advance item, PracticeSessionController.buildCheckoutData()
//      → navigate to /session/checkout (see PROMPTS.md section 9).
//   6. Dispose: stopImageStream + dispose CameraController, cancel result
//      subscription (see exercise_screen.dart dispose()).
class PracticeSessionScreen extends ConsumerWidget {
  final String lessonId;
  final String difficulty;
  const PracticeSessionScreen({
    required this.lessonId,
    required this.difficulty,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(child: Text('Practice Session — TODO')),
    );
  }
}
