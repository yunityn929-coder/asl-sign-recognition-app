# GESTURE_TESTING_PROTOCOL.md
> How to evaluate real-world MLP model performance and (separately) test
> the full on-device gesture recognition pipeline.
> Companion to: lib/screens/debug/recognition_test_screen.dart,
> lib/services/test_logger_service.dart, docs/analysis/analyze_recognition_log.py,
> asl-gesture-recognition-model/static/live_recognition_test.py

---

## Two ways to test — pick based on what you're checking

| | Laptop webcam script | Phone debug screen |
|---|---|---|
| Script/screen | `asl-gesture-recognition-model/static/live_recognition_test.py` | `lib/screens/debug/recognition_test_screen.dart` |
| Setup cost | `python live_recognition_test.py` — nothing to build | `flutter run` to a physical device, USB debugging |
| Tests | Model accuracy under real (non-training) conditions — MediaPipe Tasks API + TFLite, same config/normalization as the app | The above **plus** the Android-specific integration: hand-rolled YUV420→NV21→JPEG→Bitmap conversion in `HandLandmarkDetector.kt`, the `MethodChannel` round-trip, real phone camera hardware |
| Does NOT test | The Android pipeline glue code, phone camera characteristics | — (this is the full path) |

**Start with the laptop script.** It's the same model, same MediaPipe Tasks
API config, same normalization — it answers "how good is the model
real-world" without a build/deploy cycle. Both scripts write the same CSV
schema (see below), so their outputs can be mixed in one analysis run.

Run the phone screen at least once before calling the feature "physical
device tested" — the YUV→Bitmap conversion in `HandLandmarkDetector.kt` is
custom stride-handling code that's never been exercised outside code review
(see "Why this is needed" below), and that risk is invisible from a laptop
test.

---

## Laptop webcam script — fastest path to model accuracy numbers

```
cd asl-gesture-recognition-model
python static/live_recognition_test.py --session-tag yourname_daylight
```

Requires the packages already in `requirements.txt` (mediapipe, tensorflow,
opencv). Run on Windows, not WSL — same constraint as the existing
`static_data_collection.py` (camera access doesn't work in WSL2 without USB
passthrough).

Controls: press `0`–`9` / `A`–`Z` to set the target sign (ground truth),
`SPACE` to start/pause logging, `S` to export a CSV, `ESC` to quit (auto-
exports unsaved data). Same idea as the phone screen's tap-a-letter grid —
work through all 36 signs per session/condition (see the condition table
below; it applies to both tools). Exports to `C:\HiASL_BSE_FYP_2026\test_data\`
by default.

---

## Why this is needed

BUILD_STATUS.md tracks "Physical device testing" as not done. This matters
more than usual here because:

- `MainActivity.kt` sets `mediaPipeAvailable = false` permanently the first
  time MediaPipe throws (`UnsatisfiedLinkError` on x86_64 — no `.so` shipped
  for emulators). **The emulator cannot exercise this feature at all** — every
  frame silently returns "no hand detected" once that flag flips. Everything
  claimed "✅ Complete" in BUILD_STATUS.md for gesture recognition has only
  been exercised in code review, never on real camera input.
- TECH_STACK.md validation accuracy is 100.00%, explicitly flagged as
  optimistic ("expect lower real-world webcam accuracy due to lighting/angle
  variation"). That gap is unmeasured.
- J and Z use a static PNG instead of the LSTM originally planned (a known,
  documented limitation) — real testing is how you find out how bad that is.

## Phone debug screen — full pipeline validation

### Prerequisites

- A physical Android device, API 26+, with a working front camera.
- USB cable + USB debugging enabled on the device (Settings → About phone →
  tap Build number x7 → Developer options → USB debugging).
- Flutter SDK + `adb` installed on **your own machine** (not this sandbox —
  no USB/network path from here to your phone). Run all commands below from
  your machine's terminal in `asl-sign-recognition-app/`.
- `flutter pub get` after pulling these changes (adds `path_provider`).

### Step 0 — Smoke test (do this first, don't skip)

```
flutter run -d <your-device-id>
```

In the app: Settings → scroll to **Debug** section (only visible in debug
builds — this won't appear in a release build) → **Recognition Test**.

Grant camera permission when prompted. Hold up any hand shape and check the
HUD line at the top of the screen updates with a `top:` label and a
`latency:` number. In a second terminal, tail the log:

```
adb logcat | grep -E "DIAG|Recognition"
```

You should see `[DIAG] Input shape: [1, 63]` / `[DIAG] Output shape: [1, 36]`
once, and repeating `[Recognition] label=... conf=...` lines. If instead you
see `MediaPipe unavailable: ...`, something is wrong with the native build on
that device — stop and debug that before running a full session (all
subsequent data would be garbage).

### Step 1 — Run test sessions

Each session = one full pass over all 36 signs (0–9, A–Z) under one
condition. In the Recognition Test screen:

1. Type a session tag describing tester + condition, e.g. `yuni_daylight`,
   `yuni_dimlight`, `yuni_backcam`, `alex_daylight`.
2. Tap **Start**.
3. Tap a letter/digit in the grid (sets it as the ground-truth target).
4. Hold that sign steadily in frame for ~5 seconds, roughly where you'd
   naturally hold it during a real lesson (comparable distance/angle to
   `exercise_screen.dart`'s camera panel).
5. Tap the next letter in the grid. Repeat for all 36.
6. Tap **Stop**, then **Export**. The on-screen path (also printed to
   logcat as `[TestLogger] wrote N rows to ...`) is directly `adb pull`-able:

```
adb pull "<printed path>" ./test_data/
```

Recommended conditions to cover (run as many as time allows — each is a
separate session/export):

| Condition | Why |
|---|---|
| Good lighting, front camera, normal distance (baseline) | Matches typical lesson usage |
| Dim/low light | Common real usage (bedroom, evening) |
| Closer to camera / farther from camera | Users don't hold phones at a fixed distance |
| Cluttered/bright background | MediaPipe hand detection can degrade |
| Back camera | Sanity check only — front is the documented default |
| A second tester with a different hand size/skin tone if available | Single-tester data won't reveal fairness issues |

Pay particular attention to signs flagged as risky in BUILD_STATUS.md:
**J and Z** (static PNG, no motion modeling), and handshapes that are
visually close (M/N/S/T, A/S/T, K/V, etc.) — these are the most likely
sources of confusion.

## Analyze (either source, or both mixed together)

Copy all exported/pulled CSVs into one folder (default for both tools is
`C:\HiASL_BSE_FYP_2026\test_data\`), then run:

```
python3 docs/analysis/analyze_recognition_log.py test_data/*.csv
```

This prints per-letter accuracy, a confusion matrix, confidence
distribution, and latency stats, and writes `analysis_report.md` +
`confusion_matrix.png` next to the input files. See that script's header for
output details.

## Interpret against targets

From TECH_STACK.md's Performance Targets table:

| Metric | Target | Where to check it |
|---|---|---|
| Feedback latency | ≤ 1000ms | `latency_ms` column covers channel call + MediaPipe + normalize + TFLite — compare against this end-to-end budget, not just the 50ms TFLite-only target |
| Camera framerate | ≥ 15fps | Not captured by this harness (frame processing is throttled to ~10fps by `_kFrameIntervalMs` in `recognition_controller.dart` — that's a deliberate gate on inference calls, separate from camera preview fps) |
| TFLite inference | ≤ 50ms | `latency_ms` is an upper bound on this; if it's consistently >50ms the gap is MediaPipe/channel overhead, not the model itself |

For accuracy, there's no pre-set target in the docs — use the 100% Colab
validation accuracy as the ceiling and report the real-world number as the
delta. A wide gap (e.g. real-world <70%) suggests the training data
(controlled lab photos, `ASL-HG` dataset) doesn't generalize to phone-camera
conditions and may need retraining with in-the-wild data; a narrow gap
suggests the pipeline is basically sound and specific classes (J/Z, or a
handful of confusable letters) are the fix.

## Record findings

Update BUILD_STATUS.md:
- Flip `Physical device testing` from ❌ to ✅ (or ⚠️ with notes) in both the
  Overall Status table and the Gesture Recognition table.
- Add a short note under Known Bugs / Issues for any specific letters/
  conditions found to be unreliable, with the measured accuracy.

## Cleanup note

`RecognitionTestScreen` and its Settings entry point are gated behind
`kDebugMode` — they're compiled out of release builds automatically, no
manual removal needed before shipping. `test_logger_service.dart` and
`recognition_result.dart`'s `latencyMs` field are inert unless this screen is
used.
