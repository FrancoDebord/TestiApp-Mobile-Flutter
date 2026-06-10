import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/moderation_models.dart';
import '../providers/moderation_provider.dart';
import '../widgets/moderation_item_card.dart';
import '../widgets/moderation_stat_card.dart';
import '../widgets/review_bottom_sheet.dart';

// =============================================================================
// ModerationScreen  — Moderator Dashboard
//
// Widget tree:
//   Scaffold
//     body: NestedScrollView
//       headerSliverBuilder:
//         SliverAppBar (pinned, "Modération" + pending badge)
//         SliverToBoxAdapter
//           _StatsRow            (horizontal scroll, 4 stat cards)
//           _FilterTabBar        (En attente | En révision | Tous)
//       body: Consumer → ListView.builder
//               ModerationItemCard (per item)
// =============================================================================

class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(moderationStatsProvider).value ??
        const ModerationStats(
            pending: 0, approvedToday: 0,
            rejectedToday: 0, totalThisMonth: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Pinned App Bar ─────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: innerBoxIsScrolled ? 2 : 0,
            shadowColor: Colors.black.withAlpha(20),
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                const Text(
                  'Modération',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                _PendingBadge(count: stats.pending),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded,
                    color: Color(0xFF6B21A8)),
                tooltip: 'Filtres avancés',
                onPressed: () {},
              ),
            ],
          ),

          // ── Stats row + filter tabs ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _StatsRow(stats: stats),
                const SizedBox(height: 16),
                const _FilterTabBar(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],

        // ── Items list ───────────────────────────────────────────────────────
        body: Consumer(
          builder: (context, ref, _) {
            final items = ref.watch(moderationItemsProvider);

            if (items.isEmpty) {
              return const _EmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ModerationItemCard(
                  item: item,
                  onApprove: () => _onApprove(context, item),
                  onRequestEdit: () =>
                      _showReviewSheet(context, item, ReviewAction.requestEdit),
                  onReject: () =>
                      _showReviewSheet(context, item, ReviewAction.reject),
                  onPreview: () =>
                      context.push('/moderation/${item.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _onApprove(BuildContext context, ModerationItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Témoignage approuvé : ${item.truncatedTitle}',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showReviewSheet(
    BuildContext context,
    ModerationItem item,
    ReviewAction action,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewBottomSheet(
        item: item,
        action: action,
        onConfirm: (reason, note) {
          final msg = action == ReviewAction.reject
              ? 'Témoignage rejeté'
              : 'Demande de modification envoyée';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
              backgroundColor: action == ReviewAction.reject
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final ModerationStats stats;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          ModerationStatCard(
            label: 'En attente',
            count: stats.pending,
            color: const Color(0xFFF59E0B),
            icon: Icons.hourglass_top_rounded,
          ),
          const SizedBox(width: 10),
          ModerationStatCard(
            label: 'Approuvés\naujourd\'hui',
            count: stats.approvedToday,
            color: const Color(0xFF22C55E),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 10),
          ModerationStatCard(
            label: 'Rejetés',
            count: stats.rejectedToday,
            color: const Color(0xFFEF4444),
            icon: Icons.cancel_outlined,
          ),
          const SizedBox(width: 10),
          ModerationStatCard(
            label: 'Total ce mois',
            count: stats.totalThisMonth,
            color: const Color(0xFF6B21A8),
            icon: Icons.bar_chart_rounded,
          ),
        ],
      ),
    );
  }
}

// ─── Filter tab bar ───────────────────────────────────────────────────────────

class _FilterTabBar extends ConsumerWidget {
  const _FilterTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(moderationFilterProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: ModerationFilterTab.values.map((tab) {
            final selected = tab == current;
            final label = switch (tab) {
              ModerationFilterTab.pending => 'En attente',
              ModerationFilterTab.inReview => 'En révision',
              ModerationFilterTab.all => 'Tous',
            };
            return Expanded(
              child: GestureDetector(
                onTap: () => ref
                    .read(moderationFilterProvider.notifier)
                    .setTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withAlpha(15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? const Color(0xFF6B21A8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Pending badge ────────────────────────────────────────────────────────────

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6B21A8).withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Color(0xFF6B21A8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun témoignage à modérer',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tout est à jour !',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
