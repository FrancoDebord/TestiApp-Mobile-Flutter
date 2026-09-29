import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/admin_models.dart';
import '../providers/admin_provider.dart';
import '../widgets/admin_metric_card.dart';
import '../widgets/admin_section_tile.dart';
import 'admin_categories_screen.dart';
import 'admin_content_screen.dart';
import 'admin_moderators_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_users_screen.dart';

// =============================================================================
// AdminDashboardScreen
//
// Widget tree:
//   Scaffold
//     body: NestedScrollView
//       headerSliverBuilder:
//         SliverAppBar (pinned, "Administration")
//         SliverToBoxAdapter
//           _MetricsGrid          (2×2 AdminMetricCards)
//           _SectionNavList       (6 AdminSectionTiles)
//       body: _SectionBody        (switches on adminSectionProvider)
// =============================================================================

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider).value ??
        const AdminMetrics(
            totalUsers: 0, newUsersToday: 0, totalTestimonies: 0,
            viewsThisMonth: 0, approvalRate: 0.0, pendingTestimonies: 0,
            avgEngagement: 0.0, commentsThisMonth: 0);
    final currentSection = ref.watch(adminSectionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Pinned app bar ─────────────────────────────────────────────────
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF184797),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Administration',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: Color(0xFF263238),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // Quick-access to moderation queue
              IconButton(
                icon: const Icon(Icons.fact_check_outlined,
                    color: Color(0xFF184797)),
                tooltip: 'File de modération',
                onPressed: () => context.push('/moderation'),
              ),
            ],
          ),

          // ── Metrics + section nav ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _MetricsGrid(metrics: metrics),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Gestion',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF263238),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SectionNavList(current: currentSection),
                const SizedBox(height: 12),
                // Section title bar
                _SectionTitleBar(section: currentSection),
              ],
            ),
          ),
        ],

        // ── Section body ──────────────────────────────────────────────────────
        body: _SectionBody(section: currentSection),
      ),
    );
  }
}

// ─── 2×2 metrics grid ─────────────────────────────────────────────────────────

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final AdminMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = [
        AdminMetricCard(
          title: 'Utilisateurs',
          primaryValue: _fmt(metrics.totalUsers),
          primaryLabel: 'total',
          secondaryValue: '+${metrics.newUsersToday}',
          secondaryLabel: 'nouveaux aujourd\'hui',
          icon: Icons.people_outline_rounded,
          accentColor: const Color(0xFF184797),
        ),
        AdminMetricCard(
          title: 'Témoignages',
          primaryValue: _fmt(metrics.totalTestimonies),
          primaryLabel: 'publiés',
          secondaryValue: _fmt(metrics.viewsThisMonth),
          secondaryLabel: 'vues ce mois',
          icon: Icons.auto_stories_outlined,
          accentColor: const Color(0xFFF79009),
        ),
        AdminMetricCard(
          title: 'Approbation',
          primaryValue: '${metrics.approvalRate.toStringAsFixed(1)}%',
          primaryLabel: 'taux d\'approbation',
          secondaryValue: '${metrics.pendingTestimonies}',
          secondaryLabel: 'en attente',
          icon: Icons.check_circle_outline_rounded,
          accentColor: const Color(0xFF12B76A),
        ),
        AdminMetricCard(
          title: 'Engagement',
          primaryValue: metrics.avgEngagement.toStringAsFixed(1),
          primaryLabel: 'moy. interactions',
          secondaryValue: _fmt(metrics.commentsThisMonth),
          secondaryLabel: 'commentaires/mois',
          icon: Icons.trending_up_rounded,
          accentColor: const Color(0xFF2B5DB0),
        ),
    ];

    // Grille 2×2 sans hauteur imposée (l'ancien childAspectRatio faisait
    // déborder les cartes) : chaque ligne prend la hauteur de sa carte la
    // plus haute.
    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          ),
        );

    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: 12),
        row(cards[2], cards[3]),
      ],
    );
  }

  /// 950 → « 950 », 12 400 → « 12,4k », 1 234 567 → « 1,2M ».
  String _fmt(int n) {
    String one(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    if (n >= 1000000) return '${one(n / 1000000)}M';
    if (n >= 1000) return '${one(n / 1000)}k';
    return '$n';
  }
}

// ─── Section navigation list ──────────────────────────────────────────────────

class _SectionNavList extends ConsumerWidget {
  const _SectionNavList({required this.current});
  final AdminSection current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider).value;

    final sections = [
      (
        AdminSection.users,
        Icons.people_outline_rounded,
        'Utilisateurs',
        'Gérer les comptes',
        null,
      ),
      (
        AdminSection.content,
        Icons.article_outlined,
        'Contenus',
        'Témoignages publiés',
        null,
      ),
      (
        AdminSection.moderators,
        Icons.shield_outlined,
        'Modérateurs',
        'Assigner / retirer le rôle',
        null,
      ),
      (
        AdminSection.categories,
        Icons.category_outlined,
        'Catégories',
        'Ajouter, modifier, réordonner',
        null,
      ),
      (
        AdminSection.stats,
        Icons.bar_chart_rounded,
        'Statistiques',
        'Graphiques et tendances',
        null,
      ),
      (
        AdminSection.settings,
        Icons.settings_outlined,
        'Paramètres',
        'Configuration de l\'app',
        metrics?.pendingTestimonies,
      ),
    ];

    return Column(
      children: sections.map((s) {
        final (section, icon, label, sub, badge) = s;
        return AdminSectionTile(
          icon: icon,
          label: label,
          sublabel: sub,
          isSelected: current == section,
          badgeCount: badge,
          onTap: () =>
              ref.read(adminSectionProvider.notifier).select(section),
        );
      }).toList(),
    );
  }
}

// ─── Section title bar ────────────────────────────────────────────────────────

class _SectionTitleBar extends StatelessWidget {
  const _SectionTitleBar({required this.section});
  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = switch (section) {
      AdminSection.users => ('Gestion des utilisateurs', Icons.people_rounded),
      AdminSection.content =>
        ('Gestion des contenus', Icons.article_rounded),
      AdminSection.moderators =>
        ('Modérateurs', Icons.admin_panel_settings_rounded),
      AdminSection.categories => ('Catégories', Icons.category_rounded),
      AdminSection.stats => ('Statistiques', Icons.analytics_rounded),
      AdminSection.settings => ('Paramètres', Icons.settings_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF184797)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF263238),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section body switcher ────────────────────────────────────────────────────

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      AdminSection.users => const AdminUsersScreen(),
      AdminSection.content => const AdminContentScreen(),
      AdminSection.moderators => const AdminModeratorsScreen(),
      AdminSection.categories => const AdminCategoriesScreen(),
      AdminSection.stats => const AdminStatsScreen(),
      AdminSection.settings => const AdminSettingsScreen(),
    };
  }
}
