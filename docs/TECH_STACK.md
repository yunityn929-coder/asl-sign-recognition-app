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
| `shared_preferences` | Lightweight local cache (quiz best scores) |

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
// AuthService.signInSilently()
if (_auth.currentUser != null) return _auth.currentUser!;
final cred = await _auth.signInAnonymously();
return cred.user!;
```
`SplashScreen` calls this, then `FirestoreService.createUser(uid)` (no-op if
the doc already exists), then routes to Welcome Brand or Home depending on
`onboardingComplete`.

**Self-healing reconciliation (also in `SplashScreen._init()`):** if
`FirebaseAuth`'s current user is non-anonymous but the Firestore doc is
still `isAnonymous: true` (or missing/just-recreated) — e.g. a link
succeeded in Firebase Auth but the app was killed before the Firestore write
landed — Splash detects the mismatch and backfills the Firestore doc from
the live `User`: `isAnonymous: false`, `authProvider: 'google'`, and
`displayName`/`email`/`photoUrl` read from the `google.com` entry in
`user.providerData` (see "Profile display fields" below — **not** the
top-level `User.displayName`/`photoURL`, which aren't reliably populated by
`linkWithCredential()`). This runs on every launch but is a no-op once the
Firestore doc already agrees with Auth.

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
// authProvider: 'google', displayName/email/photoUrl), preferring the
// GoogleSignInAccount's own fields over the FirebaseAuth User's.
```
There is **no client-side timeout** wrapping this call — an earlier version
wrapped it in `.timeout(60s)`, which doesn't cancel the underlying Firebase
call; if linking took longer than the timeout, the screen showed a false
"taking longer than expected" error while the link silently succeeded
moments later, leaving the UI out of sync with reality. Removed entirely —
if the call is slow, the screen just keeps waiting.

On success, the screen navigates straight to Home (`context.go(kRouteHome)`)
regardless of which screen launched it — success is always "move forward,"
never "go back to where you came from" (see Navigation notes below).

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
final result = await _auth.signInWithCredential(credential);
// Returns (user, isNewUser) — isNewUser == true means this Google identity
// was never registered before.
```
There is no blocklist check — a previously-deleted Google identity can sign
in / link again freely (see "Deleted-account blocklist removed" below).

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

On success, the screen navigates straight to Home, same as Create Profile
above — never back to the launching screen.

### Profile display fields (name / email / photo)
Both `LinkAccountScreen` and the Splash self-heal reconciliation prefer the
Google-specific source over `FirebaseAuth.User`'s own top-level fields:
`LinkAccountScreen` uses the live `GoogleSignInAccount`'s
`displayName`/`email`/`photoUrl` (captured at the moment of linking);
Splash's reconciliation reads the `google.com` entry in `user.providerData`.
`User.displayName`/`User.photoURL` themselves are **not** a reliable source
after `linkWithCredential()` — Firebase Auth doesn't always populate the
top-level profile fields on link, even though the provider-specific entry in
`providerData` always carries the linked account's real profile data.

### Sign Out
```dart
// AuthService.signOut()
Future<void> signOut() async {
  try {
    await _googleSignIn.disconnect().timeout(const Duration(seconds: 5));
  } catch (_) {}
  await _auth.signOut();
}
```
**Always fully signs out**, unconditionally, regardless of how the current
account was reached (linked in-place from this device's own guest session,
or signed into a separate existing account via Sign In). The next app launch
creates a brand-new anonymous session and lands on Welcome Brand. The signed-
out account's data is not lost — it stays in Firestore under that account's
uid — this device just doesn't auto-resume it; signing back into the same
Google account (via Sign In) recovers it.

This replaced an earlier heuristic that tried to distinguish "this device's
own guest session, upgraded in place" (which unlinked instead of fully
signing out, to auto-preserve that session) from a true account switch,
using a `native_anonymous_uid` value cached in `SharedPreferences`. That
heuristic went stale across repeated sign-in/out cycles — because it was set
once, permanently, the first time a device ever created any anonymous
session — and could pick the wrong behavior (e.g. quietly keeping the same
session alive on "sign out" instead of actually signing out, or performing a
full sign-out that abandoned a device-original guest session by mistake).
Simplified to always fully sign out per product decision — consistent,
predictable behavior beats an automatic-preserve heuristic that couldn't be
made reliable.

`_googleSignIn.disconnect()` is wrapped in a 5-second timeout because it has
been observed to hang indefinitely with no exception and no UI on some
devices/network conditions (a stale native session with nothing to actually
disconnect) — without the timeout, that silently stalls the entire sign-out
with no feedback to the user.

### Delete Account
Three steps, in this exact order (see `_DeleteAccountButtonState._onTap()`
in `profile_screen.dart`):
```dart
await authService.reauthenticateForDeleteIfNeeded();  // no-op if already anonymous
await firestoreService.deleteUserData(uid);           // all subcollections + user doc
await authService.deleteAccount();                    // user.delete()
```
Reauthentication happens **first**, before any data is touched — deleting a
Firebase Auth account can fail with `requires-recent-login` if the session
isn't fresh, and if that happened *after* Firestore data was already wiped,
the account would be stuck alive with no data and no way to recover except
by manually retrying (this was a real, previously-hit failure mode).
Reauthenticating up front means the subsequent `deleteUserData()` +
`deleteAccount()` sequence isn't at risk of failing partway through for that
reason.

There is no anti-re-registration blocklist anymore — a deleted account's
Google identity can be freely linked or signed into again afterward as a
brand-new profile (see "Deleted-account blocklist removed" below).

**Timeout guards:** on the device(s) this was tested on, `user.delete()`
itself has been observed to hang indefinitely with no exception — a genuine
device/network-flakiness issue (confirmed via a `SocketTimeoutException` in
the platform logs from an unrelated concurrent network call at the same
moment). `user.delete()` is wrapped in a 15-second timeout that surfaces a
real, user-visible error ("Deleting your account is taking longer than
expected...") on timeout, rather than leaving the button silently stuck
forever with no feedback.

**Root-cause fix — widget disposal mid-operation:** the Profile screen's
signed-in gating (see below) depends on the Firestore user doc. The instant
`deleteUserData()` wipes that doc, the live stream backing it emits `null`,
which flips the gate to "not confirmed signed in" and removes
`_DeleteAccountButton` (and `_SignOutButton`) from the widget tree —
disposing their `State` **while their own tap handler is still running**.
Any `ref.read(...)` or `context`-derived object used *after* that point
throws (`Bad state: Cannot use "ref" after the widget was disposed`) and, if
naively guarded with `if (mounted)`, gets silently swallowed — the operation
appears to just do nothing, with no error shown, because the button itself
is gone by the time it would have shown one. Fixed by capturing everything
needed — the `AuthService`/`FirestoreService` instances, plus
`GoRouter.of(context)` and `ScaffoldMessenger.of(context)` — **before**
`deleteUserData()` runs, and using only those captured references
afterward, never `ref`/`context` directly. `_SignOutButtonState` captures
`GoRouter.of(context)` the same way, before `signOut()` runs, for the same
reason (signing out flips `authStateProvider` to `null`, which similarly
removes the button from the tree).

### Live auth state (Profile screen UI)
`authStateProvider` (`lib/providers/auth_provider.dart`) uses
`FirebaseAuth.instance.userChanges()`, not `authStateChanges()` — the latter
only fires on true sign-in/out transitions and misses provider link/unlink
events, which would leave `isAnonymous`-driven UI stale.

**Safety-net gating:** the Profile screen does not treat the account as
signed-in based on Firebase Auth alone. `_ProfileContent` computes
```dart
final confirmedSignedIn = !isAnonymous && user?.isAnonymous == false;
```
— `isAnonymous` from the live `authStateProvider`, `user` from the
Firestore-backed `userProvider(uid)` stream. The signed-in ID card, Sign Out
button, and Delete Account button only appear once **both** sources agree
the account is non-anonymous. This guards against the window where Firebase
Auth has already gone non-anonymous (e.g. `linkWithCredential` succeeding)
but the Firestore `updateUser()` write hasn't landed yet, or failed —
without it, the UI could briefly (or permanently, if the Firestore write
never completes) show a signed-in state with no corresponding confirmed
account data. Any ambiguity resolves to showing the guest UI, never a
premature signed-in one.

### Navigation notes
- **Welcome Brand → Sign In uses `push()`, not `go()`.** `go()` replaces the
  navigation stack, which left `context.canPop()` false on the Sign In
  screen — so its "Maybe Later" button and back icon (which pop if possible,
  else fall back to Home) always fell through to Home instead of back to
  Welcome Brand. `push()` fixes this; Profile screen's own entry points into
  Create Profile / Sign In already used `push()` and were unaffected.
- **Success always navigates forward** (`context.go(kRouteHome)`),
  independent of entry point — this is deliberately *not* symmetric with the
  cancel/"Maybe Later" behavior above. A completed link or sign-in should
  never bounce back to the pre-auth screen it was launched from; only
  explicitly cancelling should do that.

### Onboarding controller — per-uid, not a stale singleton
`onboardingControllerProvider` (`lib/controllers/onboarding_controller.dart`)
watches the live signed-in uid via
`ref.watch(authStateProvider.select((async) => async.value?.uid))` rather
than reading it once. This makes the controller (and its `OnboardingState`)
rebuild fresh whenever the uid actually changes — e.g. Delete Account or
Sign Out followed by a new anonymous session — so answers entered under a
previous account can never leak into, or get submitted under, the next one.
`select()` specifically avoids rebuilding on same-uid token refreshes, which
would otherwise wipe in-progress answers mid-onboarding.

### Deleted-account blocklist — removed
An earlier version recorded a deleted account's Google identity in a
`deletedGoogleAccounts` Firestore collection so `signInWithGoogle()` could
refuse future Sign In attempts with that identity. This has been removed
entirely (`_recordDeletedGoogleAccount`/`_rollbackDeletedGoogleAccountRecord`
in `AuthService`, the `deletedGoogleAccounts` check in `signInWithGoogle()`,
and the corresponding Firestore rules) — a deleted Google identity can now
always be freely re-linked or re-signed-in as a new profile. Do not
reference `deletedGoogleAccounts` as an active collection; see
DATA_SCHEMA.md.

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
