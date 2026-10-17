import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/journal_offline_controller.dart';
import '../../../l10n/app_localizations.dart';

/// « 512 Ko », « 1.5 Mo », « 2.25 Go » (format d'origine conservé en français).
String _size(int bytes) {
  final l = L10n.current;
  if (bytes < 1024 * 1024) return l.publishSizeKb('${(bytes / 1024).ceil()}');
  if (bytes < 1024 * 1024 * 1024) {
    return l.publishSizeMb((bytes / (1024 * 1024)).toStringAsFixed(1));
  }
  return l.publishSizeGb((bytes / (1024 * 1024 * 1024)).toStringAsFixed(2));
}

/// « Mise à jour le 05/10/2026 à 14h05 » / « Updated 10/05/2026 at 14:05 ».
String _updatedAt(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return L10n.current.journalOfflineUpdatedAt(
      two(l.day), two(l.month), '${l.year}', two(l.hour), two(l.minute));
}

/// Question posée à la première visite du carnet.
Future<void> askJournalOffline(BuildContext context, WidgetRef ref) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.offline_pin_rounded, color: AppColors.primary, size: 36),
      title: Text(context.l10n.journalOfflineAskTitle),
      content: Text(context.l10n.journalOfflineAskBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.journalOfflineAskNo)),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(context.l10n.journalOfflineAskYes),
        ),
      ],
    ),
  );
  final offline = ref.read(journalOfflineProvider.notifier);
  if (yes == true) {
    await offline.enable();
  } else {
    await offline.decline();
  }
}

/// Bouton de la barre du haut : état de la copie hors ligne.
class JournalOfflineButton extends ConsumerWidget {
  const JournalOfflineButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(journalOfflineProvider);
    return IconButton(
      tooltip: s.enabled ? context.l10n.journalOfflineAvailable : context.l10n.journalOfflineKeep,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (_) => const JournalOfflineSheet(),
      ),
      icon: s.syncing
          ? const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              s.enabled ? Icons.offline_pin_rounded : Icons.cloud_download_outlined,
              color: s.enabled ? AppColors.primary : AppColors.textSecondary,
            ),
    );
  }
}

/// Réglage « Disponible hors ligne » et état de la copie.
class JournalOfflineSheet extends ConsumerWidget {
  const JournalOfflineSheet({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final ctrl = ref.read(journalOfflineProvider.notifier);
    if (on) {
      await ctrl.enable();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.journalOfflineRemoveTitle),
        content: Text(context.l10n.journalOfflineRemoveBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.commonRemove)),
        ],
      ),
    );
    if (ok == true) await ctrl.disable();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(journalOfflineProvider);
    final result = s.lastResult;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.journalOfflineTitle, style: AppTextStyles.h4),
            const SizedBox(height: 4),
            Text(
              context.l10n.journalOfflineSheetIntro,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.enabled,
              onChanged: s.syncing ? null : (v) => _toggle(context, ref, v),
              title: Text(context.l10n.journalOfflineAvailableOnPhone),
              subtitle: Text(s.enabled
                  ? context.l10n.journalOfflineEnabledHint
                  : context.l10n.journalOfflineOnlineOnly),
            ),
            if (s.enabled) ...[
              const Divider(),
              if (s.syncing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.total == 0
                          ? context.l10n.journalOfflineUpdating
                          : context.l10n.journalOfflineDownloading(s.done, s.total)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                          value: s.total == 0 ? null : s.done / s.total),
                    ],
                  ),
                )
              else ...[
                _Line(Icons.sd_storage_outlined, context.l10n.journalOfflineSpaceUsed(_size(s.sizeBytes))),
                if (s.settings.lastSyncAt != null)
                  _Line(Icons.update_rounded, _updatedAt(s.settings.lastSyncAt!)),
                if (result != null && result.mediaFailed > 0)
                  _Line(
                    Icons.warning_amber_rounded,
                    context.l10n.journalOfflineMediaFailed(result.mediaFailed),
                    color: AppColors.secondary,
                  ),
                if (s.error != null)
                  _Line(Icons.error_outline_rounded, s.error!, color: AppColors.danger),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.read(journalOfflineProvider.notifier).sync(),
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(context.l10n.journalOfflineUpdateNow),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color))),
        ],
      ),
    );
  }
}
