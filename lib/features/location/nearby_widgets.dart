// En tête des fils : « Près de chez vous · Cotonou » (→ réglage de localisation) et
// l'invitation refermable « Activez votre position… » ; étiquette discrète des cartes proches.
// Doc serveur : docs/fonctionnalites/localisation.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../auth/providers/auth_notifier.dart' show currentUserProvider;
import 'location_providers.dart';
import 'user_location.dart';
import '../../l10n/app_localizations.dart';

/// Écran du réglage (route de premier niveau, ouverte depuis n'importe quel onglet).
const locationSettingsPath = '/settings/location';

/// Position consentie : rafraîchie au plus une fois par lancement (si ancienne).
bool _staleChecked = false;

class NearbyFeedBanner extends ConsumerWidget {
  const NearbyFeedBanner({
    required this.place,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Zone renvoyée par le fil (meta.place), ou null.
  final FeedPlace? place;

  /// Marge autour du bandeau, seulement s'il est affiché.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider) != null;
    final dismissed = ref.watch(locationPromptDismissedProvider);
    final showPrompt = signedIn && !dismissed && !(place?.fromGps ?? false);
    if (signedIn && (place?.fromGps ?? false) && !_staleChecked) {
      _staleChecked = true;
      Future.microtask(
        () => ref.read(userLocationProvider.notifier).refreshIfStale(),
      );
    }
    if (place == null && !showPrompt) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place case final p?)
            Semantics(
              button: signedIn,
              label: context.l10n.locationNearbySemantics(p.label),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: signedIn
                    ? () => context.push(locationSettingsPath)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          context.l10n.locationNearbyChip(p.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (place != null && showPrompt) const SizedBox(height: 10),
          if (showPrompt) const _LocationPrompt(),
        ],
      ),
    );
  }
}

class _LocationPrompt extends ConsumerWidget {
  const _LocationPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.my_location_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.locationPrompt,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.push(locationSettingsPath),
                  child: Text(context.l10n.locationEnable),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () =>
                ref.read(locationPromptDismissedProvider.notifier).dismiss(),
          ),
        ],
      ),
    );
  }
}

/// Étiquette discrète au-dessus d'une carte proche (« À Cotonou », « Au Bénin ») ; rien sinon.
class NearbyCardLabel extends ConsumerWidget {
  const NearbyCardLabel({required this.testimonyId, super.key});

  final String testimonyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(nearbyLabelsProvider.select((m) => m[testimonyId]));
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.place_outlined,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
