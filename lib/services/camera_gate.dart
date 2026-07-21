import 'dart:async';

// Serializes camera hardware acquisition across every screen that opens its
// own CameraController — CalibrationScreen, ExerciseScreen,
// PracticeSessionScreen, RecognitionTestScreen. Overlapping open/close
// attempts on the same physical camera device is a known cause of corrupted
// preview frames; this ensures a new instance's camera-open always waits for
// the previous instance's camera-close to fully finish, regardless of which
// screen owned it or how its teardown was triggered (explicit navigation,
// system back gesture, hot reload, etc).
class CameraGate {
  static Future<void> chain = Future.value();
}
