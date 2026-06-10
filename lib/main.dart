import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/local_db/database_service.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'features/auth/providers/auth_notifier.dart'
    show AuthStateAuthenticated, authStateProvider, currentUserProvider;
import 'features/home/providers/home_providers.dart' show feedNotifierProvider;
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/database_seed_service.dart';
import 'services/fcm_service.dart';
import 'services/sync_service.dart';

// ── FCM background handler ────────────────────────────────────────────────────
//
// Must be a top-level function. Called when a data message arrives while the
// app is killed or in background. No Riverpod/Navigator available here.
// The next foreground open triggers a full deltaSync.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background FCM handler before any other Firebase call.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final db = DatabaseService();
  try {
    await DatabaseSeedService(db).seedIfEmpty();
  } catch (e) {
    debugPrint('DB seed skipped: $e');
  }

  runApp(const ProviderScope(child: TemoignagesApp()));
}

// ── Root widget ───────────────────────────────────────────────────────────────

class TemoignagesApp extends ConsumerStatefulWidget {
  const TemoignagesApp({super.key});

  @override
  ConsumerState<TemoignagesApp> createState() => _TemoignagesAppState();
}

class _TemoignagesAppState extends ConsumerState<TemoignagesApp>
    with WidgetsBindingObserver {

  Timer? _pollTimer;
  bool   _fcmInitialized = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerSync();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    switch (appState) {
      case AppLifecycleState.resumed:
        _triggerSync();
        _startPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopPolling();
    }
  }

  // ── Polling (30 s foreground refresh) ────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _triggerSync();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _triggerSync() {
    unawaited(() async {
      try {
        final userId = ref.read(currentUserProvider)?.id;
        await ref.read(syncServiceProvider).deltaSync(userId: userId);
        // Refresh feed UI after sync completes.
        await ref.read(feedNotifierProvider.notifier).refresh();
      } catch (_) {}
    }());
  }

  // ── FCM init (once, after first successful auth) ──────────────────────────

  void _maybeInitFcm() {
    if (_fcmInitialized) return;
    _fcmInitialized = true;
    unawaited(ref.read(fcmServiceProvider).init());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);

    // Init FCM as soon as the user is authenticated.
    ref.listen(authStateProvider, (_, next) {
      if (next.value is AuthStateAuthenticated) _maybeInitFcm();
    });

    // Handle notification taps → navigate to the right screen.
    ref.listen(fcmNavProvider, (_, intent) {
      if (intent == null) return;
      _handleFcmNavigation(router, intent);
      ref.read(fcmNavProvider.notifier).clear();
    });

    return MaterialApp.router(
      title: 'Témoignages',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _AppScrollBehavior(),
    );
  }

  // ── FCM navigation routing ────────────────────────────────────────────────

  void _handleFcmNavigation(GoRouter router, FcmNavIntent intent) {
    final testimonyId = intent.testimonyId;
    switch (intent.type) {
      case 'comment':
      case 'reply':
      case 'mention':
      case 'like':
      case 'prayer':
        if (testimonyId != null) {
          router.pushNamed(
            AppRoutes.testimonyDetail,
            pathParameters: {'id': testimonyId},
          );
        } else {
          router.pushNamed(AppRoutes.notifications);
        }
      case 'testimony_approved':
      case 'testimony_rejected':
      case 'pending_correction':
        router.pushNamed(AppRoutes.notifications);
      default:
        router.pushNamed(AppRoutes.notifications);
    }
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B21A8),
        primary:   const Color(0xFF6B21A8),
        secondary: const Color(0xFFF59E0B),
        surface:   const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      dividerColor: const Color(0xFFE2E8F0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        indicatorColor: const Color(0xFF6B21A8).withAlpha(30),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B21A8),
            );
          }
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF64748B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF6B21A8));
          }
          return const IconThemeData(color: Color(0xFF64748B));
        }),
      ),
    );
  }
}

// ── Scroll behavior ───────────────────────────────────────────────────────────

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
