class QuizSet {
  final String id;
  final String title;
  final String description;
  final List<String> signs;
  final int sectionNumber;

  const QuizSet({
    required this.id,
    required this.title,
    required this.description,
    required this.signs,
    required this.sectionNumber,
  });
}

const List<String> _kSection1Signs = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

const List<String> _kSection2Signs = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'O', 'P', 'S', 'T', 'U',
];

const List<String> _kSection3Signs = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
];

const List<String> _kAllSigns = [
  ..._kSection1Signs,
  ..._kSection3Signs,
];

const List<QuizSet> kQuizSets = [
  QuizSet(
    id: 'section_1',
    title: 'Foundations',
    description: 'Letters A–Z',
    signs: _kSection1Signs,
    sectionNumber: 1,
  ),
  QuizSet(
    id: 'section_2',
    title: 'Fingerspelling',
    description: 'Common words and spelling',
    signs: _kSection2Signs,
    sectionNumber: 2,
  ),
  QuizSet(
    id: 'section_3',
    title: 'Numbers',
    description: 'Digits 0–9',
    signs: _kSection3Signs,
    sectionNumber: 3,
  ),
  QuizSet(
    id: 'section_4',
    title: 'Mixed Review',
    description: 'All signs mixed',
    signs: _kAllSigns,
    sectionNumber: 4,
  ),
  QuizSet(
    id: 'quick',
    title: 'Quick Quiz',
    description: 'Random 10 signs',
    signs: _kAllSigns,
    sectionNumber: 0,
  ),
];
