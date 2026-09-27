/// Data models for the Rukhsa content bundle.
///
/// Every user-facing piece of question text is a [Localized] map keyed by
/// BCP-47-ish language codes (en, ar, ur, hi, tl, ml, bn, ta, fa, fr), each
/// entry carrying both the [LocalizedText.text] and whether it is a real,
/// reviewed translation or an English fallback ([TranslationStatus.pending]).
library;

enum TranslationStatus { done, pending }

class LocalizedText {
  final String text;
  final TranslationStatus status;
  const LocalizedText(this.text, this.status);

  factory LocalizedText.fromJson(Map<String, dynamic> j) => LocalizedText(
        j['text'] as String,
        (j['translationStatus'] as String) == 'done'
            ? TranslationStatus.done
            : TranslationStatus.pending,
      );
}

typedef Localized = Map<String, LocalizedText>;

Localized _localizedFromJson(Map<String, dynamic> j) => j.map(
      (lang, v) => MapEntry(lang, LocalizedText.fromJson(v as Map<String, dynamic>)),
    );

/// Looks up [lang] in a Localized map, falling back to English then to the
/// first available entry if even English is somehow missing.
extension LocalizedLookup on Localized {
  LocalizedText resolve(String lang) => this[lang] ?? this['en'] ?? values.first;
}

class Category {
  final String id;
  final String icon;
  final String en;
  final String ar;
  final List<Subcategory> subcategories;
  const Category(this.id, this.icon, this.en, this.ar, this.subcategories);

  String name(String lang) => lang == 'ar' ? ar : en;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        j['id'],
        j['icon'] ?? 'category',
        j['en'],
        j['ar'],
        ((j['subcategories'] as List?) ?? const [])
            .map((s) => Subcategory.fromJson(s))
            .toList(),
      );
}

class Subcategory {
  final String id;
  final String en;
  final String ar;
  const Subcategory(this.id, this.en, this.ar);

  String name(String lang) => lang == 'ar' ? ar : en;

  factory Subcategory.fromJson(Map<String, dynamic> j) =>
      Subcategory(j['id'], j['en'], j['ar']);
}

class Question {
  final String id;
  final String category;
  final String? subcategory;
  final int difficulty;
  final bool needsVerification;
  final Localized q;
  final List<Localized> options;
  final int answer;
  final Localized explanation;

  const Question({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.difficulty,
    required this.needsVerification,
    required this.q,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'],
        category: j['category'],
        subcategory: j['subcategory'],
        difficulty: j['difficulty'] ?? 1,
        needsVerification: j['needsVerification'] ?? false,
        q: _localizedFromJson(j['q']),
        options: (j['options'] as List)
            .map((o) => _localizedFromJson(o as Map<String, dynamic>))
            .toList(),
        answer: j['answer'],
        explanation: _localizedFromJson(j['explanation']),
      );
}

class ContentBundle {
  final List<String> languages;
  final List<Category> categories;
  final List<Question> questions;

  const ContentBundle(this.languages, this.categories, this.questions);

  List<Question> byCategory(String categoryId) =>
      questions.where((q) => q.category == categoryId).toList();

  factory ContentBundle.fromJson(Map<String, dynamic> j) => ContentBundle(
        List<String>.from(j['languages']),
        ((j['taxonomy']['categories']) as List)
            .map((c) => Category.fromJson(c))
            .toList(),
        (j['questions'] as List).map((q) => Question.fromJson(q)).toList(),
      );
}
