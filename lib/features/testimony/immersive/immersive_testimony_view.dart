// Mode immersif de la page d'un témoignage (au choix de l'utilisateur) :
// plein écran sombre, image du témoignage en fond flouté, typographie de
// lecture, rien d'autre que le témoignage — propice à la prière.
//
// - Texte : paragraphe par paragraphe ; pendant la lecture vocale, le
//   paragraphe lu est mis en lumière et le texte défile tout seul. Toucher un
//   paragraphe lance la lecture à partir de lui.
// - Audio : la transcription défile au rythme de l'audio (horodatage du
//   serveur s'il existe, sinon réparti sur la durée) ; toucher un passage y
//   amène la lecture.
// - Vidéo : lecteur mis en scène (halo lumineux, fond flouté), titre et verset.

import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_player_service.dart' show audioPlayerProvider;
import '../../../shared/widgets/video_poster.dart';
import '../../../shared/widgets/youtube_video_player.dart';
import '../../home/models/testimony_model.dart';
import '../providers/tts_provider.dart';
import '../screens/video_player_screen.dart';
import '../widgets/tts_listen_card.dart' show startTestimonyReading;
import 'reading_passages.dart';

const _kSerif = 'Lora'; // i18n-ignore : nom de police

class ImmersiveTestimonyView extends StatelessWidget {
  const ImmersiveTestimonyView({
    required this.testimony,
    required this.isLiked,
    required this.isPraying,
    required this.onLike,
    required this.onPray,
    required this.onComment,
    required this.onShare,
    required this.onClassic,
    required this.onBack,
    this.verse,
    this.verseRef,
    super.key,
  });

  final Testimony testimony;
  final bool isLiked;
  final bool isPraying;
  final VoidCallback onLike;
  final VoidCallback onPray;
  final VoidCallback onComment;
  final VoidCallback onShare;

  /// Revenir à l'affichage classique (mémorisé).
  final VoidCallback onClassic;
  final VoidCallback onBack;
  final String? verse;
  final String? verseRef;

  String? get _backgroundUrl => switch (testimony) {
        TextTestimony(:final coverImageUrl) => coverImageUrl,
        AudioTestimony(:final coverImageUrl) => coverImageUrl,
        VideoTestimony(:final thumbnailUrl) => thumbnailUrl,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = testimony;
    final bg = _backgroundUrl;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const ValueKey('immersive-testimony'),
        backgroundColor: const Color(0xFF0B1220),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fond : image du témoignage floutée, sinon dégradé nuit.
            if (bg != null && bg.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: CachedNetworkImage(
                  imageUrl: bg,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE60B1220), Color(0xCC111B3A), Color(0xF20B1220)],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barre du haut : retour, affichage classique, partager.
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.commonBack,
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: l10n.immersiveSwitchToClassic,
                        onPressed: onClassic,
                        icon: const Icon(Icons.view_agenda_outlined, color: Colors.white70),
                      ),
                      IconButton(
                        tooltip: l10n.commonShare,
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share_rounded, color: Colors.white70),
                      ),
                    ],
                  ),
                  // En-tête : catégorie, titre, auteur.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.category.label.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.sun,
                            fontSize: 11.5,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: _kSerif,
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.immersiveBy(t.author.displayName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: switch (t) {
                      TextTestimony() => _ImmersiveText(testimony: t),
                      AudioTestimony() => _ImmersiveAudio(testimony: t),
                      VideoTestimony() => _ImmersiveVideo(testimony: t, verse: verse, verseRef: verseRef),
                    },
                  ),
                  _ActionsRow(
                    isLiked: isLiked,
                    isPraying: isPraying,
                    onLike: onLike,
                    onPray: onPray,
                    onComment: onComment,
                    onShare: onShare,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Passages (texte et audio) ────────────────────────────────────────────────

/// Liste de passages : le passage en cours est mis en lumière et amené au
/// tiers de l'écran à chaque changement.
class _PassageList extends StatefulWidget {
  const _PassageList({required this.passages, required this.current, required this.onTap});

  final List<String> passages;

  /// null : rien n'est lu, tout est lisible normalement.
  final int? current;
  final ValueChanged<int> onTap;

  @override
  State<_PassageList> createState() => _PassageListState();
}

class _PassageListState extends State<_PassageList> {
  late List<GlobalKey> _keys = _makeKeys();

  List<GlobalKey> _makeKeys() => List.generate(widget.passages.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(covariant _PassageList old) {
    super.didUpdateWidget(old);
    if (old.passages.length != widget.passages.length) _keys = _makeKeys();
    final c = widget.current;
    if (c != null && c != old.current && c < _keys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[c].currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    return ShaderMask(
      // Fondu en haut et en bas : le texte « apparaît » et « s'efface ».
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.06, 0.9, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.passages.length; i++)
              Padding(
                key: _keys[i],
                padding: const EdgeInsets.only(bottom: 18),
                child: Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => widget.onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                      decoration: BoxDecoration(
                        color: current == i ? Colors.white.withAlpha(16) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: current == i ? AppColors.sun : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 350),
                        style: TextStyle(
                          fontFamily: _kSerif,
                          fontSize: current == i ? 20 : 18,
                          height: 1.6,
                          color: current == null
                              ? Colors.white.withAlpha(225)
                              : current == i
                                  ? Colors.white
                                  : Colors.white.withAlpha(95),
                        ),
                        child: Text(widget.passages[i]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Texte : lecture vocale paragraphe par paragraphe ─────────────────────────

class _ImmersiveText extends ConsumerWidget {
  const _ImmersiveText({required this.testimony});
  final TextTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final passages = textPassages(testimony);
    final starts = chunkStarts(passages);
    final tts = ref.watch(ttsControllerProvider);
    final controller = ref.read(ttsControllerProvider.notifier);
    final mine = tts.isFor(testimony.id);
    final playing = mine && tts.status == TtsStatus.playing;
    final paused = mine && tts.status == TtsStatus.paused;
    final int? current;
    if (!mine) {
      current = null;
    } else if (starts != null) {
      current = passageForChunk(starts, tts.index);
    } else {
      // Découpage inattendu : position proportionnelle.
      current = tts.chunks.isEmpty
          ? 0
          : (tts.index * passages.length / tts.chunks.length).floor().clamp(0, passages.length - 1);
    }

    return Column(
      children: [
        Expanded(
          child: _PassageList(
            passages: passages,
            current: current,
            onTap: (i) => startTestimonyReading(context, ref, testimony, startIndex: starts?[i] ?? 0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: _PlayerBar(
            playing: playing,
            onPlayPause: () {
              if (playing) {
                controller.pause();
              } else if (paused) {
                controller.resume();
              } else {
                startTestimonyReading(context, ref, testimony);
              }
            },
            caption: playing
                ? l10n.testimonyTtsReading
                : paused
                    ? l10n.testimonyTtsPaused
                    : l10n.immersiveTextHint,
            trailing: TextButton(
              onPressed: controller.cycleSpeed,
              child: Text(tts.speed.label, style: const TextStyle(color: Colors.white)),
            ),
            progress: mine ? tts.progress : null,
          ),
        ),
      ],
    );
  }
}

// ── Audio : transcription défilante ──────────────────────────────────────────

class _ImmersiveAudio extends ConsumerWidget {
  const _ImmersiveAudio({required this.testimony});
  final AudioTestimony testimony;

  static String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = testimony;
    final player = ref.watch(audioPlayerProvider);
    final audio = ref.read(audioPlayerProvider.notifier);
    final isThisTrack = player.currentTestimony?.id == t.id;
    final playing = isThisTrack && player.isPlaying;
    final total = isThisTrack && player.duration > Duration.zero
        ? player.duration
        : Duration(seconds: t.durationSeconds);
    final position = isThisTrack ? player.position : Duration.zero;
    final passages = audioPassages(t, total);
    final current = isThisTrack && passages.isNotEmpty ? passageAt(passages, position) : null;

    void start() {
      ref.read(ttsControllerProvider.notifier).stop();
      audio.setTestimonyQueue([t]);
    }

    return Column(
      children: [
        Expanded(
          child: passages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.graphic_eq_rounded, size: 72, color: Colors.white.withAlpha(90)),
                        const SizedBox(height: 12),
                        Text(l10n.immersiveNoTranscript,
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                )
              : _PassageList(
                  passages: [for (final p in passages) p.text],
                  current: current,
                  onTap: (i) {
                    if (isThisTrack) {
                      audio.seek(passages[i].start);
                    } else {
                      start();
                    }
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: _PlayerBar(
            playing: playing,
            onPlayPause: () {
              if (playing) {
                audio.pause();
              } else if (isThisTrack) {
                audio.resume();
              } else {
                start();
              }
            },
            caption: '${_fmt(position)} / ${_fmt(total)}',
            progress: total.inMilliseconds == 0 ? 0 : position.inMilliseconds / total.inMilliseconds,
            onSeekFraction: isThisTrack ? audio.seekToFraction : null,
            trailing: t.transcriptSegments.isEmpty && passages.isNotEmpty
                ? Tooltip(
                    message: l10n.immersiveApproxSync,
                    child: const Icon(Icons.subtitles_outlined, color: Colors.white38, size: 20),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ── Vidéo : lecteur mis en scène ─────────────────────────────────────────────

class _ImmersiveVideo extends StatelessWidget {
  const _ImmersiveVideo({required this.testimony, this.verse, this.verseRef});
  final VideoTestimony testimony;
  final String? verse;
  final String? verseRef;

  @override
  Widget build(BuildContext context) {
    final t = testimony;
    final Widget media = t.isYouTube
        ? YouTubeVideoPlayer(videoId: t.youtubeId!, autoPlay: false)
        : VideoPoster(
            thumbnailUrl: t.thumbnailUrl,
            durationSeconds: t.durationSeconds,
            onPlay: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => VideoPlayerScreen(testimonyId: t.id, mediaPath: t.mediaPath, testimony: t),
            )),
          );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: AppColors.secondary.withAlpha(70), blurRadius: 40, spreadRadius: 2),
                BoxShadow(color: Colors.black.withAlpha(160), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(aspectRatio: 16 / 9, child: media),
            ),
          ),
          if (verse != null && verse!.trim().isNotEmpty) ...[
            const SizedBox(height: 28),
            const Icon(Icons.format_quote_rounded, color: AppColors.sun, size: 28),
            const SizedBox(height: 6),
            Text(
              verse!.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _kSerif,
                color: Colors.white,
                fontSize: 18,
                height: 1.55,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (verseRef != null && verseRef!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(verseRef!, style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Commandes ────────────────────────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.playing,
    required this.onPlayPause,
    required this.caption,
    this.progress,
    this.onSeekFraction,
    this.trailing,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final String caption;
  final double? progress;
  final ValueChanged<double>? onSeekFraction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(110),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? l10n.testimonyTtsPause : l10n.testimonyTtsListen,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPlayPause,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.sun, shape: BoxShape.circle),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.primaryDark, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (progress != null)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: AppColors.sun,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppColors.sun,
                      disabledActiveTrackColor: AppColors.sun,
                      disabledInactiveTrackColor: Colors.white24,
                      disabledThumbColor: AppColors.sun,
                    ),
                    child: SizedBox(
                      height: 20,
                      child: Slider(
                        value: progress!.clamp(0.0, 1.0),
                        onChanged: onSeekFraction,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.isLiked,
    required this.isPraying,
    required this.onLike,
    required this.onPray,
    required this.onComment,
    required this.onShare,
  });

  final bool isLiked;
  final bool isPraying;
  final VoidCallback onLike;
  final VoidCallback onPray;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget action(IconData icon, String label, VoidCallback onTap, {bool active = false}) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: active ? AppColors.sun : Colors.white70, size: 24),
                  const SizedBox(height: 3),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: active ? AppColors.sun : Colors.white60, fontSize: 11.5)),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          action(Icons.volunteer_activism_rounded, l10n.detailPray, onPray, active: isPraying),
          action(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, l10n.detailLike, onLike,
              active: isLiked),
          action(Icons.chat_bubble_outline_rounded, l10n.detailComment, onComment),
          action(Icons.ios_share_rounded, l10n.commonShare, onShare),
        ],
      ),
    );
  }
}
