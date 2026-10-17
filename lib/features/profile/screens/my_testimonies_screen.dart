import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../conversion/widgets/conversion_widgets.dart' show ConversionLabel;
import '../../../core/router/app_routes.dart' show AppPaths;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/media/video_source.dart' show VideoStatusText;
import '../../../shared/widgets/video_poster.dart'
    show VideoThumbnailImage, formatVideoDuration;
import '../../publish/upload/video_resend.dart' show resendFailedVideo;
import '../../../shared/widgets/why_testify_card.dart';
import '../../publish/screens/video_upload_screen.dart' show VideoUploadPanel;
import '../../publish/upload/video_upload_controller.dart' show videoUploadProvider;
import '../../publish/upload/video_upload_models.dart' show VideoUploadPhase;
import '../../../services/api_service.dart' show LaravelApiException;
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
    final upload = ref.watch(videoUploadProvider);

    final all       = async.value ?? [];
    final pending   = all.where((t) => t.status == 'pending').toList();
    final published = all.where((t) => t.status == 'published').toList();
    final rejected  = all.where((t) => t.status == 'rejected').toList();
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.profileMyTesti,
          style: const TextStyle(
            fontFamily: AppFonts.family,
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
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 13,
          ),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: l10n.profileTabAll(all.length)),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.profileStatusPending),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: pending.length, color: _statusColor('pending')),
                  ],
                ],
              ),
            ),
            Tab(text: l10n.profileTabPublished(published.length)),
            Tab(text: l10n.profileTabRejected(rejected.length)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Envoi de vidéo en cours ou interrompu : progression, Annuler, Réessayer.
          if (upload != null && upload.phase != VideoUploadPhase.done)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: () => context.push(AppPaths.videoUploadPath),
                child: VideoUploadPanel(state: upload, compact: true),
              ),
            ),
          Expanded(
            child: async.when(
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/publish'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          l10n.profileNewTestimony,
          style: const TextStyle(
            fontFamily: AppFonts.family,
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
        // Onglet « Tous » : « Pourquoi témoigner ? » replié en fin de liste.
        itemCount: testimonies.length + (status == null ? 1 : 0),
        separatorBuilder: (_, i) => SizedBox(height: i == testimonies.length - 1 ? 24 : 10),
        itemBuilder: (_, i) => i < testimonies.length
            ? _MyTestimonyCard(testimony: testimonies[i])
            : const WhyTestifyCard(collapsible: true),
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
                _TypeIcon(testimony: testimony),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimony.title.isNotEmpty ? testimony.title : context.l10n.commonUntitled,
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
                  // Vidéo en traitement : le détail re-vérifie son état.
                  onView: () => context.push('/testimony/${testimony.id}'),
                  // Témoignage de conversion : écran dédié (année, lieu, verset).
                  onEdit: () => testimony.isConversion
                      ? context.push('/conversions/mine/edit')
                      : editAndResubmit(context, ref, testimony),
                  onDelete: () => _confirmDelete(context, ref),
                ),
              ],
            ),

            // ── Status + rejection reason ───────────────────────────────────
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusBadge(status: testimony.status),
                if (testimony.isConversion) const ConversionLabel(compact: true),
                // Vidéo pas encore en ligne : visible ici seulement.
                if (testimony.isVideoProcessing || testimony.isVideoFailed)
                  _VideoStatusBadge(failed: testimony.isVideoFailed),
                // Vidéo : durée affichée sur la vignette.
                if (testimony.type == 'audio' && testimony.durationSeconds > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        _fmtDuration(testimony.durationSeconds),
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),

            // Encodage en échec : nouvel envoi (upload-init, TUS, upload-complete).
            if (testimony.type == 'video' && testimony.isVideoFailed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        VideoStatusText.failed,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 11,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('resend-video-button'),
                  onPressed: () => resendFailedVideo(context, ref, testimony.id),
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: Text(VideoStatusText.resend),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],

            if (testimony.status == 'pending') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.sunSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.sun.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded,
                        size: 14, color: AppColors.sunText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.profilePendingNotice,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 11,
                          color: AppColors.sunText,
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
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        testimony.rejectionReason!,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 11,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Refusé : corriger puis renvoyer en modération (PUT /testimonies/{id}).
            if (testimony.status == 'rejected') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('resubmit-button'),
                  onPressed: () => editAndResubmit(context, ref, testimony),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(context.l10n.profileEditResubmit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.l10n.profileDeleteTestimonyTitle,
          style: const TextStyle(fontFamily: AppFonts.family, fontWeight: FontWeight.w600),
        ),
        content: Text(
          context.l10n.profileDeleteTestimonyBody,
          style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
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
                  SnackBar(
                      content: Text(context.l10n.profileDeleteTestimonyFailed)),
                );
              }
            },
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  static String _relativeDate(DateTime date) {
    final now   = DateTime.now();
    final diff  = now.difference(date);
    final l10n  = L10n.current;
    if (diff.inDays == 0) return l10n.profileDateToday;
    if (diff.inDays == 1) return l10n.profileDateYesterday;
    if (diff.inDays < 7) return l10n.profileDateDaysAgo(diff.inDays);
    if (diff.inDays < 30) return l10n.profileDateWeeksAgo(diff.inDays ~/ 7);
    return formatDate(date);
  }

  static String _fmtDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';
}

// =============================================================================
// Small widgets
// =============================================================================

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.testimony});
  final UserTestimony testimony;

  String get type => testimony.type;

  @override
  Widget build(BuildContext context) {
    if (type != 'video') return _iconContainer();
    final t = testimony;
    final duration = formatVideoDuration(t.durationSeconds);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52, height: 52,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Pas de miniature tant que l'encodage n'a pas abouti.
            VideoThumbnailImage(
              url: t.isVideoFailed ? null : t.thumbnailUrl,
              fallback: _iconContainer(),
            ),
            if (t.isVideoProcessing || t.isVideoFailed)
              ColoredBox(
                color: Colors.black.withAlpha(90),
                child: Icon(
                  t.isVideoFailed
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              )
            else if (duration.isNotEmpty)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    duration,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconContainer() {
    final (color, bg, icon) = switch (type) {
      'audio' => (AppColors.danger, AppColors.dangerSoft, Icons.mic_rounded),
      'video' => (AppColors.secondary,     AppColors.secondarySoft, Icons.videocam_rounded),
      _       => (AppColors.primary,       AppColors.primarySoft, Icons.edit_note_rounded),
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
    final l10n = context.l10n;
    final (label, bg, fg) = switch (status) {
      'pending'   => (l10n.profileStatusPending,   AppColors.sunSoft, AppColors.sunText),
      'published' => (l10n.profileStatusPublished, AppColors.successSoft, AppColors.success),
      'rejected'  => (l10n.profileStatusRejected,  AppColors.dangerSoft, AppColors.danger),
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
          fontFamily: AppFonts.family,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// « Vidéo en cours de traitement » (envoi ou encodage Bunny) ou « Échec ».
class _VideoStatusBadge extends StatelessWidget {
  const _VideoStatusBadge({required this.failed});
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = failed
        ? (context.l10n.profileVideoFailed, Icons.error_outline_rounded, AppColors.dangerSoft, AppColors.danger)
        : (VideoStatusText.processing, Icons.hourglass_top_rounded,
            AppColors.infoSoft, AppColors.info);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
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
          fontFamily: AppFonts.family,
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
          fontFamily: AppFonts.family,
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
        if (testimony.status == 'published' || testimony.type == 'video')
          PopupMenuItem(
            value: 'view',
            child: Row(children: [
              const Icon(Icons.visibility_outlined, size: 18),
              const SizedBox(width: 10),
              Text(context.l10n.profileView),
            ]),
          ),
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 18),
            const SizedBox(width: 10),
            Text(context.l10n.commonEdit),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            const SizedBox(width: 10),
            Text(context.l10n.commonDelete, style: const TextStyle(color: Colors.red)),
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
    final l10n = context.l10n;
    final (icon, title, subtitle) = switch (status) {
      'pending'   => (
          Icons.hourglass_top_rounded,
          l10n.profileEmptyPendingTitle,
          l10n.profileEmptyPendingBody,
        ),
      'published' => (
          Icons.check_circle_outline_rounded,
          l10n.profileEmptyPublishedTitle,
          l10n.profileEmptyPublishedBody,
        ),
      'rejected'  => (
          Icons.block_rounded,
          l10n.profileEmptyRejectedTitle,
          l10n.profileEmptyRejectedBody,
        ),
      _           => (
          Icons.auto_stories_outlined,
          l10n.profileEmptyAllTitle,
          l10n.profileEmptyAllBody,
        ),
    };
    return Center(
      child: SingleChildScrollView(
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
                label: Text(l10n.profilePublishTestimony,
                    style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            // Aucun témoignage : « Pourquoi témoigner ? » ouvert sur la première raison
            // (le bouton Publier est juste au-dessus).
            if (status == null) ...[
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: const WhyTestifyCard(initiallyOpen: 0, showAction: false),
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
            Text(context.l10n.profileMyTestimoniesLoadFailed,
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
              label: Text(context.l10n.commonRetry),
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
      'pending'   => AppColors.sunText,
      'published' => AppColors.success,
      'rejected'  => AppColors.danger,
      _           => AppColors.textSecondary,
    };

// =============================================================================
// « Modifier et renvoyer » (docs serveur fonctionnalites/gestion-des-temoignages.md)
// =============================================================================

/// Message de confirmation avant de modifier un témoignage déjà publié.
String publishedEditWarning(UserTestimony t) {
  final l10n = L10n.current;
  return t.hasApprovedLabel
      ? l10n.profilePublishedEditWarningLabel
      : l10n.profilePublishedEditWarning;
}

/// Modifie le titre et le texte, puis enregistre (PUT /testimonies/{id}). Le
/// serveur renvoie le statut : refusé ou publié → « Renvoyé en modération ».
Future<void> editAndResubmit(BuildContext context, WidgetRef ref, UserTestimony t) async {
  final edited = await showModalBottomSheet<({String title, String body})>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _EditTestimonySheet(testimony: t),
  );
  if (edited == null || !context.mounted) return;

  // Déjà publié : il repassera en modération (et perdra son label).
  if (t.status == 'published') {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.profileEditPublishedTitle),
        content: Text(publishedEditWarning(t)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonContinue),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final updated = await ref
        .read(myTestimoniesNotifierProvider.notifier)
        .resubmit(t.id, title: edited.title, bodyText: edited.body);
    final resent = updated.status == 'pending' && t.status != 'pending';
    messenger.showSnackBar(SnackBar(
      content: Text(resent ? l10n.profileResubmitted : l10n.profileChangesSaved),
      behavior: SnackBarBehavior.floating,
    ));
  } on LaravelApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.displayMessage)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaveFailed)));
  }
}

class _EditTestimonySheet extends StatefulWidget {
  const _EditTestimonySheet({required this.testimony});
  final UserTestimony testimony;

  @override
  State<_EditTestimonySheet> createState() => _EditTestimonySheetState();
}

class _EditTestimonySheetState extends State<_EditTestimonySheet> {
  late final _title = TextEditingController(text: widget.testimony.title);
  late final _body = TextEditingController(text: widget.testimony.bodyText);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.testimony;
    final rejected = t.status == 'rejected';
    final l10n = context.l10n;
    final bodyLabel = switch (t.type) {
      'audio' => l10n.profileBodyTranscription,
      'video' => l10n.profileBodyDescription,
      _ => l10n.profileBodyTestimony,
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(rejected ? l10n.profileEditResubmit : l10n.profileEditTestimony, style: AppTextStyles.h4),
                if (rejected && (t.rejectionReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.profileRejectionReason(t.rejectionReason ?? ''),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _title,
                  maxLength: 200,
                  decoration: InputDecoration(labelText: l10n.profileTitleLabel),
                  validator: (v) => (v ?? '').trim().isEmpty ? l10n.profileTitleRequired : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 5000,
                  decoration: InputDecoration(labelText: bodyLabel, alignLabelWithHint: true),
                  validator: (v) => t.type == 'text' && (v ?? '').trim().isEmpty
                      ? l10n.profileBodyRequired
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('resubmit-save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    if (!(_form.currentState?.validate() ?? false)) return;
                    Navigator.of(context).pop((title: _title.text.trim(), body: _body.text.trim()));
                  },
                  icon: Icon(rejected ? Icons.send_rounded : Icons.save_outlined),
                  label: Text(rejected ? l10n.profileResubmitAction : l10n.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
