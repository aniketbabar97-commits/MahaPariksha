class Bi {
  final String hi;
  final String en;
  const Bi(this.hi, this.en);
  String of(String lang) => lang == 'en' ? en : hi;
}

class Topic {
  final String id;
  final String subjectId;
  final Bi name;
  const Topic(this.id, this.subjectId, this.name);
}

class Subject {
  final String id;
  final Bi name;
  final String icon;
  final List<Topic> topics;
  const Subject(this.id, this.name, this.icon, this.topics);
}

class Exam {
  final String id;
  final String group;
  final Bi name;
  final List<String> subjects;

  /// Subject id -> relative weight, matching each exam's real question-count split
  /// (e.g. RRB JE's Maths/Science-heavy pattern vs RPF's General-Awareness-heavy one).
  /// Used by [QuizBuilder.mock] to build a mock test that mirrors the real exam,
  /// not an even split across subjects.
  final Map<String, int> weights;
  final double negative;

  /// Real exam's CBT-1 question count / time limit (minutes), used to build a
  /// full-length mock that matches the actual paper instead of the quick
  /// default-length one. Falls back to the quick mock's own defaults when unset.
  final int? paperQuestions;
  final int? paperMinutes;
  const Exam(this.id, this.group, this.name, this.subjects, this.weights,
      [this.negative = 0, this.paperQuestions, this.paperMinutes]);
}

class ExamGroup {
  final String id;
  final Bi name;
  const ExamGroup(this.id, this.name);
}

class Question {
  final String id;
  final String subject;
  final String topic;
  final int difficulty;
  final Bi text;
  final List<String> optionsHi;
  final List<String> optionsEn;
  final int answer;
  final Bi explanation;
  final Bi? hook;
  final Bi? fact;

  /// ISO `YYYY-MM-DD` date this item was auto-drafted on (current-affairs pipeline
  /// only). Null for hand-curated questions, which aren't dated.
  final String? date;

  /// Source article URL. Only kept in the content pack for dated (auto-drafted)
  /// current-affairs items -- see pipeline/build_bundle.py.
  final String? src;

  /// Previous-year question: the paper it appeared in, e.g.
  /// "RRB JE CBT-1 2025 · 19 Feb 2026 · Shift 1". Null for the regular bank.
  final String? pyq;

  /// Which languages this question has text in: 'both', 'hi' or 'en'.
  final String langs;
  bool hasLang(String lang) => langs == 'both' || langs == lang;

  const Question({
    required this.id,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.text,
    required this.optionsHi,
    required this.optionsEn,
    required this.answer,
    required this.explanation,
    this.hook,
    this.fact,
    this.date,
    this.src,
    this.pyq,
    this.langs = 'both',
  });

  List<String> options(String lang) => lang == 'en' ? optionsEn : optionsHi;

  static Bi? _opt(Map<String, dynamic> j, String k) =>
      (j['${k}_hi'] != null || j['${k}_en'] != null)
          ? Bi(j['${k}_hi'] ?? j['${k}_en'], j['${k}_en'] ?? j['${k}_hi'])
          : null;

  // Previous-year questions from a single-language paper have only *_hi or only
  // *_en fields; they show that text in both languages.
  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        subject: j['s'],
        topic: j['t'],
        difficulty: j['d'],
        text: Bi(j['q_hi'] ?? j['q_en'], j['q_en'] ?? j['q_hi']),
        optionsHi: List<String>.from(j['o_hi'] ?? j['o_en']),
        optionsEn: List<String>.from(j['o_en'] ?? j['o_hi']),
        answer: j['a'],
        explanation: Bi(j['e_hi'] ?? j['e_en'], j['e_en'] ?? j['e_hi']),
        langs: j['q_hi'] == null ? 'en' : (j['q_en'] == null ? 'hi' : 'both'),
        hook: _opt(j, 'hook'),
        fact: _opt(j, 'fact'),
        date: j['date'],
        src: j['src'],
        pyq: j['pyq'],
      );
}

class Flashcard {
  final String id;
  final String subject;
  final String topic;
  final Bi front;
  final Bi back;
  const Flashcard(this.id, this.subject, this.topic, this.front, this.back);

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        j['id'],
        j['s'],
        j['t'],
        Bi(j['f_hi'], j['f_en']),
        Bi(j['b_hi'], j['b_en']),
      );
}

class Motivation {
  final String id;
  final String type;
  final Bi text;
  final String? by;
  const Motivation(this.id, this.type, this.text, this.by);

  factory Motivation.fromJson(Map<String, dynamic> j) =>
      Motivation(j['id'], j['type'], Bi(j['hi'], j['en']), j['by']);
}

class StrategyStage {
  final Bi title;
  final Bi detail;
  const StrategyStage(this.title, this.detail);

  factory StrategyStage.fromJson(Map<String, dynamic> j) =>
      StrategyStage(Bi(j['hi'], j['en']), Bi(j['detail_hi'], j['detail_en']));
}

/// Static "Exam Strategy & Pattern" reference content: the real multi-stage
/// selection process, tactical tips and an honest cutoff note for one exam.
/// Negative-marking math and time budgeting aren't stored here -- they're
/// computed live from the [Exam]'s own paperQuestions/paperMinutes/negative
/// so the worked example never drifts out of sync with the taxonomy.
class ExamStrategy {
  final String examId;
  final List<StrategyStage> stages;
  final List<Bi> tips;
  final Bi cutoffNote;
  const ExamStrategy(this.examId, this.stages, this.tips, this.cutoffNote);

  factory ExamStrategy.fromJson(String examId, Map<String, dynamic> j) => ExamStrategy(
        examId,
        (j['stages'] as List).map((s) => StrategyStage.fromJson(s)).toList(),
        (j['tips'] as List).map((t) => Bi(t['hi'], t['en'])).toList(),
        Bi(j['cutoff_hi'], j['cutoff_en']),
      );
}

/// One reference entry in a GK booster category -- e.g. one scheme, one award,
/// one national park. A short bold title plus a one/two-line bilingual detail
/// covers every category's shape (dates+themes, scheme facts, award winners,
/// author names, park/species) without category-specific fields.
class GkBoosterItem {
  final Bi title;
  final Bi detail;
  const GkBoosterItem(this.title, this.detail);

  factory GkBoosterItem.fromJson(Map<String, dynamic> j) => GkBoosterItem(
        Bi(j['title_hi'], j['title_en']),
        Bi(j['detail_hi'], j['detail_en']),
      );
}

/// A browsable category of static GK reference entries (Important Days,
/// Govt Schemes, Awards, Books & Authors, National Parks, Committees...),
/// read/browsed rather than quizzed -- see content/gk_booster.json.
class GkBoosterCategory {
  final String id;
  final String icon;
  final Bi name;
  final List<GkBoosterItem> items;
  const GkBoosterCategory(this.id, this.icon, this.name, this.items);

  factory GkBoosterCategory.fromJson(Map<String, dynamic> j) => GkBoosterCategory(
        j['id'],
        j['icon'] ?? 'book',
        Bi(j['name_hi'], j['name_en']),
        (j['items'] as List).map((i) => GkBoosterItem.fromJson(i)).toList(),
      );
}

/// One condensed cram category (e.g. "Percentage", "Zones & HQs") within a
/// subject's cheat sheet -- the exam-day "5 minutes before the exam" version
/// of a topic, distinct from [TopicNote] which is the explanatory one.
class CheatSheet {
  final String subject;
  final String topic;
  final Bi category;
  final List<String> itemsHi;
  final List<String> itemsEn;
  const CheatSheet(this.subject, this.topic, this.category, this.itemsHi, this.itemsEn);

  List<String> items(String lang) => lang == 'en' ? itemsEn : itemsHi;

  factory CheatSheet.fromJson(Map<String, dynamic> j) => CheatSheet(
        j['s'],
        j['t'],
        Bi(j['cat_hi'], j['cat_en']),
        List<String>.from(j['items_hi']),
        List<String>.from(j['items_en']),
      );
}

class MapNode {
  final Bi label;
  final List<MapNode> children;
  const MapNode(this.label, this.children);

  factory MapNode.fromJson(Map<String, dynamic> j) => MapNode(
        Bi(j['hi'], j['en']),
        ((j['children'] as List?) ?? const []).map((c) => MapNode.fromJson(c)).toList(),
      );
}

class TopicNote {
  final String subject;
  final String topic;
  final Bi summary;
  final List<String> factsHi;
  final List<String> factsEn;
  final List<String> tipsHi;
  final List<String> tipsEn;
  final MapNode map;
  const TopicNote(this.subject, this.topic, this.summary, this.factsHi, this.factsEn, this.map,
      {this.tipsHi = const [], this.tipsEn = const []});

  List<String> facts(String lang) => lang == 'en' ? factsEn : factsHi;

  /// Empty for notes drafted before the tips schema addition, until backfilled.
  List<String> tips(String lang) => lang == 'en' ? tipsEn : tipsHi;
  bool get hasTips => tipsHi.isNotEmpty;

  factory TopicNote.fromJson(Map<String, dynamic> j) => TopicNote(
        j['s'],
        j['t'],
        Bi(j['summary_hi'], j['summary_en']),
        List<String>.from(j['facts_hi']),
        List<String>.from(j['facts_en']),
        MapNode.fromJson(j['map']),
        tipsHi: List<String>.from(j['tips_hi'] ?? const []),
        tipsEn: List<String>.from(j['tips_en'] ?? const []),
      );
}
