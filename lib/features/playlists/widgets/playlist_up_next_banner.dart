// Bandeau « À suivre : <titre> » de la lecture automatique d'une liste :
// compte à rebours de 5 s, Annuler, Lire maintenant. À zéro : [onPlay].

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../models/playlist_models.dart';

class PlaylistUpNextBanner extends StatefulWidget {
  const PlaylistUpNextBanner({
    required this.item,
    required this.onPlay,
    required this.onCancel,
    this.seconds = 5,
    this.dark = true,
    super.key,
  });

  final PlaylistItem item;

  /// Appelé une seule fois : à la fin du compte à rebours ou par « Lire maintenant ».
  final VoidCallback onPlay;
  final VoidCallback onCancel;
  final int seconds;

  /// Sur la vidéo (fond sombre) ; sinon carte claire (lecteur audio).
  final bool dark;

  @override
  State<PlaylistUpNextBanner> createState() => _PlaylistUpNextBannerState();
}

class _PlaylistUpNextBannerState extends State<PlaylistUpNextBanner> {
  late int _left = widget.seconds;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) {
        _play();
      } else {
        setState(() => _left--);
      }
    });
  }

  void _play() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onPlay();
  }

  void _cancel() {
    _done = true;
    _timer?.cancel();
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fg = widget.dark ? Colors.white : AppColors.textPrimary;
    final muted = widget.dark ? Colors.white70 : AppColors.textSecondary;
    final title = widget.item.title.isEmpty ? l10n.playlistNext : widget.item.title;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: widget.dark ? Colors.black.withValues(alpha: 0.82) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Icon(Icons.playlist_play_rounded, color: widget.dark ? Colors.white : AppColors.primary, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.playlistUpNext(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppFonts.family, color: fg, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      l10n.playlistUpNextIn(_left),
                      style: TextStyle(fontFamily: AppFonts.family, color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _cancel,
                style: TextButton.styleFrom(foregroundColor: fg, minimumSize: const Size(48, 40)),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                key: const ValueKey('playlist-play-now'),
                onPressed: _play,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l10n.playlistPlayNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
