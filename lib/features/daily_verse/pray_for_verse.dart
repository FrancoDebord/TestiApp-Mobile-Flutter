// « Je prie » du verset du jour : temps de prière immersif de 5 minutes, comme
// partout ailleurs (docs serveur fonctionnalites/temps-de-priere.md) ; retirer
// sa prière reste immédiat.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart' show apiServiceProvider;
import '../home/providers/home_providers.dart' show dailyVerseProvider;
import '../prayer/screens/prayer_focus_screen.dart';

Future<void> prayForDailyVerse(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(dailyVerseProvider.notifier);
  final verse = ref.read(dailyVerseProvider).value;
  if (verse == null) return;
  if (verse.isPrayed) {
    await notifier.togglePray();
    return;
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
  if (ok && context.mounted && !(ref.read(dailyVerseProvider).value?.isPrayed ?? true)) {
    await notifier.togglePray();
  }
}
