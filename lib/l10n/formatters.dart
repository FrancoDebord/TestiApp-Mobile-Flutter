// lib/l10n/formatters.dart
//
// Dates, heures, durées et nombres formatés selon la langue affichée
// (L10n.locale) : « 14 oct. 2026 » / « Oct 14, 2026 », « 1 234 » / « 1,234 »,
// « il y a 3 h » / « 3 h ago ».
//
// Exporté par app_localizations.dart : un seul import suffit.

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart' show L10n;

/// Charge les noms de mois et de jours des deux langues (main.dart, avant
/// runApp). Sans effet si déjà fait ; les formateurs savent aussi s'en passer.
Future<void> initLocaleFormatting() async {
  await initializeDateFormatting('fr');
  await initializeDateFormatting('en');
}

/// Données de langue non chargées (test sans initLocaleFormatting) : les données
/// locales d'intl se chargent de façon synchrone, on les charge puis on réessaie.
T _withLocaleData<T>(T Function() build, T Function() fallback) {
  try {
    return build();
  } catch (_) {
    try {
      initializeDateFormatting(L10n.intlLocale);
      return build();
    } catch (_) {
      return fallback();
    }
  }
}

DateFormat _df(String Function(String locale) build, String fallbackPattern) => _withLocaleData(
      () => DateFormat(build(L10n.intlLocale), L10n.intlLocale),
      () => DateFormat(fallbackPattern),
    );

DateFormat _named(DateFormat Function(String locale) ctor, String fallbackPattern) => _withLocaleData(
      () => ctor(L10n.intlLocale),
      () => DateFormat(fallbackPattern),
    );

/// « 14 oct. 2026 » / « Oct 14, 2026 ».
String formatDate(DateTime d) => _named(DateFormat.yMMMd, 'dd/MM/yyyy').format(d.toLocal());

/// « 14 octobre 2026 » / « October 14, 2026 ».
String formatDateLong(DateTime d) => _named(DateFormat.yMMMMd, 'dd/MM/yyyy').format(d.toLocal());

/// « mardi 14 octobre » / « Tuesday, October 14 ».
String formatWeekdayDate(DateTime d) =>
    _named(DateFormat.MMMMEEEEd, 'dd/MM').format(d.toLocal());

/// « 14 oct. » / « Oct 14 ».
String formatDayMonth(DateTime d) => _named(DateFormat.MMMd, 'dd/MM').format(d.toLocal());

/// « octobre 2026 » / « October 2026 ».
String formatMonthYear(DateTime d) => _named(DateFormat.yMMMM, 'MM/yyyy').format(d.toLocal());

/// « 14:05 » / « 2:05 PM ».
String formatTime(DateTime d) => _named(DateFormat.jm, 'HH:mm').format(d.toLocal());

/// « 14 oct. 2026 à 14:05 » / « Oct 14, 2026, 2:05 PM ».
String formatDateTime(DateTime d) {
  final date = formatDate(d);
  final time = formatTime(d);
  return L10n.languageCode == 'fr' ? '$date à $time' : '$date, $time';
}

/// Motif libre (« EEE d MMM ») dans la langue affichée.
String formatDatePattern(DateTime d, String pattern) =>
    _df((_) => pattern, pattern).format(d.toLocal());

/// « il y a 5 min », « il y a 3 h », « Hier »… / « 5 min ago »…
String formatTimeAgo(DateTime d, {DateTime? now}) {
  final l = L10n.current;
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l.timeDaysAgo(diff.inDays);
  if (diff.inDays < 30) return l.timeWeeksAgo(diff.inDays ~/ 7);
  if (diff.inDays < 365) return l.timeMonthsAgo(diff.inDays ~/ 30);
  return l.timeYearsAgo(diff.inDays ~/ 365);
}

/// « 1 234 » / « 1,234 ».
String formatNumber(num n) {
  try {
    return NumberFormat.decimalPattern(L10n.intlLocale).format(n);
  } catch (_) {
    return '$n';
  }
}

/// « 1,2 k » / « 1.2K » (compteurs de vues, de réactions…).
String formatCompactNumber(num n) {
  try {
    return NumberFormat.compact(locale: L10n.intlLocale).format(n);
  } catch (_) {
    return '$n';
  }
}

/// « 12,5 % » / « 12.5% ».
String formatPercent(double ratio) {
  try {
    return NumberFormat.percentPattern(L10n.intlLocale).format(ratio);
  } catch (_) {
    return '${(ratio * 100).round()}%';
  }
}

/// « 2,4 Mo » / « 2.4 MB ».
String formatBytes(int bytes) {
  final fr = L10n.languageCode == 'fr';
  final units = fr ? ['o', 'Ko', 'Mo', 'Go'] : ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final digits = i == 0 || v >= 100 ? 0 : 1;
  try {
    final f = NumberFormat.decimalPatternDigits(locale: L10n.intlLocale, decimalDigits: digits);
    return '${f.format(v)} ${units[i]}';
  } catch (_) {
    return '${v.toStringAsFixed(digits)} ${units[i]}';
  }
}

/// Durée de lecture « 04:05 » ou « 1:02:30 » (identique dans les deux langues).
String formatClockDuration(int seconds) {
  if (seconds <= 0) return '00:00';
  final h = seconds ~/ 3600;
  final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
