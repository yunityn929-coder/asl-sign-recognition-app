# TECH_STACK.md — Technology & Package Reference
# HiASL

## Core Framework
| Technology | Version Target | Notes |
|---|---|---|
| Flutter | Latest stable | Dart, null-safe |
| Dart | Latest stable | |
| Android SDK | API 26+ min, Target API 34+ | tflite_flutter requires min SDK 26 |

---

## pubspec.yaml — Key Packages

### Camera & Gesture Recognition
| Package | Purpose | Notes |
|---|---|---|
| `camera` | Live camera feed | Use for CameraPreview widget |
| `tflite_flutter` | Run `.tflite` model on-device | Input tensor [1,42]; load from assets |

### 3D Rendering
| Package | Purpose | Notes |
|---|---|---|
| `flutter_3d_controller` | Display `.glb` models with rotate/zoom | One `.glb` per sign in assets/models/3d/ |

### Firebase
| Package | Purpose |
|---|---|
| `firebase_core` | Firebase init |
| `firebase_auth` | Anonymous + Google auth |
| `cloud_firestore` | All persistent data |

### Auth
| Package | Purpose | Notes |
|---|---|---|
| `google_sign_in` | Google OAuth | Only used for social/leaderboard unlock (S-25) |

### Audio
| Package | Purpose | Notes |
|---|---|---|
| `flutter_tts` | Text-to-speech | Call speak() async; never blocks UI |
| `audioplayers` | Sound effects | Preload all .mp3 assets on app start |

### Notifications
| Package | Purpose | Notes |
|---|---|---|
| `flutter_local_notifications` | Daily reminder | Trigger at 19:00 if no activity today |
| `permission_handler` | Camera + POST_NOTIFICATIONS | Used in onboarding S-07 |
| `timezone` | Timezone-aware scheduling | Required by flutter_local_notifications |

### Navigation & State
| Package | Purpose |
|---|---|
| `go_router` | Named routes + navigation (25 routes) |
| `flutter_riverpod` | State management |
| `shared_preferences` | Lightweight local cache |

---

## Confirmed Model Specifications

| Property | Value |
|---|---|
| Model file | `assets/models/keypoint_classifier.tflite` |
| Label file | `assets/models/keypoint_classifier_label.csv` |
| Input shape | `[1, 42]` — 21 landmarks x (x,y) only, z dropped |
| Output classes | 26 — A-Z alphabet only |
| Label order | A=0, B=1, C=2 ... Z=25 |
| Confidence threshold | 0.85 — below this show low-detection hint |
| Training samples | 142,082 landmark vectors |
| Dataset | grassknoted ASL Alphabet via Kaggle |
| Weakest classes | M (4,391 samples), N (3,392 samples) |

Numbers (0-9): OUT OF SCOPE — no suitable landmark dataset. Future work.

---

## Asset Structure

```
assets/
├── models/
│   ├── keypoint_classifier.tflite
│   ├── keypoint_classifier_label.csv   # one label per line, A-Z
│   └── 3d/
│       ├── sign_A.glb ... sign_Z.glb
├── audio/
│   ├── success.mp3
│   ├── error.mp3
│   ├── fanfare.mp3
│   └── xp_gain.mp3
└── images/
    ├── mascot_wave.png       # S-02
    ├── mascot_speech.png     # onboarding Q screens
    ├── mascot_excited.png    # S-04
    ├── mascot_celebrate.png  # S-19, S-11
    ├── mascot_streak.png     # S-21
    ├── mascot_commit.png     # S-12
    └── flame.png
```

---

## Auth Flow

### First launch — silent, no UI
```dart
await FirebaseAuth.instance.signInAnonymously();
// Create Firestore user doc with isAnonymous: true
```

### Social unlock only (S-25)
```dart
final googleUser = await GoogleSignIn().signIn();
final credential = GoogleAuthProvider.credential(...);
await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
// Update Firestore: isAnonymous: false, authProvider: "google"
```

No email/password auth. No login screen. Anonymous-first.

---

## Gesture Recognition Pipeline

### Input
- MediaPipe Hands: 21 landmarks x 2 (x,y only — z dropped) = 42 floats
- Normalise relative to wrist (landmark index 0)
- Input tensor: `[1, 42]`
- Based on kinivi/hand-gesture-recognition-mediapipe, retrained on ASL data

### Output
- Softmax over 26 classes (A-Z)
- Confidence < 0.85 → emit as uncertain → show hint (FR-17)

### Session Control
- startSession() once on screen entry
- stopSession() in dispose()
- Never start/stop per attempt

### Finger-State Feedback
- Uses raw landmarks, NOT TFLite model
- Extended: tip.y < pip.y
- Curled: tip.y > pip.y
- Report first mismatching finger only

---

## TTS Pattern
```dart
void initState() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (ttsService.enabled) ttsService.speak(label);
  });
}
void onNextSign(String label) {
  ttsService.stop();
  ttsService.speak(label);
}
```

---

## Performance Targets
| Metric | Target |
|---|---|
| Feedback latency | ≤ 1000ms |
| Camera framerate | ≥ 15fps |
| TFLite inference | ≤ 50ms |
| TTS response | ≤ 300ms |
| Sound playback | ≤ 100ms |

---

## Firebase Config
- google-services.json → android/app/
- Enable: Anonymous Auth, Google Auth, Firestore
- SHA-1 debug fingerprint in Firebase Console
- android/app/build.gradle.kts: minSdk = 26, isCoreLibraryDesugaringEnabled = true
- Firestore rules: see DATA_SCHEMA.md

## What NOT to Use
- No custom REST API or cloud functions
- No image upload or cloud inference
- No tflite (deprecated) — use tflite_flutter
- No ARCore/ARKit — 3D via flutter_3d_controller
- No just_audio — use audioplayers
- No email/password auth
- No SQLite — Firestore only
