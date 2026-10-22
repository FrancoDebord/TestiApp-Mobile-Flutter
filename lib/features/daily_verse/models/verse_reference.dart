// i18n-ignore-file : noms et abréviations des livres bibliques (fr / en), non traduits.
// Références bibliques écrites à la main : « Jérémie 29 : 11 », « Jean 3:16-18 »,
// « 1 Pierre 5.7 », « Ps 23,1 », « John 3:16 ». Même règle que le serveur
// (App\Support\BibleReference) : sert hors connexion à relire le passage dans
// les Bibles téléchargées. Docs serveur : fonctionnalites/verset-du-jour.md

import 'package:flutter/foundation.dart';

@immutable
class VerseReference {
  const VerseReference({
    required this.book,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
  });

  /// Numéro du livre (1 = Genèse … 66 = Apocalypse).
  final int book;
  final int chapter;
  final int verseStart;
  final int verseEnd;

  bool get isRange => verseEnd > verseStart;

  String get bookName => kBibleBookNamesFr[book] ?? 'Livre $book';

  /// « Jean 3:16-17 ».
  String get label => labelWith(null);

  /// Même référence avec le nom du livre d'une traduction (« John 3:16-17 ») ;
  /// nom français si [name] est vide.
  String labelWith(String? name) =>
      '${name == null || name.trim().isEmpty ? bookName : name} $chapter:${isRange ? '$verseStart-$verseEnd' : '$verseStart'}';

  bool contains(int verse) => verse >= verseStart && verse <= verseEnd;

  /// Première référence de [text], ou null. Une référence seule d'un livre d'un
  /// chapitre peut omettre le chapitre : « Jude 24-25 », « 3 Jean 3 » (= chapitre 1).
  static VerseReference? parse(String? text) {
    final all = findAll(text);
    return all.isEmpty ? _parseSingleChapter(text) : all.first;
  }

  static VerseReference? _parseSingleChapter(String? text) {
    if (text == null) return null;
    final m = RegExp(r'^\s*(.+?)\s+(\d{1,3})(?:\s*(?:[-–—]|à|to)\s*(\d{1,3}))?\s*$').firstMatch(text);
    if (m == null) return null;
    final book = bookNumber(m.group(1)!);
    if (book == null || !_singleChapterBooks.contains(book)) return null;
    final start = int.parse(m.group(2)!);
    if (start < 1) return null;
    final end = m.group(3) == null ? start : int.parse(m.group(3)!);
    return VerseReference(book: book, chapter: 1, verseStart: start, verseEnd: end < start ? start : end);
  }

  /// Toutes les références d'un texte libre, dans l'ordre.
  static List<VerseReference> findAll(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final found = <VerseReference>[];
    for (final m in _numbers.allMatches(text)) {
      final words = text
          .substring(0, m.start)
          .trim()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      int? book;
      for (var n = words.length < 4 ? words.length : 4; n >= 1 && book == null; n--) {
        book = bookNumber(words.sublist(words.length - n).join(' '));
      }
      if (book == null) continue;
      final chapter = int.parse(m.group(1)!);
      final start = int.parse(m.group(2)!);
      final endRaw = m.group(3);
      final end = endRaw == null ? start : int.parse(endRaw);
      if (chapter < 1 || start < 1) continue;
      found.add(VerseReference(
        book: book,
        chapter: chapter,
        verseStart: start,
        verseEnd: end < start ? start : end,
      ));
    }
    return found;
  }

  /// Numéro du livre d'après son nom ou une abréviation (fr / en).
  static int? bookNumber(String name) {
    final key = _normalize(name);
    if (key.isEmpty) return null;
    return _lookup[key];
  }

  @override
  bool operator ==(Object other) =>
      other is VerseReference &&
      other.book == book &&
      other.chapter == chapter &&
      other.verseStart == verseStart &&
      other.verseEnd == verseEnd;

  @override
  int get hashCode => Object.hash(book, chapter, verseStart, verseEnd);

  @override
  String toString() => label;
}

/// Livres d'un seul chapitre : Abdias, Philémon, 2 Jean, 3 Jean, Jude.
const _singleChapterBooks = {31, 57, 63, 64, 65};

final _numbers = RegExp(
    r'(\d{1,3})\s*[:.,]\s*(\d{1,3})(?:\s*(?:[-–—]|à|to)\s*(\d{1,3}))?');

const Map<int, String> kBibleBookNamesFr = {
  1: 'Genèse', 2: 'Exode', 3: 'Lévitique', 4: 'Nombres', 5: 'Deutéronome',
  6: 'Josué', 7: 'Juges', 8: 'Ruth', 9: '1 Samuel', 10: '2 Samuel',
  11: '1 Rois', 12: '2 Rois', 13: '1 Chroniques', 14: '2 Chroniques', 15: 'Esdras',
  16: 'Néhémie', 17: 'Esther', 18: 'Job', 19: 'Psaumes', 20: 'Proverbes',
  21: 'Ecclésiaste', 22: 'Cantique des Cantiques', 23: 'Ésaïe', 24: 'Jérémie', 25: 'Lamentations',
  26: 'Ézéchiel', 27: 'Daniel', 28: 'Osée', 29: 'Joël', 30: 'Amos',
  31: 'Abdias', 32: 'Jonas', 33: 'Michée', 34: 'Nahoum', 35: 'Habacuc',
  36: 'Sophonie', 37: 'Aggée', 38: 'Zacharie', 39: 'Malachie',
  40: 'Matthieu', 41: 'Marc', 42: 'Luc', 43: 'Jean', 44: 'Actes',
  45: 'Romains', 46: '1 Corinthiens', 47: '2 Corinthiens', 48: 'Galates', 49: 'Éphésiens',
  50: 'Philippiens', 51: 'Colossiens', 52: '1 Thessaloniciens', 53: '2 Thessaloniciens', 54: '1 Timothée',
  55: '2 Timothée', 56: 'Tite', 57: 'Philémon', 58: 'Hébreux', 59: 'Jacques',
  60: '1 Pierre', 61: '2 Pierre', 62: '1 Jean', 63: '2 Jean', 64: '3 Jean',
  65: 'Jude', 66: 'Apocalypse',
};

const Map<int, String> _namesEn = {
  1: 'Genesis', 2: 'Exodus', 3: 'Leviticus', 4: 'Numbers', 5: 'Deuteronomy',
  6: 'Joshua', 7: 'Judges', 8: 'Ruth', 9: '1 Samuel', 10: '2 Samuel',
  11: '1 Kings', 12: '2 Kings', 13: '1 Chronicles', 14: '2 Chronicles', 15: 'Ezra',
  16: 'Nehemiah', 17: 'Esther', 18: 'Job', 19: 'Psalms', 20: 'Proverbs',
  21: 'Ecclesiastes', 22: 'Song of Solomon', 23: 'Isaiah', 24: 'Jeremiah', 25: 'Lamentations',
  26: 'Ezekiel', 27: 'Daniel', 28: 'Hosea', 29: 'Joel', 30: 'Amos',
  31: 'Obadiah', 32: 'Jonah', 33: 'Micah', 34: 'Nahum', 35: 'Habakkuk',
  36: 'Zephaniah', 37: 'Haggai', 38: 'Zechariah', 39: 'Malachi',
  40: 'Matthew', 41: 'Mark', 42: 'Luke', 43: 'John', 44: 'Acts',
  45: 'Romans', 46: '1 Corinthians', 47: '2 Corinthians', 48: 'Galatians', 49: 'Ephesians',
  50: 'Philippians', 51: 'Colossians', 52: '1 Thessalonians', 53: '2 Thessalonians', 54: '1 Timothy',
  55: '2 Timothy', 56: 'Titus', 57: 'Philemon', 58: 'Hebrews', 59: 'James',
  60: '1 Peter', 61: '2 Peter', 62: '1 John', 63: '2 John', 64: '3 John',
  65: 'Jude', 66: 'Revelation',
};

const Map<int, List<String>> _aliases = {
  1: ['Gn', 'Gen', 'Ge'], 2: ['Ex', 'Exo'], 3: ['Lv', 'Lev'], 4: ['Nb', 'Nomb', 'Num'], 5: ['Dt', 'Deut'],
  6: ['Jos'], 7: ['Jg', 'Jug'], 8: ['Rt', 'Ru'], 9: ['1 S', '1 Sam'], 10: ['2 S', '2 Sam'],
  11: ['1 R', '1 Ro'], 12: ['2 R', '2 Ro'], 13: ['1 Ch', '1 Chr'], 14: ['2 Ch', '2 Chr'], 15: ['Esd'],
  // Pas « Est » pour Esther : trop fréquent dans un texte libre.
  16: ['Ne', 'Neh'], 17: ['Esth'], 18: ['Jb'], 19: ['Ps', 'Psaume', 'Psalm', 'Psa'], 20: ['Pr', 'Prov', 'Proverbe'],
  21: ['Ec', 'Eccl', 'Qohelet'], 22: ['Ct', 'Cantique', 'Song of Songs', 'Cant'], 23: ['Es', 'Is', 'Isaïe', 'Esa'], 24: ['Jr', 'Jer'], 25: ['Lm', 'Lam'],
  26: ['Ez', 'Ezk', 'Ezech'], 27: ['Dn', 'Dan'], 28: ['Os'], 29: ['Jl'], 30: ['Am'],
  31: ['Ab', 'Abd'], 32: ['Jon'], 33: ['Mi', 'Mic'], 34: ['Na', 'Nahum'], 35: ['Ha', 'Hab', 'Habakuk'],
  36: ['So', 'Soph'], 37: ['Ag'], 38: ['Za', 'Zach'], 39: ['Ml', 'Mal'],
  40: ['Mt', 'Matt'], 41: ['Mc', 'Mk'], 42: ['Lc', 'Lk'], 43: ['Jn'], 44: ['Ac', 'Actes des apôtres', 'Act'],
  45: ['Rm', 'Rom'], 46: ['1 Co', '1 Cor'], 47: ['2 Co', '2 Cor'], 48: ['Ga', 'Gal'], 49: ['Ep', 'Eph'],
  50: ['Ph', 'Phil'], 51: ['Col'], 52: ['1 Th', '1 Thes'], 53: ['2 Th', '2 Thes'], 54: ['1 Tm', '1 Tim'],
  55: ['2 Tm', '2 Tim'], 56: ['Tt', 'Tit'], 57: ['Phm', 'Philem'], 58: ['He', 'Hb', 'Heb'], 59: ['Jc', 'Jas'],
  60: ['1 P', '1 Pi', '1 Pet'], 61: ['2 P', '2 Pi', '2 Pet'], 62: ['1 Jn'], 63: ['2 Jn'], 64: ['3 Jn'],
  65: ['Jd'], 66: ['Ap', 'Apoc', 'Rev', 'Révélation'],
};

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e',
  'ë': 'e', 'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u',
  'û': 'u', 'ü': 'u', 'ú': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

String _normalize(String s) {
  final buffer = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

final Map<String, int> _lookup = () {
  final map = <String, int>{};
  for (final names in [kBibleBookNamesFr, _namesEn]) {
    names.forEach((n, name) => map.putIfAbsent(_normalize(name), () => n));
  }
  _aliases.forEach((n, list) {
    for (final a in list) {
      map.putIfAbsent(_normalize(a), () => n);
    }
  });
  return map;
}();
