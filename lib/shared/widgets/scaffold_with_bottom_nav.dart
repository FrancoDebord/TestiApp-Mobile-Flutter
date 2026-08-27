import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:testi_app/core/router/app_routes.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/l10n/app_localizations.dart';

/// Persistent shell for the 6 bottom-nav branches.
///
/// The Publish tab (index 3) is surfaced as a centred FAB with a
/// [CircularNotchedRectangle] notch cut into the [BottomAppBar].
/// The remaining 4 visible destinations are arranged 2-left / 2-right.
/// Bible (branch 2) remains reachable via the horizontal swipe gesture
/// and via the [AppPaths.biblePath] route.
class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const double _swipeVelocityThreshold = 500;

  // Total branch count (including Publish at index 3).
  static const int _branchCount = 6;

  void _onTabTap(BuildContext context, int index) {
    if (index == navigationShell.currentIndex) {
      navigationShell.goBranch(index, initialLocation: true);
    } else {
      navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n  = AppLocalizations.of(context);
    final cur   = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          final i = navigationShell.currentIndex;
          if (v < -_swipeVelocityThreshold && i < _branchCount - 1) {
            navigationShell.goBranch(i + 1);
          } else if (v > _swipeVelocityThreshold && i > 0) {
            navigationShell.goBranch(i - 1);
          }
        },
        child: navigationShell,
      ),

      // ── Centred FAB (Publish) ────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTap(context, 3),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── BottomAppBar with notch ──────────────────────────────────────────
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: theme.colorScheme.surface,
        elevation: 8,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Left 2: Home (0) · Explore (1)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavIcon(
                      activeIcon:   Icons.home_rounded,
                      inactiveIcon: Icons.home_outlined,
                      label: l10n.navHome,
                      selected: cur == 0,
                      onTap: () => _onTabTap(context, 0),
                    ),
                    _NavIcon(
                      activeIcon:   Icons.explore_rounded,
                      inactiveIcon: Icons.explore_outlined,
                      label: l10n.navExplore,
                      selected: cur == 1,
                      onTap: () => _onTabTap(context, 1),
                    ),
                  ],
                ),
              ),

              // Centre gap for FAB notch
              const SizedBox(width: 72),

              // Right 2: Notifications (4) · Profile (5)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavIcon(
                      activeIcon:   Icons.notifications_rounded,
                      inactiveIcon: Icons.notifications_outlined,
                      label: l10n.navNotifications,
                      selected: cur == 4,
                      onTap: () => _onTabTap(context, 4),
                    ),
                    _NavIcon(
                      activeIcon:   Icons.person_rounded,
                      inactiveIcon: Icons.person_outline_rounded,
                      label: l10n.navProfile,
                      selected: cur == 5,
                      onTap: () => _onTabTap(context, 5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single nav icon with label ────────────────────────────────────────────────

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : inactiveIcon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
