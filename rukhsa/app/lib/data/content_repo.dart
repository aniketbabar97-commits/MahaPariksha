import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Loads and caches the offline content bundle shipped as an app asset.
class ContentRepo {
  ContentBundle? _bundle;

  Future<ContentBundle> load() async {
    final cached = _bundle;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/content/bundle.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final bundle = ContentBundle.fromJson(json);
    _bundle = bundle;
    return bundle;
  }
}
