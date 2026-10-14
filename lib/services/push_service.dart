// lib/services/push_service.dart
//
// Notifications push Firebase Cloud Messaging (PushService, singleton).
//
// Responsibilities:
//   • Request notification permissions (iOS/Android 13+)
//   • Get/refresh the FCM device token and register it with the Laravel server
//     (POST /devices/token ; DELETE at logout)
//   • Handle foreground messages → show local notification + trigger delta sync
//   • Handle taps (background, terminated, foreground) → navigation intent via Riverpod
//   • Respect user push preferences (UserSettings toggles)
//
// Integration points:
//   • PushService.init() + registerDevice() → main.dart, on every switch to « authenticated »
//   • PushService.unregisterDevice()       → AuthNotifier.logout(), before the Sanctum token is cleared
//   • fcmNavProvider                       → watched by TemoignagesApp to drive navigation
//   • firebaseMessagingBackgroundHandler (top-level) → declared in main.dart

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../features/home/providers/home_providers.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/prophecies/data/prophecy_reminders.dart';
import '../features/prophecies/providers/prophecies_providers.dart';
import '../features/auth/providers/auth_notifier.dart' show authStateProvider, currentUserProvider;
import '../features/profile/providers/account_verification_provider.dart' show accountVerificationProvider;
import '../features/profile/providers/profile_provider.dart'
    show myTestimoniesNotifierProvider, userSettingsProvider;
import '../features/testimony/providers/testimony_refresh.dart'
    show kVideoPushTypes, testimonyReloaderProvider, videoPushTestimonyId;
import 'api_service.dart';
import 'sync_service.dart';

// ── Android notification channel ──────────────────────────────────────────────

/// Canal Android des notifications : même identifiant que le serveur (FCM_ANDROID_CHANNEL)
/// et que `default_notification_channel_id` dans AndroidManifest.xml.
const kPushChannelId = 'testi_notifications';
const _kChannelName = 'Notifications Témoignages';
const _kChannelDesc = 'Commentaires, réactions, approbations et prières.';

// ── Local notifications plugin (singleton for background handler access) ──────

final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ── FCM navigation intent ─────────────────────────────────────────────────────

class FcmNavIntent {
  const FcmNavIntent({
    required this.type,
    this.testimonyId,
    this.liveId,
    this.prophecyId,
    this.prayerRequestId,
    this.prayerSessionId,
    this.eventId,
    this.actorId,
    this.dailyVerseId,
  });
  final String  type;
  final String? testimonyId;
  final String? liveId;

  /// Rappel de prière d'une parole prophétique (notification locale).
  final String? prophecyId;

  /// Requête / session de prière (types prayer_*).
  final String? prayerRequestId;
  final String? prayerSessionId;

  /// Événement (types event_*, mention dans un commentaire d'événement).
  final String? eventId;

  /// Compte à l'origine du push (`follow` : ouvre son profil).
  final String? actorId;

  /// Verset du jour (mention dans un commentaire du verset).
  final String? dailyVerseId;

  /// Construit l'intention depuis les données d'un push FCM
  /// (null si `type` est absent).
  static FcmNavIntent? fromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return null;
    String? str(String key) {
      final v = data[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }
    return FcmNavIntent(
      type:        type,
      // `video_ready` / `video_failed` : `testimony_id`, ou `id` à défaut.
      testimonyId: kVideoPushTypes.contains(type)
          ? videoPushTestimonyId(data)
          : str('testimony_id'),
      liveId:      str('live_id'),
      prophecyId:  str('prophecy_id'),
      // `type: prayer_request` + `id` : la requête de prière elle-même.
      prayerRequestId: str('prayer_request_id') ?? (type == 'prayer_request' ? str('id') : null),
      prayerSessionId: str('prayer_session_id'),
      eventId:     str('event_id'),
      actorId:     str('actor_id'),
      dailyVerseId: str('daily_verse_id'),
    );
  }
}

class FcmNavNotifier extends Notifier<FcmNavIntent?> {
  @override
  FcmNavIntent? build() => null;

  void set(FcmNavIntent intent) => state = intent;
  void clear()                  => state = null;
}

final fcmNavProvider =
    NotifierProvider<FcmNavNotifier, FcmNavIntent?>(FcmNavNotifier.new);

// ── Push service ──────────────────────────────────────────────────────────────

/// Notifications push Firebase Cloud Messaging (singleton).
///
///   • [init]              : autorisation, canal Android, écoute des messages (une seule fois) ;
///   • [registerDevice]    : jeton FCM → POST /devices/token, puis suivi de onTokenRefresh ;
///   • [unregisterDevice]  : DELETE /devices/token puis suppression du jeton local ;
///   • [handleNavigation]  : toucher d'une notification (arrière-plan, app fermée, premier plan).
///
/// Branché par main.dart : [init] puis [registerDevice] à chaque passage à l'état « connecté »
/// (démarrage avec une session, connexion e-mail, Google, téléphone, inscription) ;
/// [unregisterDevice] dans AuthNotifier.logout(), avant la suppression du token Sanctum.
/// Une erreur de l'API (404, réseau…) est seulement journalisée : jamais bloquante.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Accès aux providers (réglages, API, navigation), fourni par [pushServiceProvider].
  Ref? _ref;
  Ref get _r => _ref!;

  final _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  StreamSubscription<String>? _tokenRefresh;

  void _attach(Ref ref) => _ref = ref;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Autorisation, canal Android et écoute des messages. Sans effet après le premier appel.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _requestPermissions();
      await _initLocalNotifications();
      _setupMessageHandlers();
      await _handleLaunchNotification();
    } catch (e, stack) {
      _log('init', e, stack);
    }
  }

  /// Envoie le jeton FCM de l'appareil à l'API (compte connecté) et suit son renouvellement.
  Future<void> registerDevice() async {
    // Session hors ligne / locale : l'API n'est pas joignable.
    final storage = _r.read(secureStorageProvider);
    final accessToken = await storage.read(key: AppConstants.keyAccessToken);
    if (accessToken == null || accessToken == 'offline_mode' || accessToken == 'local_auth') {
      return;
    }
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('Push : aucun jeton FCM (Google Play Services indisponibles ?)');
        return;
      }
      await _sendToken(token);
    } catch (e, stack) {
      _log('getToken', e, stack);
    }
    await _tokenRefresh?.cancel();
    _tokenRefresh = _messaging.onTokenRefresh.listen(_sendToken);
  }

  /// Dissocie l'appareil du compte : DELETE /devices/token, puis suppression du jeton local
  /// (un nouveau jeton sera créé à la prochaine connexion). Jamais bloquant.
  Future<void> unregisterDevice() async {
    await _tokenRefresh?.cancel();
    _tokenRefresh = null;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _r.read(apiServiceProvider).delete<void>(
          AppConstants.unregisterFcmToken,
          data: {'token': token},
        );
      }
    } catch (e, stack) {
      _log('DELETE ${AppConstants.unregisterFcmToken}', e, stack);
    }
    try {
      await _messaging.deleteToken();
    } catch (e, stack) {
      _log('deleteToken', e, stack);
    }
  }

  /// Recharge ce que le push [type] a changé (toucher d'une notification, main.dart).
  void refreshFor(String? type, {String? testimonyId}) =>
      refreshForPush(_r, type, testimonyId: testimonyId);

  /// Types qui changent le badge « Approuvé » du compte connecté.
  static const accountBadgeTypes = {
    'account_verified',
    'organization_verified',
    'account_verification_rejected',
    'organization_rejected',
    // Badge retiré, quel que soit le chemin (docs serveur fonctionnalites/badge-approuve.md).
    'account_approval_revoked',
  };

  /// Toucher d'une notification : ouvre l'écran correspondant (main.dart, _handleFcmNavigation).
  /// `type: prayer_request` + `id` ouvre aussi la requête de prière.
  void handleNavigation(Map<String, dynamic> data) {
    final intent = FcmNavIntent.fromData(data);
    if (intent == null) {
      debugPrint('Push : notification sans type, aucune navigation ($data)');
      return;
    }
    _r.read(fcmNavProvider.notifier).set(intent);
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // Foreground display off: we show our own styled local notifications.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  // ── Local notifications setup ─────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await localNotificationsPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    // Create the Android channel once (same id as the server: FCM_ANDROID_CHANNEL,
    // and as default_notification_channel_id in AndroidManifest.xml).
    const channel = AndroidNotificationChannel(
      kPushChannelId, _kChannelName,
      description: _kChannelDesc,
      importance: Importance.high,
    );
    await localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Message handlers ──────────────────────────────────────────────────────

  void _setupMessageHandlers() {
    // Foreground message
    FirebaseMessaging.onMessage.listen(_onForeground);

    // Tap while app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((m) => handleNavigation(m.data));
  }

  /// App lancée par le toucher d'une notification : push FCM (app fermée) ou
  /// notification locale affichée au premier plan avant la fermeture.
  Future<void> _handleLaunchNotification() async {
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      handleNavigation(initial.data);
      return;
    }
    final launch = await localNotificationsPlugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      _onLocalNotifTap(response);
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    // Parole prophétique modifiée ailleurs (site, autre téléphone) : message
    // silencieux, rappel reprogrammé et liste rechargée ; rien à afficher.
    if (await ProphecyReminders.handlePush(message.data)) {
      _r.invalidate(propheciesListProvider);
      _r.invalidate(prophecyProvider);
      return;
    }

    // Vidéo prête ou en échec : témoignage rechargé dans les écrans ouverts ;
    // témoignage approuvé ou refusé : « Mes publications » rechargé ;
    // badge « Approuvé » attribué ou retiré : profil rechargé.
    final type = message.data['type']?.toString();
    refreshForPush(_r, type,
        testimonyId: kVideoPushTypes.contains(type)
            ? videoPushTestimonyId(message.data)
            : null);

    // 1. Refresh local data immediately.
    await _deltaSync();

    // 2. Show local notification if user has the preference enabled.
    if (_shouldShow(message) && message.notification != null) {
      await _showLocalNotif(message);
    }
  }

  // ── Notification filter (respects UserSettings) ───────────────────────────

  bool _shouldShow(RemoteMessage message) {
    final settings = _r.read(userSettingsProvider);
    return switch (message.data['type'] as String? ?? '') {
      'comment' || 'reply' || 'mention' => settings.pushComments,
      'like'                            => settings.pushLikes,
      'prayer' || 'prayer_encouragement' || 'prayer_request_prayed' => settings.pushPrayers,
      // Pas de préférence dédiée « abonnements » dans UserSettings :
      // toujours affichées.
      'live_started'
          || 'new_followed_testimony'
          // Mon témoignage vidéo est en ligne, ou n'a pas pu être traité.
          || 'video_ready'
          || 'video_failed'
          // Badge « Approuvé » attribué ou retiré, témoignage renvoyé en modération.
          || 'account_verified'
          || 'organization_verified'
          || 'account_verification_rejected'
          || 'organization_rejected'
          || 'account_approval_revoked'
          || 'testimony_resubmitted'    => true,
      'testimony_approved'
          || 'testimony_rejected'
          || 'pending_correction'       => settings.pushApproval,
      _                                 => true,
    };
  }

  // ── Show local notification ───────────────────────────────────────────────

  Future<void> _showLocalNotif(RemoteMessage message) async {
    final n = message.notification!;
    await localNotificationsPlugin.show(
      (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}').hashCode,
      n.title ?? 'Témoignages',
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kPushChannelId, _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.high,
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Navigation from tap ───────────────────────────────────────────────────

  void _onLocalNotifTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      handleNavigation(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (e, stack) {
      _log('payload', e, stack);
    }
  }

  // ── Delta sync + provider refresh ────────────────────────────────────────

  Future<void> _deltaSync() async {
    try {
      final userId = _r.read(currentUserProvider)?.id;
      await _r.read(syncServiceProvider).deltaSync(userId: userId);
      // Silent refresh — keeps current data visible, no loading flash.
      _r.read(feedNotifierProvider.notifier).refresh();
      _r.invalidate(notificationsNotifierProvider);
    } catch (_) {}
  }

  // ── FCM token registration ────────────────────────────────────────────────

  /// POST /devices/token { token, platform }. Une erreur (404, réseau…) est seulement journalisée.
  Future<void> _sendToken(String token) async {
    if (kDebugMode) debugPrint('FCM TOKEN: $token');
    try {
      await _r.read(apiServiceProvider).post<void>(
        AppConstants.registerFcmToken,
        data: {
          'token':    token,
          'platform': kIsWeb
              ? 'web'
              : defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'ios',
        },
      );
    } catch (e, stack) {
      _log('POST ${AppConstants.registerFcmToken}', e, stack);
    }
  }

  void _log(String step, Object error, [StackTrace? stack]) {
    debugPrint('Push ✗ $step : $error');
    if (kDebugMode && stack != null) debugPrint('$stack');
  }
}

// ── Rafraîchissements liés à un push ─────────────────────────────────────────

/// Recharge ce qu'un push de type [type] a changé (reçu au premier plan ou touché).
/// Vidéo prête ou en échec : le témoignage [testimonyId] est relu et mis à jour
/// partout (détail, fil, « Mes témoignages », modération).
void refreshForPush(Ref ref, String? type, {String? testimonyId}) {
  switch (type) {
    case 'video_ready' || 'video_failed':
      if (testimonyId != null) {
        unawaited(ref.read(testimonyReloaderProvider).reload(testimonyId));
      } else {
        ref.invalidate(myTestimoniesNotifierProvider);
      }
    case 'testimony_approved' || 'testimony_rejected':
      ref.invalidate(myTestimoniesNotifierProvider);
    case final t? when PushService.accountBadgeTypes.contains(t):
      // Badge « Approuvé » attribué ou retiré (docs serveur fonctionnalites/badge-approuve.md).
      unawaited(ref.read(authStateProvider.notifier).refreshCurrentUser());
      ref.invalidate(accountVerificationProvider);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Le singleton [PushService], relié aux providers de l'application.
final pushServiceProvider = Provider<PushService>((ref) => PushService.instance.._attach(ref));
