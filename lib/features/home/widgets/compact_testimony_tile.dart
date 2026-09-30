// lib/features/home/widgets/compact_testimony_tile.dart
//
// Affichage « liste » d'un témoignage : une ligne minimaliste
// (vignette · titre · auteur/catégorie/date · lecture · chevron) qu'on peut
// déplier d'un tap pour voir l'aperçu, les statistiques et les actions.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../../shared/widgets/youtube_video_player.dart' show YouTubeBadge;
import '../../testimony/screens/shorts_screen.dart';
import '../../testimony/screens/video_player_screen.dart' show VideoPlayerScreen;
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'feed_card_frame.dart' show ensureMember;
import 'testimony_action_bar.dart';

/// Ouvre le lecteur plein écran (Shorts) sur [testimony], dans l'ordre des
/// vidéos du fil principal — même comportement que la grande carte vidéo.
/// Une vidéo YouTube s'ouvre dans le lecteur vidéo (lecteur YouTube) : le
/// défilement vertical des Shorts n'accepte que les fichiers du serveur.
void openVideoTestimony(
  BuildContext context,
  WidgetRef ref,
  VideoTestimony testimony,
) {
  if (testimony.isYouTube) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoPlayerScreen(
          testimonyId: testimony.id,
          testimony: testimony,
        ),
      ),
    );
    return;
  }
  var allVideos = ref
      .read(feedNotifierProvider)
      .whereType<VideoTestimony>()
      .where((v) => !v.isYouTube)
      .toList();
  var startIndex = allVideos.indexWhere((v) => v.id == testimony.id);
  if (startIndex < 0) {
    allVideos = [testimony, ...allVideos];
    startIndex = 0;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ShortsScreen(
        testimonies: allVideos,
        startIndex: startIndex,
      ),
    ),
  );
}

class CompactTestimonyTile extends ConsumerStatefulWidget {
  const CompactTestimonyTile({
    required this.testimony,
    this.initiallyExpanded = false,
    super.key,
  });

  final Testimony testimony;
  final bool initiallyExpanded;

  @override
  ConsumerState<CompactTestimonyTile> createState() =>
      _CompactTestimonyTileState();
}

class _CompactTestimonyTileState extends ConsumerState<CompactTestimonyTile> {
  static const _duration = Duration(milliseconds: 200);

  late bool _expanded = widget.initiallyExpanded;

  Testimony get _t => widget.testimony;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _openDetail() => context.push('/testimony/${_t.id}');

  /// Même action que le bouton lecture de la grande carte.
  void _play() => switch (_t) {
        VideoTestimony v => openVideoTestimony(context, ref, v),
        _ => _openDetail(),
      };

  void _share() {
    SharePlus.instance.share(ShareParams(
      text: '${_t.title}\n\n${_t.shareLink}',
    ));
    ref.read(interactionProvider.notifier).recordShare(_t.id);
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    if (diff.inDays < 365) return 'il y a ${diff.inDays ~/ 30} mois';
    return 'il y a ${diff.inDays ~/ 365} an${diff.inDays >= 730 ? 's' : ''}';
  }

  String get _typeLabel => switch (_t) {
        TextTestimony() => 'Témoignage écrit',
        AudioTestimony() => 'Témoignage audio',
        VideoTestimony() => 'Témoignage vidéo',
      };

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final hasPlay = t is AudioTestimony || t is VideoTestimony;

    return DecoratedBox(
      decoration: AppShadows.cardDecoration,
      child: Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.antiAlias,
      borderRadius: AppRadius.cardRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Ligne compacte (tap = déplier / replier) ────────────────────
          Semantics(
            button: true,
            expanded: _expanded,
            label: '$_typeLabel : ${t.title}, par ${t.author.displayName}. '
                '${_expanded ? 'Appuyer pour replier' : 'Appuyer pour déplier'}',
            child: InkWell(
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                  child: Row(
                    children: [
                      _Thumbnail(testimony: t),
                      const SizedBox(width: 12),
                      Expanded(child: _TitleBlock(testimony: t, timeAgo: _timeAgo(t.createdAt))),
                      if (hasPlay)
                        IconButton(
                          tooltip: t is VideoTestimony
                              ? 'Lire la vidéo'
                              : "Écouter l'audio",
                          onPressed: _play,
                          constraints:
                              const BoxConstraints(minWidth: 44, minHeight: 44),
                          icon: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: _expanded ? 'Replier' : 'Déplier',
                        onPressed: _toggle,
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        icon: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: _duration,
                          child: const Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Détails dépliés ─────────────────────────────────────────────
          AnimatedSize(
            duration: _duration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _ExpandedDetails(
                    testimony: t,
                    onPlay: _play,
                    onOpen: _openDetail,
                    onShare: _share,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Vignette 56×56 ───────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.testimony});
  final Testimony testimony;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final t = testimony;
    final Widget content = switch (t) {
      VideoTestimony v => Stack(
          fit: StackFit.expand,
          children: [
            _NetworkOrFallback(
              url: v.thumbnailUrl,
              fallbackIcon: Icons.videocam_rounded,
            ),
            Container(color: Colors.black.withAlpha(50)),
            const Center(
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 26),
            ),
            if (v.isYouTube)
              const Positioned(
                right: 3,
                bottom: 3,
                child: YouTubeBadge(compact: true),
              )
            else if (v.durationSeconds > 0)
              Positioned(
                right: 3,
                bottom: 3,
                child: _MiniBadge(text: v.formattedDuration),
              ),
          ],
        ),
      AudioTestimony a => Stack(
          fit: StackFit.expand,
          children: [
            _NetworkOrFallback(
              url: a.coverImageUrl,
              fallbackIcon: Icons.graphic_eq_rounded,
            ),
            if (a.durationSeconds > 0)
              Positioned(
                right: 3,
                bottom: 3,
                child: _MiniBadge(text: a.formattedDuration),
              ),
          ],
        ),
      TextTestimony() => const _IconSquare(icon: Icons.format_quote_rounded),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: _size, height: _size, child: content),
    );
  }
}

class _NetworkOrFallback extends StatelessWidget {
  const _NetworkOrFallback({required this.url, required this.fallbackIcon});
  final String? url;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty || !u.startsWith('http')) {
      return _IconSquare(icon: fallbackIcon);
    }
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      placeholder: (_, _) => _IconSquare(icon: fallbackIcon),
      errorWidget: (_, _, _) => _IconSquare(icon: fallbackIcon),
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary, size: 26),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppFonts.family,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Titre + sous-titre ───────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.testimony, required this.timeAgo});
  final Testimony testimony;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    final t = testimony;
    final meta = AppTextStyles.bodySmall.copyWith(
      color: AppColors.textSecondary,
      fontSize: 12,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Flexible(
              child: Text(
                t.author.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            OrganizationBadge(
              isOrganization: t.author.isOrganization,
              isVerified: t.author.isVerified,
              size: 13,
            ),
            Flexible(
              flex: 2,
              child: Text(
                ' · ${t.category.label} · $timeAgo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: meta,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Partie dépliée ───────────────────────────────────────────────────────────

class _ExpandedDetails extends ConsumerWidget {
  const _ExpandedDetails({
    required this.testimony,
    required this.onPlay,
    required this.onOpen,
    required this.onShare,
  });

  final Testimony testimony;
  final VoidCallback onPlay;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = testimony;
    final liked = ref.watch(likedIdsProvider).contains(t.id);
    final prayed = ref.watch(prayedIdsProvider).contains(t.id);
    final saved = ref.watch(savedIdsProvider).contains(t.id);
    final reaction = ref.watch(reactionsMapProvider)[t.id];

    final previewStyle = AppTextStyles.bodyMedium.copyWith(
      color: AppColors.textSecondary,
      height: 1.5,
    );

    final String? verseRef = switch (t) {
      TextTestimony x => x.bibleVerseRef,
      AudioTestimony x => x.bibleVerseRef,
      VideoTestimony x => x.bibleVerseRef,
    };

    final Widget preview = switch (t) {
      TextTestimony x => Text(
          stripFormatting(x.preview).trim(),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: previewStyle,
        ),
      AudioTestimony x => x.transcriptPreview.trim().isEmpty
          ? const SizedBox.shrink()
          : Text(
              x.transcriptPreview.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: previewStyle.copyWith(fontStyle: FontStyle.italic),
            ),
      VideoTestimony x => _VideoPreview(testimony: x, onPlay: onPlay),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          preview,
          if (verseRef != null && verseRef.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    verseRef.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TestimonyActionBar(
            testimony: t,
            isLiked: liked,
            isPrayed: prayed,
            isSaved: saved,
            onSave: () async {
              if (!await ensureMember(
                  context, ref, 'enregistrer vos favoris')) {
                return;
              }
              ref.read(interactionProvider.notifier).toggleSave(t.id);
            },
            currentReaction: reaction,
            onReact: (type) async {
              if (!await ensureMember(
                  context, ref, 'réagir aux témoignages')) {
                return;
              }
              final n = ref.read(interactionProvider.notifier);
              type == null ? n.removeReaction(t.id) : n.setReaction(t.id, type);
            },
            onPray: () async {
              if (!await ensureMember(
                  context, ref, 'réagir aux témoignages')) {
                return;
              }
              ref.read(interactionProvider.notifier).togglePray(t.id);
            },
            onComment: () => context.push('/testimony/${t.id}/comments'),
            onShare: onShare,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Voir le témoignage'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.testimony, required this.onPlay});
  final VideoTestimony testimony;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Lire la vidéo',
      child: GestureDetector(
        onTap: onPlay,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetworkOrFallback(
                  url: testimony.thumbnailUrl,
                  fallbackIcon: Icons.video_library_outlined,
                ),
                Container(color: Colors.black.withAlpha(40)),
                if (testimony.isYouTube)
                  const Positioned(
                    right: 8,
                    bottom: 8,
                    child: YouTubeBadge(),
                  ),
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: AppColors.primary, size: 30),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
