# GAMIFICATION.md — Medals / Badges
# HiASL

Covers the medal/badge system layered on top of practice sessions. This is
separate from XP, streaks, and daily quests (see DATA_SCHEMA.md /
APP_FLOW.md for those) — medals track per-lesson, per-difficulty mastery.

---

## Data Model

`medalsEarned: Map<String, bool>` on `users/{uid}` (see DATA_SCHEMA.md's User
Document section). Keyed `"{lessonId}_{difficulty}"`, e.g. `"s1l1_easy"`,
`"s2l3_hard"`. A key is present with value `true` once that lesson has been
awarded a medal at that difficulty; keys are never written `false` or
removed — absence means "not earned."

**Award logic** — `FirestoreService.awardMedalIfEligible()`
(`lib/services/firestore_service.dart`):

```dart
Future<bool> awardMedalIfEligible({
  required String uid,
  required String lessonId,
  required String difficulty,
  required bool allCorrect,
}) async {
  if (!allCorrect || difficulty == 'n/a') return false;
  final key = '${lessonId}_$difficulty';
  final snap = await _db.collection('users').doc(uid).get();
  final existing = (snap.data()?['medalsEarned'] as Map?)?[key] == true;
  if (existing) return false;
  await _db.collection('users').doc(uid).update({'medalsEarned.$key': true});
  return true;
}
```

- Only awarded from a **Practice session** (`difficulty` is `'easy'` /
  `'medium'` / `'hard'` — `'n/a'`, used by Learn-mode sessions, never earns a
  medal).
- Only awarded when **every question in that session was answered
  correctly** (`allCorrect`) — a single miss means no medal that attempt.
- Only awarded **once** per `lessonId`+`difficulty` combination — replaying
  an already-medaled lesson+difficulty with another perfect run returns
  `false` and writes nothing. There is no un-earning; the map only grows.
- Best-effort: a `FirebaseException` on the update returns `false` rather
  than throwing — a failed medal write never blocks navigation to Checkout.
- Called from `practice_session_screen.dart`'s `_finishSession()`, wrapped
  in its own `try`/`catch` (swallows any exception) so a medal-award failure
  can never break the rest of session completion (XP, streak, quest
  updates all proceed independently).

---

## Tiers

| Difficulty | Medal | Color constant | Value |
|---|---|---|---|
| easy | Bronze | `AppColors.medalBronze` | `0xFFCD7F32` |
| medium | Silver | `AppColors.medalSilver` | `0xFFB0B0B8` |
| hard | Gold | `AppColors.medalGold` | `0xFFFFD700` |

(`lib/core/constants/app_colors.dart`)

---

## Where Medals Surface in the UI

### Home screen — total medal count (`home_screen.dart`)
`_MedalBadge` in the app bar, next to the XP badge: a gold trophy icon +
`user.medalsEarned.values.where((v) => v).length` (total medals earned
across every lesson and difficulty, not per-lesson). Pill-styled to match
`_XpBadge`.

### Practice Setup screen — per-difficulty indicator (`practice_setup_screen.dart`)
Each `_DifficultyCard` (Easy/Medium/Hard) shows a small trophy icon in the
tier's color immediately beside the difficulty label (same line, e.g. right
next to "Easy") when `medalsEarned['${lessonId}_$difficulty'] == true` for
*that specific lesson* — i.e. this is a per-lesson, per-difficulty check,
distinct from Home's aggregate total. `medalColor` is passed in per card:
`AppColors.medalBronze` (easy), `medalSilver` (medium), `medalGold` (hard).

### Checkout/Results screen — inline congratulatory dialog (`checkout_screen.dart`)
When a practice session finishes, `PracticeSessionScreen` builds a
`CheckoutData` with `medalNewlyEarned: bool` (the return value of
`awardMedalIfEligible()`) and pushes `CheckoutScreen`. If `medalNewlyEarned`
is true, `_CheckoutScreenState.initState()` schedules `_showMedalDialog()`
via `addPostFrameCallback`, guarded by a `_medalDialogShown` flag so it only
ever shows once per screen instance.

The dialog is a plain `AlertDialog` — **not** a separate full-screen route:
```dart
AlertDialog(
  icon: Icon(Icons.emoji_events_rounded, color: spec.color, size: 30),
  title: Text(spec.label),                 // e.g. "Bronze Medal"
  content: Text("Congratulations! You've earned a ${...} medal."),
  actions: [TextButton('Continue')],        // always AppColors.primary blue
)
```
`_kMedalSpecs` maps difficulty → `(label, color)`: `easy` → `('Bronze
Medal', medalBronze)`, `medium` → `('Silver Medal', medalSilver)`, `hard` →
`('Gold Medal', medalGold)`. Only ever shows **one** medal (whichever tier
was just earned this session) — never all three at once. The "Continue"
button always renders in the primary blue regardless of medal tier.

### Profile screen — badges section (`profile_screen.dart`)
Under "Your Progress", a `_BadgesCard` renders a `Row` of three
`_BadgeColumn`s — one per difficulty tier, always all three, regardless of
progress:

| Difficulty | Title | Owl asset |
|---|---|---|
| easy | "Skilled Signer" | `assets/images/owl_student.png` |
| medium | "Expert Signer" | `assets/images/owl_expert.png` |
| hard | "Master Signer" | `assets/images/owl_master.png` |

Each column's **count** is the number of *distinct lessons* medaled at that
difficulty — `medalsEarned.entries.where((e) => e.value &&
e.key.endsWith('_$difficulty')).length` — not a total across all three
tiers combined.

**Badge tiers** (`_kBadgeTiers = [5, 10, 20]`, cumulative medal counts at
that difficulty, independent of the bronze/silver/gold medal color):
- `< 5` → locked: greyscale + dimmed (55% opacity) owl artwork, grey
  background (`0xFFD0D0D0`), grey label text.
- `5–9` → tier 1 unlocked: full-color owl, pale-yellow background
  (`0xFFFDFAE5`).
- `10–19` → tier 2: sky-blue background (`0xFFBCE2ED`).
- `≥ 20` → tier 3 ("mastered"): pink background (`0xFFFFE2E8`), plus a small
  gold `workspace_premium` crown badge overlaid bottom-right on the circle.

The background-circle color is tier-based as above; the medal-kind color
(bronze/silver/gold) is used only for the count text
(`"$count/$nextThreshold"`) once unlocked, and for the badge-info dialog
text — it does not affect the circle background.

Tapping any badge opens an `AlertDialog` via `_showBadgeInfoDialog()`
showing progress toward the next tier (or a "fully mastered" message once
at 20+).
