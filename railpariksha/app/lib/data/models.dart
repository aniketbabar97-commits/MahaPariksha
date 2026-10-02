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
  });

  List<String> options(String lang) => lang == 'en' ? optionsEn : optionsHi;

  static Bi? _opt(Map<String, dynamic> j, String k) =>
      (j['${k}_hi'] != null || j['${k}_en'] != null)
          ? Bi(j['${k}_hi'] ?? j['${k}_en'], j['${k}_en'] ?? j['${k}_hi'])
          : null;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        subject: j['s'],
        topic: j['t'],
        difficulty: j['d'],
        text: Bi(j['q_hi'], j['q_en']),
        optionsHi: List<String>.from(j['o_hi']),
        optionsEn: List<String>.from(j['o_en']),
        answer: j['a'],
        explanation: Bi(j['e_hi'], j['e_en']),
        hook: _opt(j, 'hook'),
        fact: _opt(j, 'fact'),
        date: j['date'],
        src: j['src'],
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
