import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:testi_app/core/router/app_routes.dart';
import 'package:testi_app/l10n/app_localizations.dart';

/// The persistent shell that wraps the 6 bottom-nav tabs.
///
/// Each branch of the [StatefulShellRoute] maintains its own [Navigator],
/// so switching tabs preserves each tab's individual back-stack.
/// Horizontal swipe on the body switches tabs (inner scrollables win the
/// gesture arena and are not affected).
class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  // Minimum swipe speed (px/s) required to switch tab.
  static const double _swipeVelocityThreshold = 500;

  // Tab icon metadata (labels resolved at build time via l10n)
  static const List<_TabItem> _tabs = [
    _TabItem(
      index: 0,
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      initialRoute: AppPaths.home,
    ),
    _TabItem(
      index: 1,
      activeIcon: Icons.explore_rounded,
      inactiveIcon: Icons.explore_outlined,
      initialRoute: AppPaths.explore,
    ),
    _TabItem(
      index: 2,
      activeIcon: Icons.menu_book_rounded,
      inactiveIcon: Icons.menu_book_outlined,
      initialRoute: AppPaths.biblePath,
    ),
    _TabItem(
      index: 3,
      activeIcon: Icons.add_circle_rounded,
      inactiveIcon: Icons.add_circle_outline_rounded,
      initialRoute: AppPaths.publish,
    ),
    _TabItem(
      index: 4,
      activeIcon: Icons.notifications_rounded,
      inactiveIcon: Icons.notifications_outlined,
      initialRoute: AppPaths.notifications,
    ),
    _TabItem(
      index: 5,
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      initialRoute: AppPaths.profile,
    ),
  ];

  void _onTabTap(BuildContext context, int index) {
    if (index == navigationShell.currentIndex) {
      // Already on this tab — pop back to the tab root (iOS-style double-tap).
      navigationShell.goBranch(index, initialLocation: true);
    } else {
      // Switch to the new branch while preserving its own back-stack.
      navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentIndex = navigationShell.currentIndex;

    final labels = [
      l10n.navHome,
      l10n.navExplore,
      'Bible',
      l10n.navPublish,
      l10n.navNotifications,
      l10n.navProfile,
    ];

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          final i = navigationShell.currentIndex;
          if (v < -_swipeVelocityThreshold && i < _tabs.length - 1) {
            navigationShell.goBranch(i + 1);
          } else if (v > _swipeVelocityThreshold && i > 0) {
            navigationShell.goBranch(i - 1);
          }
        },
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _onTabTap(context, index),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withAlpha(30),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 3,
        destinations: _tabs.asMap().entries.map((entry) {
          final tab = entry.value;
          final label = labels[entry.key];
          return NavigationDestination(
            icon: Icon(
              tab.inactiveIcon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              tab.activeIcon,
              color: theme.colorScheme.primary,
            ),
            label: label,
            tooltip: label,
          );
        }).toList(),
      ),
    );
  }
}

// ── Private data class ───────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({
    required this.index,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.initialRoute,
  });

  final int index;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String initialRoute;
}
