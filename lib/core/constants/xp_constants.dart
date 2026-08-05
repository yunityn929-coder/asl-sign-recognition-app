// Only source of XP for lesson and practice sessions — no flat completion bonus.
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
