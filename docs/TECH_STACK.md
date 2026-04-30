# TECH_STACK.md — Technology & Package Reference
# HiASL

## Core Framework
| Technology | Version Target | Notes |
|---|---|---|
| Flutter | Latest stable | Dart, null-safe |
| Dart | Latest stable | |
| Android SDK | API 29+ (Android 10) | Target API 34+ |

---

## pubspec.yaml — Key Packages

### Camera & Gesture Recognition
| Package | Purpose | Notes |
|---|---|---|
| `camera` | Live camera feed | Use for CameraPreview widget |
| `google_mlkit_commons` | MLKit base dependency | Required |
| `tflite_flutter` | Run `.tflite` model on-device | Input tensor [1,42]; load from assets |

> MediaPipe Hands integration: use platform channel (MethodChannel) to call native MediaPipe Android SDK. Source model and pipeline from github.com/kinivi/hand-gesture-recognition-mediapipe — retrained on ASL data. Model file: `keypoint_classifier.tflite`, label file: `keypoint_classifier_label.csv`.

### 3D Rendering
| Package | Purpose | Notes |
|---|---|---|
| `flutter_3d_controller` | Display `.glb` models with rotate/zoom | One `.glb` per sign in assets/models/3d/ |

### Firebase
| Package | Purpose |
|---|---|
| `firebase_core` | Firebase init |
| `firebase_auth` | Email/password auth |
| `cloud_firestore` | All persistent data |
| `firebase_messaging` | Push notifications (daily reminders) |

### Audio
| Package | Purpose | Notes |
|---|---|---|
| `flutter_tts` | Text-to-speech | Call `speak()` async; does not block UI |
| `audioplayers` | Sound effects | Preload `.mp3` assets on app start |

### Notifications
| Package | Purpose | Notes |
|---|---|---|
| `flutter_local_notifications` | Schedule daily reminder notification | Trigger at user's reminder time if no activity today |
| `permission_handler` | Request POST_NOTIFICATIONS + camera permissions | Use for both |
| `timezone` | Timezone-aware notification scheduling | Required by flutter_local_notifications |

### Navigation & State
| Package | Purpose |
|---|---|
| `go_router` | Named routes + navigation |
| `riverpod` (or `provider`) | State management — use Riverpod preferred |
| `shared_preferences` | Local cache for lightweight session data |

---

## Asset Structure

```
assets/
├── models/
│   ├── asl_classifier.tflite
│   ├── label_map.txt               # one label per line, index = class
│   └── 3d/
│       ├── sign_A.glb
│       ├── sign_B.glb  ... sign_Z.glb
│       └── sign_0.glb  ... sign_9.glb
├── audio/
│   ├── success.mp3                 # correct attempt chime
│   ├── error.mp3                   # incorrect attempt tone
│   ├── fanfare.mp3                 # session checkout celebration
│   └── xp_gain.mp3                 # XP awarded sparkle
└── images/
    └── (UI icons, onboarding illustrations)
```

---

## Gesture Recognition Pipeline

### Input
- MediaPipe Hands → 21 landmarks × 2 (x,y only — z not used) = **42 floats**
- Normalise all values relative to wrist (landmark index 0) before model input
- Input tensor shape: `[1, 42]`
- z coordinate is dropped — sufficient for static one-hand signs
- Pipeline sourced from kinivi/hand-gesture-recognition-mediapipe, retrained on ASL

### Output
- Softmax probabilities over 36 classes (A–Z, 0–9)
- Class order → `assets/models/label_map.txt`
- Confidence threshold: **0.85** — below this, treat as `handDetected: true` but label uncertain → show hint (FR-17)

### Session Control (FR-14)
- `RecognitionController.startSession()` called once on screen entry
- `stopSession()` called on screen exit (dispose)
- Never start/stop per attempt

### Finger-State Feedback (FR-10)
- Use raw landmark positions, NOT the TFLite model
- Extended: `tip.y < pip.y` (normalised)
- Curled: `tip.y > pip.y`
- Compare to `kSignFingerStates` in DATA_SCHEMA.md
- Report first mismatching finger only

---

## TTS Usage Pattern
```dart
// In any screen that shows a sign label or prompt:
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (ttsService.enabled) ttsService.speak(signLabel);
  });
}
// On sign change:
void onNextSign(String label) {
  ttsService.stop();  // cancel any in-progress speech
  ttsService.speak(label);
}
```
TTS must run async — never await in build or gesture handlers.

## Sound Effects Usage Pattern
```dart
// Preload on app start (in main.dart or SoundService init):
await soundService.preloadAll();

// In session logic:
onCorrect: () {
  soundService.playSuccess();   // non-blocking
  ttsService.speak("Correct!"); // non-blocking
  xpService.award(xpAmount);
  soundService.playXpGain();
}
```

---

## Notification Setup
```dart
// Schedule daily reminder (called after onboarding if permission granted):
// 1. Use flutter_local_notifications + timezone
// 2. Schedule repeating daily notification at user's chosen time (default 19:00)
// 3. Before showing: check if lastStreakDate == today → cancel if already practiced
// 4. Notification payload: 'daily_reminder' → on tap, open app to Home
```

---

## Performance Targets
| Metric | Target |
|---|---|
| Recognition feedback latency | ≤ 1000ms end-to-end |
| Camera framerate | ≥ 15fps |
| TFLite inference | ≤ 50ms per frame |
| TTS response (speak called → audio starts) | ≤ 300ms |
| Sound effect trigger → playback | ≤ 100ms |

---

## Firebase Config
- `google-services.json` → `android/app/`
- Enable: Email/Password Auth, Firestore, Firebase Cloud Messaging
- Firestore rules: see DATA_SCHEMA.md

## What NOT to Use
- No custom REST API or cloud functions
- No image upload or cloud inference
- No `tflite` (deprecated) — use `tflite_flutter` only
- No ARCore/ARKit — 3D via `flutter_3d_controller` only
- No `just_audio` (licence constraints) — use `audioplayers`

---
## Amendment — Quick Auth Packages (appended)

### Authentication
| Package | Purpose | Notes |
|---|---|---|
| `google_sign_in` | Google OAuth flow | Pairs with `firebase_auth` `GoogleAuthProvider.credential` |
| `firebase_auth` | All auth methods | Handles email, Google, and anonymous sign-in |

### Auth Implementation Notes

**Google Sign-In flow:**
```dart
final googleUser = await GoogleSignIn().signIn();
final googleAuth = await googleUser!.authentication;
final credential = GoogleAuthProvider.credential(
  accessToken: googleAuth.accessToken,
  idToken: googleAuth.idToken,
);
await FirebaseAuth.instance.signInWithCredential(credential);
```

**Anonymous Sign-In flow:**
```dart
await FirebaseAuth.instance.signInAnonymously();
// Then create Firestore user doc with isGuest: true
```

**Guest → Google conversion flow:**
```dart
final credential = GoogleAuthProvider.credential(...); // from google_sign_in
await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
// Then update Firestore doc: isGuest=false, authProvider="google"
```

**Guest → Email conversion flow:**
```dart
final credential = EmailAuthProvider.credential(email: email, password: password);
await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
// Then update Firestore doc: isGuest=false, authProvider="email"
```

**New user detection (Google Sign-In):**
```dart
final result = await FirebaseAuth.instance.signInWithCredential(credential);
if (result.additionalUserInfo?.isNewUser == true) {
  await FirestoreService.createUser(...); // only for new users
}
```

**Required: add to android/app/build.gradle**
SHA-1 fingerprint must be registered in Firebase Console for Google Sign-In to work.
