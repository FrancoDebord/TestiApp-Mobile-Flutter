// lib/core/app_constants.dart
//
// Central constants for the Témoignages application.
//
// API base: http://192.168.0.4:8000/api/v1
// Auth: Bearer JWT via Laravel Sanctum (token returned by /auth/login)
// Envelope: { "success": bool, "data": any, "message": string, "errors"?: map }
//
// ── Route map (from routes/api.php) ───────────────────────────────────────────
// PUBLIC (no auth)
//   POST   /auth/login                    { email, password }
//   POST   /auth/register                 { display_name, email, password, password_confirmation, country? }
//   POST   /auth/phone                    { firebase_token, phone, first_name?, last_name?, country? }
//   POST   /auth/social                   { provider: 'google'|'facebook', token }
//   POST   /auth/forgot-password          { email }
//   GET    /categories
//   GET    /testimonies                   ?featured&category&status&after&limit
//   GET    /testimonies/featured
//   GET    /testimonies/{id}
//   GET    /testimonies/{id}/comments
//   GET    /testimonies/{id}/reactions
//   GET    /users/{id}
//   GET    /users/{id}/testimonies
//
// AUTHENTICATED (Bearer token)
//   GET    /auth/me                       → current user object
//   POST   /auth/logout
//   POST   /auth/refresh                  { refresh_token }
//   POST   /testimonies                   { title, type, category, bodyText, bibleVerse?, verseReference?, visibility, tags? }
//   PUT    /testimonies/{id}
//   DELETE /testimonies/{id}
//   PUT    /testimonies/{id}/save
//   DELETE /testimonies/{id}/unsave
//   GET    /testimonies/saved/list
//   POST   /testimonies/{id}/reactions    { type: 'like'|'pray' }
//   DELETE /testimonies/{id}/reactions/{reactionId}
//   POST   /testimonies/{id}/comments     { text }
//   PUT    /comments/{id}
//   DELETE /comments/{id}
//   PUT    /users/me                      { display_name?, country?, bio?, phone? }
//   POST   /users/me/avatar              (multipart)
//   PUT    /users/me/settings
//   DELETE /users/me
//   POST   /users/{id}/follow
//   DELETE /users/{id}/unfollow
//   GET    /notifications                 ?after
//   POST   /notifications/{id}/read
//   POST   /notifications/read-all
//   POST   /media/upload                 (multipart)
//   GET    /media/presigned-url
//
// MODERATOR + ADMIN
//   GET    /moderation/stats
//   GET    /moderation/pending
//   GET    /moderation/{id}
//   POST   /moderation/{id}/approve
//   POST   /moderation/{id}/reject
//
// ADMIN ONLY
//   GET    /admin/stats
//   GET    /admin/users
//   GET    /admin/users/{id}
//   POST   /admin/users/{id}/ban
//   POST   /admin/users/{id}/suspend
//   POST   /admin/users/{id}/activate
//   PUT    /admin/users/{id}/role         { role: 'utilisateur'|'moderateur'|'administrateur' }
//   GET    /admin/testimonies
//   GET    /admin/categories
//   POST   /admin/categories
//   PUT    /admin/categories/{id}
//   DELETE /admin/categories/{id}
//   GET    /admin/settings
//   PUT    /admin/settings

abstract final class AppConstants {
  // ── Network ──────────────────────────────────────────────────────────────

  /// Override at build time: --dart-define=API_BASE_URL=https://your-laravel.app/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.74:8000/api/v1',
    // Dev: http://192.168.0.4:8000/api/v1  (LAN server)
    // Android emulator localhost alias: http://10.0.2.2:8000/api/v1
    // Production: https://api.testi-app.com/api/v1
  );

  static const int connectTimeoutMs = 8000;
  static const int receiveTimeoutMs = 20000;
  static const int maxRetries = 2;

  // ── Secure-storage keys ───────────────────────────────────────────────────

  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId       = 'user_id';

  // ── Pagination ────────────────────────────────────────────────────────────

  static const int defaultPageSize = 20;

  // ── Auth endpoints ────────────────────────────────────────────────────────
  // Login body:    { email, password }
  // Register body: { display_name, email, password, password_confirmation, country? }

  static const String authLogin          = '/auth/login';
  static const String authRegister       = '/auth/register';
  static const String authPhone          = '/auth/phone';
  static const String authSocial         = '/auth/social';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authRefresh        = '/auth/refresh';
  static const String authLogout         = '/auth/logout';
  static const String authMe             = '/auth/me';   // GET only — current user

  // ── Testimonies ───────────────────────────────────────────────────────────
  // Query params for GET /testimonies: featured, category, status, after, limit

  static const String testimonies         = '/testimonies';
  static const String testimoniesFeatured = '/testimonies/featured';
  static const String testimoniesSaved    = '/testimonies/saved/list';

  static String testimonyById(String id)          => '/testimonies/$id';
  static String testimonyReactions(String id)     => '/testimonies/$id/reactions';
  static String testimonyReactionById(String testimonyId, String reactionId)
      => '/testimonies/$testimonyId/reactions/$reactionId';
  static String testimonyComments(String id)      => '/testimonies/$id/comments';
  static String testimonySave(String id)   => '/testimonies/$id/save';    // PUT
  static String testimonyUnsave(String id) => '/testimonies/$id/unsave'; // DELETE
  static String testimonyShare(String id)  => '/testimonies/$id/share';  // POST
  static String testimonyReport(String id) => '/testimonies/$id/report'; // POST

  // Delta sync: GET /testimonies?after=ISO8601&limit=N
  static String feedDelta({required String after, int limit = 20}) =>
      '/testimonies?after=$after&limit=$limit';

  // ── Comments (body field: "text") ─────────────────────────────────────────

  static String commentById(String id) => '/comments/$id';

  // ── Users ─────────────────────────────────────────────────────────────────

  static String userById(String id)         => '/users/$id';
  static String userTestimonies(String id)  => '/users/$id/testimonies';
  static String userFollow(String id)       => '/users/$id/follow';    // POST
  static String userUnfollow(String id)     => '/users/$id/unfollow';  // DELETE

  // Self management
  static const String updateProfile    = '/users/me';          // PUT
  static const String uploadAvatar     = '/users/me/avatar';   // POST multipart
  static const String updateSettings   = '/users/me/settings'; // PUT
  static const String deleteAccount    = '/users/me';          // DELETE

  // ── Notifications ─────────────────────────────────────────────────────────

  static const String notifications         = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read'; // POST
  static const String notificationsReadAll  = '/notifications/read-all';  // POST

  static String notificationsDelta({required String after}) =>
      '/notifications?after=$after';

  // ── Categories ────────────────────────────────────────────────────────────

  static const String categories = '/categories';

  // ── Bible ─────────────────────────────────────────────────────────────────
  // GET /bible/translations                         → [{code, name, language, booksCount, versesCount}]
  // GET /bible/download/{code}                      → full Bible (books+chapters+verses)
  // GET /bible/books?translation={code}             → books list
  // GET /bible/{book}/{chapter}?translation={code}  → chapter verses (online)
  // GET /bible/search?q=...&translation={code}      → search

  static const String bibleTranslations = '/bible/translations';
  static String bibleDownload(String code) => '/bible/download/$code';
  static String bibleBooks(String code)    => '/bible/books?translation=$code';
  static String bibleChapter(String code, int book, int chapter) =>
      '/bible/$book/$chapter?translation=$code';
  static const String bibleSearch = '/bible/search';

  // ── Verset du jour ────────────────────────────────────────────────────────
  // POST /daily-verse/react  { type: "like"|"pray"|"amen" }
  // DELETE /daily-verse/react  { type: "like"|"pray"|"amen" }
  // POST /daily-verse/share

  static const String verseToday  = '/daily-verse';
  static const String verseReact  = '/daily-verse/react';  // POST + DELETE
  static const String verseShare  = '/daily-verse/share';  // POST

  // ── Media upload (multipart/form-data) ────────────────────────────────────

  static const String uploadMedia  = '/media/upload';
  static const String presignedUrl = '/media/presigned-url';

  // ── Moderation (role: moderateur | administrateur) ────────────────────────

  static const String moderationStats    = '/moderation/stats';
  static const String moderationPending  = '/moderation/pending';
  static String moderationById(String id)    => '/moderation/$id';
  static String moderationApprove(String id) => '/moderation/$id/approve'; // POST
  static String moderationReject(String id)  => '/moderation/$id/reject';  // POST

  // ── Admin (role: administrateur) ──────────────────────────────────────────

  static const String adminStats       = '/admin/stats';
  static const String adminUsers       = '/admin/users';
  static const String adminTestimonies = '/admin/testimonies';
  static const String adminCategories  = '/admin/categories';
  static const String adminSettings    = '/admin/settings';

  static String adminCategoryById(String id) => '/admin/categories/$id'; // PUT / DELETE

  static String adminUserById(String id)    => '/admin/users/$id';
  static String adminBanUser(String id)     => '/admin/users/$id/ban';     // POST
  static String adminSuspendUser(String id) => '/admin/users/$id/suspend'; // POST
  static String adminActivateUser(String id)=> '/admin/users/$id/activate';// POST
  static String adminUserRole(String id)    => '/admin/users/$id/role';    // PUT

  // ── Live streaming ────────────────────────────────────────────────────────
  // GET    /live/streams              → [{id, title, author, category, viewer_count}]
  // POST   /live/streams             → create broadcast session
  // DELETE /live/streams/{id}        → end session

  static const String liveStreams  = '/live/streams';
  static String liveStream(String id) => '/live/streams/$id';

  // ── Prayer ────────────────────────────────────────────────────────────────
  // GET    /prayer/requests              → [{id, author, body, prayer_count, message_count, ...}]
  // POST   /prayer/requests             { body, visibility }
  // POST   /prayer/requests/{id}/pray   → toggle pray
  // GET    /prayer/sessions             → [{id, host, title, scheduled_at, status, participant_count}]
  // POST   /prayer/sessions             { title, description, scheduled_at, visibility }

  static const String prayerRequests = '/prayer/requests';
  static String prayerRequestById(String id)  => '/prayer/requests/$id';
  static String prayerRequestPray(String id)  => '/prayer/requests/$id/pray';
  static const String prayerSessions = '/prayer/sessions';
  static String prayerSessionById(String id)  => '/prayer/sessions/$id';

  // ── FCM device token ─────────────────────────────────────────────────────
  // POST   /devices/token  { token, platform: 'android'|'ios' }
  // DELETE /devices/token  { token }

  static const String registerFcmToken   = '/devices/token';
  static const String unregisterFcmToken = '/devices/token';

  // ── Validation limits ─────────────────────────────────────────────────────

  static const int minPasswordLength  = 8;
  static const int maxTestimonyLength = 5000;
  static const int maxCommentLength   = 500;
  static const int maxTitleLength     = 200;

  // ── Media ─────────────────────────────────────────────────────────────────

  static const List<double> playbackSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  static const int maxAudioDurationMin  = 60;
  static const int maxVideoDurationMin  = 10;

  // ── Category slugs (matches /categories API) ──────────────────────────────

  static const List<String> categorySlugs = [
    'guerison',
    'delivrance',
    'protection',
    'provision',
    'famille',
    'salut',
    'mariage',
    'emploi',
    'etudes',
    'autre',
  ];
}
