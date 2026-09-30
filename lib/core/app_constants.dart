// lib/core/app_constants.dart
//
// Central constants for the Témoignages application.
//
// API base: https://testi.airid-africa.com/api/v1
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
    defaultValue: 'https://testi.airid-africa.com/api/v1',
    // defaultValue: 'http://192.168.1.74:8000/api/v1',
    // Dev: http://192.168.0.4:8000/api/v1  (LAN server)
    // Android emulator localhost alias: http://10.0.2.2:8000/api/v1
    // Production: https://api.testi-app.com/api/v1
  );

  /// Racine du site web (sans /api/v1) : domaine des liens de partage.
  static String get webBaseUrl =>
      baseUrl.replaceFirst(RegExp(r'/api/v\d+/?$'), '');

  /// Lien public d'un témoignage — même format que `share_url` côté Laravel
  /// (route web `testimonies.show`). Ouvert par l'app via les App Links.
  static String testimonyWebUrl(String id) => '$webBaseUrl/testimonies/$id';

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

  // Fil « Pour vous » (paginé) : GET /testimonies?sort=for_you&limit=20&page=N
  //   → data = témoignages, meta = { currentPage, lastPage, total, perPage }
  static Map<String, dynamic> forYouFeedQuery({required int page, int limit = defaultPageSize}) =>
      {'sort': 'for_you', 'limit': limit, 'page': page};

  static String testimonyById(String id)          => '/testimonies/$id';
  // Suggestions liées à un témoignage (intérêts, comptes suivis, déjà vus en fin).
  static String testimonyRecommendations(String id) => '/testimonies/$id/recommendations'; // GET ?limit=
  // Preuves privées (auteur + modération) : POST multipart « file » (+ position 1|2),
  // GET {proofId} = fichier (Bearer requis), DELETE {proofId}.
  static String testimonyProofs(String id) => '/testimonies/$id/proofs';
  static String testimonyProof(String id, String proofId) => '/testimonies/$id/proofs/$proofId';
  static String testimonyReactions(String id)     => '/testimonies/$id/reactions';
  static String testimonyReactionById(String testimonyId, String reactionId)
      => '/testimonies/$testimonyId/reactions/$reactionId';
  static String testimonyComments(String id)      => '/testimonies/$id/comments';
  static String testimonySave(String id)   => '/testimonies/$id/save';    // PUT
  static String testimonyUnsave(String id) => '/testimonies/$id/unsave'; // DELETE
  static String testimonyShare(String id)  => '/testimonies/$id/share';  // POST
  static String testimonyReport(String id) => '/testimonies/$id/report'; // POST

  // Carnet privé (docs/fonctionnalites/carnet-prive.md) :
  //   GET /journal?type=&q=&page=&limit= · POST /testimonies {visibility: private}
  static const String journal = '/journal';
  static String testimonyPublish(String id)     => '/testimonies/$id/publish';      // POST : partager
  static String testimonyMakePrivate(String id) => '/testimonies/$id/make-private'; // POST : ranger dans le carnet

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
  // Communauté et abonnements — backend : docs/fonctionnalites/abonnements.md
  //   GET /community?tab=organizations|people&q=&page=  → comptes (+ is_following), meta de pagination
  //   GET /users/me/following-ids                       → identifiants des comptes suivis
  static const String community    = '/community';
  static const String followingIds = '/users/me/following-ids';
  static const String myFollowing  = '/users/me/following';     // GET ?q=&page= → « Mes abonnements »

  // Self management
  static const String updateProfile    = '/users/me';          // PUT
  static const String uploadAvatar     = '/users/me/avatar';   // POST multipart
  static const String profileCover     = '/users/me/cover';    // POST multipart « cover » / DELETE
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

  // ── Témoignages en direct (LiveKit) ──────────────────────────────────────
  // Doc backend : docs/fonctionnalites/lives.md
  // Lecture publique (connexion facultative) :
  //   GET  /lives                     → { configured, canGoLive, active[], recent[] }
  //   GET  /lives/{id}                → direct + liveStats
  //   POST /lives/{id}/viewer-token   → { url, token, identity }
  //   GET  /lives/{id}/comments       → 100 derniers commentaires
  //   GET  /lives/{id}/stats          → { status, viewers, peakViewers, commentCount, reactions }
  // Authentifié :
  //   POST   /lives                   { title, description?, category_slug?, comments_enabled? }
  //                                   → { live, video: { url, token, identity } } (modérateur/admin)
  //   POST   /lives/{id}/host-token   → reprise du direct par le diffuseur
  //   POST   /lives/{id}/go-live      → passage à l'antenne (caméra publiée)
  //   POST   /lives/{id}/end          → terminer / couper
  //   POST   /lives/{id}/comments     { body }
  //   DELETE /lives/{id}/comments/{commentId}
  //   POST   /lives/{id}/comments/{commentId}/pin · DELETE /lives/{id}/pin
  //   POST   /lives/{id}/bans         { user_id }
  //   POST   /lives/{id}/reactions    { type: like|pray|amen|worship|fire }

  static const String lives = '/lives';
  static String liveById(String id)       => '/lives/$id';
  static String liveViewerToken(String id)=> '/lives/$id/viewer-token';
  static String liveHostToken(String id)  => '/lives/$id/host-token';
  static String liveGoLive(String id)     => '/lives/$id/go-live';
  static String liveEnd(String id)        => '/lives/$id/end';
  static String liveStats(String id)      => '/lives/$id/stats';
  static String liveViewers(String id)    => '/lives/$id/viewers'; // qui regarde (public)
  static String liveComments(String id)   => '/lives/$id/comments';
  static String liveComment(String id, String commentId) =>
      '/lives/$id/comments/$commentId';
  static String livePinComment(String id, String commentId) =>
      '/lives/$id/comments/$commentId/pin';                    // POST
  static String liveUnpin(String id)      => '/lives/$id/pin';  // DELETE
  static String liveBans(String id)       => '/lives/$id/bans';
  static String liveReactions(String id)  => '/lives/$id/reactions';

  // Intervenants (un à la fois) — backend : docs/fonctionnalites/lives-intervenants.md
  //   GET    /lives/{id}/stage                        → état (file pour le personnel, « mine »)
  //   POST   /lives/{id}/stage/requests  { message? } → demander à intervenir
  //   DELETE /lives/{id}/stage/requests/mine          → retirer / refuser / quitter l'antenne
  //   POST   /lives/{id}/stage/accept    { identity, camera? }
  //   POST   /lives/{id}/stage/{speakerId}/invite|decline|remove   (diffuseur / modération)
  //   POST   /lives/{id}/stage/settings  { enabled }                (diffuseur / modération)
  static String liveStage(String id)          => '/lives/$id/stage';
  static String liveStageRequests(String id)  => '/lives/$id/stage/requests';
  static String liveStageMine(String id)      => '/lives/$id/stage/requests/mine';
  static String liveStageAccept(String id)    => '/lives/$id/stage/accept';
  static String liveStageSettings(String id)  => '/lives/$id/stage/settings';
  static String liveStageSpeaker(String id, String speakerId, String action) =>
      '/lives/$id/stage/$speakerId/$action';

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
