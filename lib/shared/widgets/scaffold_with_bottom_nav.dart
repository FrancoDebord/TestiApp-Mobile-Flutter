import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:testi_app/core/router/app_routes.dart';

/// The persistent shell that wraps the 5 bottom-nav tabs.
///
/// Each branch of the [StatefulShellRoute] maintains its own [Navigator],
/// so switching tabs preserves each tab's individual back-stack.
class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  // Tab metadata ─────────────────────────────────────────────────────────────

  static const List<_TabItem> _tabs = [
    _TabItem(
      index: 0,
      label: 'Accueil',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      initialRoute: AppPaths.home,
    ),
    _TabItem(
      index: 1,
      label: 'Explorer',
      activeIcon: Icons.explore_rounded,
      inactiveIcon: Icons.explore_outlined,
      initialRoute: AppPaths.explore,
    ),
    _TabItem(
      index: 2,
      label: 'Publier',
      activeIcon: Icons.add_circle_rounded,
      inactiveIcon: Icons.add_circle_outline_rounded,
      initialRoute: AppPaths.publish,
    ),
    _TabItem(
      index: 3,
      label: 'Notifications',
      activeIcon: Icons.notifications_rounded,
      inactiveIcon: Icons.notifications_outlined,
      initialRoute: AppPaths.notifications,
    ),
    _TabItem(
      index: 4,
      label: 'Profil',
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
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _onTabTap(context, index),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withAlpha(30),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 3,
        destinations: _tabs.map((tab) {
          return NavigationDestination(
            icon: Icon(
              tab.inactiveIcon,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              tab.activeIcon,
              color: theme.colorScheme.primary,
            ),
            label: tab.label,
            // Show notification badge on the Notifications tab
            tooltip: tab.label,
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
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.initialRoute,
  });

  final int index;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String initialRoute;
}
