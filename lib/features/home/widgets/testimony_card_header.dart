import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../community/widgets/follow_button.dart';
import '../models/testimony_model.dart';
import 'testimony_action_bar.dart' show formatCount;

/// Compact author row for content-first card layout (maquette « Accueil »).
/// Avatar (28 px) · Nom · badge organisation · « 3.4k vues » · « il y a 2 jours »
/// · bouton Suivre optionnel.
class TestimonyAuthorRow extends StatelessWidget {
  const TestimonyAuthorRow({
    required this.testimony,
    this.showFollow = true,
    this.showViews = true,
    super.key,
  });

  final Testimony testimony;
  final bool showFollow;
  final bool showViews;

  @override
  Widget build(BuildContext context) {
    final author = testimony.author;
    final views = testimony.stats.views;
    final meta = [
      if (showViews && views > 0) '${formatCount(views)} vues',
      timeAgoFr(testimony.createdAt),
    ].join(' · ');

    return Row(
      children: [
        GestureDetector(
          onTap: () => openAuthorProfile(context, author.uid),
          child: AuthorAvatar(author: author, radius: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => openAuthorProfile(context, author.uid),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (author.isOrganization || author.isVerified)
                  OrganizationBadge(
                    isOrganization: author.isOrganization,
                    isVerified: author.isVerified,
                    size: 13,
                  ),
                Flexible(
                  child: Text(
                    '  ·  $meta',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showFollow) ...[
          const SizedBox(width: 8),
          FollowButton(userId: author.uid, displayName: author.displayName, compact: true),
        ],
      ],
    );
  }
}

/// « il y a 2 jours », « il y a 3 h », « à l'instant »…
String timeAgoFr(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'il y a 1 jour';
  if (diff.inDays < 30) return 'il y a ${diff.inDays} jours';
  if (diff.inDays < 365) return 'il y a ${diff.inDays ~/ 30} mois';
  final years = diff.inDays ~/ 365;
  return 'il y a $years an${years > 1 ? 's' : ''}';
}

/// Avatar rond de l'auteur (photo ou initiale sur fond bleu clair).
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({required this.author, this.radius = 14, super.key});
  final TestimonyAuthor author;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = author.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              author.displayName.isNotEmpty
                  ? author.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

/// Category chip — public so cards can use it directly.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({required this.category, super.key});
  final TestimonyCategory category;

  @override
  Widget build(BuildContext context) =>
      _CategoryBadge(category: category);
}

// ─────────────────────────────────────────────────────────────────────────────

/// Reusable card header: avatar + display name + timestamp + follow button
/// + optional trailing widget + category chip.
class TestimonyCardHeader extends StatelessWidget {
  const TestimonyCardHeader({
    required this.testimony,
    this.onFollowTap,
    this.trailing,
    super.key,
  });

  final Testimony testimony;
  final VoidCallback? onFollowTap;
  /// Ancien rappel du bouton Suivre : le bouton gère désormais lui-même l'abonnement.
  /// Optional widget placed after the follow button (e.g. a PopupMenuButton).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () => openAuthorProfile(context, testimony.author.uid),
              child: AuthorAvatar(author: testimony.author, radius: 20),
            ),
            const SizedBox(width: 10),
            // Name + timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => openAuthorProfile(context, testimony.author.uid),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            testimony.author.displayName,
                            style: AppTextStyles.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        OrganizationBadge(
                          isOrganization: testimony.author.isOrganization,
                          isVerified: testimony.author.isVerified,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    timeAgoFr(testimony.createdAt),
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Follow button
            FollowButton(userId: testimony.author.uid, displayName: testimony.author.displayName, compact: true),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Category chip
        _CategoryBadge(category: testimony.category),
      ],
    );
  }

}

// ── Profil de l'auteur ────────────────────────────────────────────────────────

/// Ouvre le profil public de l'auteur (son propre profil : onglet « Profil »).
void openAuthorProfile(BuildContext context, String uid) {
  if (uid.isEmpty) return;
  context.push('/users/$uid');
}

// ── Category badge ────────────────────────────────────────────────────────────

/// Ton de badge de la charte pour chaque catégorie (jaune « Guérison » comme
/// sur la maquette, bleu / orange / vert pour les autres).
AppBadgeTone categoryBadgeTone(TestimonyCategory category) => switch (category) {
      TestimonyCategory.guerison => AppBadgeTone.yellow,
      TestimonyCategory.miracles => AppBadgeTone.yellow,
      TestimonyCategory.delivrance => AppBadgeTone.orange,
      TestimonyCategory.mariage => AppBadgeTone.orange,
      TestimonyCategory.salut => AppBadgeTone.orange,
      TestimonyCategory.finances => AppBadgeTone.success,
      TestimonyCategory.famille => AppBadgeTone.success,
      TestimonyCategory.conversion => AppBadgeTone.blue,
      TestimonyCategory.protection => AppBadgeTone.blue,
      TestimonyCategory.ministere => AppBadgeTone.blue,
    };

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final TestimonyCategory category;

  @override
  Widget build(BuildContext context) => AppBadge(
        label: category.label,
        tone: categoryBadgeTone(category),
        dense: true,
      );
}
