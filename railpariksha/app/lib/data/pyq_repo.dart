import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Where the sets and topic shards that are not bundled in the APK are served from: the release
/// workflow publishes the complete pack as assets of the 'pyq-pack' GitHub release (one file per
/// set/shard, '/' in a name replaced by '__'). Empty disables downloads.
const String kPyqPackUrl = String.fromEnvironment('PYQ_PACK_URL',
    defaultValue: 'https://github.com/aniketbabar97-commits/MahaPariksha/releases/download/pyq-pack');

/// A set or topic shard that is not in the APK could not be fetched (offline, or the pack is not
/// published yet). The screens show a retry.
class PyqDownloadException implements Exception {
  final String file;
  const PyqDownloadException(this.file);
  @override
  String toString() => 'PyqDownloadException($file)';
}

/// One previous-year paper (a single exam shift), e.g.
/// "RRB JE CBT-1 2025 · 19 Feb 2026 · Shift 1".
class PyqPaper {
  final String label;
  final int count;
  const PyqPaper(this.label, this.count);

  /// The part after the exam/year, e.g. "19 Feb 2026 · Shift 1" (empty when the
  /// source didn't record the date/shift).
  String get shortLabel {
    final i = label.indexOf(' · ');
    return i < 0 ? '' : label.substring(i + 3);
  }
}

/// All of one exam's questions from one year, shipped as its own asset file.
class PyqSet {
  final String exam;
  final int year;

  /// A railway (RRB/RPF) paper, as opposed to a same-syllabus non-railway exam (SSC).
  final bool railway;
  final String file;
  final int count;
  final Map<String, int> subjects;
  final List<PyqPaper> papers;

  /// Size of the set file in KB, for the one-time download hint.
  final int kb;
  const PyqSet(this.exam, this.year, this.railway, this.file, this.count, this.subjects, this.papers, {this.kb = 0});

  String get title => '$exam $year';

  factory PyqSet.fromJson(Map<String, dynamic> j) => PyqSet(
        j['exam'],
        j['year'],
        j['rail'] == true,
        j['file'],
        j['n'],
        Map<String, int>.from(j['subjects']),
        [for (final p in j['papers']) PyqPaper(p['label'], p['n'])],
        kb: (j['kb'] as num?)?.toInt() ?? 0,
      );
}

/// Every PYQ of one topic, shipped as its own small file (see build_bundle.py).
class PyqTopic {
  final String subject;
  final String topic;
  final int count;
  final String file;

  /// Question count per exam name ("RRB NTPC Graduate CBT-1" -> 812).
  final Map<String, int> byExam;
  final int kb;
  const PyqTopic(this.subject, this.topic, this.count, this.file, this.byExam, {this.kb = 0});

  /// Questions in this topic from exams whose name starts with [prefix] ("RRB NTPC"), or all if null.
  int countFor(String? prefix) => prefix == null
      ? count
      : byExam.entries.where((e) => e.key.startsWith(prefix)).fold(0, (a, e) => a + e.value);

  factory PyqTopic.fromJson(Map<String, dynamic> j) =>
      PyqTopic(j['s'], j['t'], j['n'], j['file'], Map<String, int>.from(j['by_exam']),
          kb: (j['kb'] as num?)?.toInt() ?? 0);
}

/// Previous-year questions live outside the main content pack (~80k of them, from
/// English-only sources) so they cost nothing at launch: the small index loads when
/// the PYQ section opens, and each exam/year file only when that set is opened.
class PyqRepo {
  static const _dir = 'assets/pyq';

  final AssetBundle _bundle;
  final http.Client Function() _client;
  final Future<Directory> Function() _cacheRoot;
  PyqRepo([AssetBundle? bundle, http.Client Function()? client, Future<Directory> Function()? cacheRoot])
      : _bundle = bundle ?? rootBundle,
        _client = client ?? http.Client.new,
        _cacheRoot = cacheRoot ?? (() async => Directory('${(await getApplicationSupportDirectory()).path}/pyq'));

  List<PyqSet>? _sets;
  List<PyqTopic>? _topics;
  int _version = 0;
  final Map<String, List<Question>> _loaded = {};

  /// The file currently being downloaded (null when none): screens show a one-time download note.
  final ValueNotifier<String?> downloading = ValueNotifier(null);

  /// The raw JSON of a set or topic shard: from the APK when bundled, else from the download
  /// cache, else fetched once from [kPyqPackUrl] and cached. The cache lives under the pack
  /// version, so a new app build never reads files an older build fetched.
  Future<String> _raw(String file) async {
    try {
      return await _bundle.loadString('$_dir/$file');
    } catch (_) {
      // Not bundled in this build: fall through to the cache / download.
    }
    await sets();
    final Directory root;
    final File cached;
    try {
      root = await _cacheRoot();
      cached = File('${root.path}/$_version/${file.replaceAll('/', '__')}');
      if (await cached.exists()) return await cached.readAsString();
    } catch (_) {
      // No usable cache directory (e.g. a test host without path_provider): try the network.
      throw PyqDownloadException(file);
    }
    final dir = cached.parent;
    if (kPyqPackUrl.isEmpty) throw PyqDownloadException(file);
    downloading.value = file;
    try {
      final client = _client();
      try {
        final res = await client
            .get(Uri.parse('$kPyqPackUrl/${file.replaceAll('/', '__')}'))
            .timeout(const Duration(seconds: 90));
        if (res.statusCode != 200) throw PyqDownloadException(file);
        final body = utf8.decode(res.bodyBytes);
        // Only a document that parses is worth caching.
        jsonDecode(body);
        await dir.create(recursive: true);
        await cached.writeAsString(body);
        _dropOldCaches(root, keep: dir.path);
        return body;
      } finally {
        client.close();
      }
    } on PyqDownloadException {
      rethrow;
    } catch (_) {
      throw PyqDownloadException(file);
    } finally {
      downloading.value = null;
    }
  }

  /// Caches written by earlier app builds are dead weight; remove them in the background.
  void _dropOldCaches(Directory root, {required String keep}) {
    root.list().listen((e) {
      if (e is Directory && e.path != keep) e.delete(recursive: true).catchError((_) => e);
    }, onError: (_) {});
  }

  /// The set index, or an empty list if this build has no PYQ pack.
  Future<List<PyqSet>> sets() async {
    if (_sets != null) return _sets!;
    try {
      final j = jsonDecode(await _bundle.loadString('$_dir/index.json')) as Map<String, dynamic>;
      _version = (j['version'] as num?)?.toInt() ?? 0;
      // A 'year' with only a handful of stray questions is noise, not a paper students can practise.
      _sets = [for (final s in j['sets']) PyqSet.fromJson(s)].where((s) => s.count >= 20).toList();
      _topics = [for (final t in (j['topics'] as List? ?? const [])) PyqTopic.fromJson(t)];
    } catch (_) {
      _sets = const [];
      _topics = const [];
    }
    return _sets!;
  }

  /// The topic index (empty if this build has no PYQ pack).
  Future<List<PyqTopic>> topics() async {
    await sets();
    return _topics ?? const [];
  }

  /// Every question of [topic], from all exams. Callers filter by `Question.pyq` prefix.
  Future<List<Question>> topicQuestions(PyqTopic topic) async {
    final cached = _loaded[topic.file];
    if (cached != null) return cached;
    final raw = await _raw(topic.file);
    final qs = await Isolate.run(() => [
          for (final q in jsonDecode(raw) as List) Question.fromJson(q as Map<String, dynamic>),
        ]);
    if (_loaded.length >= 3) _loaded.remove(_loaded.keys.first);
    return _loaded[topic.file] = qs;
  }

  /// A random draw of previous-year questions for an exam: [quota] questions per subject, taken
  /// from [candidates] (the exam's sets) a few at a time, so a full 100-question exam reads two or
  /// three year-files rather than the whole pack. [accept] filters (language, exam name).
  /// Subjects with too few questions in the sampled sets are topped up from the remaining sets.
  Future<Map<String, List<Question>>> sampleBySubject(
    List<PyqSet> candidates,
    Map<String, int> quota, {
    bool Function(Question q)? accept,
    Random? random,
  }) async {
    final rnd = random ?? Random();
    final order = [...candidates]..shuffle(rnd);
    final pool = {for (final s in quota.keys) s: <Question>[]};
    for (final set in order) {
      // Done when every subject has plenty to choose from (3x its quota).
      if (quota.entries.every((e) => pool[e.key]!.length >= e.value * 3)) break;
      for (final q in await questions(set)) {
        final list = pool[q.subject];
        if (list != null && (accept == null || accept(q))) list.add(q);
      }
    }
    return {
      for (final e in quota.entries) e.key: (pool[e.key]!..shuffle(rnd)).take(e.value).toList(),
    };
  }

  /// Every question in [set]. Decoded off the UI isolate (a set can be a few MB).
  Future<List<Question>> questions(PyqSet set) async {
    final cached = _loaded[set.file];
    if (cached != null) return cached;
    final raw = await _raw(set.file);
    final qs = await Isolate.run(() => [
          for (final q in jsonDecode(raw) as List) Question.fromJson(q as Map<String, dynamic>),
        ]);
    // Keep only the most recently opened few sets in memory.
    if (_loaded.length >= 3) _loaded.remove(_loaded.keys.first);
    return _loaded[set.file] = qs;
  }
}
