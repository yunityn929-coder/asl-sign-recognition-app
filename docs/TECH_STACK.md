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
| `google_sign_in` | Google OAuth | Used by both `LinkAccountScreen` (S-25, create profile) and `SignInScreen` (S-25b, switch account) |

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
| `shared_preferences` | Lightweight local cache (quiz best scores; `native_anonymous_uid` for Sign Out behaviour — see Auth Flow) |

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

No email/password auth. No forced login screen. Anonymous-first — all
learning features work fully signed-out. Google is the only social provider,
and it's split across **two independent screens** with different
semantics, both backed by `lib/services/auth_service.dart`
(`AuthService`, registered as `authServiceProvider`).

### First launch — silent, no UI
```dart
await FirebaseAuth.instance.signInAnonymously();
// Create Firestore user doc with isAnonymous: true
```
`AuthService.signInSilently()` also records the resulting UID to
`SharedPreferences` under `native_anonymous_uid` if not already set — this
is what Sign Out later uses to decide whether it can safely unlink instead
of fully signing out (see below).

### Create Profile — `LinkAccountScreen` (`/login/link`)
Upgrades the **current anonymous session in place**. Same UID before and
after, so all Firestore progress under `users/{uid}/` carries over with zero
migration.

```dart
// AuthService.linkWithGoogle()
final current = _auth.currentUser;
if (current == null || !current.isAnonymous) {
  throw const AuthException("You're already signed in. Sign out first...");
}
await GoogleSignIn().signOut();          // force the account picker —
final googleUser = await GoogleSignIn().signIn();  // never reuse a cached account
final credential = GoogleAuthProvider.credential(
  accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
final result = await current.linkWithCredential(credential);
// Returns (user, googleDisplayName, googleEmail, googlePhotoUrl) — the
// screen writes these straight to Firestore (isAnonymous: false,
// authProvider: 'google', displayName/email/photoUrl).
```
`credential-already-in-use` (this Google identity is already linked to a
*different* Firebase user) surfaces as "This Google account is already
linked to another profile. Try Sign In instead."

### Sign In — `SignInScreen` (`/login/signin`)
Switches to a **different, already-existing** account via
`signInWithCredential` — a different UID, not an upgrade of the current one.

```dart
// AuthService.signInWithGoogle()
await GoogleSignIn().signOut();          // force the account picker
final googleUser = await GoogleSignIn().signIn();
final blocked = await FirebaseFirestore.instance
    .collection('deletedGoogleAccounts').doc(googleUser.id).get();
if (blocked.exists) throw const AuthException('...previously deleted...');
final result = await _auth.signInWithCredential(credential);
// Returns (user, isNewUser) — isNewUser == true means this Google identity
// was never registered before.
```
If `isNewUser == true`, the screen treats it as **"account not found"**
rather than silently onboarding a stranger into a fresh account: it deletes
the Firebase Auth user `signInWithCredential` just auto-created, calls
`signInSilently()` to restore an anonymous session, and shows "We couldn't
find an account for this Google sign-in. Try Create Profile instead." — no
navigation happens.

Before either sign-in attempt actually proceeds, `SignInScreen` also checks
whether the *current* anonymous account has progress worth losing
(`totalXp > 0 || currentStreak > 0 || signAccuracy.isNotEmpty`) and, if so,
shows a "Switch account?" confirmation dialog first.

### Sign Out
```dart
// AuthService.signOut()
if (current != null && !current.isAnonymous &&
    nativeUid != null && current.uid == nativeUid) {
  // This account originated from THIS device's own anonymous session —
  // unlink instead of full sign-out, so progress survives.
  await current.unlink('google.com');
} else {
  await _auth.signOut();  // true account switch — start fresh anonymous
}
```
`native_anonymous_uid` (SharedPreferences) is what makes this distinction:
it's set once when a device first creates/reuses an anonymous session, and
is only ever compared, never re-derived from the live Auth state.

### Delete Account
Two-step, in this order (see `profile_screen.dart`):
```dart
await firestoreService.deleteUserData(uid);   // all subcollections + user doc
await authService.deleteAccount();            // blocklist write, then user.delete()
```
`deleteAccount()` writes the `deletedGoogleAccounts/{googleUid}` blocklist
record **before** `user.delete()` — not after, since the write requires an
authenticated `request.auth` which `delete()` clears. On failure (e.g.
`requires-recent-login`), the blocklist record is rolled back so a still-live
account isn't incorrectly blocked. Re-authentication (Google re-prompt) is
attempted once for `requires-recent-login`, then retried.

### Live auth state (Profile screen UI)
`authStateProvider` (`lib/providers/auth_provider.dart`) uses
`FirebaseAuth.instance.userChanges()`, not `authStateChanges()` — the latter
only fires on true sign-in/out transitions and misses provider link/unlink
events (like the unlink-based Sign Out path above), which would leave
`isAnonymous`-driven UI stale. The Profile screen's guest-vs-signed-in gating
is driven by this live stream, not the Firestore user doc — a Firestore
write failing independently of the Auth-layer change can never leave the UI
showing a stale state. Displayed profile *details* (name, email, photo) are
still Firestore-backed, sourced from the Google account data captured at
link/sign-in time.

> Open/unconfirmed as of 2026-07-23: an investigation into Google profile
> details (name/email/photo) not always appearing immediately after linking
> is still unresolved — the linking code has been re-verified correct and a
> direct Firestore check showed no write-path regression, but a clean
> isolated repro was never captured. See BUILD_STATUS.md Known Bugs/Issues.

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
