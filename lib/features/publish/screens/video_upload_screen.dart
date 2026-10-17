// lib/features/publish/screens/video_upload_screen.dart
//
// Suivi de l'envoi d'un témoignage vidéo (Bunny Stream) : compression, envoi
// reprenable, finalisation. Bouton Annuler pendant l'envoi, Réessayer en cas
// d'échec ; à la fin, le témoignage est « en cours de traitement ».
// [VideoUploadPanel] est aussi affiché en tête de « Mes publications ».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../upload/video_upload_controller.dart';
import '../upload/video_upload_models.dart';
import '../../../l10n/app_localizations.dart';

/// Message affiché une fois la vidéo envoyée.
String get kVideoProcessingMessage => L10n.current.uploadProcessingMessage;

class VideoUploadScreen extends ConsumerWidget {
  const VideoUploadScreen({super.key});

  void _leave(BuildContext context, WidgetRef ref) {
    ref.read(videoUploadProvider.notifier).dismiss();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.homePath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upload = ref.watch(videoUploadProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.uploadScreenTitle,
            style: AppTextStyles.h4.copyWith(fontSize: 17)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: context.l10n.commonClose,
          onPressed: () => _leave(context, ref),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (upload == null)
              _NothingToSend(onBack: () => _leave(context, ref))
            else ...[
              VideoUploadPanel(state: upload),
              if (upload.phase == VideoUploadPhase.done) ...[
                const SizedBox(height: AppSpacing.xl),
                // Témoignage affiché « en traitement », sans attendre l'encodage.
                if (upload.testimonyId case final id?) ...[
                  AppButton(
                    key: const ValueKey('open-uploaded-testimony'),
                    label: context.l10n.uploadSeeTestimony,
                    fullWidth: true,
                    leadingIcon: Icons.play_circle_outline_rounded,
                    onPressed: () {
                      ref.read(videoUploadProvider.notifier).dismiss();
                      context.go('/testimony/$id');
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppButton(
                  label: context.l10n.uploadSeeMyPublications,
                  variant: upload.testimonyId == null
                      ? AppButtonVariant.primary
                      : AppButtonVariant.outline,
                  fullWidth: true,
                  leadingIcon: Icons.video_library_outlined,
                  onPressed: () {
                    ref.read(videoUploadProvider.notifier).dismiss();
                    context.go('${AppPaths.profilePath}/my-testimonies');
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: context.l10n.uploadBackHome,
                  variant: AppButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () {
                    ref.read(videoUploadProvider.notifier).dismiss();
                    context.go(AppPaths.homePath);
                  },
                ),
              ] else if (upload.phase != VideoUploadPhase.failed) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.l10n.uploadCanLeave,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _NothingToSend extends StatelessWidget {
  const _NothingToSend({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.cloud_done_outlined,
            size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(context.l10n.uploadNothing,
            style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        AppButton(label: context.l10n.commonBack, onPressed: onBack),
      ],
    );
  }
}

/// Carte de progression d'un envoi de vidéo, avec Annuler / Réessayer.
/// [compact] : version réduite (en tête de « Mes publications »).
class VideoUploadPanel extends ConsumerWidget {
  const VideoUploadPanel({required this.state, this.compact = false, super.key});

  final VideoUploadState state;
  final bool compact;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.uploadCancelTitle),
        content: Text(ctx.l10n.uploadCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.uploadContinue),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(ctx.l10n.uploadCancelPublication),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(videoUploadProvider.notifier).cancel();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = state.phase;
    final failed = phase == VideoUploadPhase.failed;
    final done = phase == VideoUploadPhase.done;
    final waiting = phase == VideoUploadPhase.waitingNetwork;

    final (icon, color) = switch (phase) {
      VideoUploadPhase.done => (Icons.check_circle_rounded, AppColors.success),
      VideoUploadPhase.failed => (Icons.error_outline_rounded, AppColors.danger),
      VideoUploadPhase.waitingNetwork => (Icons.wifi_off_rounded, AppColors.warning),
      VideoUploadPhase.compressing => (Icons.compress_rounded, AppColors.primary),
      _ => (Icons.cloud_upload_outlined, AppColors.primary),
    };

    // Barre déterminée pour la compression et l'envoi ; indéterminée sinon.
    final showsPercent = phase == VideoUploadPhase.compressing ||
        phase == VideoUploadPhase.uploading ||
        waiting;
    final percent = (state.progress * 100).floor();

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: failed ? AppColors.danger.withAlpha(90) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: compact ? 22 : 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.title.isNotEmpty)
                      Text(
                        state.title,
                        style: AppTextStyles.h4.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      done ? kVideoProcessingMessage : phase.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: failed ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (showsPercent)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(context.l10n.uploadPercent(percent),
                      style: AppTextStyles.labelSmall
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (!done && !failed) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: showsPercent ? state.progress : null,
                backgroundColor: AppColors.primarySoft,
                color: waiting ? AppColors.warning : AppColors.secondary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 10),
              _Steps(phase: phase),
            ],
          ],
          if (failed && state.error != null) ...[
            const SizedBox(height: 10),
            Text(state.error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
          ],
          if (state.failedProofs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              state.failedProofs.length == 1
                  ? context.l10n.uploadProofFailed(state.failedProofs.first)
                  : context.l10n.uploadProofsFailed,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],
          if (!done) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (failed) ...[
                  Expanded(
                    child: AppButton(
                      label: context.l10n.commonRetry,
                      leadingIcon: Icons.refresh_rounded,
                      size: compact ? AppButtonSize.small : AppButtonSize.medium,
                      fullWidth: true,
                      onPressed: ref.read(videoUploadProvider.notifier).retry,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AppButton(
                    label: failed ? context.l10n.uploadGiveUp : context.l10n.commonCancel,
                    variant: AppButtonVariant.outline,
                    size: compact ? AppButtonSize.small : AppButtonSize.medium,
                    fullWidth: true,
                    onPressed: () => _confirmCancel(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Étapes : Compression · Envoi · Finalisation.
class _Steps extends StatelessWidget {
  const _Steps({required this.phase});
  final VideoUploadPhase phase;

  @override
  Widget build(BuildContext context) {
    final current = switch (phase) {
      VideoUploadPhase.compressing => 0,
      VideoUploadPhase.preparing ||
      VideoUploadPhase.uploading ||
      VideoUploadPhase.waitingNetwork =>
        1,
      _ => 2,
    };
    final labels = [
      context.l10n.uploadStepCompression,
      context.l10n.uploadStepUpload,
      context.l10n.uploadStepFinalize,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded,
                  size: 14, color: AppColors.textSecondary),
            ),
          Text(
            labels[i],
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
              color: i < current
                  ? AppColors.success
                  : i == current
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
