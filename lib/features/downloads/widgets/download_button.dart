import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../home/models/testimony_model.dart';
import '../offline_open.dart';
import '../providers/downloads_provider.dart';

/// Bouton « Télécharger pour lire hors ligne » d'un témoignage.
///
/// API stable, utilisable partout (cartes, détail, lecteurs) :
///   DownloadButton(testimony: t)            → icône seule
///   DownloadButton(testimony: t, label: true) → icône + libellé
///
/// États : à télécharger → progression (appui = annuler) → téléchargé
/// (appui = Lire hors ligne / Supprimer) ; en échec → appui = réessayer.
/// Invisible sur le web et pour les vidéos YouTube (non téléchargeables).
/// Les invités peuvent télécharger.
class DownloadButton extends ConsumerWidget {
  const DownloadButton({
    super.key,
    required this.testimony,
    this.label = false,
    this.color,
    this.size = 22,
  });

  final Testimony testimony;

  /// Affiche aussi un libellé (« Télécharger », « Téléchargé »…).
  final bool label;

  /// Couleur de l'icône (par défaut : textSecondary).
  final Color? color;
  final double size;

  static bool isDownloadable(Testimony t) =>
      !kIsWeb && !(t is VideoTestimony && t.isYouTube);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDownloadable(testimony)) return const SizedBox.shrink();
    final supported = ref.watch(downloadsProvider.select((s) => s.supported));
    if (!supported) return const SizedBox.shrink();
    final item = ref.watch(downloadItemProvider(testimony.id));
    final c = color ?? AppColors.textSecondary;

    final (Widget icon, String text, String tip, VoidCallback onTap) =
        switch (item.status) {
      DownloadStatus.none => (
          Icon(Icons.download_rounded, size: size, color: c),
          'Télécharger',
          'Télécharger pour lire hors ligne',
          () => _start(context, ref),
        ),
      DownloadStatus.queued || DownloadStatus.downloading => (
          _Progress(value: item.progress, size: size, color: c),
          item.progress == null
              ? 'En attente…'
              : '${((item.progress ?? 0) * 100).round()} %',
          'Annuler le téléchargement',
          () => _cancel(context, ref),
        ),
      DownloadStatus.done => (
          Icon(Icons.download_done_rounded,
              size: size, color: AppColors.success),
          'Téléchargé',
          'Téléchargé · disponible hors ligne',
          () => _openMenu(context, ref, item.entry),
        ),
      DownloadStatus.failed => (
          Icon(Icons.refresh_rounded, size: size, color: AppColors.danger),
          'Réessayer',
          item.error ?? 'Échec du téléchargement · réessayer',
          () => _start(context, ref, retry: true),
        ),
    };

    if (!label) {
      return IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: icon,
      );
    }
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: size, height: size, child: Center(child: icon)),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: item.status == DownloadStatus.done
                        ? AppColors.success
                        : item.status == DownloadStatus.failed
                            ? AppColors.danger
                            : c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    final m = ScaffoldMessenger.maybeOf(context);
    m
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _start(BuildContext context, WidgetRef ref,
      {bool retry = false}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notifier = ref.read(downloadsProvider.notifier);
    _snack(context, 'Téléchargement lancé…');
    final outcome = retry
        ? await notifier.retry(testimony)
        : await notifier.download(testimony);
    final msg = switch (outcome) {
      DownloadOutcome.done => '« ${testimony.title} » est disponible hors ligne',
      DownloadOutcome.cancelled => null,
      DownloadOutcome.failed || DownloadOutcome.unsupported =>
        notifier.statusOf(testimony.id).error ?? 'Échec du téléchargement',
    };
    if (msg == null || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _cancel(BuildContext context, WidgetRef ref) {
    ref.read(downloadsProvider.notifier).cancel(testimony.id);
    _snack(context, 'Téléchargement annulé');
  }

  Future<void> _openMenu(
      BuildContext context, WidgetRef ref, DownloadEntry? entry) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
              child: Text(
                testimony.title,
                style: AppTextStyles.h4,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.primary),
              title: const Text('Lire hors ligne'),
              onTap: () => Navigator.pop(ctx, 'play'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              title: const Text('Supprimer le téléchargement'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final e = entry ?? ref.read(downloadsProvider).entries[testimony.id];
    if (choice == 'play' && e != null) {
      await openDownloadedTestimony(context, ref, e);
    } else if (choice == 'delete') {
      await ref.read(downloadsProvider.notifier).delete(testimony.id);
      if (context.mounted) _snack(context, 'Téléchargement supprimé');
    }
  }
}

/// Progression circulaire avec une croix (annuler) au centre.
class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.size, required this.color});

  final double? value;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2.4,
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
            ),
            Icon(Icons.close_rounded, size: size * 0.55, color: color),
          ],
        ),
      );
}
