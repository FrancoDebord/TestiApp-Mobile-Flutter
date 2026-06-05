// lib/core/app_constants.dart
//
// Central constants for the Témoignages application.
// The API follows Laravel conventions:
//   • Base URL: https://api.testi-app.com/api/v1
//   • All endpoints prefixed with /api/v1
//   • Responses: { success, data, message, errors? }
//   • Auth: Bearer JWT in Authorization header
//   • Social auth: POST /auth/social { provider, token }

abstract final class AppConstants {
  // ── Network ──────────────────────────────────────────────────────────────

  /// Override at build time: --dart-define=API_BASE_URL=https://your-laravel.app/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
    // 10.0.2.2 = localhost from Android emulator
    // Replace with your production URL before release
  );

  static const int connectTimeoutMs = 15000;
  static const int receiveTimeoutMs = 30000;
  static const int maxRetries = 3;

  // ── Secure-storage keys ───────────────────────────────────────────────────

  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId       = 'user_id';

  // ── Pagination ────────────────────────────────────────────────────────────

  static const int defaultPageSize = 20;

  // ── Auth endpoints (Laravel Sanctum / Passport) ───────────────────────────

  static const String authLogin          = '/auth/login';
  static const String authRegister       = '/auth/register';
  static const String authRefresh        = '/auth/refresh';
  static const String authLogout         = '/auth/logout';
  static const String authVerifyEmail    = '/auth/verify-email';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword  = '/auth/reset-password';
  static const String authMe             = '/auth/me';

  /// Connexion par téléphone — POST { firebase_token, phone, [first_name, last_name, country] }
  /// Laravel vérifie le token Firebase et crée/retrouve l'utilisateur.
  static const String authPhone         = '/auth/phone';

  /// Social login — POST { provider: 'google'|'facebook', token: '...' }
  static const String authSocial        = '/auth/social';

  // ── Testimonies ───────────────────────────────────────────────────────────

  static const String testimonies = '/testimonies';

  static String testimonyById(String id)       => '/testimonies/$id';
  static String testimonyReactions(String id)  => '/testimonies/$id/reactions';
  static String testimonyComments(String id)   => '/testimonies/$id/comments';
  static String testimonySave(String id)       => '/testimonies/$id/save';
  static String testimonyUnsave(String id)     => '/testimonies/$id/unsave';

  // Delta sync: GET /testimonies?after=ISO8601&limit=N
  static String feedDelta({required String after, int limit = 20}) =>
      '/testimonies?after=$after&limit=$limit';

  // ── Comments ──────────────────────────────────────────────────────────────

  static String commentById(String id) => '/comments/$id';

  // ── Users ─────────────────────────────────────────────────────────────────

  static String userById(String id)         => '/users/$id';
  static String userFollow(String id)       => '/users/$id/follow';
  static String userUnfollow(String id)     => '/users/$id/unfollow';
  static String userTestimonies(String id)  => '/users/$id/testimonies';
  static const String updateProfile         = '/users/me';
  static const String uploadAvatar          = '/users/me/avatar';

  // ── Notifications ─────────────────────────────────────────────────────────

  static const String notifications        = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll  = '/notifications/read-all';

  // Delta sync: GET /notifications?after=ISO8601
  static String notificationsDelta({required String after}) =>
      '/notifications?after=$after';

  // ── Categories ────────────────────────────────────────────────────────────

  static const String categories = '/categories';

  // ── Media upload (multipart/form-data) ────────────────────────────────────

  static const String uploadMedia = '/media/upload';

  // Presigned URL for direct S3/R2 upload
  static const String presignedUrl = '/media/presigned-url';

  // ── Moderation ────────────────────────────────────────────────────────────

  static const String moderationPending = '/moderation/pending';
  static String moderationApprove(String id) => '/moderation/$id/approve';
  static String moderationReject(String id)  => '/moderation/$id/reject';

  // ── Admin ─────────────────────────────────────────────────────────────────

  static const String adminUsers        = '/admin/users';
  static const String adminTestimonies  = '/admin/testimonies';
  static const String adminCategories   = '/admin/categories';
  static const String adminStats        = '/admin/stats';
  static String adminUserById(String id) => '/admin/users/$id';
  static String adminBanUser(String id)  => '/admin/users/$id/ban';

  // ── Validation limits ─────────────────────────────────────────────────────

  static const int minPasswordLength  = 8;
  static const int maxTestimonyLength = 5000;
  static const int maxCommentLength   = 500;
  static const int maxTitleLength     = 200;

  // ── Media ─────────────────────────────────────────────────────────────────

  static const List<double> playbackSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const int maxAudioDurationMin  = 60;
  static const int maxVideoDurationMin  = 10;

  // ── Categories (mirrors Laravel seeder slugs) ─────────────────────────────

  static const List<String> categorySlugs = [
    'guerison',
    'delivrance',
    'conversion',
    'mariage',
    'famille',
    'finances',
    'miracles',
    'protection-divine',
    'ministere',
    'salut',
  ];
}
