// « Je prie » sur un témoignage : comme pour une requête de prière, un temps de
// prière immersif de 5 minutes précède la prière (docs serveur
// fonctionnalites/temps-de-priere.md). On peut prier plusieurs fois : chaque
// prière a son temps de prière ; retirer sa dernière prière reste immédiat
// (fonctionnalites/prier-plusieurs-fois.md).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import '../../../shared/utils/rich_text_utils.dart' show stripFormatting;
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show interactionProvider;
import '../../prayer/screens/prayer_focus_screen.dart';
import '../../prayer/widgets/pray_again_sheet.dart';

/// Texte du témoignage montré pendant le temps de prière (extrait).
String prayerSubjectText(Testimony t) {
  final raw = switch (t) {
    TextTestimony(:final preview) => stripFormatting(preview),
    AudioTestimony(:final transcript, :final transcriptPreview) =>
      transcript.isNotEmpty ? transcript : transcriptPreview,
    VideoTestimony() => '',
  };
  final text = raw.trim();
  return text.length > 700 ? '${text.substring(0, 700).trimRight()}…' : text;
}

/// Prie pour [t] (après les 5 minutes). Si la personne prie déjà : prier encore
/// ou retirer sa dernière prière.
Future<void> prayForTestimony(BuildContext context, WidgetRef ref, Testimony t) async {
  final interactions = ref.read(interactionProvider.notifier);
  if (interactions.isPrayed(t)) {
    final choice = await askPrayAgain(context, times: ref.read(interactionProvider).prayerTimesOf(t));
    if (choice == PrayAgainChoice.removeLast) await interactions.removeLastPrayer(t);
    if (choice != PrayAgainChoice.again || !context.mounted) return;
  }
  final l10n = context.l10n;
  final api = ref.read(apiServiceProvider);
  final ok = await openPrayerFocusFor(
    context,
    PrayerFocusSubject(
      title: t.title,
      body: prayerSubjectText(t),
      mentions: t.mentions,
      authorName: t.author.displayName,
      label: l10n.prayerFocusTestimonyLabel,
      confirmLabel: l10n.prayerFocusTestimonyConfirm,
      onStart: () => api.post<dynamic>(AppConstants.testimonyPrayStart(t.id)),
    ),
  );
  if (ok && context.mounted) await interactions.pray(t);
}
