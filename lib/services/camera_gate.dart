import 'dart:async';

// Serializes camera open/close across every screen that owns a
// CameraController — overlapping open/close on the same physical camera
// causes corrupted preview frames, so a new open always waits for the
// previous close to finish first.
class CameraGate {
  static Future<void> chain = Future.value();
}
