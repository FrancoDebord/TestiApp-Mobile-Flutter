// lib/core/app_constants.dart
//
// Central constants for the Témoignages application.
//
// API base: https://temoignage.as-krea.com/api/v1
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
    defaultValue: 'https://temoignage.as-krea.com/api/v1',
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

  // ── Connexion Google (google_sign_in 7.x) ─────────────────────────────────

  /// Identifiant client **Web** du projet Firebase (google-services.json → oauth_client,
  /// client_type 3) : `serverClientId` de GoogleSignIn, audience du jeton vérifiée par l'API
  /// (GOOGLE_CLIENT_ID côté serveur).
  static const String googleServerClientId =
      '566166419345-b78faa624rdlcqeigmublhhbseqvhofr.apps.googleusercontent.com';

  /// Identifiant client iOS (GoogleService-Info.plist → CLIENT_ID), utilisé sur iOS seulement.
  static const String googleIosClientId =
      '78564751626-tfc6p4rvivn2pt2hfanpvar336a8nud6.apps.googleusercontent.com';

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
  /// Connexion Google : { id_token } → même réponse que [authLogin] (token Sanctum + utilisateur).
  static const String authGoogle         = '/auth/google';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authRefresh        = '/auth/refresh';
  static const String authLogout         = '/auth/logout';
  static const String authMe             = '/auth/me';   // GET only — current user
  // { current_password, new_password, new_password_confirmation } (comptes e-mail)
  static const String authChangePassword = '/auth/change-password';

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
  // Gestion des témoignages (docs serveur fonctionnalites/gestion-des-temoignages.md) :
  //   GET  /testimonies/my ?status=all|pending|approved|rejected&limit=&page= (auteur : tous ses statuts)
  //   POST /testimonies/{id}/view { device_id?, watched_seconds? } (public) : vue dédoublonnée 30 min
  //   GET  /testimonies ?verified=1&featured=1&sort=recent|popular|most_viewed|for_you
  //   PUT  /testimonies/{id} : « Modifier et renvoyer » (refusé ou publié → pending, label retiré)
  static const String myTestimonies = '/testimonies/my';
  static String testimonyView(String id) => '/testimonies/$id/view';
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
  /// PUT { publicationWeb?, isAnonymous? } : accord pour le web, auteur seulement,
  /// sans nouvelle modération (docs serveur fonctionnalites/referencement.md).
  static String testimonyWeb(String id)    => '/testimonies/$id/web';
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
  // Témoignage de conversion publié d'un compte (404 s'il n'en a pas) ;
  // le mien, quel que soit son statut : { data | null, can_create }.
  // docs serveur fonctionnalites/temoignage-de-conversion.md
  static String userConversionTestimony(String id) => '/users/$id/conversion-testimony';
  static const String myConversionTestimony = '/me/conversion-testimony';
  // Types de témoignages autorisés (réglages administrateur) — docs serveur types-de-temoignages.md
  static const String mePublishing = '/me/publishing';
  static String adminUserPublishing(String id) => '/admin/users/$id/publishing';
  // « J'aime » des commentaires : voir lib/shared/comments/comment_likes.dart.
  static String userFollow(String id)       => '/users/$id/follow';    // POST
  static String userUnfollow(String id)     => '/users/$id/unfollow';  // DELETE
  // Communauté et abonnements — backend : docs/fonctionnalites/abonnements.md
  //   GET /community?tab=organizations|people&q=&page=  → comptes (+ is_following), meta de pagination
  //   GET /users/me/following-ids                       → identifiants des comptes suivis
  static const String community    = '/community';
  static const String followingIds = '/users/me/following-ids';
  static const String myFollowing  = '/users/me/following';     // GET ?q=&page= → « Mes abonnements »
  static const String myFollowers  = '/users/me/followers';     // GET ?q=&page= → « Mes abonnés » (+ is_following = je le suis en retour)
  // Comptes à suivre : GET ?limit=10&type=all|organizations|people → [{…profil public, reason, isVerified…}] (invité accepté)
  static const String userSuggestions = '/users/suggestions';
  // Mentions « @ » : GET ?q=&limit=8&testimony_id= → [{id, displayName, avatarUrl, initials, isVerified, isFollowing}] (connecté)
  static const String mentionSearch   = '/users/mention-search';

  /// Aperçu d'un lien (docs serveur fonctionnalites/liens-et-apercus.md) :
  /// `GET ?url=` → `{ url, title, description, image, siteName, host } | null`.
  static const String linkPreview     = '/link-preview';      // API, connecté
  static const String webLinkPreview  = '/liens/apercu';      // site, visiteur
  // Autocomplétion des recherches (public) : GET ?q=&scope=all|testimonies|users|events|prayer|bible&limit=
  // → {query, scope, suggestions:[{text, source, highlight}], results:[{type, id, label, sublabel, route, url, avatar…}]}
  static const String searchSuggest = '/search/suggest';
  static const String searchLog     = '/search/log'; // POST { q } : recherche validée, anonyme (recherches populaires)

  // Self management
  static const String updateProfile    = '/users/me';          // PUT
  /// PUT { locale: fr|en } : langue des notifications et e-mails (repli : updateProfile).
  static const String meLocale         = '/me';
  static const String uploadAvatar     = '/users/me/avatar';   // POST multipart
  static const String profileCover     = '/users/me/cover';    // POST multipart « cover » / DELETE
  static const String updateSettings   = '/users/me/settings'; // GET · PUT (clés snake_case)
  // Localisation privée (fils classés par zone) : GET · PUT { use_gps, latitude, longitude, home_city } · DELETE
  static const String myLocation       = '/users/me/location';
  // DELETE /me { password } ou { confirm: true } : compte et données supprimés
  // (docs serveur fonctionnalites/confidentialite-et-suppression.md).
  static const String deleteAccount    = '/me';
  // GET ?lang=fr|en, sans connexion → { title, updated_at, html, url } : politique affichée dans l'app.
  static const String legalPrivacy     = '/legal/privacy';
  // Vérification d'un compte personnel (docs/fonctionnalites/verification-des-comptes.md) :
  // GET → {status: none|pending|verified|rejected|revoked, canRequest, blockReason, retryAt, reason, request, roles, limits}
  // POST multipart { full_name, role, role_other?, church, links[]?, message?, documents[] (1 à 3 : jpg/png/webp/pdf, 8 Mo) } → 201 même forme
  static const String myVerification   = '/users/me/verification';

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
  static String versePrayStart(int id) => '/daily-verse/$id/pray/start'; // temps de prière
  static const String verseHistory = '/daily-verse/history'; // ?page=&limit= — versets des jours passés
  static String verseById(int id) => '/daily-verse/$id';
  static const String verseShare  = '/daily-verse/share';  // POST

  // Page plein écran (docs serveur fonctionnalites/verset-du-jour.md)
  // GET  /daily-verse/{id}/versions          → { reference, parsed, original, versions: [{code, name, language, available, text, verses}] }
  // POST /daily-verse/{id}/react  { type, active? }
  // GET · POST /daily-verse/{id}/comments { body } · DELETE …/comments/{cid} · POST …/comments/{cid}/report { reason }
  // GET  /daily-verse/{id}/prayer-requests   (création : POST /prayer/requests { …, daily_verse_id })
  // GET  /daily-verse/{id}/testimonies
  static String verseVersions(int id) => '/daily-verse/$id/versions';
  static String verseReactTo(int id) => '/daily-verse/$id/react';
  static String verseComments(int id) => '/daily-verse/$id/comments';
  static String verseComment(int id, String commentId) => '/daily-verse/$id/comments/$commentId';
  static String versePrayerRequests(int id) => '/daily-verse/$id/prayer-requests';
  static String verseTestimonies(int id) => '/daily-verse/$id/testimonies';

  // Designs du verset (docs serveur fonctionnalites/designs-du-verset.md) :
  // GET /verse-designs (public, 24 h) → { designs: [{id, name, mood, order, tone}], fonts,
  //   text_sizes, text_aligns, defaults } ; la ressource du verset ajoute design_of_the_day,
  //   user_style (connecté, sinon null) et effective_design_id.
  // GET · PUT /me/verse-style { design_id, design_chosen_on, design_always, font, text_size,
  //   text_align } (noms d'enum de l'app ; valeur inconnue → 422).
  static const String verseDesigns = '/verse-designs';
  static const String myVerseStyle = '/me/verse-style';

  // ── Media upload (multipart/form-data) ────────────────────────────────────

  static const String uploadMedia  = '/media/upload';
  static const String presignedUrl = '/media/presigned-url';

  // ── Vidéos Bunny Stream (envoi reprenable TUS) ────────────────────────────
  // POST /videos/upload-init { mêmes champs que POST /testimonies, sans media_url }
  //   → crée le témoignage (video_status = uploading, invisible publiquement) et la vidéo Bunny :
  //   { video_id, testimony_id, library_id, bunny_video_id, signature, expiration, tus_endpoint }
  // POST /videos/{id}/upload-signature → { signature, expiration } (même bunny_video_id)
  // POST /videos/{id}/upload-complete  → fin de l'envoi, traitement par Bunny
  // Témoignage vidéo : video { status: uploading|processing|ready|failed, hls_url,
  //   thumbnail_url, mp4_urls { "240": url, "360": url, … }, duration } ; push « video_ready ».
  static const String videoUploadInit = '/videos/upload-init';
  static String videoUploadSignature(String id) => '/videos/$id/upload-signature';
  static String videoUploadComplete(String id)  => '/videos/$id/upload-complete';

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
  // Description des réglages (mêmes groupes et libellés que le site) — docs serveur parametres-globaux.md
  static const String adminSettingsSchema = '/admin/settings/schema';

  static String adminCategoryById(String id) => '/admin/categories/$id'; // PUT / DELETE

  static String adminUserById(String id)    => '/admin/users/$id';
  static String adminBanUser(String id)     => '/admin/users/$id/ban';     // POST
  static String adminSuspendUser(String id) => '/admin/users/$id/suspend'; // POST
  static String adminActivateUser(String id)=> '/admin/users/$id/activate';// POST
  static String adminUserRole(String id)    => '/admin/users/$id/role';    // PUT
  // Vérification des comptes personnels : GET ?status=pending|approved|rejected|revoked|all
  // → {items, pendingCount, currentPage, lastPage, total} ; détail {…, links, message, documents[{index, name, mime, isImage, url}]}
  static const String adminVerificationRequests = '/admin/verification-requests';
  static String adminVerificationRequest(String id) => '/admin/verification-requests/$id';
  static String adminVerificationDocument(String id, int index) => '/admin/verification-requests/$id/documents/$index'; // GET (jeton admin)
  static String adminVerificationApprove(String id) => '/admin/verification-requests/$id/approve'; // POST
  static String adminVerificationReject(String id)  => '/admin/verification-requests/$id/reject';  // POST { reason }
  static String adminRevokeVerification(String userId) => '/admin/users/$userId/revoke-verification'; // POST { reason }

  // ── Témoignages en direct (LiveKit) ──────────────────────────────────────
  // Doc backend : docs/fonctionnalites/lives.md
  // Lecture publique (connexion facultative) :
  //   GET  /lives                     → { configured, canGoLive, active[], recent[] }
  //   GET  /lives/{id}                → direct + liveStats
  //   POST /lives/{id}/viewer-token   → { url, token, identity }
  //   GET  /lives/{id}/comments       → 100 derniers commentaires (direct terminé : tous, ?page, offsetSeconds)
  //   GET  /lives/{id}/testimonies    → témoignages rattachés au direct (live_id)
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
  static String liveHeartbeat(String id)  => '/lives/$id/heartbeat'; // direct YouTube (public)
  static String liveViewers(String id)    => '/lives/$id/viewers'; // qui regarde (public)
  static String liveComments(String id)   => '/lives/$id/comments';
  static String liveTestimonies(String id) => '/lives/$id/testimonies';
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

  // ── Événements chrétiens ─────────────────────────────────────────────────
  // Backend : docs/fonctionnalites/evenements.md
  //   GET    /events?scope=upcoming|past|mine|going&type=&q=  → liste paginée (meta.canCreate, meta.types)
  //   GET    /events/{id}  · /events/{id}/comments · /events/{id}/testimonies
  //   POST   /events  · PUT/DELETE /events/{id}            (organisation vérifiée / admin, gestionnaires)
  //   POST   /events/{id}/images (multipart « image ») · DELETE …/images/{imageId} · POST …/images/{imageId}/cover
  //   POST   /events/{id}/participation { status: going|not_going } · DELETE /events/{id}/participation
  //   GET    /events/{id}/participants                      (gestionnaires)
  //   POST   /events/{id}/comments { body } · DELETE …/comments/{commentId}
  //   POST   /events/{id}/comments/{commentId}/promote { title?, category? } → témoignage officiel
  // Paroles prophétiques du carnet privé (docs/fonctionnalites/paroles-prophetiques.md)
  //   GET/POST /prophecies · GET/PUT/DELETE /prophecies/{id}
  //   GET/POST /prophecies/{id}/prayers { note? } · DELETE …/prayers/{prayerId}
  //   POST /testimonies { …, prophecy_id, prophecy_public } → parole accomplie
  static const String prophecies = '/prophecies';
  static String prophecyById(String id) => '/prophecies/$id';
  static String prophecyPrayers(String id) => '/prophecies/$id/prayers';
  static String prophecyPrayStart(String id) => '/prophecies/$id/pray/start'; // temps de prière
  static String prophecyPrayer(String id, int prayerId) => '/prophecies/$id/prayers/$prayerId';

  // Mon fil (tous les témoignages, comptes suivis d'abord) : GET /feed → feedReason
  // following|suggested|repost (+ repostedBy, repostComment, repostedAt pour un partage).
  static const String personalFeed = '/feed';
  // Insérés dans Mon fil : GET /feed/inserts → { following|others: { events, prayerSessions,
  // prayerRequests, prophecies } } (comptes suivis d'abord).
  static const String personalFeedInserts = '/feed/inserts';
  // Partage interne « X a partagé » : POST { comment? } · DELETE ; partages d'un compte.
  static String testimonyRepost(String id) => '/testimonies/$id/repost';
  static String userReposts(String id) => '/users/$id/reposts';

  static const String events = '/events';
  static String eventById(String id)          => '/events/$id';
  // Types d'événements gérés par les administrateurs (docs serveur types-evenements.md).
  static const String eventTypes = '/event-types';
  static const String adminEventTypes = '/admin/event-types';
  static const String adminEventTypesReorder = '/admin/event-types/reorder';
  static String adminEventType(int id) => '/admin/event-types/$id';
  static String eventImages(String id)        => '/events/$id/images';
  static String eventImage(String id, String imageId) => '/events/$id/images/$imageId';
  static String eventImageCover(String id, String imageId) =>
      '/events/$id/images/$imageId/cover';
  static String eventParticipation(String id) => '/events/$id/participation';
  static String eventParticipants(String id)  => '/events/$id/participants';
  static String eventComments(String id)      => '/events/$id/comments';
  static String eventComment(String id, String commentId) =>
      '/events/$id/comments/$commentId';
  static String eventCommentPromote(String id, String commentId) =>
      '/events/$id/comments/$commentId/promote';
  static String eventTestimonies(String id)   => '/events/$id/testimonies';
  //   POST   /events/{id}/managers { user_id } · DELETE …/managers/{userId}  (2 co-gestionnaires au plus)
  //   GET/POST /users/me/managers { user_id } · DELETE …/{userId}          (organisation : 2 gestionnaires)
  //   GET    /users/me/managed-organizations · DELETE …/{organizationId}  (organisations que je gère)
  static String eventManagers(String id)      => '/events/$id/managers';
  static String eventManager(String id, String userId) => '/events/$id/managers/$userId';
  //   POST   /events/{id}/postpone { date_tbd } | { starts_at, ends_at } + reason? · POST …/cancel { reason? }
  //   POST   /events/{id}/report { reason, comment? } (une fois) · POST …/review { attended, rating?, body? }
  //   GET    /events/{id}/reviews · modérateurs : GET /events/moderation?filter= · POST …/hide|restore|dismiss
  static String eventPostpone(String id)      => '/events/$id/postpone';
  static String eventCancel(String id)        => '/events/$id/cancel';
  static String eventReport(String id)        => '/events/$id/report';
  static String eventReview(String id)        => '/events/$id/review';
  static String eventReviews(String id)       => '/events/$id/reviews';
  static String eventModeration(String id, String action) => '/events/$id/$action';
  static const String myManagers              = '/users/me/managers';
  // Administrateurs de compte (tous les comptes, 2 au plus) : agir au nom d'un compte
  // avec l'en-tête X-Act-As (lib/services/acting_as_interceptor.dart).
  //   GET /users/me/accounts → {accounts: [{id, displayName, username, initials, avatarUrl,
  //       isOrganization, isVerified, role: owner|manager, since}], actingAs}
  //   GET /users/me → comme /auth/me, mais suit X-Act-As (acting_as, acting_actor)
  //   GET /users/me/managers/activity → [{id, actorId, actorName, action, createdAt}]
  static const String myAccounts              = '/users/me/accounts';
  static const String me                      = '/users/me';
  static const String myManagersActivity      = '/users/me/managers/activity';
  static String myManager(String userId)      => '/users/me/managers/$userId';
  static const String myManagedOrganizations  = '/users/me/managed-organizations';
  static String myManagedOrganization(String id) => '/users/me/managed-organizations/$id';

  // ── Requêtes et sessions de prière ────────────────────────────────────────
  // Docs serveur : fonctionnalites/requetes-de-priere.md, fonctionnalites/sessions-de-priere.md
  // GET    /prayer/requests?scope=all|feed|following|mine|event&event_id=&status=open|answered&page=
  //        → [PrayerRequestResource] + meta { currentPage, lastPage, total, canCreate }
  // POST   /prayer/requests { body, visibility: public|followers|private, is_anonymous, event_id? }
  // GET · PUT · DELETE /prayer/requests/{id}   (PUT : body, visibility, is_anonymous, testimony_id)
  // POST   /prayer/requests/{id}/pray { prayed? }    « Je prie » (bascule)
  // POST · DELETE /prayer/requests/{id}/answered { note? }   exaucée / de nouveau en attente
  // GET · POST /prayer/requests/{id}/messages { message, bible_reference? } · DELETE …/messages/{messageId}
  // POST   /prayer/requests/{id}/report { reason, comment? }
  // GET    /prayer/sessions?scope=upcoming|past|mine|joined|event&event_id=  → [PrayerSessionResource]
  // POST   /prayer/sessions { title, description?, topics[], starts_at, duration_minutes, visibility, event_id? }
  // GET · PUT · DELETE /prayer/sessions/{id} · POST …/cancel
  // POST · DELETE /prayer/sessions/{id}/join          « Je serai là »
  // POST   /prayer/sessions/{id}/start  (hôte) → { session, live, video } : la salle est un direct (/lives/{id})

  static const String prayerRequests = '/prayer/requests';
  static String prayerRequestById(String id)  => '/prayer/requests/$id';
  static String prayerRequestPray(String id)  => '/prayer/requests/$id/pray';
  // Temps de prière : début des 5 minutes avant « Je prie » (docs serveur temps-de-priere.md).
  static String prayerRequestPrayStart(String id) => '/prayer/requests/$id/pray/start';
  static String testimonyPrayStart(String id)     => '/testimonies/$id/pray/start';
  static String prayerRequestAnswered(String id) => '/prayer/requests/$id/answered';
  static String prayerRequestMessages(String id) => '/prayer/requests/$id/messages';
  static String prayerRequestMessage(String id, String messageId) =>
      '/prayer/requests/$id/messages/$messageId';
  static String prayerRequestReport(String id) => '/prayer/requests/$id/report';
  static const String prayerSessions = '/prayer/sessions';
  static String prayerSessionById(String id)  => '/prayer/sessions/$id';
  static String prayerSessionJoin(String id)  => '/prayer/sessions/$id/join';
  static String prayerSessionStart(String id) => '/prayer/sessions/$id/start';
  static String prayerSessionCancel(String id) => '/prayer/sessions/$id/cancel';

  // ── FCM device token ─────────────────────────────────────────────────────
  // POST   /devices/token  { token, platform: 'android'|'ios' }
  // DELETE /devices/token  { token }

  static const String registerFcmToken   = '/devices/token';
  static const String unregisterFcmToken = '/devices/token';
  /// POST : envoie un push de test aux appareils du compte (Paramètres ›
  /// « Tester les notifications »).
  static const String pushTest           = '/me/push-test';

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
