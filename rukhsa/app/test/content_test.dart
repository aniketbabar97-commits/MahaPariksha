import 'package:rukhsa/data/content_repo.dart';
import 'package:rukhsa/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentBundle bundle;

  setUpAll(() async {
    bundle = await ContentRepo().load();
  });

  test('bundle loads with categories and questions', () {
    expect(bundle.categories, isNotEmpty);
    expect(bundle.questions.length, greaterThanOrEqualTo(55));
  });

  test('all 10 languages are present and en/ar are always done', () {
    expect(bundle.languages.length, 10);
    for (final q in bundle.questions) {
      for (final lang in bundle.languages) {
        expect(q.q[lang], isNotNull, reason: '${q.id} missing $lang');
      }
      expect(q.q['en']!.status, TranslationStatus.done, reason: q.id);
      expect(q.q['ar']!.status, TranslationStatus.done, reason: q.id);
    }
  });

  test('every question has 4 options and a valid answer index', () {
    for (final q in bundle.questions) {
      expect(q.options.length, 4, reason: q.id);
      expect(q.answer, inInclusiveRange(0, 3), reason: q.id);
    }
  });

  test('every question belongs to a known category', () {
    final categoryIds = bundle.categories.map((c) => c.id).toSet();
    for (final q in bundle.questions) {
      expect(categoryIds.contains(q.category), isTrue, reason: q.id);
    }
  });

  test('no duplicate question ids', () {
    final ids = bundle.questions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
