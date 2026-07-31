# Debug data-collection screen for fine-tuning dataset capture

Date: 2026-07-31
Status: Approved

## Purpose

A temporary, debug-only developer tool to capture real, personally-captured
feature vectors for fine-tuning the gesture recognition model. Not part of
the learner-facing app flow — same reachability model as the existing
`RecognitionTestScreen`: registered as a route, but only reachable via a
`kDebugMode`-gated entry in Settings, so it never appears in release builds.

Captures the exact 80-value feature vector (63 raw normalized landmarks + 17
engineered features) that `RecognitionController` computes for live
inference, tagged with a target sign label and timestamp, and appends it as
one JSON Lines record to a session file in the app's external/documents
directory for later `adb pull` and offline fine-tuning.

## Non-goals

- Not wired into any user-facing screen, home flow, or navigation the
  learner can reach.
- Not a replacement for `CalibrationScreen` (per-user calibration) or
  `RecognitionTestScreen` (live accuracy/latency diagnostics) — this tool's
  only job is exporting raw training/held-out-test feature vectors.
- No on-device training or evaluation — export only.
- No enforcement of literal train/test non-overlap at the data level (see
  "Train/held-out separation" below) — separation is structural (distinct
  capture passes, distinct files), not deduplicated.

## Architecture

### New files

- `lib/screens/debug/data_collection_screen.dart` — capture UI, a
  `ConsumerStatefulWidget` modeled directly on `CalibrationScreen`'s
  camera-init/dispose/capture scaffolding (including the same `CameraGate`
  chaining behavior for safe handoff with other camera-using screens).
- `lib/services/feature_vector_export_service.dart` — owns session file
  lifecycle: resolves the export directory, creates the two per-session
  files lazily on first capture in each mode, and appends one JSON line per
  captured sample.

### Touched files

- `lib/controllers/recognition_controller.dart` — rename
  `_computeEngineeredFeatures` to `computeEngineeredFeatures` (drop the
  leading underscore only; no logic change) so it's importable from the new
  service. This is the single source of truth for the 17 engineered
  features on both the live inference path and this export tool.
- `lib/router.dart` — add a `GoRoute` for the new screen, same shape as the
  existing `kRouteDebugRecognitionTest` entry (root navigator key, no
  shell).
- `lib/core/constants/route_constants.dart` — add
  `kRouteDebugDataCollection` / `kRouteNameDebugDataCollection`.
- `lib/screens/settings/settings_screen.dart` — add a second `ListTile`
  ("Data Collection") under the existing `if (kDebugMode)` Debug section,
  next to "Recognition Test".

## Feature vector computation (must match live inference exactly)

`RecognitionResult.landmarks` (populated in
`RecognitionControllerImpl._infer`, `recognition_controller.dart:528`) is
already the 63-value normalized landmark vector used for live inference —
same centering (subtract wrist), same scaling (divide by norm of landmark
9), same left-hand mirroring already applied upstream in `processFrame`.
The capture screen listens to `recognitionControllerProvider.results`
exactly as `CalibrationScreen` does, so it receives this same vector for
free.

The 17 engineered features are produced by calling the newly-public
`computeEngineeredFeatures(result.landmarks)` — the exact function used by
`_infer`, no reimplementation.

Exported vector: `[...result.landmarks, ...computeEngineeredFeatures(result.landmarks)]`
— 80 values, same order as `_infer`'s `combined` local.

## Capture flow

- Segmented control at the top of the screen: **Train** / **Held-out
  Test**, defaulting to Train. Switching modes does not reset per-sign
  progress in the other mode — each mode tracks its own captured-count map
  independently for the lifetime of the screen.
- Below that: quick-jump horizontal bar of all 36 `kSignLabels` (reused
  pattern from `CalibrationScreen._buildQuickJump`), current-sign header,
  and a "Captured: N/target" counter, where target is 15 for Train and 10
  for Held-out Test.
- **Capture** button: if `result.handDetected && result.landmarks.isNotEmpty`,
  builds the 80-vector, appends one JSON line to that mode's session file,
  increments that mode's counter for the current sign. Otherwise shows the
  same snackbar `CalibrationScreen` uses: "Hold the sign steady, then try
  again."
- Reaching the per-sign target for the active mode **auto-advances** to the
  next label in `kSignLabels`. **Skip** and **Back** buttons remain
  available for manual override in either direction.
- After the 36th sign's target is reached (or is manually skipped past),
  the screen shows a "session complete" state for that mode instead of
  wrapping back to the first sign.

## Train / held-out separation

Separation between the two capture sets is structural, not data-level:

- Each mode has its own physical output file, with a distinct filename
  prefix (`train` vs `test`), so a file can never be mistaken for the other
  kind after `adb pull`.
- Each mode's 36-sign x N-samples pass is a deliberate, separate capture
  session performed by the developer (e.g. do a full Train pass one day,
  a full Held-out Test pass in a separate sitting/pose variation).
- No landmark-level deduplication or similarity check is performed between
  modes — this tool does not attempt to detect or prevent a developer from
  capturing near-identical poses in both modes. That is an operational
  discipline concern (vary hand pose/angle slightly between the two
  passes), not something enforceable from a single video frame's feature
  vector.

## File output

- Format: JSON Lines. One file per mode per screen session (a "session" =
  one lifetime of the `DataCollectionScreen` widget instance — reopening
  the screen starts fresh files).
- Each line:
  ```json
  {"label":"A","mode":"train","timestamp_ms":1234567890,"features":[0.01,-0.02,...]}
  ```
  (`features` has exactly 80 elements.)
- Written immediately on every capture (no buffer-then-export step) — data
  survives an app crash or force-close mid-session, unlike
  `TestLoggerService`'s buffer-then-export pattern.
- Directory resolution mirrors `TestLoggerService.exportCsv`:
  `getExternalStorageDirectory()` (adb-pullable without `run-as` on most
  devices) falling back to `getApplicationDocumentsDirectory()`. Android/iOS
  only — this tool has no desktop use case, so the desktop branch in
  `TestLoggerService` is not replicated.
- Filenames:
  `hiasl_datacollect_train_<sessionTimestampMs>.jsonl`
  `hiasl_datacollect_test_<sessionTimestampMs>.jsonl`
  Files are created lazily — a mode with zero captures in a session
  produces no file.

## Error handling

- No hand detected on capture → snackbar, no file write, no counter
  increment (matches `CalibrationScreen`).
- File write failure (e.g. storage unavailable) → snackbar with the error,
  captured sample is lost for that attempt (consistent with this being a
  best-effort dev tool, not a production data path).
- Camera init failure → same silent-log-and-continue behavior as
  `CalibrationScreen._initCamera`'s catch block.

## Testing

No unit tests — consistent with `CalibrationScreen` and
`RecognitionTestScreen`, neither of which has tests, since the core logic
is camera/native-hand-tracking dependent. Verification is manual: run the
app, capture a few samples per sign in each mode, confirm `.jsonl` files
land in the expected directory with correct content via `adb pull`, and
spot-check that a captured `features` array matches what
`recognition_controller.dart` logs via its existing `[DIAG] Model input:`
debug print for the same pose.

## Retrieving captured files

Package ID (confirmed from `android/app/build.gradle.kts`): `com.hiasl.app`.

Preferred path — `getExternalStorageDirectory()` resolves to
`/sdcard/Android/data/com.hiasl.app/files/` on Android, which is
`adb pull`-able without `run-as` on most devices:

```
adb pull /sdcard/Android/data/com.hiasl.app/files/hiasl_datacollect_train_<ts>.jsonl .
adb pull /sdcard/Android/data/com.hiasl.app/files/hiasl_datacollect_test_<ts>.jsonl .
# or pull everything captured so far:
adb pull /sdcard/Android/data/com.hiasl.app/files/ ./hiasl_datacollect/
```

Fallback path — only used if `getExternalStorageDirectory()` returns null
(app-internal docs dir, requires `run-as`, matching
`TestLoggerService.exportCsv`'s same fallback):

```
adb shell run-as com.hiasl.app ls files
adb shell run-as com.hiasl.app cat files/hiasl_datacollect_train_<ts>.jsonl > hiasl_datacollect_train_<ts>.jsonl
```

Exact filenames (with their session timestamps) will be shown on-screen
after each capture, and confirmed again in this conversation once the
screen is built and run at least once on-device.
