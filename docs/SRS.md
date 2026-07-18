# IMPLEMENTATION STATUS NOTE (2026-07-18)
> This SRS describes the original planned requirements.
> See docs/BUILD_STATUS.md for what is actually built.
> Key deviations from this document:
> - Auth: email/password removed entirely — anonymous +
>   Google Sign-In only (see final amendment below)
> - 3D hand models (FR-05/FR-06): replaced with static
>   PNG images in assets/models/3d/. flutter_3d_controller
>   removed from project.
> - Placement test (FR placement section): removed from
>   onboarding flow. ASL level answer now auto-maps to
>   startLessonId directly.
> - Sound effects (FR-33–FR-37): audioplayers in pubspec
>   but not wired — sound effects not implemented.
> - Push notifications (FR-57/FR-58): package present but
>   not implemented beyond permission request.
> - Difficulty-tiered XP: flat kXpLearnCorrect (10) used
>   in practice session — kXpPracticeEasy/Medium/Hard
>   defined but unused.
> - Quiz tab: not in original SRS — added as new feature.
>   See docs/APP_FLOW.md for Quiz screen specs.
> - Bottom nav: Home/Quiz/Signs/Profile
>   (not Home/Quest/Signs/Profile as originally planned)
> - J and Z: static PNG in MLP model, not LSTM.
>   Documented limitation, future work.

---

# SRS.md — Software Requirements Specification
# HiASL: Beginner ASL Learning App

## Project in One Sentence
Android Flutter app that teaches beginners static one-hand ASL signs (A–Z, 0–9) using real-time on-device gesture recognition (MediaPipe + TFLite), interactive 3D hand models, a structured curriculum with placement onboarding, XP/quest motivation system, text-to-speech, sound effects, and session checkout summaries.

---

## Hard Constraints (never violate these)
- Android only, minimum Android 10 (API 29)
- On-device inference only — no camera frames or images leave the device
- Static one-hand signs only — no two-hand, dynamic, or continuous signing
- No custom backend — Firebase Auth + Firestore only
- Flutter + Dart only

---

## Curriculum Structure

Organised into **Sections** (themed groups) → **Lessons** (5–6 signs each).
Section N+1 fully locked until all lessons in Section N completed.
Within a section, lessons are gated sequentially.

**Lesson ID format:** `s{section}l{lesson}` e.g. `s1l1`, `s2l3`

```
SECTION 1 — Foundations
  s1l1: Alphabet A–E         signs: [A,B,C,D,E]
  s1l2: Alphabet F–J         signs: [F,G,H,I,J]
  s1l3: Alphabet K–O         signs: [K,L,M,N,O]
  s1l4: Alphabet P–T         signs: [P,Q,R,S,T]
  s1l5: Alphabet U–Z         signs: [U,V,W,X,Y,Z]
  s1l6: Numbers 0–4          signs: [0,1,2,3,4]
  s1l7: Numbers 5–9          signs: [5,6,7,8,9]

SECTION 2 — Fingerspelling Practice
  s2l1: Short Words (3 letters)    words: [CAT,DOG,SUN,HAT,BIG]
  s2l2: Spell Your Name            user spells their own displayName
  s2l3: Common Words (4 letters)   words: [FISH,BOOK,TREE,BIRD,FROG]
  s2l4: Longer Words (5+ letters)  words: [APPLE,HOUSE,SMILE,WATER,OCEAN]
  s2l5: Speed Challenge            timed mixed-length fingerspelling

SECTION 3 — Numbers in Context
  s3l1: Count 0–9 in order         sequence signs: [0→9]
  s3l2: Random number recognition  10 random numbers flashed
  s3l3: Number pairs               pairs: [(1,2),(3,4),(5,6),(7,8),(9,0)]
  s3l4: Number expressions         signs for common quantities

SECTION 4 — Mixed Review & Mastery
  s4l1: Full Alphabet Review       all 26 letters, random order
  s4l2: Alphabet Speed Run         all 26, Hard difficulty only
  s4l3: Numbers + Letters Mix      mixed set
  s4l4: Mastery Test               30-item random from full set, no retries
```

**Placement start points (set during onboarding):**
| Q1 Answer | Start Point |
|---|---|
| I know no ASL | s1l1 |
| I know the alphabet | s2l1 |
| I can have a basic ASL conversation | s3l1 |
| Placement test ≥ 80% | advance one section beyond Q1 answer |
| Placement test < 80% | use Q1 answer start point |

---

## Functional Requirements

### Authentication
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-01 | Register with email + password | Account in Firebase Auth; user doc in Firestore |
| FR-02 | Login and logout | Session persists across restarts; logout clears session |

### Onboarding (shown once, on first login only)
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-19 | New users complete Q&A onboarding before accessing Home | Flag `onboardingComplete: true` written to Firestore on finish |
| FR-20 | Q1 — ASL experience level | Options: "I know no ASL" / "I know the alphabet" / "I know numbers too" / "I can have a basic ASL conversation" → stored as `aslLevel` |
| FR-21 | Q2 — Daily learning goal | Options: "5 minutes" / "10 minutes" / "15 minutes" → stored as `dailyGoalMinutes` |
| FR-22 | Q3 — Notification opt-in | Explain reminder benefit → request Android POST_NOTIFICATIONS permission → store result |
| FR-23 | Q4 — Starting point | "Start from scratch" or "Find my level" |
| FR-24 | "Start from scratch" → place user at Q1 answer start point, navigate to Home | Correct lesson unlocked |
| FR-25 | "Find my level" + Q1 = "I know no ASL" → treat as "Start from scratch" | No test needed for zero knowledge |
| FR-26 | "Find my level" + Q1 ≠ "I know no ASL" → run 10-item placement test | Placement test is Practice session (Hard, no skip) from Q1 start section |
| FR-27-placement | Placement ≥ 8/10 → advance one section; < 8/10 → Q1 start point | Navigate to Home after; no XP; no checkout |

### Curriculum & Lesson System
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-03 | Progress, lesson status, streak, XP persist across sessions | Data survives app close/reopen |
| FR-04 | Lessons gated within section; sections gated sequentially | Locked items visually distinct and non-tappable |
| FR-27 | Home organised by Section → Lesson | Sections shown as collapsible cards; active section expanded by default |

### 3D Hand Model
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-05 | Each sign has a 3D hand model in Learn mode | Correct `.glb` loads for active sign |
| FR-06 | User can rotate and zoom 3D model | Drag rotates; pinch zooms; zoom clamped |

> ❌ NOT IMPLEMENTED AS SPECIFIED (FR-05, FR-06) — replaced with static PNG
> images (assets/models/3d/{SIGN}.png, all 36 signs).

### Gesture Recognition
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-07 | Camera permission requested before recognition activates | Dialog on first use; denied state handled gracefully |
| FR-08 | Real-time recognition of one-hand static signs | ≥15fps on target hardware |
| FR-09 | Correctness feedback shown after each attempt | Within 1.0s of gesture |
| FR-10 | Finger-state guidance in Learn mode on incorrect attempt | At least one specific instruction shown + spoken |
| FR-14 | Session-based recognition | Single activation per session; runs until session ends |
| FR-17 | Contextual hint on low hand detection quality | Message shown; no penalty |

### Text-to-Speech (TTS)
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-28 | Sign labels and prompts read aloud when displayed | TTS fires on each new sign/prompt appearing on screen |
| FR-29 | Onboarding question text read aloud on screen entry | TTS on each onboarding card |
| FR-30 | Feedback messages read aloud | "Correct!", guidance text, "Time's up" all spoken |
| FR-31 | Section/lesson titles read aloud when tapped | TTS on card tap |
| FR-32 | TTS toggle in Settings | Default ON; persisted to Firestore |

### Sound Effects
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-33 | Correct attempt → success chime | Short positive sound |
| FR-34 | Incorrect attempt → soft error tone | Non-jarring sound |
| FR-35 | Session checkout → completion fanfare | Celebratory sound on checkout screen entry |
| FR-36 | XP awarded → XP gain sound | Coin/sparkle sound plays alongside XP animation |
| FR-37 | Sound effects toggle in Settings | Default ON; persisted to Firestore |

> ❌ NOT IMPLEMENTED (FR-33–FR-37) — audioplayers package in pubspec.yaml
> but zero imports in lib/. Sound assets exist in assets/audio/ but are never played.

### Practice Mode
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-11 | Random question set from lesson signs, no duplicates | N items drawn without repetition |
| FR-12 | Difficulty: Easy / Medium / Hard | Each maps to distinct time limit |
| FR-13 | Time limit enforced per item; timeout handled | Marked missed; auto-advance |
| FR-15 | Auto-advance on correct attempt | No tap needed |
| FR-16 | Session checkout shown after session | See checkout spec |

### Session Checkout
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-38 | Checkout shown after every Learn and Practice session | Full-screen summary before returning to Home |
| FR-39 | Shows total XP earned this session | Animated counter from 0 to earned amount |
| FR-40 | Shows accuracy percentage | e.g. "85% accuracy" |
| FR-41 | Shows session duration | e.g. "3 min 24 sec" |
| FR-42 | Shows streak status | Current streak + "Streak extended!" if applicable |
| FR-43 | Shows daily quest progress | Progress bar per quest |
| FR-44 | Fanfare sound + animation on checkout entry | FR-35 triggered here |

### XP System
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-45 | XP for correct sign in Learn mode | +10 XP per correct sign |
| FR-46 | XP for correct sign in Practice mode | +15 XP Easy / +20 XP Medium / +25 XP Hard |
| FR-47 | Bonus XP for perfect session (100% accuracy) | +50 XP bonus |
| FR-48 | Bonus XP for streak milestones (every 7 days) | +100 XP on day 7, 14, 21, … |
| FR-49 | Total XP on user profile; shown on Home | XP counter in app bar |
| FR-50 | XP never decreases | Additive only |

### Daily Quests
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-51 | 3 daily quests generated each day; reset at midnight local time | New quests available daily |
| FR-52 | Quest types: Complete N lessons / Earn N XP / Practice N sessions / Get N correct in a row | At least 2 of 3 from this pool each day |
| FR-53 | Quest progress tracked in real-time; updated on checkout | Progress bar reflects current count |
| FR-54 | Completing a quest awards +30 XP | XP added immediately; sound plays |
| FR-55 | Daily quests visible on Home screen | Horizontal card strip below section list |
| FR-56 | Completed quests show checkmark; in-progress show bar | Visual state clear |

### Streak & Notifications
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-18 | Streak tracked daily | Increments on any session completion today; resets if day missed |
| FR-57 | Daily practice push notification if permission granted | Sent at 7pm local time if no activity today |
| FR-58 | Notification suppressed if user already practiced today | Check `lastStreakDate` before sending |

---

## Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-01 | Performance | Feedback latency ≤ 1.0s end-to-end |
| NFR-02 | Accuracy | Recognition ≥ 85% for one-hand static signs indoors |
| NFR-03 | Usability | Usable by zero-experience beginners |
| NFR-04 | Learnability | In-app guidance on first camera use |
| NFR-05 | Reliability | No frequent crashes during camera sessions |
| NFR-06 | Availability | Auth/sync needs internet; learning + recognition offline-capable |
| NFR-07 | Privacy | Raw camera images/video never stored (MUST) |
| NFR-08 | Privacy | Recognition fully on-device |
| NFR-09 | Security | Firestore data accessible only to authenticated user |
| NFR-10 | Transparency | Camera permission rationale shown before requesting |
| NFR-11 | Audio | TTS and sound effects must not block UI interaction (run async) |
| NFR-12 | Accessibility | Readable fonts; sufficient colour contrast |
| NFR-13 | Maintainability | Modular; features independently replaceable |
| NFR-14 | Compatibility | Android 10+; requires camera |

---

## Learn Mode — Exact Behaviour
1. User selects lesson → taps "Learn"
2. TTS reads lesson title; session timer starts
3. First sign loads: 3D model + TTS reads sign name + camera activates
4. Recognition runs continuously (session-based)
5. Correct → success sound + TTS "Correct!" + +10 XP (XP sound) → 1.5s → next sign
6. Incorrect → error sound + finger-state guidance shown + TTS reads guidance
7. Low detection → hint shown; no sound; no penalty
8. Final sign done → navigate to Checkout (S-12) → then S-08 (completion) on dismiss

## Practice Mode — Exact Behaviour
1. User selects completed lesson → "Practice" → selects difficulty
2. Random question set; session timer starts
3. Each item: TTS reads sign name immediately on load
4. Correct → success sound + TTS "Correct!" + XP sound → 0.8s → next item
5. Timeout/Skip → error sound + TTS "Time's up" → 0.8s → next item
6. All items done → navigate to Checkout (S-12)

## Placement Test — Exact Behaviour
> ❌ REMOVED FROM FLOW — placement test screens are orphaned
> (unrouted). Level selection now auto-maps to startLessonId.
> See onboarding_level_screen.dart for mapping logic.

1. 10 random signs from entry-level section for Q1 answer
2. Runs as Practice session: Hard difficulty, no skip button, no TTS prompt (test conditions)
3. Score ≥ 8/10 → advance one section; < 8/10 → Q1 start point
4. No XP awarded; checkout skipped; navigate directly to Home

## Session Checkout — Exact Behaviour
1. Full-screen overlay; fanfare sound plays
2. Animate XP counter from 0 → session XP earned
3. Show accuracy %, session duration, streak status, quest progress bars
4. If any quest completed during session → show completion badge + TTS "Quest complete!"
5. "Continue" button → dismiss to Home (or S-08 if coming from Learn)

---

## Out of Scope
- Two-hand signs
- Dynamic / moving signs
- Continuous sign language recognition
- iOS support / Web support
- Custom ML training pipeline (model pre-trained, bundled as `.tflite`)
- Social features, leaderboards
- In-app purchases
- User-created lessons

> NOTE: Quiz tab (Kahoot-style) was added in development despite not being
> in original scope. See docs/APP_FLOW.md Quiz Tab section for full spec.

---
## Amendment — Quick Authentication (appended)

### Authentication — Revised FRs

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-01 | Google Sign-In | One-tap Google auth via `google_sign_in` + Firebase credential; new users get Firestore doc created automatically |
| FR-01b | Guest / Anonymous Sign-In | `FirebaseAuth.signInAnonymously()`; user starts immediately with no form; Firestore doc created with `isGuest: true` |
| FR-01c | Email Sign-Up | Display Name + Email + Password on same screen as login; no separate register screen |
| FR-02 | Email Log In | Email + password; inline error; forgot password sends reset email |
| FR-02b | Guest Account Conversion | Guest user can link Google or Email credential to their anonymous account at any time via S-18; all progress preserved (same UID) |
| FR-02c | Guest banner | Persistent yellow banner on Home (S-09) and Settings (S-17) reminding guest to save account |

### Priority of auth methods on S-02
1. Google Sign-In (top, largest button)
2. Guest / Anonymous (second button)
3. Email Log In / Sign Up (below divider, tab-toggled)

---
## Amendment — No-Login-First Approach (appended)

### Core Philosophy Change
Users access the full app immediately with no login required.
Firebase Anonymous Auth runs silently in the background on first launch.
Login (Google) is only required for social/leaderboard features.

### Revised Authentication FRs

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-01 | Silent anonymous auth on first launch | `FirebaseAuth.signInAnonymously()` called automatically; user sees nothing |
| FR-01b | Google Sign-In | Available only when user taps a locked social feature |
| FR-01c | Email Sign-Up/Login | Removed — not needed |
| FR-02 | Account linking | Anonymous → Google via `linkWithCredential()`; all progress preserved |
| FR-02b | No forced login screen | App never shows login screen unless user taps a social feature |

### Welcome Screens (NEW)
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-60 | Welcome screens shown on first launch only | 2-3 swipeable illustration screens before onboarding |
| FR-61 | Welcome screen 1 | "Welcome to HiASL" + app tagline + illustration |
| FR-62 | Welcome screen 2 | "Learn ASL at your own pace" + feature highlights |
| FR-63 | Welcome screen 3 | "Track your progress every day" + streak/XP preview |
| FR-64 | "Get Started" button on last welcome screen | Navigates to onboarding Q&A |
| FR-65 | Skip button on welcome screens | Skips to onboarding Q&A |

### Social / Leaderboard (Login Gate)
| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-66 | Leaderboard screen exists but is login-gated | Shows preview with blur/lock; "Login to join" button |
| FR-67 | Tapping "Login to join" → Google Sign-In flow | Links anonymous account to Google; unlocks leaderboard |
| FR-68 | All other features work without login | Lessons, practice, XP, streak, quests — fully local via anonymous Firebase |

### Storage Strategy
- **Primary:** Firebase Firestore via anonymous UID (same as before)
- **No SQLite** — single storage system only
- **Anonymous UID persists** across app restarts automatically
- **Data survives** app reinstall only if user has linked Google account
- **Unlinked anonymous data** is lost on reinstall — acceptable trade-off for zero-friction onboarding
- Add subtle "Back up your progress" nudge in Settings after 7 days of activity

### Out of Scope (removed)
- Email/password registration and login — removed entirely
- Guest banner — replaced by silent anonymous approach (no banner needed)
- S-18 Convert Guest Account screen — replaced by inline login gate on leaderboard
