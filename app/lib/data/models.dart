class Bi {
  final String mr;
  final String en;
  const Bi(this.mr, this.en);
  String of(String lang) => lang == 'en' ? en : mr;
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
  final double negative;
  const Exam(this.id, this.group, this.name, this.subjects, [this.negative = 0]);
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
  final List<String> optionsMr;
  final List<String> optionsEn;
  final int answer;
  final Bi explanation;
  final Bi? hook;
  final Bi? fact;

  const Question({
    required this.id,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.text,
    required this.optionsMr,
    required this.optionsEn,
    required this.answer,
    required this.explanation,
    this.hook,
    this.fact,
  });

  List<String> options(String lang) => lang == 'en' ? optionsEn : optionsMr;

  static Bi? _opt(Map<String, dynamic> j, String k) =>
      (j['${k}_mr'] != null || j['${k}_en'] != null)
          ? Bi(j['${k}_mr'] ?? j['${k}_en'], j['${k}_en'] ?? j['${k}_mr'])
          : null;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        subject: j['s'],
        topic: j['t'],
        difficulty: j['d'],
        text: Bi(j['q_mr'], j['q_en']),
        optionsMr: List<String>.from(j['o_mr']),
        optionsEn: List<String>.from(j['o_en']),
        answer: j['a'],
        explanation: Bi(j['e_mr'], j['e_en']),
        hook: _opt(j, 'hook'),
        fact: _opt(j, 'fact'),
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
        Bi(j['f_mr'], j['f_en']),
        Bi(j['b_mr'], j['b_en']),
      );
}

class Motivation {
  final String id;
  final String type;
  final Bi text;
  final String? by;
  const Motivation(this.id, this.type, this.text, this.by);

  factory Motivation.fromJson(Map<String, dynamic> j) =>
      Motivation(j['id'], j['type'], Bi(j['mr'], j['en']), j['by']);
}
