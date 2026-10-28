// Liens vers un passage de la Bible — même format que le serveur
// (app/Support/BibleReference.php, docs serveur fonctionnalites/liens-bible.md) :
//
//   {webBaseUrl}/bible/{TRADUCTION}/{livre}/{chapitre}/{versets}
//   https://temoignage.as-krea.com/bible/LSG/jean/3/16-18
//
// Construits sur le téléphone (partage hors connexion) ; ouverts dans l'application
// par les App Links (chemin /bible/ du manifeste) ou dans le site.
// i18n-ignore-file (noms de livres : données bilingues comme côté serveur)

import '../../core/app_constants.dart';

/// Plage de versets [start, end] (bornes comprises).
typedef VerseRange = ({int start, int end});

abstract final class BibleLinks {
  /// Nombre de plages acceptées dans un lien (« 1,3,5-7… »).
  static const maxRanges = 10;

  /// Traductions en anglais (livre nommé en anglais dans le lien) quand la langue
  /// de la traduction n'est pas connue sur le téléphone.
  static const englishTranslations = {'KJV', 'WEB', 'ASV'};

  static const namesFr = {
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

  static const namesEn = {
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

  static const _aliases = {
    1: ['Gn', 'Gen', 'Ge'], 2: ['Ex', 'Exo'], 3: ['Lv', 'Lev'], 4: ['Nb', 'Nomb', 'Num'], 5: ['Dt', 'Deut'],
    6: ['Jos'], 7: ['Jg', 'Jug'], 8: ['Rt', 'Ru'], 9: ['1 S', '1 Sam'], 10: ['2 S', '2 Sam'],
    11: ['1 R', '1 Ro'], 12: ['2 R', '2 Ro'], 13: ['1 Ch', '1 Chr'], 14: ['2 Ch', '2 Chr'], 15: ['Esd'],
    16: ['Ne', 'Neh'], 17: ['Esth'], 18: ['Jb'], 19: ['Ps', 'Psaume', 'Psalm', 'Psa'], 20: ['Pr', 'Prov', 'Proverbe'],
    21: ['Ec', 'Eccl', 'Qohelet'], 22: ['Ct', 'Cantique', 'Song of Songs', 'Cant'], 23: ['Es', 'Is', 'Isaïe', 'Esa'],
    24: ['Jr', 'Jer'], 25: ['Lm', 'Lam'],
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

  static const _accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae', 'ẹ': 'e', 'ọ': 'o', 'ṣ': 's', 'ɛ': 'e', 'ɔ': 'o',
  };

  /// Minuscules sans accents (Str::ascii + lower du serveur).
  static String _ascii(String s) {
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(_accents[ch] ?? ch);
    }
    return b.toString();
  }

  /// Clé de comparaison : lettres et chiffres seulement (« 1 Co. » → « 1co »).
  static String normalize(String name) => _ascii(name).replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Map<String, int>? _lookup;

  static Map<String, int> get _map {
    if (_lookup != null) return _lookup!;
    final map = <String, int>{};
    for (final names in [namesFr, namesEn]) {
      names.forEach((n, name) => map.putIfAbsent(normalize(name), () => n));
    }
    _aliases.forEach((n, list) {
      for (final a in list) {
        map.putIfAbsent(normalize(a), () => n);
      }
    });
    return _lookup = map;
  }

  /// Numéro du livre (1-66) d'après un nom ou une abréviation, sinon null.
  static int? bookNumber(String name) {
    final key = normalize(name);
    return key.isEmpty ? null : _map[key];
  }

  /// Livre écrit dans un lien : « 43 », « jean », « 1-corinthiens », « john », « jn ».
  static int? bookFromSegment(String segment) {
    final s = Uri.decodeComponent(segment);
    final n = int.tryParse(s);
    if (n != null) return n >= 1 && n <= 66 ? n : null;
    return bookNumber(s.replaceAll(RegExp(r'[-_]'), ' '));
  }

  /// Traduction en anglais : livre nommé en anglais dans le lien.
  static bool isEnglish(String translationCode, {String? language}) =>
      language != null ? language == 'en' : englishTranslations.contains(translationCode.toUpperCase());

  /// Nom du livre dans un lien : « jean », « 1-corinthiens », « song-of-solomon ».
  static String slug(int book, String translationCode, {String? language}) {
    final name = (isEnglish(translationCode, language: language) ? namesEn : namesFr)[book];
    if (name == null) return '$book';
    return _ascii(name).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// « 16 », « 16-18 », « 16,18-20 » → plages triées et fusionnées ; null si invalide.
  static List<VerseRange>? parseVerses(String spec) {
    final parts = spec.split(',');
    if (parts.length > maxRanges) return null;
    final ranges = <VerseRange>[];
    for (final part in parts) {
      final m = RegExp(r'^(\d{1,3})(?:-(\d{1,3}))?$').firstMatch(part.trim());
      if (m == null) return null;
      final start = int.parse(m.group(1)!);
      final end = m.group(2) != null ? int.parse(m.group(2)!) : start;
      if (start < 1 || end < start) return null;
      ranges.add((start: start, end: end));
    }
    return mergeRanges(ranges);
  }

  /// Plages triées, celles qui se touchent fusionnées.
  static List<VerseRange> mergeRanges(Iterable<VerseRange> input) {
    final sorted = [...input]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <VerseRange>[];
    for (final r in sorted) {
      if (merged.isNotEmpty && r.start <= merged.last.end + 1) {
        final last = merged.removeLast();
        merged.add((start: last.start, end: r.end > last.end ? r.end : last.end));
      } else {
        merged.add(r);
      }
    }
    return merged;
  }

  /// Versets choisis → plages (« 16, 17, 18, 20 » → 16-18,20).
  static List<VerseRange> rangesOf(Iterable<int> verses) =>
      mergeRanges([for (final v in verses) (start: v, end: v)]);

  static String formatVerses(List<VerseRange> ranges) =>
      ranges.map((r) => r.start == r.end ? '${r.start}' : '${r.start}-${r.end}').join(',');

  /// Numéros des versets couverts.
  static Set<int> versesIn(List<VerseRange> ranges) => {
        for (final r in ranges)
          for (var v = r.start; v <= r.end; v++) v,
      };

  /// « /bible/LSG/jean/3/16-18 » (chapitre entier sans plages).
  static String passagePath(String translationCode, int book, int chapter,
      {List<VerseRange> ranges = const [], String? language}) {
    final code = translationCode.toUpperCase();
    final path = '/bible/$code/${slug(book, code, language: language)}/$chapter';
    return ranges.isEmpty ? path : '$path/${formatVerses(ranges)}';
  }

  /// Lien public à partager.
  static String passageUrl(String translationCode, int book, int chapter,
          {List<VerseRange> ranges = const [], String? language}) =>
      '${AppConstants.webBaseUrl}${passagePath(translationCode, book, chapter, ranges: ranges, language: language)}';

  /// « Jean 3:16-18, 20 », « Jean 3 ».
  static String passageLabel(String bookName, int chapter, [List<VerseRange> ranges = const []]) =>
      ranges.isEmpty ? '$bookName $chapter' : '$bookName $chapter:${formatVerses(ranges).replaceAll(',', ', ')}';
}
