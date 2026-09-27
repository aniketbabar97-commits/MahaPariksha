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

/// Emirates the question content can be scoped to. "all" (the default) means
/// the question applies UAE-wide / is not emirate-specific.
const List<String> emirateOptions = ['all', 'dubai', 'abu_dhabi', 'sharjah'];

/// Vehicle categories the question content can be scoped to. "car" (Light
/// Motor Vehicle) is the default and the only category the current bank
/// covers; the others are forward-compatible slots so a future content pass
/// can tag motorcycle/heavy-vehicle/bus-specific questions without an app
/// change.
const List<String> vehicleTypeOptions = ['all', 'car', 'motorcycle', 'heavy_vehicle', 'bus'];

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

  /// Optional per-emirate and per-vehicle-type tagging. Defaults to "all" so
  /// existing content (none of which sets these fields yet) is served to
  /// every emirate/vehicle-type filter unchanged.
  final String emirate;
  final String vehicleType;

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
    this.emirate = 'all',
    this.vehicleType = 'all',
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
        emirate: (j['emirate'] as String?) ?? 'all',
        vehicleType: (j['vehicleType'] as String?) ?? 'all',
      );

  /// Whether this question should be served under the given [emirate]
  /// (e.g. "dubai") and [vehicleType] (e.g. "car") filters. A question tagged
  /// "all" always matches; "all" as the requested filter matches everything.
  bool matchesFilters({required String emirate, required String vehicleType}) {
    final emirateOk = this.emirate == 'all' || emirate == 'all' || this.emirate == emirate;
    final vehicleOk = this.vehicleType == 'all' || vehicleType == 'all' || this.vehicleType == vehicleType;
    return emirateOk && vehicleOk;
  }
}

class ContentBundle {
  final List<String> languages;
  final List<Category> categories;
  final List<Question> questions;

  const ContentBundle(this.languages, this.categories, this.questions);

  List<Question> byCategory(String categoryId) =>
      questions.where((q) => q.category == categoryId).toList();

  /// All questions matching the given emirate/vehicle-type filters
  /// ("all" matches everything), optionally further restricted to a category.
  List<Question> filtered({String emirate = 'all', String vehicleType = 'all', String? categoryId}) {
    return questions
        .where((q) => (categoryId == null || q.category == categoryId) &&
            q.matchesFilters(emirate: emirate, vehicleType: vehicleType))
        .toList();
  }

  factory ContentBundle.fromJson(Map<String, dynamic> j) => ContentBundle(
        List<String>.from(j['languages']),
        ((j['taxonomy']['categories']) as List)
            .map((c) => Category.fromJson(c))
            .toList(),
        (j['questions'] as List).map((q) => Question.fromJson(q)).toList(),
      );
}
