import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';

// ── Enums & models ─────────────────────────────────────────────────────────────

enum TestimonyCardType { text, audio, video }

enum TestimonyCategory {
  guerison,
  delivrance,
  conversion,
  mariage,
  famille,
  finances,
  miracles,
  protection,
  ministere,
  salut,
}

extension TestimonyCategoryX on TestimonyCategory {
  String get label => switch (this) {
        TestimonyCategory.guerison => 'Guérison',
        TestimonyCategory.delivrance => 'Délivrance',
        TestimonyCategory.conversion => 'Conversion',
        TestimonyCategory.mariage => 'Mariage',
        TestimonyCategory.famille => 'Famille',
        TestimonyCategory.finances => 'Finances',
        TestimonyCategory.miracles => 'Miracles',
        TestimonyCategory.protection => 'Protection divine',
        TestimonyCategory.ministere => 'Ministère',
        TestimonyCategory.salut => 'Salut',
      };

  List<Color> get gradient => switch (this) {
        TestimonyCategory.guerison => AppColors.guerisonGradient,
        TestimonyCategory.delivrance => AppColors.delivranceGradient,
        TestimonyCategory.conversion => AppColors.conversionGradient,
        TestimonyCategory.mariage => AppColors.mariageGradient,
        TestimonyCategory.famille => AppColors.familleGradient,
        TestimonyCategory.finances => AppColors.financesGradient,
        TestimonyCategory.miracles => AppColors.miraclesGradient,
        TestimonyCategory.protection => AppColors.protectionGradient,
        TestimonyCategory.ministere => AppColors.ministereGradient,
        TestimonyCategory.salut => AppColors.salutGradient,
      };
}

/// Lightweight data class — replace with your Hive/Freezed model as needed.
class TestimonyModel {
  const TestimonyModel({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.category,
    required this.type,
    required this.title,
    required this.excerpt,
    required this.publishedAt,
    required this.likeCount,
    required this.prayCount,
    required this.commentCount,
    this.authorAvatarUrl,
    this.thumbnailUrl,
    this.audioUrl,
    this.videoUrl,
    this.audioDurationSeconds,
    this.videoDurationSeconds,
    this.isLikedByMe = false,
    this.isPrayedByMe = false,
    this.isFeatured = false,
    this.verse,
    this.verseReference,
  });

  final String id;
  final String authorName;
  final String authorHandle;
  final TestimonyCategory category;
  final TestimonyCardType type;
  final String title;
  final String excerpt;
  final DateTime publishedAt;
  final int likeCount;
  final int prayCount;
  final int commentCount;
  final String? authorAvatarUrl;
  final String? thumbnailUrl;
  final String? audioUrl;
  final String? videoUrl;
  final int? audioDurationSeconds;
  final int? videoDurationSeconds;
  final bool isLikedByMe;
  final bool isPrayedByMe;
  final bool isFeatured;
  final String? verse;
  final String? verseReference;
}

// ── Main widget ────────────────────────────────────────────────────────────────

class TestimonyCard extends StatelessWidget {
  const TestimonyCard({
    required this.testimony,
    required this.onTap,
    this.onLike,
    this.onPray,
    this.onComment,
    this.onShare,
    super.key,
  });

  final TestimonyModel testimony;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onPray;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media header (audio / video thumbnail)
            if (testimony.type != TestimonyCardType.text)
              _MediaHeader(testimony: testimony),

            // Featured badge strip
            if (testimony.isFeatured) _FeaturedBadge(testimony: testimony),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UserAvatarRow(testimony: testimony),
                  const SizedBox(height: 10),
                  _CategoryChip(category: testimony.category),
                  const SizedBox(height: 8),
                  Text(testimony.title, style: AppTextStyles.h4),
                  const SizedBox(height: 6),
                  Text(
                    testimony.excerpt,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (testimony.verse != null) ...[
                    const SizedBox(height: 10),
                    _VerseBlock(
                      verse: testimony.verse!,
                      reference: testimony.verseReference,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _StatsRow(testimony: testimony),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            _ActionBar(
              testimony: testimony,
              onLike: onLike,
              onPray: onPray,
              onComment: onComment,
              onShare: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

/// Thumbnail / waveform header for audio and video cards.
class _MediaHeader extends StatelessWidget {
  const _MediaHeader({required this.testimony});
  final TestimonyModel testimony;

  @override
  Widget build(BuildContext context) {
    final isAudio = testimony.type == TestimonyCardType.audio;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Stack(
        children: [
          // Background: thumbnail or gradient placeholder
          SizedBox(
            height: isAudio ? 90 : 190,
            width: double.infinity,
            child: testimony.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: testimony.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _GradientPlaceholder(
                        gradient: testimony.category.gradient),
                    errorWidget: (_, __, ___) => _GradientPlaceholder(
                        gradient: testimony.category.gradient),
                  )
                : _GradientPlaceholder(gradient: testimony.category.gradient),
          ),

          // Dark scrim for video
          if (!isAudio)
            Container(
              height: 190,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(160),
                  ],
                ),
              ),
            ),

          // Play button overlay
          Positioned.fill(
            child: Center(
              child: Container(
                width: isAudio ? 44 : 56,
                height: isAudio ? 44 : 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAudio
                      ? Icons.headphones_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: isAudio ? 24 : 32,
                ),
              ),
            ),
          ),

          // Duration badge
          if (testimony.audioDurationSeconds != null ||
              testimony.videoDurationSeconds != null)
            Positioned(
              bottom: 8,
              right: 10,
              child: _DurationBadge(
                seconds: (testimony.audioDurationSeconds ??
                    testimony.videoDurationSeconds)!,
              ),
            ),

          // Type badge (top-left)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAudio ? AppColors.secondary : AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAudio ? Icons.mic_rounded : Icons.videocam_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAudio ? 'Audio' : 'Vidéo',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: Colors.white, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({required this.gradient});
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});
  final int seconds;

  String get _formatted {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatted,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Featured gradient banner.
class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge({required this.testimony});
  final TestimonyModel testimony;

  @override
  Widget build(BuildContext context) {
    final isTextType = testimony.type == TestimonyCardType.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: testimony.category.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: isTextType
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : BorderRadius.zero,
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            'Témoignage mis en avant',
            style: AppTextStyles.labelSmall
                .copyWith(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Author avatar + name + handle + relative time.
class _UserAvatarRow extends StatelessWidget {
  const _UserAvatarRow({required this.testimony});
  final TestimonyModel testimony;

  String get _relativeTime {
    final diff = DateTime.now().difference(testimony.publishedAt);
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${testimony.publishedAt.day}/${testimony.publishedAt.month}/${testimony.publishedAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        _AuthorAvatar(
          avatarUrl: testimony.authorAvatarUrl,
          name: testimony.authorName,
        ),
        const SizedBox(width: 10),

        // Name + handle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(testimony.authorName, style: AppTextStyles.labelMedium),
              Text(
                '@${testimony.authorHandle} • $_relativeTime',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),

        // Options icon
        const Icon(Icons.more_horiz_rounded,
            color: AppColors.textSecondary, size: 20),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.avatarUrl, required this.name});
  final String? avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
        backgroundColor: AppColors.border,
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primaryLight.withAlpha(40),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
      ),
    );
  }
}

/// Single category chip (used inside the card).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});
  final TestimonyCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: category.gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Bible verse / quote block.
class _VerseBlock extends StatelessWidget {
  const _VerseBlock({required this.verse, this.reference});
  final String verse;
  final String? reference;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: AppColors.primary.withAlpha(100), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"$verse"', style: AppTextStyles.verseQuote.copyWith(
            fontSize: 14,
            color: AppColors.textPrimary.withAlpha(200),
          )),
          if (reference != null) ...[
            const SizedBox(height: 4),
            Text('— $reference', style: AppTextStyles.verseReference),
          ],
        ],
      ),
    );
  }
}

/// Compact stat counters (views, likes, prayers, comments).
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.testimony});
  final TestimonyModel testimony;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
          icon: Icons.favorite_rounded,
          count: testimony.likeCount,
          color: testimony.isLikedByMe ? AppColors.danger : AppColors.textSecondary,
        ),
        const SizedBox(width: 14),
        _StatItem(
          icon: Icons.volunteer_activism_rounded,
          count: testimony.prayCount,
          color: testimony.isPrayedByMe
              ? AppColors.secondary
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 14),
        _StatItem(
          icon: Icons.chat_bubble_outline_rounded,
          count: testimony.commentCount,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  String get _formatted {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          _formatted,
          style: AppTextStyles.bodySmall.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Four-action bottom bar.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.testimony,
    this.onLike,
    this.onPray,
    this.onComment,
    this.onShare,
  });

  final TestimonyModel testimony;
  final VoidCallback? onLike;
  final VoidCallback? onPray;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          _ActionButton(
            icon: testimony.isLikedByMe
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: 'J\'aime',
            activeColor: AppColors.danger,
            isActive: testimony.isLikedByMe,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.volunteer_activism_rounded,
            label: 'Prier',
            activeColor: AppColors.secondary,
            isActive: testimony.isPrayedByMe,
            onTap: onPray,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Commenter',
            activeColor: AppColors.primary,
            isActive: false,
            onTap: onComment,
          ),
          _ActionButton(
            icon: Icons.share_rounded,
            label: 'Partager',
            activeColor: AppColors.primary,
            isActive: false,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color activeColor;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
