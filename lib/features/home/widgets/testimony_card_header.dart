import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../community/widgets/follow_button.dart';
import '../models/testimony_model.dart';

/// Compact author row for content-first card layout.
/// Avatar (28 px) · Name · timestamp · optional Suivre button.
class TestimonyAuthorRow extends StatelessWidget {
  const TestimonyAuthorRow({
    required this.testimony,
    this.showFollow = true,
    super.key,
  });

  final Testimony testimony;
  final bool showFollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => openAuthorProfile(context, testimony.author.uid),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryLight.withAlpha(40),
            backgroundImage: testimony.author.avatarUrl != null
                ? NetworkImage(testimony.author.avatarUrl!)
                : null,
            child: testimony.author.avatarUrl == null
                ? Text(
                    testimony.author.displayName.isNotEmpty
                        ? testimony.author.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => openAuthorProfile(context, testimony.author.uid),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: testimony.author.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (testimony.author.isOrganization ||
                      testimony.author.isVerified)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: OrganizationBadge(
                        isOrganization: testimony.author.isOrganization,
                        isVerified: testimony.author.isVerified,
                        size: 13,
                      ),
                    ),
                  const TextSpan(text: '  ·  '),
                  TextSpan(text: _timeAgo(testimony.createdAt)),
                ],
              ),
            ),
          ),
        ),
        if (showFollow) ...[
          const SizedBox(width: 8),
          FollowButton(userId: testimony.author.uid, displayName: testimony.author.displayName, compact: true),
        ],
      ],
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
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
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryLight.withAlpha(40),
                backgroundImage: testimony.author.avatarUrl != null
                    ? NetworkImage(testimony.author.avatarUrl!)
                    : null,
                child: testimony.author.avatarUrl == null
                    ? Text(
                        testimony.author.displayName.isNotEmpty
                            ? testimony.author.displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
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
                    _timeAgo(testimony.createdAt),
                    style: AppTextStyles.bodySmall,
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }
}

// ── Profil de l'auteur ────────────────────────────────────────────────────────

/// Ouvre le profil public de l'auteur (son propre profil : onglet « Profil »).
void openAuthorProfile(BuildContext context, String uid) {
  if (uid.isEmpty) return;
  context.push('/users/$uid');
}

// ── Category badge ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final TestimonyCategory category;

  static const Map<TestimonyCategory, Color> _bgColors = {
    TestimonyCategory.guerison: Color(0xFFECFDF3),
    TestimonyCategory.delivrance: Color(0xFFFFFAEB),
    TestimonyCategory.conversion: Color(0xFFEAF1FC),
    TestimonyCategory.mariage: Color(0xFFFCE7F3),
    TestimonyCategory.famille: Color(0xFFE0F2FE),
    TestimonyCategory.finances: Color(0xFFD1FAE5),
    TestimonyCategory.miracles: Color(0xFFFFF1E2),
    TestimonyCategory.protection: Color(0xFFECFDF3),
    TestimonyCategory.ministere: Color(0xFFF5F3FF),
    TestimonyCategory.salut: Color(0xFFFFF1F2),
  };

  static const Map<TestimonyCategory, Color> _fgColors = {
    TestimonyCategory.guerison: Color(0xFF12B76A),
    TestimonyCategory.delivrance: Color(0xFFD97706),
    TestimonyCategory.conversion: Color(0xFF184797),
    TestimonyCategory.mariage: Color(0xFFDB2777),
    TestimonyCategory.famille: Color(0xFF0284C7),
    TestimonyCategory.finances: Color(0xFF059669),
    TestimonyCategory.miracles: Color(0xFFD96F0B),
    TestimonyCategory.protection: Color(0xFF15803D),
    TestimonyCategory.ministere: Color(0xFF6D28D9),
    TestimonyCategory.salut: Color(0xFFE11D48),
  };

  @override
  Widget build(BuildContext context) {
    final bg = _bgColors[category] ?? const Color(0xFFE4E7EC);
    final fg = _fgColors[category] ?? const Color(0xFF667085);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        category.label,
        style: AppTextStyles.bodySmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
