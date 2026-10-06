import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/prophecy.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// « 5 octobre 2026 ».
String prophecyDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String _two(int n) => n.toString().padLeft(2, '0');

String formatClock(Duration d) => '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';

/// « il y a 3 jours » / « aujourd'hui ».
String prayedAgo(DateTime d) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days <= 0) return "aujourd'hui";
  if (days == 1) return 'hier';
  if (days < 30) return 'il y a $days jours';
  return 'le ${prophecyDay(d)}';
}

/// Pastille d'état : En attente · Échéance passée · Accomplie.
class ProphecyStatusChip extends StatelessWidget {
  const ProphecyStatusChip({required this.prophecy, super.key});
  final Prophecy prophecy;

  @override
  Widget build(BuildContext context) {
    final p = prophecy;
    final (IconData icon, String label, Color bg, Color fg) = p.fulfilled
        ? (Icons.verified_rounded, 'Accomplie', AppColors.successSoft, AppColors.success)
        : p.isOverdue
            ? (Icons.hourglass_bottom_rounded, 'Échéance passée', AppColors.secondarySoft, AppColors.secondaryDark)
            : (Icons.hourglass_top_rounded, 'En attente', AppColors.primarySoft, AppColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

/// Carte d'une parole dans la liste.
class ProphecyCard extends StatelessWidget {
  const ProphecyCard({required this.prophecy, required this.onTap, super.key});

  final Prophecy prophecy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = prophecy;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: p.fulfilled ? AppColors.success.withAlpha(90) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: ProphecyStatusChip(prophecy: p)),
                  const Spacer(),
                  if (p.hasAudio) ...[
                    const Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                  ],
                  if (p.reminder != null && !p.fulfilled)
                    const Icon(Icons.notifications_active_outlined, size: 16, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p.displayTitle(prophecyDay),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              if (p.title != null && p.bodyText != null) ...[
                const SizedBox(height: 4),
                Text(p.bodyText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Meta(Icons.event_note_rounded, prophecyDay(p.receivedOn)),
                  if (p.givenBy != null) _Meta(Icons.person_outline_rounded, p.givenBy!),
                  if (p.dueOn != null && !p.fulfilled) _Meta(Icons.flag_outlined, 'Échéance : ${prophecyDay(p.dueOn!)}'),
                  if (p.fulfilledOn != null) _Meta(Icons.verified_outlined, 'Accomplie le ${prophecyDay(p.fulfilledOn!)}'),
                  _Meta(Icons.volunteer_activism_outlined,
                      p.prayerCount == 0 ? 'Pas encore priée' : 'Priée ${p.prayerCount} fois'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Lecteur audio simple (fichier local ou adresse).
class ProphecyAudioPlayer extends StatefulWidget {
  const ProphecyAudioPlayer({this.url, this.filePath, this.onDelete, this.dark = false, super.key});

  final String? url;
  final String? filePath;
  final VoidCallback? onDelete;
  final bool dark;

  @override
  State<ProphecyAudioPlayer> createState() => _ProphecyAudioPlayerState();
}

class _ProphecyAudioPlayerState extends State<ProphecyAudioPlayer> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.filePath != null) {
        await _player.setFilePath(widget.filePath!);
      } else if (widget.url != null) {
        await _player.setUrl(widget.url!);
      }
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
            _player.pause();
            _player.seek(Duration.zero);
          }
          setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
        }));
    } catch (_) {
      if (mounted) setState(() => _error = true);
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

  @override
  Widget build(BuildContext context) {
    final fg = widget.dark ? Colors.white : AppColors.primary;
    final sub = widget.dark ? Colors.white70 : AppColors.textSecondary;
    final max = _duration.inMilliseconds.toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: widget.dark ? Colors.white.withAlpha(25) : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: _playing ? 'Pause' : 'Écouter',
            onPressed: _error ? null : () => _playing ? _player.pause() : _player.play(),
            icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                size: 40, color: fg),
          ),
          Expanded(
            child: _error
                ? Text('Audio indisponible', style: TextStyle(color: sub))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: _position.inMilliseconds.toDouble().clamp(0, max <= 0 ? 1 : max),
                          max: max <= 0 ? 1 : max,
                          activeColor: fg,
                          inactiveColor: fg.withAlpha(50),
                          onChanged: max <= 0 ? null : (v) => _player.seek(Duration(milliseconds: v.round())),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatClock(_position), style: TextStyle(color: sub, fontSize: 11.5)),
                          Text(formatClock(_duration), style: TextStyle(color: sub, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
          ),
          if (widget.onDelete != null)
            IconButton(
              tooltip: "Supprimer l'enregistrement",
              onPressed: widget.onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: sub),
            ),
        ],
      ),
    );
  }
}
