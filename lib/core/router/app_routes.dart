/// Route name constants for the Témoignages app.
/// Use these constants everywhere instead of raw strings to prevent typos
/// and enable safe refactoring.
abstract final class AppRoutes {
  // ── Auth ────────────────────────────────────────────────────────────────
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';
  static const String phoneAuth = 'phone-auth';
  static const String login = 'login';
  static const String register = 'register';
  static const String simpleRegister = 'simple-register';
  static const String forgotPassword = 'forgot-password';
  static const String verifyEmail = 'verify-email';

  // ── Shell (bottom nav) ─────────────────────────────────────────────────
  static const String shell = 'shell';

  // ── Tab: Accueil ────────────────────────────────────────────────────────
  static const String home = 'home';
  static const String featuredTestimony = 'featured-testimony';
  static const String trending = 'trending';
  static const String liveDiscovery = 'live-discovery';

  // ── Tab: Explorer ───────────────────────────────────────────────────────
  static const String explore = 'explore';
  static const String category = 'category';
  static const String searchResults = 'search-results';

  // ── Tab: Publier ────────────────────────────────────────────────────────
  static const String publish = 'publish';
  static const String publishPreview = 'publish-preview';

  // ── Tab: Notifications ──────────────────────────────────────────────────
  static const String notifications = 'notifications';

  // ── Tab: Profil ─────────────────────────────────────────────────────────
  static const String profile = 'profile';
  static const String editProfile = 'edit-profile';
  static const String myTestimonies = 'my-testimonies';
  static const String savedTestimonies = 'saved-testimonies';
  static const String settings = 'settings';
  static const String changePassword = 'change-password';
  static const String deleteAccount = 'delete-account';

  // ── Testimony detail (accessible from any tab) ──────────────────────────
  static const String testimonyDetail = 'testimony-detail';
  static const String testimonyComments = 'testimony-comments';
  static const String reportTestimony = 'report-testimony';

  // ── Moderation (Modérateur / Administrateur only) ───────────────────────
  static const String moderation = 'moderation';
  static const String moderationDetail = 'moderation-detail';

  // ── Admin (Administrateur only) ──────────────────────────────────────────
  static const String adminDashboard = 'admin-dashboard';

  // ── Error ────────────────────────────────────────────────────────────────
  static const String notFound = 'not-found';
}

/// Route path segments.
/// Combine with [AppPaths] to build full paths.
abstract final class AppPaths {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String phoneAuth = '/phone-auth';
  static const String login = '/register';
  static const String register = '/register';
  static const String simpleRegister = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';

  // Shell root
  static const String shell = '/';

  // Tab roots (relative — used inside ShellRoute branches)
  static const String home = 'home';
  static const String explore = 'explore';
  static const String publish = 'publish';
  static const String notifications = 'notifications';
  static const String profile = 'profile';

  // Nested under home
  static const String featuredTestimony = 'featured/:id';

  // Nested under explore
  static const String category = 'category/:slug';
  static const String searchResults = 'search';

  // Nested under publish
  static const String publishPreview = 'preview';

  // Nested under profile
  static const String editProfile = 'edit';
  static const String myTestimonies = 'my-testimonies';
  static const String savedTestimonies = 'saved';
  static const String settings = 'settings';
  static const String changePassword = 'settings/change-password';
  static const String deleteAccount = 'settings/delete-account';

  // Shared detail routes (push on top of any tab)
  static const String testimonyDetail = '/testimony/:id';
  static const String testimonyComments = '/testimony/:id/comments';
  static const String reportTestimony = '/testimony/:id/report';

  // Moderation
  static const String moderation = '/moderation';
  static const String moderationDetail = '/moderation/:id';

  // Admin
  static const String adminDashboard = '/admin';

  // Error
  static const String notFound = '/404';
}
