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
| `tflite_flutter` | Run `.tflite` model on-device | Input tensor [1,63]; load from assets |

### Sign Demonstrations
Static PNG images — not 3D models.
Path: `assets/models/3d/{SIGN}.png` (A-Z + 0-9, all 36 signs).
`flutter_3d_controller` was removed — no `.glb` files remain in the project.

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
| `shared_preferences` | Lightweight local cache (also stores quiz best scores) |

**Route count:** 30 `GoRoute` entries in `router.dart`.
Plus 3 orphaned route constants (declared but never registered as a `GoRoute`):
`kRouteOnboardingStart`, `kRouteOnboardingPlacement`, `kRouteOnboardingPlacementResult`.

---

## Confirmed Model Specifications

| Property | Value |
|---|---|
| Model file | `assets/models/mlp_model.tflite` |
| Label source | `kSignLabels` in `lib/data/sign_label_map.dart` (no label file bundled — reproduces `label_encoder.pkl`'s class order by hand) |
| Input shape | `[1, 63]` — 21 landmarks x (x,y,z) |
| Output classes | 36 — 0-9 then A-Z |
| Label order | 0=0, 1=1 ... 9=9, 10=A, 11=B ... 35=Z (sklearn `LabelEncoder` alphabetical sort — digits precede uppercase letters) |
| Confidence threshold | 0.85 (`kRecognitionConfidenceThreshold`) — below this show low-detection hint |
| Training samples | 19,812 cleaned landmark vectors (capped at 600/class; low-sample classes kept as-is), 3,963 held out for validation |
| Dataset | ASL-HG (Mendeley, `data.mendeley.com/datasets/j4y5w2c8w9/1`) — 36,000 images, 1,000/class, 10 volunteers |
| Validation accuracy | 100.00% (all 36 classes, epoch 150) — expect lower real-world webcam accuracy due to lighting/angle variation |
| Source model | Converted from Keras `mlp_model.h5` (`asl-gesture-recognition-model/static/model/`) via `tf.lite.TFLiteConverter` |

---

## Asset Structure

```
assets/
├── models/
│   ├── mlp_model.tflite                # labels: kSignLabels in lib/data/sign_label_map.dart
│   └── 3d/
│       ├── A.png ... Z.png, 0.png ... 9.png   # 36 PNG hand sign images
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

`assets/models/3d/` — PNG hand sign images (A-Z + 0-9), all 36 signs available.
Referenced via `kSignImagePath` in `lib/services/quiz_service.dart`.
Used in: `learn_mode_body.dart`, `signs_screen.dart`, `quiz_session_screen.dart`,
`practice_session_screen.dart`.

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
- MediaPipe Hands: 21 landmarks x 3 (x,y,z) = 63 floats
- Normalise: subtract wrist (landmark index 0), then divide by the Euclidean
  norm of the (already-centred) landmark 9 — matches training-time
  normalisation in `asl-gesture-recognition-model/static/preprocessing.py`
- Input tensor: `[1, 63]`
- MLP trained in `asl-gesture-recognition-model/`, converted from
  `mlp_model.h5` to `mlp_model.tflite` via `tf.lite.TFLiteConverter`

### Output
- Softmax over 36 classes (0-9 then A-Z)
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
- No `flutter_3d_controller` — removed, use PNG assets instead
- No `mp.solutions.hands` — old MediaPipe API, use Tasks API (HandLandmarker) instead
- No `FirebaseFirestore.instance` directly — always use `firestoreServiceProvider`
