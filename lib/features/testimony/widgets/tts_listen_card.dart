// lib/features/testimony/widgets/tts_listen_card.dart
//
// Carte « Écouter ce témoignage » (lecture vocale d'un témoignage texte) :
// bulle lecture / pause, vitesse (0,75× · 1× · 1,25×), arrêt, menu avec la
// préférence « Lecture automatique », et la phrase en cours surlignée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/audio_player_service.dart' show audioPlayerProvider;
import '../../../services/tts_service.dart' show detectTextLanguage;
import '../../../shared/utils/rich_text_utils.dart';
import '../../home/models/testimony_model.dart';
import '../providers/tts_provider.dart';

/// Texte lu pour un témoignage texte : titre, corps, puis le verset.
String ttsTextFor(TextTestimony t, {bool includeVerse = true}) {
  String end(String s) {
    final v = s.trim();
    if (v.isEmpty) return v;
    return RegExp(r'[.!?…:;]$').hasMatch(v) ? v : '$v.';
  }

  final parts = <String>[
    end(t.title),
    stripFormatting(t.preview).trim(),
    if (includeVerse && (t.bibleVerse?.trim().isNotEmpty ?? false))
      end([t.bibleVerse!.trim(), if (t.bibleVerseRef?.isNotEmpty ?? false) t.bibleVerseRef!]
          .join(' — ')),
  ];
  return parts.where((p) => p.isNotEmpty).join('\n');
}

/// Démarre la lecture vocale de [t] ; affiche un message si impossible.
Future<void> startTestimonyReading(
  BuildContext context,
  WidgetRef ref,
  TextTestimony t,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  // Un seul son à la fois : mettre en pause un témoignage audio en cours.
  if (ref.exists(audioPlayerProvider) &&
      ref.read(audioPlayerProvider).isPlaying) {
    ref.read(audioPlayerProvider.notifier).pause();
  }
  final text = ttsTextFor(t);
  // Voix selon la langue du témoignage ; langue de l'application si elle est incertaine.
  final ok = await ref.read(ttsControllerProvider.notifier).play(
        testimonyId: t.id,
        text: text,
        languageCode: detectTextLanguage(text, fallback: l10n.isFr ? 'fr' : 'en'),
      );
  if (!ok) {
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          l10n.testimonyTtsUnavailable,
        ),
      ),
    );
  }
}

class TtsListenCard extends ConsumerWidget {
  const TtsListenCard({super.key, required this.testimony});

  final TextTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fr = l10n.isFr;
    final tts = ref.watch(ttsControllerProvider);
    final mine = tts.isFor(testimony.id);
    final playing = mine && tts.status == TtsStatus.playing;
    final paused = mine && tts.status == TtsStatus.paused;
    final controller = ref.read(ttsControllerProvider.notifier);

    final subtitle = playing
        ? l10n.testimonyTtsReading
        : paused
            ? l10n.testimonyTtsPaused
            : l10n.testimonyTtsReadAloud;
    final counter =
        mine && tts.chunks.isNotEmpty ? ' · ${tts.index + 1}/${tts.chunks.length}' : '';

    return Container(
      key: const ValueKey('tts-listen-card'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Bulle lecture / pause
              Semantics(
                button: true,
                label: playing ? l10n.testimonyTtsPause : l10n.testimonyTtsListen,
                child: InkWell(
                  key: const ValueKey('tts-play'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (playing) {
                      controller.pause();
                    } else if (paused) {
                      controller.resume();
                    } else {
                      startTestimonyReading(context, ref, testimony);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppColors.surface,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.testimonyTtsListenTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '$subtitle$counter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Vitesse
              InkWell(
                key: const ValueKey('tts-speed'),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: controller.cycleSpeed,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    tts.speed.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (mine)
                IconButton(
                  key: const ValueKey('tts-stop'),
                  tooltip: l10n.testimonyTtsStop,
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop_rounded,
                      color: AppColors.textSecondary),
                ),
              PopupMenuButton<String>(
                key: const ValueKey('tts-menu'),
                tooltip: l10n.testimonyTtsOptions,
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textSecondary),
                onSelected: (v) {
                  if (v == 'auto') controller.setAutoRead(!tts.autoRead);
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem<String>(
                    value: 'auto',
                    checked: tts.autoRead,
                    child: Text(
                      l10n.testimonyTtsAutoRead,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (mine) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: tts.progress,
                  minHeight: 4,
                  backgroundColor: AppColors.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                ),
              ),
            ),
            if (tts.currentChunk != null) ...[
              const SizedBox(height: 10),
              // Phrase en cours de lecture, surlignée.
              Container(
                key: const ValueKey('tts-current-sentence'),
                width: double.infinity,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.sunSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.sunBorder),
                ),
                child: Text(
                  tts.currentChunk!,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primaryDark),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
