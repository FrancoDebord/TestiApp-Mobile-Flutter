import 'dart:async' show StreamSubscription;
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/youtube.dart';
import '../../../core/providers/categories_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../bible/providers/bible_providers.dart' show bibleVerseRefProvider;
import '../../home/models/testimony_model.dart' show TestimonyAuthor;
import '../../home/widgets/testimony_card_header.dart' show AuthorAvatar;
import '../../testimony/widgets/testimony_info.dart' show InsightVerseCard;
import '../models/publish_models.dart';
import '../providers/publish_provider.dart';

// =============================================================================
// Aperçu avant publication — le témoignage tel que les lecteurs le verront
// =============================================================================
//
// Lit le brouillon en cours (publishProvider) : rien n'est envoyé au serveur.
// Écrit : texte mis en forme (liens, images). Audio : lecture du fichier
// enregistré. Vidéo : lecture du fichier choisi, ou miniature YouTube.

/// Ouvre l'aperçu par-dessus le formulaire (sans la barre d'onglets).
Future<void> openTestimonyDraftPreview(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const TestimonyDraftPreviewScreen()),
    );

class TestimonyDraftPreviewScreen extends ConsumerWidget {
  const TestimonyDraftPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final draft = ref.watch(publishProvider);
    final format = draft.format ?? TestimonyFormat.text;
    final user = ref.watch(currentUserProvider);
    final categoryName = draft.category == null
        ? null
        : ref
                .watch(categoriesListProvider)
                .where((c) => c.slug == draft.category)
                .firstOrNull
                ?.name ??
            draft.category;
    final body = (format == TestimonyFormat.audio ? draft.audioTranscript : draft.bodyText).trim();
    final verseRef = ref.watch(bibleVerseRefProvider)?.displayRef;
    final youtubeId = format == TestimonyFormat.video && draft.useYouTube
        ? extractYouTubeId(draft.youtubeUrl)
        : null;
    final hasCover = (draft.coverImagePath ?? '').isNotEmpty ||
        (draft.coverImageRemoteUrl ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.publishPreviewTitle),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          _PreviewNotice(visibility: draft.visibility),
          if (hasCover)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: (draft.coverImagePath ?? '').isNotEmpty && !kIsWeb
                      ? Image.file(File(draft.coverImagePath!), fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: draft.coverImageRemoteUrl ?? draft.coverImagePath!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),

          // ── Auteur ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                AuthorAvatar(
                  author: TestimonyAuthor(
                    uid: user?.id ?? '',
                    displayName: user?.displayName ?? l10n.commonYou,
                    avatarUrl: user?.avatarUrl,
                  ),
                  radius: 14,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    user?.displayName ?? l10n.commonYou,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '  ·  ${l10n.timeJustNow}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (categoryName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    categoryName,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(draft.effectiveTitle, style: AppTextStyles.h2),
          ),

          // ── Média ───────────────────────────────────────────────────────
          if (format == TestimonyFormat.audio &&
              ((draft.audioPath ?? '').isNotEmpty || (draft.audioRemoteUrl ?? '').isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PreviewAudio(
                path: draft.audioPath,
                url: draft.audioRemoteUrl,
              ),
            ),
          if (youtubeId != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PreviewYouTube(id: youtubeId, url: draft.youtubeUrl),
            )
          else if (format == TestimonyFormat.video && (draft.videoPath ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PreviewVideo(path: draft.videoPath!),
            ),

          // ── Résumé écrit (audio, vidéo) : aussi sur la page du site ────────
          if (format != TestimonyFormat.text && draft.resume.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(draft.resume.trim(), style: AppTextStyles.bodyLarge),
            ),

          // ── Texte ───────────────────────────────────────────────────────
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ProgressiveRichText(
                text: body,
                mentions: draft.mentions,
                style: AppTextStyles.bodyLarge,
                initialChars: 700,
                stepChars: 1200,
                // Pas d'ouverture de profil depuis l'aperçu.
                onMentionTap: (_) {},
                linkStyle: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (draft.bibleVerse.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: InsightVerseCard(
                verse: draft.bibleVerse.trim(),
                reference: verseRef,
                title: l10n.detailBibleTitle,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        // Hauteur du bouton seulement (sinon la barre prend tout l'écran).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppButton(
                key: const ValueKey('publish-preview-back'),
                label: l10n.publishPreviewBack,
                leadingIcon: Icons.edit_rounded,
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Aperçu : rien n'est encore publié » + qui pourra le voir.
class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.visibility});
  final TestimonyVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, label) = switch (visibility) {
      TestimonyVisibility.public => (Icons.public_rounded, l10n.publishVisibilityPublic),
      TestimonyVisibility.friends => (Icons.people_rounded, l10n.publishVisibilityFriends),
      TestimonyVisibility.private => (Icons.lock_rounded, l10n.publishJournalOption),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sunSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sunBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 18, color: AppColors.sunText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.publishPreviewNotice,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.sunText),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: AppColors.sunText),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.sunText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Audio ─────────────────────────────────────────────────────────────────────

class _PreviewAudio extends StatefulWidget {
  const _PreviewAudio({this.path, this.url});

  /// Enregistrement sur le téléphone, prioritaire sur [url] (déjà envoyé).
  final String? path;
  final String? url;

  @override
  State<_PreviewAudio> createState() => _PreviewAudioState();
}

class _PreviewAudioState extends State<_PreviewAudio> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<Object?>>[];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _duration = d);
      }))
      ..add(_player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      }))
      ..add(_player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          _player
            ..pause()
            ..seek(Duration.zero);
        }
        setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
      }));
    _load();
  }

  Future<void> _load() async {
    try {
      final path = widget.path ?? '';
      if (path.isNotEmpty && !kIsWeb) {
        await _player.setFilePath(path);
      } else {
        await _player.setUrl(path.isNotEmpty ? path : widget.url!);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final progress = total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: _failed
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: Text(context.l10n.publishPreviewMediaError, style: AppTextStyles.bodySmall),
            )
          : Row(
              children: [
                IconButton(
                  key: const ValueKey('preview-audio-play'),
                  tooltip: _playing ? context.l10n.publishPreviewPause : context.l10n.publishPreviewPlay,
                  onPressed: () => _playing ? _player.pause() : _player.play(),
                  icon: Icon(
                    _playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        value: progress,
                        onChanged: total > 0
                            ? (v) => _player.seek(Duration(milliseconds: (v * total).round()))
                            : null,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(_position), style: AppTextStyles.bodySmall),
                            Text(_fmt(_duration), style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Vidéo (fichier choisi) ────────────────────────────────────────────────────

class _PreviewVideo extends StatefulWidget {
  const _PreviewVideo({required this.path});
  final String path;

  @override
  State<_PreviewVideo> createState() => _PreviewVideoState();
}

class _PreviewVideoState extends State<_PreviewVideo> {
  late final VideoPlayerController _video = kIsWeb
      ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
      : VideoPlayerController.file(File(widget.path));
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.initialize().then((_) {
      if (!mounted) return;
      setState(() => _chewie = ChewieController(
            videoPlayerController: _video,
            aspectRatio: _video.value.aspectRatio,
            autoPlay: false,
          ));
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _chewie != null ? _video.value.aspectRatio : 16 / 9;
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: ConstrainedBox(
        // Vidéo verticale : pas plus haute que l'essentiel de l'écran.
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: AspectRatio(
          aspectRatio: ratio,
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: _failed
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.publishPreviewMediaError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : _chewie == null
                    ? const CircularProgressIndicator(color: Colors.white70)
                    : Chewie(controller: _chewie!),
          ),
        ),
      ),
    );
  }
}

// ── Vidéo YouTube (administrateurs) ───────────────────────────────────────────

class _PreviewYouTube extends StatelessWidget {
  const _PreviewYouTube({required this.id, required this.url});
  final String id;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(imageUrl: youTubeThumbnailUrl(id), fit: BoxFit.cover),
              Container(color: Colors.black26),
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 56),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
