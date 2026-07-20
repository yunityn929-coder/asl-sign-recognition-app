const int kXpLearnCorrect   = 10;

// Base XP awarded just for completing a lesson
// regardless of recognition score
const int kXpLessonCompletion = 20;
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
