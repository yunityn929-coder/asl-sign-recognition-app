class LessonDefinition {
  final String id;
  final int section;
  final String title;
  final List<String> signs;

  const LessonDefinition({
    required this.id,
    required this.section,
    required this.title,
    required this.signs,
  });
}

class SectionDefinition {
  final int number;
  final String title;
  final String description;

  const SectionDefinition({
    required this.number,
    required this.title,
    required this.description,
  });
}

const List<LessonDefinition> kLessons = [
  // Section 1 — Foundations
  LessonDefinition(id: 's1l1', section: 1, title: 'Alphabet A–E',        signs: ['A','B','C','D','E']),
  LessonDefinition(id: 's1l2', section: 1, title: 'Alphabet F–J',        signs: ['F','G','H','I','J']),
  LessonDefinition(id: 's1l3', section: 1, title: 'Alphabet K–O',        signs: ['K','L','M','N','O']),
  LessonDefinition(id: 's1l4', section: 1, title: 'Alphabet P–T',        signs: ['P','Q','R','S','T']),
  LessonDefinition(id: 's1l5', section: 1, title: 'Alphabet U–Z',        signs: ['U','V','W','X','Y','Z']),
  LessonDefinition(id: 's1l6', section: 1, title: 'Numbers 0–4',         signs: ['0','1','2','3','4']),
  LessonDefinition(id: 's1l7', section: 1, title: 'Numbers 5–9',         signs: ['5','6','7','8','9']),

  // Section 2 — Fingerspelling Practice
  LessonDefinition(id: 's2l1', section: 2, title: 'Short Words',         signs: ['C','A','T','D','O','G']),
  LessonDefinition(id: 's2l2', section: 2, title: 'Spell Your Name',     signs: []),
  LessonDefinition(id: 's2l3', section: 2, title: 'Common Words',        signs: ['F','I','S','H','B','O','K']),
  LessonDefinition(id: 's2l4', section: 2, title: 'Longer Words',        signs: ['A','P','L','E','H','O','U','S']),
  LessonDefinition(id: 's2l5', section: 2, title: 'Speed Challenge',     signs: ['A','B','C','D','E','F','G','H','I','J']),

  // Section 3 — Numbers in Context
  LessonDefinition(id: 's3l1', section: 3, title: 'Count 0–9',          signs: ['0','1','2','3','4','5','6','7','8','9']),
  LessonDefinition(id: 's3l2', section: 3, title: 'Random Numbers',     signs: ['0','1','2','3','4','5','6','7','8','9']),
  LessonDefinition(id: 's3l3', section: 3, title: 'Number Pairs',       signs: ['1','2','3','4','5','6','7','8','9','0']),
  LessonDefinition(id: 's3l4', section: 3, title: 'Number Expressions', signs: ['1','2','3','4','5']),

  // Section 4 — Mixed Review & Mastery
  LessonDefinition(
    id: 's4l1', section: 4, title: 'Full Alphabet Review',
    signs: ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'],
  ),
  LessonDefinition(
    id: 's4l2', section: 4, title: 'Alphabet Speed Run',
    signs: ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'],
  ),
  LessonDefinition(
    id: 's4l3', section: 4, title: 'Numbers + Letters',
    signs: ['A','B','C','1','2','3','D','E','F','4','5','6'],
  ),
  LessonDefinition(id: 's4l4', section: 4, title: 'Mastery Test',       signs: []),
];

const List<SectionDefinition> kSections = [
  SectionDefinition(number: 1, title: 'Foundations',             description: 'Learn every letter and number'),
  SectionDefinition(number: 2, title: 'Fingerspelling Practice', description: 'Spell real words'),
  SectionDefinition(number: 3, title: 'Numbers in Context',      description: 'Use numbers naturally'),
  SectionDefinition(number: 4, title: 'Mixed Review & Mastery',  description: 'Prove what you know'),
];
