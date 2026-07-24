// Awarded per question answered correctly — the only source of XP for
// both learning (lesson) sessions and practice sessions. No flat
// completion/base bonus is awarded regardless of correctness.
const int kXpLearnCorrect   = 2;

const int kXpPracticeEasy   = 15;
const int kXpPracticeMedium = 20;
const int kXpPracticeHard   = 25;
const int kXpPerfectBonus   = 50;
const int kXpStreakBonus     = 100;

const Map<int, int> kStreakGoalXp = {
  7:  100,
  14: 250,
  30: 500,
  50: 1000,
};
