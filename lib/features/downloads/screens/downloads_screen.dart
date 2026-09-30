// Onglet « Téléchargements » (maquette, écran 7) : témoignages disponibles
// hors ligne, filtrés par type, avec l'espace de stockage utilisé.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../home/models/testimony_model.dart';
import '../providers/downloads_provider.dart';
import '../widgets/download_tile.dart';

/// Onglet « Téléchargements » : témoignages disponibles hors ligne.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

/// Filtres (pas de type « Images » : l'application ne publie pas d'images
/// seules).
enum _Filter {
  all('Tous', null),
  video('Vidéos', TestimonyType.video),
  audio('Audios', TestimonyType.audio),
  text('Textes', TestimonyType.text);

  const _Filter(this.label, this.type);
  final String label;
  final TestimonyType? type;
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  _Filter _filter = _Filter.all;

  bool _match(TestimonyType t) => _filter.type == null || _filter.type == t;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(downloadsProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final entries = s.sortedEntries.where((e) => _match(e.type)).toList();
    final tasks =
        s.tasks.values.where((t) => _match(t.entry.type)).toList();
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: canPop,
        titleSpacing: canPop ? 0 : AppSpacing.screen,
        title: Text(
          'Mes téléchargements',
          style: AppTextStyles.h3,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: !s.supported
          ? const _WebNotice()
          : CustomScrollView(
              slivers: [
                if (!online)
                  const SliverToBoxAdapter(child: _OfflineBanner()),
                SliverToBoxAdapter(
                  child: _FilterPills(
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                ),
                if (!s.loaded)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (entries.isEmpty && tasks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      filtered: _filter != _Filter.all && s.entries.isNotEmpty,
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screen),
                    sliver: SliverList.list(
                      children: [
                        for (final t in tasks)
                          DownloadTaskTile(
                              key: ValueKey('task-${t.entry.id}'), task: t),
                        for (final e in entries)
                          DownloadTile(key: ValueKey(e.id), entry: e),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [_StorageFooter(state: s)],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ── Filtres ─────────────────────────────────────────────────────────────────

class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.value, required this.onChanged});

  final _Filter value;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
      child: Row(
        children: [
          for (final f in _Filter.values) ...[
            _Pill(
              label: f.label,
              selected: f == value,
              onTap: () => onChanged(f),
            ),
            if (f != _Filter.values.last) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bandeau hors ligne ───────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.sunSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.sunBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 20, color: AppColors.sunText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Vous êtes hors ligne. Vos téléchargements restent disponibles.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stockage ────────────────────────────────────────────────────────────────

class _StorageFooter extends ConsumerWidget {
  const _StorageFooter({required this.state});

  final DownloadsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cap = ref.watch(downloadsStorageCapProvider);
    final used = state.totalBytes;
    final ratio = cap <= 0 ? 0.0 : (used / cap).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: AppShadows.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      'Stockage utilisé $pct %',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${formatBytes(used)} / ${formatBytes(cap)}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: ratio > 0.9 ? AppColors.danger : AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Gérer le stockage',
            variant: AppButtonVariant.accent,
            leadingIcon: Icons.storage_rounded,
            fullWidth: true,
            onPressed: () => showManageStorageSheet(context),
          ),
        ],
      ),
    );
  }
}

/// Feuille « Gérer le stockage » : total, suppression par type, tout
/// supprimer (avec confirmation).
Future<void> showManageStorageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ManageStorageSheet(),
  );
}

class _ManageStorageSheet extends ConsumerWidget {
  const _ManageStorageSheet();

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
    return ok == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(downloadsProvider);
    final n = ref.read(downloadsProvider.notifier);
    final count = s.entries.length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gérer le stockage', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$count téléchargement${count > 1 ? 's' : ''} · '
              '${formatBytes(s.totalBytes)} utilisés',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final t in TestimonyType.values)
              _TypeRow(
                type: t,
                bytes: s.bytesOfType(t),
                count: s.entries.values.where((e) => e.type == t).length,
                onDelete: () async {
                  final label = switch (t) {
                    TestimonyType.video => 'les vidéos',
                    TestimonyType.audio => 'les audios',
                    TestimonyType.text => 'les textes',
                  };
                  if (await _confirm(context, 'Supprimer $label ?',
                      'Tous $label téléchargés seront supprimés de l’appareil.')) {
                    await n.deleteType(t);
                  }
                },
              ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Tout supprimer',
              variant: AppButtonVariant.danger,
              leadingIcon: Icons.delete_sweep_outlined,
              fullWidth: true,
              onPressed: count == 0 && s.tasks.isEmpty
                  ? null
                  : () async {
                      if (await _confirm(
                          context,
                          'Tout supprimer ?',
                          'Tous vos téléchargements seront supprimés. '
                              'Ils ne seront plus disponibles hors ligne.')) {
                        await n.deleteAll();
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.bytes,
    required this.count,
    required this.onDelete,
  });

  final TestimonyType type;
  final int bytes;
  final int count;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = switch (type) {
      TestimonyType.video => 'Vidéos',
      TestimonyType.audio => 'Audios',
      TestimonyType.text => 'Textes',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(downloadTypeIcon(type),
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text('$count · ${formatBytes(bytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Supprimer les $name',
            onPressed: count == 0 ? null : onDelete,
            icon: Icon(Icons.delete_outline_rounded,
                color: count == 0 ? AppColors.border : AppColors.danger),
          ),
        ],
      ),
    );
  }
}

// ── États vides ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.download_for_offline_outlined,
                size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            filtered ? 'Aucun téléchargement de ce type' : 'Aucun téléchargement',
            style: AppTextStyles.h4,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Téléchargez des témoignages pour les lire, les écouter ou les '
            'regarder sans connexion.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Explorer les témoignages',
            variant: AppButtonVariant.primary,
            leadingIcon: Icons.explore_outlined,
            onPressed: () => GoRouter.maybeOf(context)?.go(AppPaths.explorePath),
          ),
        ],
      ),
    );
  }
}

class _WebNotice extends StatelessWidget {
  const _WebNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android_rounded,
                size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Téléchargements disponibles sur l’application mobile',
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Le navigateur ne permet pas d’enregistrer les témoignages '
              'pour une lecture hors ligne.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
