import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/user_testimony_model.dart';
import '../providers/profile_provider.dart';

// =============================================================================
// MyTestimoniesScreen — "Mes témoignages" with status tabs
// =============================================================================

class MyTestimoniesScreen extends ConsumerStatefulWidget {
  const MyTestimoniesScreen({super.key});

  @override
  ConsumerState<MyTestimoniesScreen> createState() =>
      _MyTestimoniesScreenState();
}

class _MyTestimoniesScreenState extends ConsumerState<MyTestimoniesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myTestimoniesNotifierProvider);

    final all       = async.value ?? [];
    final pending   = all.where((t) => t.status == 'pending').toList();
    final published = all.where((t) => t.status == 'published').toList();
    final rejected  = all.where((t) => t.status == 'rejected').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mes témoignages',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
          ),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: 'Tous (${all.length})'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('En attente'),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: pending.length, color: _statusColor('pending')),
                  ],
                ],
              ),
            ),
            Tab(text: 'Publiés (${published.length})'),
            Tab(text: 'Rejetés (${rejected.length})'),
          ],
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(myTestimoniesNotifierProvider),
        ),
        data: (_) => TabBarView(
          controller: _tabs,
          children: [
            _TestimonyTab(testimonies: all,       status: null),
            _TestimonyTab(testimonies: pending,   status: 'pending'),
            _TestimonyTab(testimonies: published, status: 'published'),
            _TestimonyTab(testimonies: rejected,  status: 'rejected'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/publish'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nouveau',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Tab content
// =============================================================================

class _TestimonyTab extends ConsumerWidget {
  const _TestimonyTab({required this.testimonies, required this.status});
  final List<UserTestimony> testimonies;
  final String? status; // null = all tabs

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (testimonies.isEmpty) return _EmptyState(status: status);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(myTestimoniesNotifierProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: testimonies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _MyTestimonyCard(testimony: testimonies[i]),
      ),
    );
  }
}

// =============================================================================
// Card
// =============================================================================

class _MyTestimonyCard extends ConsumerWidget {
  const _MyTestimonyCard({required this.testimony});
  final UserTestimony testimony;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: type icon + info + menu ───────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeIcon(type: testimony.type, thumbnailUrl: testimony.thumbnailUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimony.title.isNotEmpty ? testimony.title : '(Sans titre)',
                        style: AppTextStyles.h4.copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _CategoryChip(slug: testimony.category),
                          const SizedBox(width: 8),
                          Text(
                            _relativeDate(testimony.createdAt),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CardMenu(
                  testimony: testimony,
                  onView: () => context.push('/testimony/${testimony.id}'),
                  onEdit: () => _showEditDialog(context, ref),
                  onDelete: () => _confirmDelete(context, ref),
                ),
              ],
            ),

            // ── Status + rejection reason ───────────────────────────────────
            const SizedBox(height: 10),
            Row(
              children: [
                _StatusBadge(status: testimony.status),
                if (testimony.type != 'text' && testimony.durationSeconds > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.schedule_rounded,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    _fmtDuration(testimony.durationSeconds),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),

            if (testimony.status == 'pending') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        size: 14, color: Color(0xFF856404)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'En cours de validation par notre équipe. '
                        'Vous recevrez une notification dès que ce sera traité.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF856404),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (testimony.status == 'rejected' &&
                testimony.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Color(0xFFB91C1C)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        testimony.rejectionReason!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: testimony.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Modifier le titre',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Titre du témoignage',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newTitle = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (newTitle.isEmpty || newTitle == testimony.title) return;
              final ok = await ref
                  .read(myTestimoniesNotifierProvider.notifier)
                  .updateTitle(testimony.id, newTitle);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Impossible de modifier. Réessaie.')),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Supprimer ce témoignage ?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Cette action est irréversible. Le témoignage sera définitivement supprimé.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await ref
                  .read(myTestimoniesNotifierProvider.notifier)
                  .deleteTestimony(testimony.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Impossible de supprimer. Réessaie.')),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  static String _relativeDate(DateTime date) {
    final now   = DateTime.now();
    final diff  = now.difference(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    if (diff.inDays < 30) return 'Il y a ${diff.inDays ~/ 7} sem';
    return DateFormat('d MMM yyyy', 'fr').format(date);
  }

  static String _fmtDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

// =============================================================================
// Small widgets
// =============================================================================

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type, this.thumbnailUrl});
  final String  type;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (type == 'video' && thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52, height: 52,
          child: Image.network(
            thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _iconContainer(),
          ),
        ),
      );
    }
    return _iconContainer();
  }

  Widget _iconContainer() {
    final (color, bg, icon) = switch (type) {
      'audio' => (const Color(0xFFEF4444), const Color(0xFFFEE2E2), Icons.mic_rounded),
      'video' => (AppColors.secondary,     const Color(0xFFFEF3C7), Icons.videocam_rounded),
      _       => (AppColors.primary,       const Color(0xFFF3E8FF), Icons.edit_note_rounded),
    };
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'pending'   => ('En attente', const Color(0xFFFFF3CD), const Color(0xFF856404)),
      'published' => ('Publié',     const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      'rejected'  => ('Rejeté',     const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      _           => (status,       AppColors.border,         AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    if (slug.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        slug,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});
  final int   count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({
    required this.testimony,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });
  final UserTestimony testimony;
  final VoidCallback  onView;
  final VoidCallback  onEdit;
  final VoidCallback  onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 20, color: AppColors.textSecondary),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        switch (v) {
          case 'view':   onView();
          case 'edit':   onEdit();
          case 'delete': onDelete();
        }
      },
      itemBuilder: (_) => [
        if (testimony.status == 'published')
          const PopupMenuItem(
            value: 'view',
            child: Row(children: [
              Icon(Icons.visibility_outlined, size: 18),
              SizedBox(width: 10),
              Text('Consulter'),
            ]),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 10),
            Text('Modifier le titre'),
          ]),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            SizedBox(width: 10),
            Text('Supprimer', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (status) {
      'pending'   => (
          Icons.hourglass_top_rounded,
          'Aucun témoignage en attente',
          'Vos témoignages soumis apparaîtront ici\npendant leur validation.',
        ),
      'published' => (
          Icons.check_circle_outline_rounded,
          'Aucun témoignage publié',
          'Vos témoignages validés\ns\'afficheront ici.',
        ),
      'rejected'  => (
          Icons.block_rounded,
          'Aucun témoignage rejeté',
          'Bonne nouvelle ! Aucun de vos\ntémoignages n\'a été rejeté.',
        ),
      _           => (
          Icons.auto_stories_outlined,
          'Aucun témoignage',
          'Partagez ce que Dieu a fait\ndans votre vie.',
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56,
                color: AppColors.textSecondary.withAlpha(80)),
            const SizedBox(height: 16),
            Text(title,
                style: AppTextStyles.h4
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
            if (status == null || status == 'published') ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/publish'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Publier un témoignage',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Error view
// =============================================================================

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Impossible de charger vos témoignages.',
                style: AppTextStyles.h4
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: AppTextStyles.bodySmall,
                maxLines: 2,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================

Color _statusColor(String status) => switch (status) {
      'pending'   => const Color(0xFF856404),
      'published' => const Color(0xFF065F46),
      'rejected'  => const Color(0xFFB91C1C),
      _           => AppColors.textSecondary,
    };
