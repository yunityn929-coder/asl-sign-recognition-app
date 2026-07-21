# Overnight Task List — HiASL

Read this file in full before starting. Work through the tasks in order.
Commit after every completed task (not just at the end) with a clear,
specific commit message. Append a short entry to `OVERNIGHT_LOG.md` after
each task — what you did, what you decided, and anything you were unsure
about. Do not guess on ambiguous points; log the question instead and move
on to the next task.

## Ground rules (do not deviate)

- Work only on the `overnight-work` branch. Create it from the current
  `main`/`develop` HEAD if it doesn't exist yet. Never commit directly to
  `main`, never merge `overnight-work` into anything — that's a human
  decision in the morning.
- Never force-push. Never delete files unless a task below explicitly
  calls for it.
- Never touch `firestore.rules`, Firebase project config, signing keys,
  or any CI/deployment config. If a task seems to require it, stop and log
  it instead of proceeding.
- Run `flutter analyze` after any code change and confirm the issue count
  hasn't grown versus the baseline noted in `OVERNIGHT_LOG.md`'s first
  entry (record the starting baseline before you touch anything).
- If something is genuinely ambiguous (a fact you can't verify from the
  repo, a design decision only the project owner can make, a place where
  "actual test output" would require a real device), do not fabricate an
  answer. Write it down in `OVERNIGHT_LOG.md` under a clearly marked
  "NEEDS INPUT" section and move to the next task.
- Do not invent test results for anything that requires a physical
  device or camera input. If a test case needs that, mark its "Actual
  Result" as "Pending — requires device session" rather than filling in
  a number.

---

## Task 1 — Update project docs to match current app state

Go through every doc file in the repo (README, any `/docs` folder,
architecture notes, setup instructions — find them, don't assume a fixed
list) and update them to reflect the current actual state of the app,
including at minimum:

- The lesson/curriculum restructure (Units 1–3 content, random-generation
  lesson types, word-sequence fingerspelling questions, Spell Your Name).
- The onboarding flow (Reason → Level → Goal → Notifications, ending at
  Home; Achievement and Streak Goal interstitials removed).
- Auth model (anonymous by default, Google linking for sign-up, true
  Google sign-in with progress-loss warning for switching accounts,
  one-Google-account-per-profile enforced natively by Firebase).
- Calibration (per-user Firestore-backed, not local-file; Settings entry
  point via Calibration Settings screen; camera-gate serialization fix).
- Practice reminder notifications (local scheduled notification, MYT
  timezone, Settings toggle).
- Any other feature implemented so far that the docs don't currently
  mention — grep commit history / recent changes if needed to find gaps.

Use the docx/xlsx skills only if you're producing something beyond plain
markdown; for repo docs, plain markdown edits are fine.

Commit as: `docs: update project docs to reflect current app state`

---

## Task 2 — CP1 → CP2 redline (comparison, not silent rewrite)

Find the CP1 proposal document in the repo (or ask — if it's not in the
repo, log this under NEEDS INPUT and skip to Task 3, noting the report
can't be drafted without the source document).

For each section of CP1, produce a redline document
(`docs/CP2_redline_from_CP1.md` or `.docx` via the docx skill) with three
columns/parts per section: the original CP1 text, whether it still
matches the current final product, and if not, a suggested replacement
paragraph. Do not overwrite the original CP1 content — this is a
comparison artifact for the project owner to review and manually apply,
not an automatic rewrite of the proposal.

Commit as: `docs: add CP1-to-CP2 redline comparison`

---

## Task 3 — Draft full CP2 report structure

Produce a complete outline/skeleton for the CP2 report (use the docx
skill), covering every section a CP2-stage report typically needs
(introduction/recap, updated literature review if applicable, finalized
requirements, system architecture, implementation details, testing
methodology, test results, UAT plan and results, discussion, conclusion,
appendices) — adapt the exact section list to whatever your institution's
CP2 template/rubric specifies if one exists in the repo; if no template
is found, log that under NEEDS INPUT and use a generic standard structure
instead, clearly marked as a placeholder pending the real template.

Each section should have a one- or two-line note on what content needs to
go there and where in the repo/codebase the supporting material for it
already exists (e.g. "Architecture section — pull from docs/architecture
notes updated in Task 1").

Commit as: `docs: draft CP2 report structure`

---

## Task 4 — SRS-format test cases with traceability

First: locate the finalized requirements and system architecture docs
(should exist after Task 1's doc update). If requirements aren't actually
finalized yet, log that clearly under NEEDS INPUT — this task depends on
it and producing test cases against a moving target isn't useful.

For each functional and non-functional requirement, produce a formal test
case (ID, requirement traced to, preconditions, steps, expected result,
actual result, pass/fail, notes) in a spreadsheet (xlsx skill) so it
reads as a proper traceability matrix.

Split this explicitly into two groups:

- **Automatable now**: anything testable via `flutter test` or
  `integration_test` without a physical device/camera (pure logic —
  lesson progression, XP/streak calculation, Firestore rule behavior if
  mockable, question generation logic, calibration data shape, etc.).
  Actually write and run these tests, and fill in the real "Actual
  Result" from the real test run output. Commit the test files
  themselves alongside the matrix.
- **Requires a device session**: anything involving the camera, MediaPipe
  hand recognition, real notification firing, or manual UI interaction.
  List these fully specified (steps, expected result) but leave "Actual
  Result" as "Pending — requires device session." Do not fabricate a
  result for these.

Commit as: `test: add SRS traceability matrix and automated test suite`

---

## Task 5 — UAT prep (form + distribution asset only, not distribution itself)

Draft the UAT Google Form content as a markdown/docx doc (question list,
suggested question types — rating scales for usability/accuracy/clarity,
open-text for feedback, a section per major feature area) ready to paste
into an actual Google Form (this can't be created programmatically
without interactive Google account access — leave that step for the
project owner).

Build a signed release APK (`flutter build apk --release`) if the
signing config is already set up in the repo; if signing isn't
configured, log that under NEEDS INPUT rather than generating an
unsigned/debug build and calling it release-ready.

Do not attempt to actually distribute the APK or collect responses —
that's outside what an overnight unattended run can meaningfully do.

Commit as: `docs: add UAT form draft and release build`

---

## End of list

After finishing (or hitting a blocker on) every task above, write a
summary at the top of `OVERNIGHT_LOG.md`: which tasks fully completed,
which are partially done pending device/human input, and the final
`flutter analyze` issue count versus the baseline recorded at the start.
