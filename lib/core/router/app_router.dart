import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bible/screens/bible_reader_screen.dart';
import '../../features/bible/screens/bible_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/error/screens/not_found_screen.dart';
import '../../features/explore/screens/category_screen.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/explore/screens/search_results_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/trending_screen.dart';
import '../../features/live/screens/live_setup_screen.dart';
import '../../features/live/screens/live_studio_screen.dart';
import '../../features/live/screens/live_viewer_screen.dart';
import '../../features/live/screens/lives_screen.dart';
import '../../features/journal/models/journal_entry.dart';
import '../../features/journal/screens/journal_entry_screen.dart';
import '../../features/journal/screens/journal_screen.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/moderation/screens/moderation_detail_screen.dart';
import '../../features/moderation/screens/moderation_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/downloads/screens/downloads_screen.dart';
import '../../features/location/location_settings_screen.dart';
import '../../features/location/nearby_widgets.dart' show locationSettingsPath;
import '../../features/profile/screens/about_screen.dart';
import '../../features/profile/screens/account_verification_screen.dart';
import '../../features/profile/screens/change_password_screen.dart';
import '../../features/profile/screens/help_screen.dart';
import '../../features/profile/screens/language_screen.dart';
import '../../features/profile/screens/delete_account_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/my_testimonies_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/saved_testimonies_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/video_quality_settings_screen.dart';
import '../../features/publish/screens/video_upload_screen.dart';
import '../../features/publish/screens/publish_preview_screen.dart';
import '../../features/publish/screens/publish_screen.dart';
import '../../features/testimony/screens/featured_testimony_screen.dart';
import '../../features/testimony/screens/report_testimony_screen.dart';
import '../../features/testimony/screens/testimony_comments_screen.dart';
import '../../features/testimony/screens/testimony_detail_screen.dart';
import '../../features/daily_verse/screens/daily_verse_screen.dart' show DailyVerseScreen;
import '../../features/daily_verse/screens/verse_history_screen.dart';
import '../../features/conversion/screens/conversion_edit_screen.dart';
import '../../features/events/screens/past_events_screen.dart';
import '../../features/events/screens/event_live_screen.dart';
import '../../features/conversion/screens/conversion_testimonies_screen.dart';
import '../../features/auth/guest_access.dart';
import '../../features/auth/providers/auth_notifier.dart'
    show
        AuthStateAuthenticated,
        AuthStateGuest,
        AuthStateLoading,
        authStateProvider;
import '../../shared/widgets/guest_gate.dart' show showAccountRequiredSheet;
import '../../shared/models/user_model.dart';
import '../../features/community/screens/community_screen.dart';
import '../../features/community/screens/following_screen.dart';
import '../../features/community/screens/user_profile_screen.dart';
import '../../features/events/screens/event_detail_screen.dart';
import '../../features/events/screens/event_form_screen.dart';
import '../../features/events/screens/events_screen.dart';
import '../../features/accounts/screens/account_managers_screen.dart';
import '../../features/accounts/widgets/account_widgets.dart' show OwnerOnlyGate;
import '../../features/feed/personal_feed_screen.dart';
import '../../features/prophecies/screens/prophecies_screen.dart';
import '../../features/prophecies/screens/prophecy_detail_screen.dart';
import '../../features/prophecies/screens/prophecy_form_screen.dart';
import '../../features/prayer/screens/create_prayer_session_screen.dart';
import '../../features/prayer/screens/group_prayer_sessions_screen.dart';
import '../../features/prayer/screens/prayer_request_detail_screen.dart';
import '../../features/prayer/screens/prayer_requests_screen.dart';
import '../../features/prayer/screens/prayer_session_detail_screen.dart';
import '../../features/prayer/screens/submit_prayer_request_screen.dart';
import 'app_routes.dart';
import 'app_transitions.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';
import '../../l10n/app_localizations.dart';
import '../../features/profile/screens/my_data_screen.dart';

// ============================================================================
// Router provider
// ============================================================================

/// The single GoRouter instance, exposed as a Riverpod provider so the
/// redirect logic can read auth state reactively.
/// Lien entrant (share_url, testi://…) reçu avant que la session soit prête :
/// pendant le splash ou pendant que l'utilisateur se connecte. Rejoué dès que
/// l'utilisateur est authentifié, pour ouvrir le témoignage demandé.
String? _pendingDeepLink;

bool _isContentDeepLink(String location) =>
    location.startsWith('/testimony/') ||
    location.startsWith('/testimonies/') ||
    (location.startsWith('/lives/') && location != '/lives/new') ||
    (location.startsWith('/events/') &&
        location != '/events/new' &&
        !location.endsWith('/edit'));

/// Devient vrai dès que la session a été résolue une première fois : un
/// rechargement ultérieur de l'état (ex. envoi d'un code SMS) ne renvoie
/// plus vers le splash, l'écran courant reste affiché.
bool _authResolvedOnce = false;

/// Évite d'empiler plusieurs feuilles « compte requis » (le redirect peut
/// être réévalué plusieurs fois pour une même navigation).
bool _guestSheetOpen = false;

/// Mode invité : explique pourquoi un compte est nécessaire, par-dessus
/// l'écran courant (appelé depuis le redirect, donc après la frame).
void _promptGuestAccount(GoRouter router, String location) {
  if (_guestSheetOpen) return;
  _guestSheetOpen = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final ctx = router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      _guestSheetOpen = false;
      return;
    }
    try {
      await showAccountRequiredSheet(ctx,
          reason: guestBlockedReason(location));
    } finally {
      _guestSheetOpen = false;
    }
  });
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirect whenever auth changes.
  final authListenable = ref.watch(_authListenableProvider);

  late final GoRouter router;
  router = GoRouter(
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
      final isGuest = authState is AuthStateGuest;
      final location = state.matchedLocation;

      // Show splash while determining auth status.
      // Un lien de témoignage reçu à ce moment est mémorisé, sinon le splash
      // puis l'accueil le feraient disparaître.
      if (isLoading) {
        // Rechargement après la première résolution (ex. code SMS en cours
        // d'envoi) : rester sur l'écran courant.
        if (_authResolvedOnce && location != AppPaths.splash) return null;
        if (_isContentDeepLink(location)) {
          _pendingDeepLink = state.uri.toString();
        }
        return AppPaths.splash;
      }
      _authResolvedOnce = true;

      // ── Mode invité ──────────────────────────────────────────────────────
      // Navigation libre dans les onglets et la lecture ; les actions
      // réservées aux membres demandent un compte.
      if (isGuest) {
        if (_pendingDeepLink != null && !_isContentDeepLink(location)) {
          final target = _pendingDeepLink!;
          _pendingDeepLink = null;
          if (guestCanAccess(target)) return target;
        }
        if (location == AppPaths.splash) return '/home';
        if (guestCanAccess(location)) return null;

        // Onglet « Publier » : feuille « Créez un compte pour … » et on
        // reste sur l'écran courant.
        if (location == AppPaths.publishPath ||
            location.startsWith('${AppPaths.publishPath}/')) {
          _promptGuestAccount(router, location);
          final current =
              router.routerDelegate.currentConfiguration.uri.toString();
          return current.isNotEmpty &&
                  current != location &&
                  guestCanAccess(current)
              ? current
              : '/home';
        }
        // Autres écrans réservés : connexion (retour possible).
        return '/login';
      }

      // Session prête : rejouer le lien mémorisé à la place de l'écran
      // d'arrivée (splash, accueil ou page de connexion).
      if (isAuthed && _pendingDeepLink != null && !_isContentDeepLink(location)) {
        final target = _pendingDeepLink;
        _pendingDeepLink = null;
        return target;
      }

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

      if (!isAuthed && !isPublicRoute) {
        // Garder le témoignage demandé pour l'ouvrir après la connexion.
        if (_isContentDeepLink(location)) {
          _pendingDeepLink = state.uri.toString();
        }
        return '/register';
      }

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
      // Diffusion en direct : modérateurs et administrateurs uniquement.
      final isBroadcastRoute = location == '/lives/new' ||
          (location.startsWith('/lives/') && location.endsWith('/studio'));
      // Exception : le direct d'un événement (/lives/new?event=…, puis le
      // studio) est ouvert à ses gestionnaires — organisation, ses gestionnaires,
      // co-gestionnaires ; le serveur vérifie les droits (docs serveur :
      // fonctionnalites/evenements.md). L'écran de préparation les affiche.
      if (isBroadcastRoute && isAuthed && !authState.user.canModerate) {
        final forEvent = location != '/lives/new' ||
            state.uri.queryParameters['event'] != null;
        if (!forEvent) return '/lives';
      }
      // Création / modification d'événements : droits vérifiés par le serveur
      // (organisation vérifiée, ses gestionnaires, co-gestionnaires, admin).

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

  // Connexion ouverte par-dessus un écran (feuille « compte requis » du mode
  // invité : pushNamed('/login')) : le redirect ne voit que l'écran du dessous,
  // la page de connexion resterait affichée. Retour à cet écran une fois connecté.
  ref.listen(authStateProvider, (prev, next) {
    if (next.value is! AuthStateAuthenticated ||
        prev?.value is AuthStateAuthenticated) {
      return;
    }
    final config = router.routerDelegate.currentConfiguration;
    if (config.isEmpty) return;
    final top = config.last.matchedLocation;
    if (_authPages.contains(top) && config.uri.path != top) {
      router.go(config.uri.toString());
    }
  });
  return router;
});

/// Pages de connexion / inscription, quittées dès que la session est ouverte.
const _authPages = {'/login', '/register', '/phone-auth'};

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
        child: const RegisterScreen(),
      ),
    ),
    // Alias /login â†’ /register
    GoRoute(
      path: '/login',
      name: AppRoutes.login,
      pageBuilder: (context, state) => AppTransitions.fade(
        state: state,
        child: const LoginScreen(),
      ),
    ),
    // ConservÃ© pour rÃ©tro-compatibilitÃ©
    GoRoute(
      path: '/phone-auth',
      name: AppRoutes.phoneAuth,
      redirect: (_, _) => '/register',
    ),

    // â”€â”€ Testimony detail â€” accessible from any tab via push â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Uses its own Navigator so it sits above the bottom-nav shell.
    // Lien public share_url (https://<domaine>/testimonies/{id}), intercepté
    // par les App Links (Android) / Universal Links (iOS).
    // Témoignages de conversion (docs serveur fonctionnalites/temoignage-de-conversion.md).
    GoRoute(
      path: '/temoignages-de-conversion',
      redirect: (_, _) => '/conversions',
    ),
    GoRoute(
      path: '/conversions',
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const ConversionTestimoniesScreen(),
      ),
      routes: [
        GoRoute(
          path: 'mine/edit',
          pageBuilder: (context, state) => AppTransitions.slideUp(
            state: state,
            child: const ConversionEditScreen(),
          ),
        ),
      ],
    ),

    GoRoute(
      path: '/testimonies/:id',
      redirect: (_, state) => '/testimony/${state.pathParameters['id']}',
    ),

    // ── Liens partagés du site ouverts dans l'app (App Links / Universal Links,
    // docs serveur fonctionnalites/app-links.md) : adresses du site → écrans.
    GoRoute(path: '/videos/:id', redirect: (_, state) => '/testimony/${state.pathParameters['id']}'),
    GoRoute(path: '/evenements/passes', redirect: (_, _) => '/events/past'),
    GoRoute(path: '/evenements', redirect: (_, _) => '/events'),
    GoRoute(path: '/evenements/:id', redirect: (_, state) => '/events/${state.pathParameters['id']}'),
    GoRoute(path: '/priere/requetes', redirect: (_, _) => '/prayer-requests'),
    GoRoute(
      path: '/priere/requetes/:id',
      redirect: (_, state) => '/prayer-requests/${state.pathParameters['id']}',
    ),
    GoRoute(path: '/priere/sessions', redirect: (_, _) => '/prayer-sessions'),
    GoRoute(
      path: '/priere/sessions/:id',
      redirect: (_, state) => '/prayer-sessions/${state.pathParameters['id']}',
    ),
    // Verset du jour (le lien d'un jour passé ouvre le verset du jour).
    GoRoute(
      path: '/verset-du-jour',
      builder: (context, state) => const DailyVerseScreen(),
      routes: [
        // Avant ':date' : sinon « historique » serait lu comme une date.
        GoRoute(path: 'historique', redirect: (_, _) => '/verse-history'),
        GoRoute(path: ':date', builder: (context, state) => const DailyVerseScreen()),
      ],
    ),
    // Historique des versets du jour (page dédiée).
    GoRoute(path: '/verse-history', builder: (context, state) => const VerseHistoryScreen()),

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
        child: const LivesScreen(),
      ),
    ),
    // ── Carnet privé (docs backend : fonctionnalites/carnet-prive.md) ────────
    GoRoute(
      path: '/journal',
      pageBuilder: (context, state) => AppTransitions.slideUp(
        state: state,
        child: const JournalScreen(),
      ),
      routes: [
        // Parcours d'enregistrement du carnet, HORS du shell : pousser
        // /publish/preview (onglet « Publier ») depuis cette page racine
        // mettait deux fois le shell dans la pile → plantage de go_router
        // (« !keyReservation.contains(key) »). Avant ':id' (sinon « new »
        // serait lu comme un identifiant).
        GoRoute(
          path: 'new',
          builder: (context, state) => const PublishPreviewScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => JournalEntryScreen(
            entryId: state.pathParameters['id']!,
            initialEntry:
                state.extra is JournalEntry ? state.extra! as JournalEntry : null,
          ),
        ),
      ],
    ),
    // Communauté et profils des auteurs (docs/fonctionnalites/abonnements.md du backend)
    GoRoute(
      path: '/community',
      pageBuilder: (context, state) => AppTransitions.slideUp(
        state: state,
        child: const CommunityScreen(),
      ),
    ),
    GoRoute(
      path: '/following',
      builder: (context, state) => const FollowsScreen(),
    ),
    GoRoute(
      path: '/followers', // « Mes abonnés » : même écran, onglet Abonnés
      builder: (context, state) => const FollowsScreen(initialTab: FollowsTab.followers),
    ),
    GoRoute(
      path: '/users/:id',
      builder: (context, state) => UserProfileScreen(userId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/lives',
      pageBuilder: (context, state) => AppTransitions.slideUp(
        state: state,
        child: const LivesScreen(),
      ),
      routes: [
        // Avant ':id' : sinon « new » serait lu comme un identifiant.
        GoRoute(
          path: 'new',
          // ?event=… : direct d'un événement (docs serveur fonctionnalites/evenements.md).
          builder: (context, state) =>
              LiveSetupScreen(eventId: state.uri.queryParameters['event']),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              LiveViewerScreen(liveId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'studio',
              builder: (context, state) => LiveStudioScreen(
                args: state.extra is LiveStudioArgs
                    ? state.extra! as LiveStudioArgs
                    : LiveStudioArgs.resume(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
      ],
    ),

    // Paroles prophétiques du carnet privé (docs serveur fonctionnalites/paroles-prophetiques.md).
    GoRoute(
      path: '/prophecies',
      builder: (context, state) => const PropheciesScreen(),
      routes: [
        GoRoute(path: 'new', builder: (context, state) => const ProphecyFormScreen()),
        GoRoute(
          path: ':id',
          builder: (context, state) => ProphecyDetailScreen(prophecyId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => ProphecyFormScreen(prophecyId: state.pathParameters['id']),
            ),
          ],
        ),
      ],
    ),

    // Événements chrétiens (hors barre du bas : menu latéral, accueil, publier).
    // docs serveur fonctionnalites/evenements.md
    GoRoute(
      path: '/events',
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const EventsScreen(),
      ),
      routes: [
        // Avant ':id' : sinon « new » serait lu comme un identifiant.
        GoRoute(
          path: 'new',
          builder: (context, state) => const EventFormScreen(),
        ),
        // Événements passés : revivre les témoignages.
        GoRoute(
          path: 'past',
          builder: (context, state) => const PastEventsScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              EventDetailScreen(eventId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) =>
                  EventFormScreen(eventId: state.pathParameters['id']),
            ),
            // Direct YouTube de l'événement (vue « YouTube », plein écran).
            GoRoute(
              path: 'live',
              builder: (context, state) =>
                  EventLiveScreen(eventId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),

    // Sessions de prière (docs serveur sessions-de-priere.md) ; les requêtes
    // sont l'onglet « Prières » de la barre du bas. La salle d'une session est
    // un direct : /lives/{id} (et son studio).
    GoRoute(
      path: '/prayer-sessions',
      builder: (context, state) => const GroupPrayerSessionsScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => CreatePrayerSessionScreen(eventId: state.uri.queryParameters['event']),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => PrayerSessionDetailScreen(sessionId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) => CreatePrayerSessionScreen(sessionId: state.pathParameters['id']),
            ),
          ],
        ),
      ],
    ),

    // Mon fil : comptes suivis + suggestions.
    GoRoute(
      path: '/my-feed',
      builder: (context, state) => const PersonalFeedScreen(),
    ),

    // Localisation privée (fils classés par zone) : réglage ouvert depuis les fils et les paramètres.
    GoRoute(
      path: locationSettingsPath,
      // Réservé au titulaire : masqué quand on agit pour un compte administré.
      builder: (context, state) =>
          OwnerOnlyGate(title: context.l10n.locationTitle, child: const LocationSettingsScreen()),
    ),

    // Administrateurs du compte (tous les comptes) / comptes que j'administre.
    GoRoute(
      path: '/managers',
      builder: (context, state) => const AccountManagersScreen(),
    ),

    // ── Téléchargements (hors barre du bas : menu latéral, profil) ─────────
    GoRoute(
      path: '/downloads',
      name: AppRoutes.downloads,
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const DownloadsScreen(),
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
    // ── Notifications : cloche de l'accueil, liens des notifications push ──
    GoRoute(
      path: '/notifications',
      name: AppRoutes.notifications,
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const NotificationsScreen(),
      ),
    ),

    // ── Envoi d'une vidéo : progression, Annuler, Réessayer ──
    GoRoute(
      path: AppPaths.videoUploadPath,
      name: AppRoutes.videoUpload,
      pageBuilder: (context, state) => AppTransitions.slideRight(
        state: state,
        child: const VideoUploadScreen(),
      ),
    ),

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

        // â”€â”€ Branch 2: Bible â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bible',
              name: AppRoutes.bible,
              pageBuilder: (context, state) => AppTransitions.none(
                state: state,
                child: const BibleScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  name: AppRoutes.bibleReader,
                  pageBuilder: (context, state) {
                    final code = state.pathParameters['id']!;
                    return AppTransitions.slideRight(
                      state: state,
                      child: BibleReaderScreen(translationCode: code),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // ── Branch 3: Publier ────────────────────────────────────────────────
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

        // ── Branch 4: Prières ────────────────────────────────────────────────
        // Onglet « Prières » (a remplacé Événements, désormais dans le menu
        // latéral). docs serveur fonctionnalites/requetes-de-priere.md
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/prayer-requests',
              // ?tab=mine : onglet « Mes requêtes » (Mes données).
              pageBuilder: (context, state) => AppTransitions.none(
                state: state,
                child: PrayerRequestsScreen(initialTab: state.uri.queryParameters['tab']),
              ),
              routes: [
                // Avant ':id' : sinon « new » serait lu comme un identifiant. ?event= : requête d'un événement.
                GoRoute(
                  path: 'new',
                  builder: (context, state) => SubmitPrayerRequestScreen(eventId: state.uri.queryParameters['event']),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) => PrayerRequestDetailScreen(requestId: state.pathParameters['id']!),
                ),
              ],
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
                // Vérification d'un compte personnel : /profile/verification
                GoRoute(
                  path: 'verification',
                  name: AppRoutes.accountVerification,
                  pageBuilder: (context, state) => AppTransitions.slideRight(
                    state: state,
                    child: OwnerOnlyGate(
                        title: context.l10n.notifTypeAccountVerification, child: const AccountVerificationScreen()),
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
                      path: 'language',
                      name: AppRoutes.language,
                      pageBuilder: (context, state) =>
                          AppTransitions.slideRight(
                        state: state,
                        child: const LanguageScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'video-quality',
                      name: AppRoutes.videoQuality,
                      pageBuilder: (context, state) =>
                          AppTransitions.slideRight(
                        state: state,
                        child: const VideoQualitySettingsScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'help',
                      name: AppRoutes.help,
                      pageBuilder: (context, state) =>
                          AppTransitions.slideRight(
                        state: state,
                        child: const HelpScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'about',
                      name: AppRoutes.about,
                      pageBuilder: (context, state) =>
                          AppTransitions.slideRight(
                        state: state,
                        child: const AboutScreen(),
                      ),
                    ),
                    GoRoute(
                      path: 'change-password',
                      name: AppRoutes.changePassword,
                      pageBuilder: (context, state) =>
                          AppTransitions.slideRight(
                        state: state,
                        child: OwnerOnlyGate(
                            title: context.l10n.appSecurityAndPassword, child: const ChangePasswordScreen()),
                      ),
                    ),
                    GoRoute(
                      path: 'my-data',
                      name: AppRoutes.myData,
                      pageBuilder: (context, state) => AppTransitions.slideRight(
                        state: state,
                        child: OwnerOnlyGate(title: context.l10n.myDataTitle, child: const MyDataScreen()),
                      ),
                    ),
                    GoRoute(
                      path: 'delete-account',
                      name: AppRoutes.deleteAccount,
                      pageBuilder: (context, state) => AppTransitions.slideUp(
                        state: state,
                        child: OwnerOnlyGate(
                            title: context.l10n.settingsDelete, child: const DeleteAccountScreen()),
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
