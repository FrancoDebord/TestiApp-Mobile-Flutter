// lib/services/fcm_service.dart
//
// Firebase Cloud Messaging service.
//
// Responsibilities:
//   • Request notification permissions (iOS/Android 13+)
//   • Get/refresh the FCM device token and register it with the Laravel server
//   • Handle foreground messages → show local notification + trigger delta sync
//   • Handle background/killed-state tap → post navigation intent via Riverpod
//   • Respect user push preferences (UserSettings toggles)
//
// Integration points:
//   • FcmService.init()        → called in main.dart after auth resolves
//   • FcmService.unregister()  → called on logout in auth_notifier.dart
//   • fcmNavigationProvider    → watched by TemoignagesApp to drive navigation
//   • firebaseMessagingBackgroundHandler (top-level) → declared in main.dart

import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_constants.dart';
import '../features/home/providers/home_providers.dart';
import '../features/notifications/providers/notifications_provider.dart';
import '../features/auth/providers/auth_notifier.dart' show currentUserProvider;
import '../features/profile/providers/profile_provider.dart'
    show userSettingsProvider;
import 'api_service.dart';
import 'sync_service.dart';

// ── Android notification channel ──────────────────────────────────────────────

const _kChannelId   = 'testi_notifications';
const _kChannelName = 'Notifications Témoignages';
const _kChannelDesc = 'Commentaires, réactions, approbations et prières.';

// ── Local notifications plugin (singleton for background handler access) ──────

final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ── FCM navigation intent ─────────────────────────────────────────────────────

class FcmNavIntent {
  const FcmNavIntent({required this.type, this.testimonyId});
  final String  type;
  final String? testimonyId;
}

class FcmNavNotifier extends Notifier<FcmNavIntent?> {
  @override
  FcmNavIntent? build() => null;

  void set(FcmNavIntent intent) => state = intent;
  void clear()                  => state = null;
}

final fcmNavProvider =
    NotifierProvider<FcmNavNotifier, FcmNavIntent?>(FcmNavNotifier.new);

// ── FCM service ───────────────────────────────────────────────────────────────

class FcmService {
  FcmService(this._ref);
  final Ref _ref;

  final _messaging = FirebaseMessaging.instance;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Call once after the user authenticates.
  Future<void> init() async {
    await _requestPermissions();
    await _initLocalNotifications();
    _setupMessageHandlers();
    await _registerToken();
    _messaging.onTokenRefresh.listen(_sendToken);
  }

  /// Call on logout to dissociate the device from the user's account.
  Future<void> unregister() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      final api = _ref.read(apiServiceProvider);
      await api.delete<void>(
        AppConstants.unregisterFcmToken,
        data: {'token': token},
      );
      await _messaging.deleteToken();
    } catch (_) {}
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

    // Create the Android channel once.
    const channel = AndroidNotificationChannel(
      _kChannelId, _kChannelName,
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
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigation);

    // Tap while app was terminated
    _messaging.getInitialMessage().then((msg) {
      if (msg != null) _handleNavigation(msg);
    });
  }

  Future<void> _onForeground(RemoteMessage message) async {
    // 1. Refresh local data immediately.
    await _deltaSync();

    // 2. Show local notification if user has the preference enabled.
    if (_shouldShow(message) && message.notification != null) {
      await _showLocalNotif(message);
    }
  }

  // ── Notification filter (respects UserSettings) ───────────────────────────

  bool _shouldShow(RemoteMessage message) {
    final settings = _ref.read(userSettingsProvider);
    return switch (message.data['type'] as String? ?? '') {
      'comment' || 'reply' || 'mention' => settings.pushComments,
      'like'                            => settings.pushLikes,
      'prayer'                          => settings.pushPrayers,
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
      message.hashCode,
      n.title ?? 'Témoignages',
      n.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _kChannelId, _kChannelName,
          importance: Importance.high,
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
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
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _postNavIntent(data);
    } catch (_) {}
  }

  void _handleNavigation(RemoteMessage message) => _postNavIntent(message.data);

  void _postNavIntent(Map<String, dynamic> data) {
    final type        = data['type']         as String?;
    final testimonyId = data['testimony_id'] as String?;
    if (type == null) return;
    _ref.read(fcmNavProvider.notifier).set(
      FcmNavIntent(type: type, testimonyId: testimonyId),
    );
  }

  // ── Delta sync + provider refresh ────────────────────────────────────────

  Future<void> _deltaSync() async {
    try {
      final userId = _ref.read(currentUserProvider)?.id;
      await _ref.read(syncServiceProvider).deltaSync(userId: userId);
      _ref.invalidate(feedNotifierProvider);
      _ref.invalidate(notificationsNotifierProvider);
    } catch (_) {}
  }

  // ── FCM token registration ────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _sendToken(token);
    } catch (_) {}
  }

  Future<void> _sendToken(String token) async {
    try {
      await _ref.read(apiServiceProvider).post<void>(
        AppConstants.registerFcmToken,
        data: {
          'token':    token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
    } catch (_) {}
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));
