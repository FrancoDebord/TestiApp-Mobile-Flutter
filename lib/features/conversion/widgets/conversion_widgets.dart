// Témoignage de conversion : badge des cartes, bandeau de la page du témoignage,
// carte mise en avant du profil, bloc de l'accueil.
// Backend : docs/fonctionnalites/temoignage-de-conversion.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../home/models/testimony_model.dart';
import '../../home/widgets/compact_testimony_tile.dart';
import '../../publish/providers/publish_provider.dart' show publishConversionProvider;
import '../data/conversion_repository.dart';
import '../providers/conversion_providers.dart';
import '../../../shared/content_deletion.dart';

/// Icône des témoignages de conversion.
const IconData conversionIcon = Icons.volunteer_activism_rounded;

/// Badge « Conversion » (cartes, listes, page du témoignage).
class ConversionLabel extends StatelessWidget {
  const ConversionLabel({this.compact = false, this.onDark = false, super.key});

  final bool compact;

  /// Sur une image : fond plein.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.secondaryDark;
    return Semantics(
      label: context.l10n.conversionLabel,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 2 : 4),
        decoration: BoxDecoration(
          color: onDark ? AppColors.secondary : AppColors.secondarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(conversionIcon, size: compact ? 13 : 15, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                context.l10n.conversionLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lignes « Année · Lieu · Verset » d'un témoignage de conversion.
class ConversionDetailsRows extends StatelessWidget {
  const ConversionDetailsRows({required this.details, super.key});

  final ConversionDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppColors.secondaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: l10n.conversionDetailLabel(label),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    TextSpan(
                      text: value,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ]),
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (details.year != null) row(Icons.event_rounded, l10n.conversionYear, '${details.year}'),
        if (details.place != null) row(Icons.place_outlined, l10n.conversionPlace, details.place!),
        if (details.verse != null) row(Icons.menu_book_rounded, l10n.conversionVerse, details.verse!),
      ],
    );
  }
}

/// Bandeau « Témoignage de conversion » de la page du témoignage (et « Modifier » pour l'auteur).
class ConversionBanner extends StatelessWidget {
  const ConversionBanner({required this.details, this.onEdit, super.key});

  final ConversionDetails details;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.sunSoft,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.sunBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(conversionIcon, color: AppColors.secondaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.l10n.conversionTestimonyTitle,
                    style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(context.l10n.commonEdit),
                ),
            ],
          ),
          if (details.hasDetails) ConversionDetailsRows(details: details),
        ],
      ),
    );
  }
}

/// Carte mise en avant au-dessus des témoignages d'un profil.
class ConversionFeaturedCard extends StatelessWidget {
  const ConversionFeaturedCard({
    required this.testimony,
    this.statusLabel,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final Testimony testimony;

  /// Mon témoignage : « ⋮ » → Supprimer.
  final VoidCallback? onDelete;

  /// « En attente de validation »… (mon propre témoignage seulement).
  final String? statusLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final details = testimony.conversion;
    return Material(
      color: AppColors.sunSoft,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => context.push('/testimony/${testimony.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.sunBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ConversionLabel(compact: true),
                  if (statusLabel != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(statusLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.sunText, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  if (onEdit != null && onDelete == null)
                    IconButton(
                      tooltip: context.l10n.commonEdit,
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                    ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      key: ValueKey('conversion-menu-${testimony.id}'),
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.primary),
                      onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete!(),
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          PopupMenuItem(
                            value: 'edit',
                            child: ListTile(leading: const Icon(Icons.edit_rounded), title: Text(context.l10n.commonEdit)),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                            title: Text(context.l10n.commonDelete),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                testimony.title.isEmpty ? context.l10n.conversionDefaultTitle : testimony.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h4.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w800),
              ),
              if (testimony case TextTestimony(:final preview) when preview.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(preview.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
              if (details != null && details.hasDetails) ...[
                const SizedBox(height: 6),
                Text(details.summary,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondaryDark, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Statut affiché sur mon propre témoignage de conversion (null : publié).
String? conversionStatusLabel(BuildContext context, MyConversion mine) {
  if (mine.isPending) return context.l10n.conversionStatusPending;
  if (mine.isRejected) return context.l10n.conversionStatusRejected;
  if (mine.status == 'draft') return context.l10n.conversionStatusDraft;
  return null;
}

/// Section du profil : mon témoignage de conversion (avec statut et « Modifier »),
/// ou le bouton « Enregistrer mon témoignage de conversion » (compte personnel) ;
/// pour un autre compte, son témoignage publié.
class ProfileConversionSection extends ConsumerWidget {
  const ProfileConversionSection({this.userId, this.padding = EdgeInsets.zero, super.key});

  /// null : mon profil.
  final String? userId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId != null) {
      final t = ref.watch(userConversionProvider(userId!)).value;
      if (t == null) return const SizedBox.shrink();
      return Padding(padding: padding, child: ConversionFeaturedCard(testimony: t));
    }
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final async = ref.watch(myConversionProvider);
    if (async.isLoading && !async.hasValue) return const SizedBox.shrink();
    // Erreur réseau : le bouton reste proposé à un compte personnel.
    final mine = async.value ?? MyConversion(canCreate: !user.isOrganization);
    if (mine.testimony case final t?) {
      if (watchIsDeleted(ref, DeletableContent.testimony, t.id)) {
        return Padding(padding: padding, child: const ConversionInviteCard(withButton: true));
      }
      return Padding(
        padding: padding,
        child: ConversionFeaturedCard(
          testimony: t,
          statusLabel: conversionStatusLabel(context, mine),
          onEdit: () => context.push('/conversions/mine/edit'),
          onDelete: () => deleteTestimonyContent(context, ref, t.id),
        ),
      );
    }
    if (!mine.canCreate) return const SizedBox.shrink();
    return Padding(padding: padding, child: const ConversionInviteCard(withButton: true));
  }
}

/// Peut-on commencer un témoignage de conversion ? Non si le serveur n'a pas encore
/// le module (il enregistrerait un témoignage ordinaire) : message affiché.
bool canStartConversion(BuildContext context, WidgetRef ref) {
  if (ref.read(myConversionProvider).value?.available ?? true) return true;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text(context.l10n.conversionServerUnavailable),
  ));
  return false;
}

/// Ouvre Publier en mode « témoignage de conversion ».
void startConversionTestimony(BuildContext context, WidgetRef ref) {
  if (!canStartConversion(context, ref)) return;
  ref.read(publishConversionProvider.notifier).start();
  context.go('/publish');
}

/// « Racontez comment vous avez rencontré Jésus » → Publier en mode conversion.
class ConversionInviteCard extends ConsumerWidget {
  const ConversionInviteCard({this.compact = false, this.withButton = false, this.onTap, super.key});

  final bool compact;

  /// Profil : bouton « Enregistrer mon témoignage de conversion » sous le texte.
  final bool withButton;

  /// Par défaut : [startConversionTestimony].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final card = Material(
      color: AppColors.sunSoft,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap ?? () => startConversionTestimony(context, ref),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: withButton ? null : Border.all(color: AppColors.sunBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
                child: const Icon(conversionIcon, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.conversionInviteTitle,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(l10n.conversionInviteBody,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (!withButton) const Icon(Icons.chevron_right_rounded, color: AppColors.sunText),
            ],
          ),
        ),
      ),
    );
    if (!withButton) return card;
    final tap = onTap ?? () => startConversionTestimony(context, ref);
    return Material(
      color: AppColors.sunSoft,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.sunBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: FilledButton.icon(
                onPressed: tap,
                icon: const Icon(conversionIcon),
                label: Text(l10n.conversionRecordButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloc « Témoignages de conversion » de l'accueil : 3 derniers publiés et « Tout voir » ;
/// masqué s'il n'y en a aucun.
class HomeConversionSection extends ConsumerWidget {
  const HomeConversionSection({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(latestConversionsProvider).value ?? const <Testimony>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConversionSectionHeader(onViewAll: () => context.push('/conversions')),
          const SizedBox(height: 10),
          for (final t in items) ...[
            CompactTestimonyTile(testimony: t),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Titre « Témoignages de conversion » + « Tout voir ».
class ConversionSectionHeader extends StatelessWidget {
  const ConversionSectionHeader({this.onViewAll, super.key});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(conversionIcon, color: AppColors.secondaryDark, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.conversionSectionTitle,
                  style: AppTextStyles.h4.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
              Text(context.l10n.conversionSectionSubtitle,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: Text(context.l10n.homeViewAll)),
      ],
    );
  }
}

/// Entrée « Témoignages de conversion » (Explorer) → section complète.
class ConversionEntryCard extends StatelessWidget {
  const ConversionEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.sunSoft,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => context.push('/conversions'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.sunBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
                child: const Icon(conversionIcon, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.conversionSectionTitle,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(l10n.conversionSectionSubtitle,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.sunText),
            ],
          ),
        ),
      ),
    );
  }
}
