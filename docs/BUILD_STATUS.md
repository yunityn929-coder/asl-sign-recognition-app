# BUILD_STATUS.md
> Tracks what is actually built vs planned vs changed vs pending.
> Update this file whenever a feature is completed or scope changes.
> Last updated: 2026-07-24

---

## Overall Status

| Area | Status |
|------|--------|
| Onboarding flow | ✅ Complete |
| Lesson flow (learn + quiz) | ✅ Complete |
| Gesture recognition | ✅ Complete |
| Practice flow | ✅ Complete |
| Checkout flow | ✅ Complete |
| Quiz tab | ✅ Complete |
| Signs dictionary | ✅ Complete |
| Streak screen | ✅ Complete |
| Quest screen | ✅ Complete |
| Profile screen | ✅ Complete |
| Settings screen | ✅ Complete |
| Auth (Create Profile / Sign In / Sign Out / Delete Account) | ✅ Complete — see TECH_STACK.md Auth Flow section |
| Gamification (medals/badges) | ✅ Complete — see GAMIFICATION.md |
| Firebase backend | ✅ Complete |
| Firestore security rules | ✅ Deployed |
| Sign PNG assets (A-Z + 0-9) | ✅ Complete (all 36) |
| Leaderboard | ⚠️ Placeholder only |
| Sound effects | ❌ Not wired |
| Push notifications | ❌ Not wired |
| Physical device testing | ❌ Not done yet |

---

## Screens

### ✅ Built and working

| Screen | File | Route |
|--------|------|-------|
| Splash | splash_screen.dart | / |
| Welcome (brand/intro/preview) | welcome_*.dart | /welcome/* |
| Onboarding (level/goal/notif/achievement) | onboarding_*.dart | /onboarding/* |
| Streak Goal | streak_goal_screen.dart | /onboarding/streak-goal |
| Home | home_screen.dart | /home |
| Mode Select | mode_select_screen.dart | /lesson/:id/mode |
| Exercise (learn + quiz) | exercise_screen.dart | /lesson/:id/exercise |
| Results | results_screen.dart | /lesson/:id/results |
| Practice Setup | practice_setup_screen.dart | /lesson/:id/practice/setup |
| Practice Session | practice_session_screen.dart | /lesson/:id/practice/session |
| Checkout | checkout_screen.dart | /session/checkout |
| Streak Born | streak_born_screen.dart | /session/streak |
| Quiz Home | quiz_screen.dart | /quiz |
| Quiz Session | quiz_session_screen.dart | /quiz/session |
| Quiz Result | quiz_result_screen.dart | /quiz/result |
| Signs Dictionary | signs_screen.dart | /signs |
| Streak | streak_screen.dart | /streak |
| Quest | quest_screen.dart | /quest |
| Profile | profile_screen.dart | /profile |
| Settings | settings_screen.dart | /settings |
| Leaderboard (gate only) | leaderboard_screen.dart | /leaderboard |
| Create Profile (Link Google) | link_account_screen.dart | /login/link |
| Sign In (Switch Google account) | sign_in_screen.dart | /login/signin |

### ⚠️ Orphaned (file exists, not routed)

| Screen | File | Notes |
|--------|------|-------|
| Onboarding Start | onboarding_start_screen.dart | Removed from flow — level now auto-maps |
| Placement Test | placement_test_screen.dart | Removed — camera never wired |
| Placement Result | placement_result_screen.dart | Removed — replaced by level mapping |
| Learn Screen | learn_screen.dart | Dead route — exercise_screen used instead |
| Learn Completion | learn_completion_screen.dart | Dead route — results_screen used instead |

### ❌ Not built

| Screen | Notes |
|--------|-------|
| Leaderboard (real) | Data model missing, no Firestore collection |

---

## Features Built Differently Than Originally Planned

| Feature | Original Plan | What Was Actually Built |
|---------|--------------|------------------------|
| 3D hand models | .glb files via flutter_3d_controller | PNG images in assets/models/3d/ |
| Placement test | Camera-based sign recognition quiz | Removed — level selection auto-maps to startLessonId |
| J and Z recognition | LSTM model for dynamic signs | Static PNG in MLP — documented limitation |
| Bottom nav | Home / Quest / Signs / Profile | Home / Quiz / Signs / Profile (Quest moved to Home card) |
| Learn mode end | → Checkout flow | → Results screen (separate from practice checkout) |
| PracticeSessionController | Separate controller class | Logic inline in State fields |

---

## Navigation Flows

### Learn mode flow
```
Home → Mode Select → Exercise Screen → Results Screen → Home
```

### Practice mode flow
```
Home → Mode Select → Practice Setup → Practice Session
     → Checkout → (Streak Born if streak) → Quest Update → Home
```

### Onboarding flow (new users)
```
Splash → Welcome Brand → Welcome Intro → Welcome Preview
       → Onboarding Level → Goal → Notifications → Achievement
       → Streak Goal → Home
```

Level → startLessonId mapping:
- none (new) → s1l1
- some → s1l3
- alphabet → s2l1
- conversational → s3l1

---

## Firestore Collections

| Collection | Status | Notes |
|-----------|--------|-------|
| users/{uid} | ✅ Active | UserModel, 20+ fields including signAccuracy |
| users/{uid}/lessons/{id} | ✅ Active | Progress per lesson |
| users/{uid}/practiceResults/{id} | ✅ Active | Written after every session |
| users/{uid}/dailyQuests/{date} | ✅ Active | Generated daily, 3 quests |
| leaderboard/ | ❌ Not created | Future work |

---

## XP Constants (lib/core/constants/xp_constants.dart)

| Constant | Value | Wired? |
|----------|-------|--------|
| kXpLearnCorrect | 2 | ✅ Per correct answer — the only XP source for both learn and practice sessions (no flat completion bonus) |
| kXpPracticeEasy/Medium/Hard | 15/20/25 | ❌ Defined but never used |
| kXpPerfectBonus | ? | ❌ Never awarded |
| kXpStreakBonus | 100 | ✅ Used — one-time bonus on first reaching a 7-day streak |
| kStreakGoalXp | 100/250/500/1000 | ❌ Never awarded |

Session XP = `correctAnswers * kXpLearnCorrect`. A 5-question, all-correct
session awards exactly 10 XP. `kXpLessonCompletion` (a flat per-completion
bonus regardless of correctness) has been removed entirely.

---

## Quest Types (lib/data/quest_pool.dart — kQuestPool)

| Type | Target | xpReward | Tracked in |
|------|--------|----------|------------|
| high_score_lessons | 3 lessons scored ≥90% | 10 | exercise_screen.dart (`_finishLesson`) only — practice sessions don't count. Progress only increments when that lesson's `correctCount / totalCount * 100 >= 90`; lessons finished below 90% don't count toward the 3 |
| spend_minutes | `user.dailyGoalMinutes` (the onboarding daily-goal answer), in seconds | 10 | exercise_screen.dart, practice_session_screen.dart, quiz_session_screen.dart — every session type accumulates its wall-clock duration |
| earn_xp | 100 XP | 20 | exercise_screen.dart, practice_session_screen.dart, quiz_session_screen.dart |

`spend_minutes`'s target/progress are stored in **seconds** internally (so
short sessions still accumulate precisely) and formatted as whole minutes on
the Quest screen. Its target is resolved per-user from `dailyGoalMinutes`
(5/10/15/20, set on the onboarding "daily learning goal" screen) at
generation and reconciliation time — `FirestoreService._resolveTarget()`.

Quests use a tap-to-collect model: reaching `target` sets `completed: true`
but does **not** credit XP. The Quest screen shows a treasure-chest button
per quest (muted while in progress, a red dot once `completed`); tapping it
while ready calls `FirestoreService.collectQuestReward()`, which atomically
sets `collected: true` and increments `totalXp` by the quest's `xpReward` in
a single transaction, then shows a short "Reward Collected! +N XP" dialog.
No XP value is shown on the quest cards themselves — only on collection.

---

## Sign Assets

| Signs | Status |
|-------|--------|
| 0–9 (digits) | ✅ PNG available |
| A–Z (all letters) | ✅ PNG available |
| Total | 36/36 complete |

Path: `assets/models/3d/{SIGN}.png`
Referenced via: `kSignImagePath` in `lib/services/quiz_service.dart`
Used in: learn_mode_body.dart, signs_screen.dart, quiz_session_screen.dart

---

## Gesture Recognition

| Component | Status | Notes |
|-----------|--------|-------|
| MediaPipe HandLandmarker | ✅ | Tasks API 0.10.35, hand_landmarker.task |
| MLP model (TFLite) | ✅ | mlp_model.tflite 75.7KB, [1,63]→[1,36] |
| Normalization | ✅ | wrist subtract + landmark 9 scale |
| FeedbackService | ✅ | 5-frame debounce, 5 states |
| FeedbackWidget | ✅ | Pill overlay on camera |
| Real device testing | ❌ | Not done yet |

---

## Known Bugs / Issues

- **"Switch account?" progress-loss warning dialog (`SignInScreen`)** —
  one investigation thread reported the dialog not appearing under
  conditions where the current anonymous account should have had progress.
  Never cleanly resolved — repro attempts were confounded by messy,
  multi-session device logs. The dialog logic itself
  (`_confirmSwitchIfProgressAtRisk()` in `sign_in_screen.dart`) checks
  `totalXp > 0 || currentStreak > 0 || signAccuracy.isNotEmpty` and appears
  correct on inspection; treat as unconfirmed until a clean isolated repro
  is captured.
- **streakGoalAchieved** — never set to true by any code path
  (updateStreakIfNeeded does not flip it)
- **difficulty-tiered XP** — kXpPracticeEasy/Medium/Hard defined
  but flat kXpLearnCorrect used in practice session instead
- **practiceResults items array** — always written as [],
  per-sign timing never tracked
- **SoundService** — audioplayers package in pubspec but zero
  imports in lib/ — sound effects never play
- **J and Z** — static PNG in MLP, may confuse with similar
  handshapes in real-world use

---

## Pending

- [ ] Physical device testing (gesture recognition)
- [ ] Leaderboard implementation
- [ ] LSTM for J and Z (future)
- [ ] Expand to simple words (future)
- [ ] Wire sound effects (audioplayers)
- [ ] Wire push notifications (flutter_local_notifications)
- [ ] Difficulty-tiered XP in practice session
- [ ] streakGoalAchieved flip logic
