import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:testi_app/core/router/app_routes.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';
import 'package:testi_app/core/theme/app_tokens.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart';

/// Persistent shell for the 6 bottom-nav branches.
///
/// Barre blanche (bordure fine en haut) : Accueil · Explorer · [+ Publier]
/// · Téléchargements · Profil. Publier (index 3) est un bouton rond bleu au
/// centre, libellé dessous. Onglet actif : icône + libellé bleus sur pastille
/// bleu clair (radius 12) ; inactif : gris.
/// Bible (branch 2) remains reachable via the horizontal swipe gesture
/// and via the [AppPaths.biblePath] route.
class ScaffoldWithBottomNav extends ConsumerWidget {
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

  /// Publier : compte requis (le garde du routeur couvre aussi ce cas, ce
  /// contrôle évite une navigation inutile pour un invité).
  Future<void> _onPublishTap(BuildContext context, WidgetRef ref) async {
    if (ref.read(isGuestProvider) &&
        !await requireAccount(context, ref,
            reason: 'publier votre témoignage')) {
      return;
    }
    if (context.mounted) _onTabTap(context, 3);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n  = AppLocalizations.of(context);
    final cur   = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
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

      // ── Barre du bas : Accueil · Explorer · [+ Publier] · Téléchargements · Profil
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _NavIcon(
                    activeIcon:   Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    label: l10n.navHome,
                    selected: cur == 0,
                    onTap: () => _onTabTap(context, 0),
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    activeIcon:   Icons.explore_rounded,
                    inactiveIcon: Icons.explore_outlined,
                    label: l10n.navExplore,
                    selected: cur == 1,
                    onTap: () => _onTabTap(context, 1),
                  ),
                ),
                // Centre : bouton rond « + » (Publier, branche 3)
                Expanded(
                  child: _PublishButton(
                    label: l10n.navPublish,
                    selected: cur == 3,
                    onTap: () => _onPublishTap(context, ref),
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    activeIcon:   Icons.download_for_offline_rounded,
                    inactiveIcon: Icons.download_for_offline_outlined,
                    label: l10n.navDownloads,
                    selected: cur == 4,
                    onTap: () => _onTabTap(context, 4),
                  ),
                ),
                Expanded(
                  child: _NavIcon(
                    activeIcon:   Icons.person_rounded,
                    inactiveIcon: Icons.person_outline_rounded,
                    label: l10n.navProfile,
                    selected: cur == 5,
                    onTap: () => _onTabTap(context, 5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bouton central « Publier » ────────────────────────────────────────────────

class _PublishButton extends StatelessWidget {
  const _PublishButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppShadows.card,
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 2),
            _NavLabel(label: label, color: AppColors.primary, bold: true),
          ],
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
    // Charte : actif Krea Blue sur fond Blue Light (arrondi 12), inactif gris #667085.
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(selected ? activeIcon : inactiveIcon,
                  color: color, size: 24),
            ),
            const SizedBox(height: 4),
            _NavLabel(label: label, color: color, bold: selected),
          ],
        ),
      ),
    );
  }
}

/// Libellé sur une ligne, réduit si nécessaire (« Téléchargements » à 320 px).
class _NavLabel extends StatelessWidget {
  const _NavLabel({
    required this.label,
    required this.color,
    required this.bold,
  });

  final String label;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
