import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/journal_offline_controller.dart';

String _size(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} Ko';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
}

String _when(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} à ${two(l.hour)}h${two(l.minute)}';
}

/// Question posée à la première visite du carnet.
Future<void> askJournalOffline(BuildContext context, WidgetRef ref) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.offline_pin_rounded, color: AppColors.primary, size: 36),
      title: const Text('Garder aussi une copie sur ce téléphone ?'),
      content: const Text(
        'Votre carnet est toujours sauvegardé en ligne : même si vous perdez '
        'ou changez de téléphone, vous le retrouvez en vous connectant.\n\n'
        'Une copie sur ce téléphone vous permet en plus de le relire et '
        'd\'écouter vos audios et vidéos sans connexion. Elle utilise de '
        'l\'espace de stockage.\n\nVous pourrez changer d\'avis à tout moment.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non merci')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Oui, garder une copie'),
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
      tooltip: s.enabled ? 'Disponible hors ligne' : 'Garder hors ligne',
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
        title: const Text('Retirer la copie de ce téléphone ?'),
        content: const Text(
            'Les fichiers enregistrés sur ce téléphone seront effacés. Votre carnet '
            'reste intact en ligne : rien n\'est supprimé de votre compte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
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
            Text('Hors ligne', style: AppTextStyles.h4),
            const SizedBox(height: 4),
            Text(
              'Votre carnet est toujours sauvegardé en ligne. La copie sur ce '
              'téléphone sert à le relire sans connexion.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.enabled,
              onChanged: s.syncing ? null : (v) => _toggle(context, ref, v),
              title: const Text('Disponible hors ligne sur ce téléphone'),
              subtitle: Text(s.enabled
                  ? 'Textes, audios et vidéos gardés sur ce téléphone'
                  : 'Seulement en ligne'),
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
                          ? 'Mise à jour de la copie…'
                          : 'Téléchargement des audios et vidéos : ${s.done} / ${s.total}'),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                          value: s.total == 0 ? null : s.done / s.total),
                    ],
                  ),
                )
              else ...[
                _Line(Icons.sd_storage_outlined, 'Espace utilisé : ${_size(s.sizeBytes)}'),
                if (s.settings.lastSyncAt != null)
                  _Line(Icons.update_rounded, 'Mise à jour le ${_when(s.settings.lastSyncAt!)}'),
                if (result != null && result.mediaFailed > 0)
                  _Line(
                    Icons.warning_amber_rounded,
                    '${result.mediaFailed} fichier${result.mediaFailed > 1 ? 's' : ''} audio/vidéo '
                    'non téléchargé${result.mediaFailed > 1 ? 's' : ''} (réessayé à la prochaine mise à jour)',
                    color: AppColors.secondary,
                  ),
                if (s.error != null)
                  _Line(Icons.error_outline_rounded, s.error!, color: AppColors.danger),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => ref.read(journalOfflineProvider.notifier).sync(),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Mettre à jour maintenant'),
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
