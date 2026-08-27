import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import 'prayer_request_detail_screen.dart';
import 'submit_prayer_request_screen.dart';

// =============================================================================
// PrayerRequestsScreen — liste des requêtes de prière
// =============================================================================

class PrayerRequestsScreen extends ConsumerWidget {
  const PrayerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRequests = ref.watch(prayerRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        title: Text(
          AppLocalizations.of(context).prayerTitle,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: AppLocalizations.of(context).prayerNew,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const SubmitPrayerRequestScreen(),
              ),
            ),
          ),
        ],
      ),
      body: asyncRequests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Impossible de charger les requêtes'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(prayerRequestsProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer',
                    style: TextStyle(fontFamily: 'Inter')),
              ),
            ],
          ),
        ),
        data: (requests) => requests.isEmpty
            ? _EmptyState(
                onAdd: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => const SubmitPrayerRequestScreen(),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _RequestCard(request: requests[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const SubmitPrayerRequestScreen(),
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: Text(
          AppLocalizations.of(context).prayerSubmit,
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});
  final PrayerRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPrayed = request.userHasPrayed;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasPrayed
              ? AppColors.primary.withAlpha(80)
              : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PrayerRequestDetailScreen(requestId: request.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + time
              Row(
                children: [
                  _Avatar(initials: request.initials),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.authorName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          request.timeAgo,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (request.visibility == PrayerVisibility.private)
                    const Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 10),

              // Body
              Text(
                request.body,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  _PrayButton(
                    count: request.prayerCount,
                    hasPrayed: hasPrayed,
                    onTap: () => ref
                        .read(prayerRequestsProvider.notifier)
                        .togglePray(request.id, 'me'),
                  ),
                  const SizedBox(width: 16),
                  _CommentCount(count: request.messageCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pray button ───────────────────────────────────────────────────────────────

class _PrayButton extends StatelessWidget {
  const _PrayButton({
    required this.count,
    required this.hasPrayed,
    required this.onTap,
  });
  final int count;
  final bool hasPrayed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasPrayed
              ? AppColors.primary.withAlpha(20)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPrayed ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasPrayed ? '🙏' : '🙏',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 5),
            Text(
              hasPrayed
                  ? '${AppLocalizations.of(context).detailPray} ($count)'
                  : '${AppLocalizations.of(context).prayerPray} ($count)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    hasPrayed ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCount extends StatelessWidget {
  const _CommentCount({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.chat_bubble_outline_rounded,
            size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$count messages',
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🙏', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context).prayerEmpty,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).prayerEmptyDesc,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context).prayerSubmitRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
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
