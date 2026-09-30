// Ligne d'un témoignage téléchargé (ou en cours de téléchargement) :
// vignette 64×64 + icône du type, titre, « Vidéo · 3,4 Mo », menu.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../home/models/testimony_model.dart';
import '../offline_open.dart';
import '../providers/downloads_provider.dart';

IconData downloadTypeIcon(TestimonyType t) => switch (t) {
      TestimonyType.video => Icons.play_arrow_rounded,
      TestimonyType.audio => Icons.volume_up_rounded,
      TestimonyType.text => Icons.article_outlined,
    };

/// Supprime un téléchargement après confirmation.
Future<void> confirmDeleteDownload(
    BuildContext context, WidgetRef ref, DownloadEntry e) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer le téléchargement ?'),
      content: Text(
        '« ${e.title} » ne sera plus disponible hors ligne.',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await ref.read(downloadsProvider.notifier).delete(e.id);
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Téléchargement supprimé'),
        behavior: SnackBarBehavior.floating,
      ));
  }
}

/// Téléchargement terminé.
class DownloadTile extends ConsumerWidget {
  const DownloadTile({required this.entry, super.key});

  final DownloadEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TileShell(
      entry: entry,
      subtitle: entry.subtitle,
      onTap: () => openDownloadedTestimony(context, ref, entry),
      trailing: PopupMenuButton<String>(
        tooltip: 'Plus d’options',
        icon: const Icon(Icons.more_vert_rounded,
            color: AppColors.textSecondary),
        onSelected: (v) {
          if (v == 'play') openDownloadedTestimony(context, ref, entry);
          if (v == 'delete') confirmDeleteDownload(context, ref, entry);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'play',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.primary),
              title: Text('Lire'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: Text('Supprimer'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Téléchargement en attente / en cours / en échec.
class DownloadTaskTile extends ConsumerWidget {
  const DownloadTaskTile({required this.task, super.key});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(downloadsProvider.notifier);
    final failed = task.status == DownloadStatus.failed;
    final subtitle = switch (task.status) {
      DownloadStatus.queued => 'En attente…',
      DownloadStatus.failed => task.error ?? 'Échec du téléchargement',
      _ => task.progress == null
          ? 'Téléchargement…'
          : 'Téléchargement · ${((task.progress ?? 0) * 100).round()} %',
    };
    return _TileShell(
      entry: task.entry,
      subtitle: subtitle,
      subtitleColor: failed ? AppColors.danger : null,
      progress: failed ? null : (task.progress ?? -1),
      trailing: failed
          ? IconButton(
              tooltip: 'Réessayer',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
              onPressed: () => n.retryId(task.entry.id),
            )
          : IconButton(
              tooltip: 'Annuler',
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
              onPressed: () => n.cancel(task.entry.id),
            ),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.entry,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.subtitleColor,
    this.progress,
  });

  final DownloadEntry entry;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? subtitleColor;

  /// null = pas de barre ; < 0 = indéterminée ; sinon 0–1.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              DownloadThumb(entry: entry),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: subtitleColor ?? AppColors.textSecondary,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: AppSpacing.xs + 2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress! < 0 ? null : progress,
                          minHeight: 4,
                          color: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Vignette 64×64 arrondie avec l'icône du type au centre.
class DownloadThumb extends StatelessWidget {
  const DownloadThumb({required this.entry, this.size = 64, super.key});

  final DownloadEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = entry.thumbnailPath;
    final hasImage = !kIsWeb && path != null && File(path).existsSync();
    final isText = entry.type == TestimonyType.text;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.file(File(path), fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _ThumbFallback())
            else
              _ThumbFallback(text: isText),
            Center(
              child: Container(
                width: size * 0.44,
                height: size * 0.44,
                decoration: BoxDecoration(
                  color: hasImage
                      ? AppColors.surface.withValues(alpha: 0.92)
                      : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  downloadTypeIcon(entry.type),
                  size: size * 0.28,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({this.text = false});

  final bool text;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: text ? AppColors.sunSoft : AppColors.primarySoft,
      );
}
