import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/simple_register_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/error/screens/not_found_screen.dart';
import '../../features/explore/screens/category_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/explore/screens/search_results_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/trending_screen.dart';
import '../../features/testimony/screens/live_discovery_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/moderation/screens/moderation_detail_screen.dart';
import '../../features/moderation/screens/moderation_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/change_password_screen.dart';
import '../../features/profile/screens/delete_account_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/my_testimonies_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/saved_testimonies_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/publish/screens/publish_preview_screen.dart';
import '../../features/publish/screens/publish_screen.dart';
import '../../features/testimony/screens/featured_testimony_screen.dart';
import '../../features/testimony/screens/report_testimony_screen.dart';
import '../../features/testimony/screens/testimony_comments_screen.dart';
import '../../features/testimony/screens/testimony_detail_screen.dart';
import '../../features/auth/providers/auth_notifier.dart'
    show AuthStateAuthenticated, AuthStateLoading, authStateProvider;
import '../../shared/models/user_model.dart';
import 'app_routes.dart';
import 'app_transitions.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';

// ============================================================================
// Router provider
// ============================================================================

/// The single GoRouter instance, exposed as a Riverpod provider so the
/// redirect logic can read auth state reactively.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirect whenever auth changes.
  final authListenable = ref.watch(_authListenableProvider);

  return GoRouter(
    // â”€â”€ Initial location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    initialLocation: AppPaths.splash,

    // â”€â”€ Deep-link URI scheme â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Registered in AndroidManifest.xml / Info.plist as:
    //   scheme: testi   host: app
    // e.g.  testi://app/testimony/abc123

    // â”€â”€ Refresh listenable â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    refreshListenable: authListenable,

    // â”€â”€ Global redirect guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider).value;
      final isLoading = authState == null || authState is AuthStateLoading;
      final isAuthed = authState is AuthStateAuthenticated;
      final location = state.matchedLocation;

      // Show splash while determining auth status.
      if (isLoading) return AppPaths.splash;

      // Unauthenticated user on splash after auth resolves â†’ go to onboarding.
      if (!isAuthed && location == AppPaths.splash) return '/onboarding';

      // â”€â”€ Unauthenticated guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final publicRoutes = {
        AppPaths.splash,
        '/onboarding',
        '/login',
        '/register',
        '/phone-auth',
      };
      final isPublicRoute = publicRoutes.contains(location);

      if (!isAuthed && !isPublicRoute) return '/register';

      // â”€â”€ Authenticated â€” redirect away from auth/public pages â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      if (isAuthed && isPublicRoute && location != AppPaths.splash) {
        return '/home';
      }

      // â”€â”€ Moderation guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final isModerationRoute = location.startsWith('/moderation');
      if (isModerationRoute && isAuthed) {
        final user = authState.user;
        if (!user.canModerate) return '/home';
      }

      // â”€â”€ Admin guard â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final isAdminRoute = location.startsWith('/admin');
      if (isAdminRoute && isAuthed) {
        final user = authState.user;
        if (user.role != UserRole.administrateur) return '/home';
      }

      return null; // no redirect needed
    },

    // â”€â”€ Error page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    errorBuilder: (context, state) => const NotFoundScreen(),

    // â”€â”€ Route tree â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    routes: _buildRoutes(),
  );
});

// ============================================================================
// Route tree builder
// ============================================================================

List<RouteBase> _buildRoutes() {
  return [
    // â”€â”€ Splash (initial â€” no bottom nav) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GoRoute(
      path: AppPaths.splash,
      name: AppRoutes.splash,
      pageBuilder: (context, state) =>
          AppTransitions.fade(state: state, child: const SplashScreen()),
    ),

    // â”€â”€ Onboarding â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GoRoute(
      path: '/onboarding',
      name: AppRoutes.onboarding,
      pageBuilder: (context, state) =>
          AppTransitions.fade(state: state, child: const OnboardingScreen()),
    ),

    // â”€â”€ Inscription simplifiÃ©e : prÃ©nom + nom, sans mot de passe â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GoRoute(
      path: '/register',
      name: AppRoutes.register,
      pageBuilder: (context, state) => AppTransitions.fade(
        state: state,
        child: const SimpleRegisterScreen(),
      ),
    ),
    // Alias /login â†’ /register
    GoRoute(
      path: '/login',
      name: AppRoutes.login,
      redirect: (_, _) => '/register',
    ),
    // ConservÃ© pour rÃ©tro-compatibilitÃ©
    GoRoute(
      path: '/phone-auth',
      name: AppRoutes.phoneAuth,
      redirect: (_, _) => '/register',
    ),

    // â”€â”€ Testimony detail â€” accessible from any tab via push â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Uses its own Navigator so it sits above the bottom-nav shell.
    GoRoute(
      path: '/testimony/:id',
      name: AppRoutes.testimonyDetail,
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return AppTransitions.fadeScale(
          state: state,
          child: TestimonyDetailScreen(testimonyId: id),
        );
      },
      routes: [
        GoRoute(
          path: 'comments',
          name: AppRoutes.testimonyComments,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return AppTransitions.slideUp(
              state: state,
              child: TestimonyCommentsScreen(testimonyId: id),
            );
          },
        ),
        GoRoute(
          path: 'report',
          name: AppRoutes.reportTestimony,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return AppTransitions.slideUp(
              state: state,
              child: ReportTestimonyScreen(testimonyId: id),
            );
          },
        ),
      ],
    ),

    // â”€â”€ Trending / Voir tout â€” accessible from any tab via push â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GoRoute(
      path: '/trending',
      name: AppRoutes.trending,
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const TrendingScreen(),
      ),
    ),

    // ── Lives en direct — accessible depuis n'importe quel onglet ────────────
    GoRoute(
      path: '/live-discovery',
      name: AppRoutes.liveDiscovery,
      pageBuilder: (context, state) => AppTransitions.slideUp(
        state: state,
        child: const LiveDiscoveryScreen(),
      ),
    ),

    // â”€â”€ Admin dashboard (Administrateur only â€” guarded by redirect above) â”€â”€â”€
    GoRoute(
      path: '/admin',
      name: AppRoutes.adminDashboard,
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const AdminDashboardScreen(),
      ),
    ),

    // â”€â”€ Moderation (role-guarded by redirect above) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GoRoute(
      path: '/moderation',
      name: AppRoutes.moderation,
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const ModerationScreen(),
      ),
      routes: [
        GoRoute(
          path: ':id',
          name: AppRoutes.moderationDetail,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return AppTransitions.slideRight(
              state: state,
              child: ModerationDetailScreen(reportId: id),
            );
          },
        ),
      ],
    ),

    // â”€â”€ Error â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    GoRoute(
      path: '/404',
      name: AppRoutes.notFound,
      pageBuilder: (context, state) =>
          AppTransitions.fade(state: state, child: const NotFoundScreen()),
    ),

    // â”€â”€ Shell: bottom-nav tabs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithBottomNav(navigationShell: navigationShell);
      },
      branches: [
        // â”€â”€ Branch 0: Accueil â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: AppRoutes.home,
              pageBuilder: (context, state) =>
                  AppTransitions.none(state: state, child: const HomeScreen()),
              routes: [
                GoRoute(
                  path: 'featured/:id',
                  name: AppRoutes.featuredTestimony,
                  pageBuilder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return AppTransitions.fadeScale(
                      state: state,
                      child: FeaturedTestimonyScreen(testimonyId: id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // â”€â”€ Branch 1: Explorer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              name: AppRoutes.explore,
              pageBuilder: (context, state) => AppTransitions.none(
                state: state,
                child: const ExploreScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'category/:slug',
                  name: AppRoutes.category,
                  pageBuilder: (context, state) {
                    final slug = state.pathParameters['slug']!;
                    return AppTransitions.slideRight(
                      state: state,
                      child: CategoryScreen(slug: slug),
                    );
                  },
                ),
                GoRoute(
                  path: 'search',
                  name: AppRoutes.searchResults,
                  pageBuilder: (context, state) {
                    // Query param: ?q=...
                    final query = state.uri.queryParameters['q'] ?? '';
                    return AppTransitions.slideRight(
                      state: state,
                      child: SearchResultsScreen(query: query),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // â”€â”€ Branch 2: Publier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/publish',
              name: AppRoutes.publish,
              pageBuilder: (context, state) => AppTransitions.slideUp(
                state: state,
                child: const PublishScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'preview',
                  name: AppRoutes.publishPreview,
                  pageBuilder: (context, state) => AppTransitions.slideRight(
                    state: state,
                    child: const PublishPreviewScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),

        // â”€â”€ Branch 3: Notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notifications',
              name: AppRoutes.notifications,
              pageBuilder: (context, state) => AppTransitions.none(
                state: state,
                child: const NotificationsScreen(),
              ),
            ),
          ],
        ),

        // â”€â”€ Branch 4: Profil â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              name: AppRoutes.profile,
              pageBuilder: (context, state) => AppTransitions.none(
                state: state,
                child: const ProfileScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  name: AppRoutes.editProfile,
                  pageBuilder: (context, state) => AppTransitions.slideRight(
                    state: state,
                    child: const EditProfileScreen(),
                  ),
                ),
                GoRoute(
                  path: 'my-testimonies',
                  name: AppRoutes.myTestimonies,
                  pageBuilder: (context, state) => AppTransitions.slideRight(
                    state: state,
                    child: const MyTestimoniesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'saved',
                  name: AppRoutes.savedTestimonies,
                  pageBuilder: (context, state) => AppTransitions.slideRight(
                    state: state,
                    child: const SavedTestimoniesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'settings',
                  name: AppRoutes.settings,
                  pageBuilder: (context, state) => AppTransitions.slideRight(
                    state: state,
                    child: const SettingsScreen(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'change-password',
                      name: AppRoutes.changePassword,
                      pageBuilder: (context, state) =>
                          AppTransitions.slideRight(
                        state: state,
                        child: const ChangePasswordScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'delete-account',
                      name: AppRoutes.deleteAccount,
                      pageBuilder: (context, state) => AppTransitions.slideUp(
                        state: state,
                        child: const DeleteAccountScreen(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

// ============================================================================
// Auth listenable â€” bridges Riverpod AsyncNotifier to GoRouter's
// refreshListenable, so the router re-evaluates its redirect whenever the
// auth state changes.
// ============================================================================

final _authListenableProvider = Provider<_AuthChangeNotifier>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.listen(authStateProvider, (_, next) => notifier.notify());
  return notifier;
});

class _AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
