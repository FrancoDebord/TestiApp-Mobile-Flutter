// lib/features/testimony/widgets/testimony_info.dart
//
// Éléments communs de la page de lecture d'un témoignage (maquette, écran 8
// « Lecture ») : ligne auteur, badge de catégorie, rangée de statistiques et
// d'actions (cœur, partage, commentaires, téléchargement), carte du verset
// « Insight ».

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart' show AppLocalizations, AppLocalizationsContext, L10n, lookupAppLocalizations;
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../downloads/widgets/download_button.dart';
import '../../home/models/testimony_model.dart';
import '../../prayer/widgets/pray_again_sheet.dart' show MyPrayerTimesLine;
import '../../reactions/reaction_people.dart' show ReactionPeopleButton, ReactionSubject;

/// 12400 → « 12,4k » (fr) / « 12.4k » (en) ; 1 500 000 → « 1,5M ».
String formatCompactCount(int n, {bool fr = true}) {
  String dec(double v) {
    final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final trimmed = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    return fr ? trimmed.replaceAll('.', ',') : trimmed;
  }

  if (n >= 1000000) return '${dec(n / 1000000)}M';
  if (n >= 1000) return '${dec(n / 1000)}k';
  return '$n';
}

/// Textes de la langue demandée ([fr] : français, sinon anglais).
AppLocalizations _l10n(bool fr) => lookupAppLocalizations(fr ? L10n.fr : L10n.en);

/// « il y a 5 jours » / « 5 days ago ».
String formatTimeAgo(DateTime dt, {bool fr = true, DateTime? now}) {
  final l = _l10n(fr);
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.inMinutes < 1) return l.testimonyAgoJustNow;
  if (diff.inMinutes < 60) return l.testimonyAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l.testimonyAgoHours(diff.inHours);
  if (diff.inDays < 30) return l.testimonyAgoDays(diff.inDays);
  if (diff.inDays < 365) return l.testimonyAgoMonths(diff.inDays ~/ 30);
  return l.testimonyAgoYears(diff.inDays ~/ 365);
}

/// « 12,4k vues · il y a 5 jours ».
String viewsAndAge(Testimony t, {bool fr = true}) {
  final v = t.stats.views;
  final views = _l10n(fr).testimonyViews(v, formatCompactCount(v, fr: fr));
  return '$views · ${formatTimeAgo(t.createdAt, fr: fr)}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
}

/// Avatar, nom + badge d'organisation, « vues · date », action à droite.
class TestimonyAuthorRow extends StatelessWidget {
  const TestimonyAuthorRow({
    super.key,
    required this.author,
    required this.meta,
    this.onTap,
    this.trailing,
    this.avatarRadius = 18,
  });

  final TestimonyAuthor author;
  final String meta;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    final avatar = author.avatarUrl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: AppColors.primarySoft,
              backgroundImage:
                  avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar == null || avatar.isEmpty
                  ? Text(
                      _initials(author.displayName),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: avatarRadius * 0.75,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelMedium
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      OrganizationBadge(
                        isOrganization: author.isOrganization,
                        isVerified: author.isVerified,
                        approvalBadge: author.approvalBadge,
                        size: 15,
                      ),
                    ],
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Badge jaune de la catégorie (maquette : « Guérison »).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.category, this.dense = true});

  final TestimonyCategory category;
  final bool dense;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: category.label,
        tone: AppBadgeTone.yellow,
        icon: Icons.auto_awesome_rounded,
        dense: dense,
      );
}

/// Un compteur cliquable : icône + nombre (ou libellé).
class TestimonyStatAction extends StatelessWidget {
  const TestimonyStatAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppColors.textSecondary,
    this.labelColor,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color? labelColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              // Libellé vide : icône seule (partage).
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée d'actions : ❤ nombre · partage · commentaires · … · télécharger.
class TestimonyStatsRow extends StatelessWidget {
  const TestimonyStatsRow({
    super.key,
    required this.testimony,
    required this.likes,
    required this.isLiked,
    required this.comments,
    this.onLike,
    this.onShare,
    this.onComment,
    this.prayers,
    this.isPraying = false,
    this.onPray,
    this.myPrayerTimes = 0,
    this.fr = true,
  });

  final Testimony testimony;
  final int likes;
  final bool isLiked;
  final int comments;
  final int? prayers;
  final bool isPraying;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onComment;
  final VoidCallback? onPray;

  /// Nombre de fois que la personne a prié (« Vous avez prié 3 fois » sous la rangée).
  final int myPrayerTimes;
  final bool fr;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          flex: 2,
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TestimonyStatAction(
                key: const ValueKey('stat-like'),
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: AppColors.danger,
                label: formatCompactCount(likes, fr: fr),
                onTap: onLike,
                semanticLabel: _l10n(fr).testimonyLikeSemantic,
              ),
              if (prayers != null)
                TestimonyStatAction(
                  icon: Icons.volunteer_activism_rounded,
                  color: isPraying ? AppColors.primary : AppColors.textSecondary,
                  label: formatCompactCount(prayers!, fr: fr),
                  onTap: onPray,
                  semanticLabel: _l10n(fr).testimonyPraySemantic,
                ),
              TestimonyStatAction(
                icon: Icons.share_rounded,
                label: '',
                onTap: onShare,
                semanticLabel: _l10n(fr).testimonyShareSemantic,
              ),
              TestimonyStatAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: formatCompactCount(comments, fr: fr),
                onTap: onComment,
                semanticLabel: _l10n(fr).testimonyCommentsSemantic,
              ),
              // Qui a réagi ? (effectif de chaque réaction, personnes et commentaires), toujours
              // visible comme sur le site.
              ReactionPeopleButton(subject: ReactionSubject.testimony, id: testimony.id),
            ],
          ),
        ),
        DownloadButton(testimony: testimony),
      ],
    );
    if (myPrayerTimes < 1) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        MyPrayerTimesLine(times: myPrayerTimes, padding: const EdgeInsets.only(left: 8, top: 2)),
      ],
    );
  }
}

/// Carte « Insight » du verset biblique : fond jaune doux, bordure jaune,
/// petite icône soleil.
class InsightVerseCard extends StatelessWidget {
  const InsightVerseCard({
    super.key,
    required this.verse,
    this.reference,
    this.title,
  });

  final String verse;
  final String? reference;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.wb_sunny_rounded, size: 18, color: AppColors.sun),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? context.l10n.testimonyWordOfGod,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.sunText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '« $verse »',
            style: AppTextStyles.bodyMedium.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.primaryDark,
            ),
          ),
          if (reference != null && reference!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— $reference',
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Étiquette « Hors ligne » (lecture d'un fichier téléchargé).
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) => AppBadge(
        key: const ValueKey('offline-badge'),
        label: context.l10n.testimonyOffline,
        tone: AppBadgeTone.success,
        icon: Icons.download_done_rounded,
        dense: true,
      );
}

/// Chemin de fichier à ouvrir pour une source locale (« file:// » retiré).
String localFilePath(String source) =>
    source.startsWith('file://') ? Uri.parse(source).toFilePath() : source;
