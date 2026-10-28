// « Je prie » du verset du jour : temps de prière immersif de 5 minutes avant
// chaque prière, comme partout ailleurs (docs serveur fonctionnalites/temps-de-priere.md) ;
// on peut prier plusieurs fois, retirer sa dernière prière reste immédiat
// (fonctionnalites/prier-plusieurs-fois.md).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart' show apiServiceProvider;
import '../home/models/testimony_model.dart' show DailyVerse;
import '../home/providers/home_providers.dart' show dailyVerseProvider;
import '../prayer/screens/prayer_focus_screen.dart';
import '../prayer/widgets/pray_again_sheet.dart';

Future<void> prayForDailyVerse(BuildContext context, WidgetRef ref) async {
  final verse = ref.read(dailyVerseProvider).value;
  if (verse == null) return;
  await prayForVerse(context, ref, verse: verse, pray: ref.read(dailyVerseProvider.notifier).pray);
}

/// « Je prie » d'un verset (du jour ou de l'historique) : temps de prière, puis [pray].
/// Si la personne prie déjà : prier encore ou retirer sa dernière prière.
Future<void> prayForVerse(
  BuildContext context,
  WidgetRef ref, {
  required DailyVerse verse,
  required Future<void> Function({bool again}) pray,
}) async {
  if (verse.isPrayed) {
    final choice = await askPrayAgain(context, times: verse.prayerTimes);
    if (choice == PrayAgainChoice.removeLast) await pray(again: false);
    if (choice != PrayAgainChoice.again || !context.mounted) return;
  }
  final l10n = context.l10n;
  final api = ref.read(apiServiceProvider);
  final ok = await openPrayerFocusFor(
    context,
    PrayerFocusSubject(
      title: verse.reference,
      body: verse.text,
      authorName: '',
      subtitle: l10n.prayerFocusVerseSubtitle,
      label: l10n.prayerFocusVerseLabel,
      confirmLabel: l10n.prayerFocusVerseConfirm,
      onStart: verse.id > 0 ? () => api.post<dynamic>(AppConstants.versePrayStart(verse.id)) : null,
    ),
  );
  if (ok && context.mounted) await pray();
}
