#!/usr/bin/env python3
"""
Generates app/lib/l10n/app_localizations.dart from the ARB files in
app/lib/l10n/app_<lang>.arb.

Flutter's own `flutter gen-l10n` tool (driven by l10n.yaml) is the normal way
to turn these ARB files into Dart code, but it requires a working Flutter SDK
which is not available in this environment. This script produces an
equivalent, hand-rolled AppLocalizations class from the very same ARB source
of truth, so the app works today; running `flutter gen-l10n` later (it will
use the same ARB files via l10n.yaml) can replace this generated file with
the official generated code with no changes to ARB content.
"""
import json
import os
import re

L10N_DIR = os.path.join(os.path.dirname(__file__), "..", "app", "lib", "l10n")
OUT_PATH = os.path.join(L10N_DIR, "app_localizations.dart")
LANGS = ["en", "ar", "ur", "hi", "tl", "ml", "bn", "ta", "fa", "fr"]


def dart_string_literal(s: str) -> str:
    escaped = s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\$", "\\\$")
    return f"'{escaped}'"


def main():
    all_data = {}
    keys = None
    for lang in LANGS:
        with open(os.path.join(L10N_DIR, f"app_{lang}.arb"), encoding="utf-8") as f:
            d = json.load(f)
        d = {k: v for k, v in d.items() if not k.startswith("@")}
        all_data[lang] = d
        if keys is None:
            keys = list(d.keys())

    lines = []
    lines.append("// GENERATED FILE - do not edit by hand.")
    lines.append("// Source of truth: app/lib/l10n/app_<lang>.arb")
    lines.append("// Regenerate with: python3 rukhsa/pipeline/gen_dart_l10n.py")
    lines.append("import 'package:flutter/material.dart';")
    lines.append("")
    lines.append("class AppLocalizations {")
    lines.append("  final String localeCode;")
    lines.append("  const AppLocalizations(this.localeCode);")
    lines.append("")
    lines.append("  static const List<Locale> supportedLocales = [")
    for lang in LANGS:
        lines.append(f"    Locale('{lang}'),")
    lines.append("  ];")
    lines.append("")
    lines.append("  static AppLocalizations of(BuildContext context) {")
    lines.append("    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??")
    lines.append("        const AppLocalizations('en');")
    lines.append("  }")
    lines.append("")
    lines.append("  static const Map<String, Map<String, String>> _strings = {")
    for lang in LANGS:
        lines.append(f"    '{lang}': {{")
        for key, value in all_data[lang].items():
            lines.append(f"      '{key}': {dart_string_literal(value)},")
        lines.append("    },")
    lines.append("  };")
    lines.append("")
    lines.append("  String _raw(String key) {")
    lines.append("    return _strings[localeCode]?[key] ?? _strings['en']?[key] ?? key;")
    lines.append("  }")
    lines.append("")
    for key in keys:
        placeholders = sorted(set(re.findall(r"\{(\w+)\}", all_data["en"][key])))
        method_name = key
        if placeholders:
            args = ", ".join(f"Object {p}" for p in placeholders)
            lines.append(f"  String {method_name}({args}) {{")
            lines.append(f"    var s = _raw('{key}');")
            for p in placeholders:
                lines.append(f"    s = s.replaceAll('{{{p}}}', '\\${p}');")
            lines.append("    return s;")
            lines.append("  }")
        else:
            lines.append(f"  String get {method_name} => _raw('{key}');")
        lines.append("")
    lines.append("}")
    lines.append("")
    lines.append("class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {")
    lines.append("  const AppLocalizationsDelegate();")
    lines.append("")
    langs_literal = ", ".join(f"'{lang}'" for lang in LANGS)
    lines.append("  @override")
    lines.append(f"  bool isSupported(Locale locale) => [{langs_literal}].contains(locale.languageCode);")
    lines.append("")
    lines.append("  @override")
    lines.append("  Future<AppLocalizations> load(Locale locale) async =>")
    lines.append("      AppLocalizations(locale.languageCode);")
    lines.append("")
    lines.append("  @override")
    lines.append("  bool shouldReload(AppLocalizationsDelegate old) => false;")
    lines.append("}")
    lines.append("")

    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
