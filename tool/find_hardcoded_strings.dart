// tool/find_hardcoded_strings.dart
//
// Liste les chaînes affichables restées en dur dans lib/ (hors traductions
// générées). À relancer après chaque modification de l'interface :
//
//   dart run tool/find_hardcoded_strings.dart              # tout lib/
//   dart run tool/find_hardcoded_strings.dart lib/features/live
//   dart run tool/find_hardcoded_strings.dart --count      # total par fichier
//
// Code de sortie 1 s'il en reste (utilisable en intégration continue).
//
// Heuristique : une chaîne est signalée si elle contient des lettres ET (un
// espace, une lettre accentuée, ou commence par une majuscule suivie de
// minuscules). Sont ignorés : imports, commentaires, clés JSON / identifiants
// (sans espace ni accent), chemins et URL, motifs de date, journaux
// (debugPrint, print, log, assert, StateError, UnimplementedError, ArgumentError),
// clés de widgets (Key / ValueKey), et toute ligne terminée par
// `// i18n-ignore` (chaîne volontairement non traduite : nom propre, marque,
// référence biblique, texte envoyé au serveur…). Un fichier contenant
// `// i18n-ignore-file` est ignoré en entier (table de données bilingue).
// Les requêtes SQL sont ignorées.

import 'dart:io';

final _ignoreFiles = <RegExp>[
  RegExp(r'lib[\\/]l10n[\\/]gen[\\/]'),
  RegExp(r'firebase_options\.dart$'),
  RegExp(r'\.g\.dart$'),
  RegExp(r'\.freezed\.dart$'),
];

final _ignoreLine = <RegExp>[
  RegExp(r'^\s*(import|export|part|library)\b'),
  RegExp(r'i18n-ignore'),
  RegExp(r'\b(debugPrint|print|log|developer\.log|assert|debugPrintStack)\s*\('),
  RegExp(r'\b(StateError|UnimplementedError|ArgumentError|UnsupportedError|AssertionError|FormatException)\s*\('),
  RegExp(r'@pragma\('),
];

final _accent = RegExp(r'[À-ÿœŒ’«»…]');
final _letter = RegExp(r'[A-Za-zÀ-ÿ]');
final _capWord = RegExp(r'^[A-ZÀ-Ý][a-zà-ÿ]{2,}');
final _identifier = RegExp(r'^[A-Za-z0-9_.\-:/@#%&=?+*,|$<>\[\](){}^!~]*$');
final _urlOrPath = RegExp(r'^(https?:|mailto:|tel:|testi:|/|assets/|package:|\.|#|[a-z]+://)');
final _datePattern = RegExp(r'^[dMyEHhmsaS ,.:/\-]+$');
final _sql = RegExp(
    r'(\?\s*(AND|OR|,|\))|\b(SELECT|INSERT|UPDATE|DELETE FROM|CREATE (TABLE|INDEX)|ALTER TABLE|WHERE|ORDER BY|GROUP BY|PRIMARY KEY|NOT NULL|INTEGER|REFERENCES|ON CONFLICT)\b|\b(ASC|DESC)$|= \?)');

class Hit {
  Hit(this.file, this.line, this.text);
  final String file;
  final int line;
  final String text;
}

/// Littéraux de chaîne d'un fichier Dart (commentaires ignorés), avec leur ligne.
Iterable<({int line, String text, String lineText})> literals(String src) sync* {
  final lines = src.split('\n');
  int lineOf(int offset) => '\n'.allMatches(src.substring(0, offset)).length + 1;
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    // Commentaires
    if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      final end = src.indexOf('\n', i);
      i = end < 0 ? src.length : end;
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '*') {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      final start = i;
      i += quote.length;
      final buf = StringBuffer();
      var depth = 0;
      while (i < src.length) {
        if (depth == 0 && src.startsWith(quote, i)) break;
        final ch = src[i];
        if (!raw && ch == r'\' && i + 1 < src.length) {
          final n = src[i + 1];
          buf.write(n == 'n' ? r'\n' : n == 't' ? r'\t' : n);
          i += 2;
          continue;
        }
        if (!raw && ch == r'$' && i + 1 < src.length && src[i + 1] == '{') {
          depth++;
          buf.write('{x}');
          i += 2;
          continue;
        }
        if (depth > 0) {
          if (ch == '{') depth++;
          if (ch == '}') depth--;
          i++;
          continue;
        }
        if (!triple && ch == '\n') break;
        buf.write(ch);
        i++;
      }
      i += quote.length;
      if (raw) continue; // regex, motifs
      final ln = lineOf(start);
      yield (line: ln, text: buf.toString(), lineText: lines[ln - 1]);
      continue;
    }
    i++;
  }
}

bool looksDisplayable(String s) {
  final t = s.replaceAll(RegExp(r'\$\w+|\{x\}'), '').trim();
  if (t.length < 2 || !_letter.hasMatch(t)) return false;
  if (_urlOrPath.hasMatch(t)) return false;
  if (_sql.hasMatch(t)) return false;
  if (_datePattern.hasMatch(t) && !t.contains(RegExp(r'[a-z]{4,}'))) return false;
  final hasSpace = t.contains(' ');
  final hasAccent = _accent.hasMatch(t);
  if (!hasSpace && !hasAccent && _identifier.hasMatch(t) && !_capWord.hasMatch(t)) {
    return false;
  }
  // Mot capitalisé seul : libellé probable (« Annuler », « Profil »).
  return hasSpace || hasAccent || _capWord.hasMatch(t);
}

bool ignoredLine(String line) {
  if (_ignoreLine.any((r) => r.hasMatch(line))) return true;
  // Clés de widgets et noms de polices.
  if (RegExp(r'\b(ValueKey|Key|PageStorageKey|ObjectKey|GlobalObjectKey)\s*(<[^>]*>)?\(').hasMatch(line) &&
      !RegExp(r'\b(Text|label|title|tooltip|hint)').hasMatch(line)) {
    return true;
  }
  if (RegExp(r'fontFamily\s*:').hasMatch(line)) return true;
  return false;
}

void main(List<String> args) {
  final count = args.contains('--count');
  final roots = args.where((a) => !a.startsWith('--')).toList();
  if (roots.isEmpty) roots.add('lib');

  final hits = <Hit>[];
  for (final root in roots) {
    final entity = FileSystemEntity.typeSync(root);
    final files = entity == FileSystemEntityType.file
        ? [File(root)]
        : Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final path = f.path.replaceAll(r'\', '/');
      if (_ignoreFiles.any((r) => r.hasMatch(f.path))) continue;
      final src = f.readAsStringSync();
      // Fichier de données volontairement bilingue ou non affiché.
      if (src.contains('i18n-ignore-file')) continue;
      for (final lit in literals(src)) {
        if (ignoredLine(lit.lineText)) continue;
        if (!looksDisplayable(lit.text)) continue;
        hits.add(Hit(path, lit.line, lit.text));
      }
    }
  }

  hits.sort((a, b) => a.file != b.file ? a.file.compareTo(b.file) : a.line.compareTo(b.line));
  if (count) {
    final byFile = <String, int>{};
    for (final h in hits) {
      byFile[h.file] = (byFile[h.file] ?? 0) + 1;
    }
    final sorted = byFile.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      stdout.writeln('${e.value.toString().padLeft(5)}  ${e.key}');
    }
  } else {
    for (final h in hits) {
      final text = h.text.length > 100 ? '${h.text.substring(0, 100)}…' : h.text;
      stdout.writeln('${h.file}:${h.line}: "${text.replaceAll('\n', r'\n')}"');
    }
  }
  stdout.writeln('${hits.length} chaîne(s) en dur.');
  exitCode = hits.isEmpty ? 0 : 1;
}
