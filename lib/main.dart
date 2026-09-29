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
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart' show AppFonts;
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
  // Seed runs in background — does not block the first frame.
  unawaited(DatabaseSeedService(db).seedIfEmpty().catchError(
    (Object e) => debugPrint('DB seed skipped: $e'),
  ));

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
      case 'live_started':
        final liveId = intent.liveId;
        if (liveId != null) {
          router.push('/lives/$liveId');
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

  /// Thème de la charte ARISE & SHINE Krea (même palette que le site).
  ThemeData _buildTheme() {
    const radius10 = BorderRadius.all(Radius.circular(10));
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: c, width: w));
    const buttonText = TextStyle(fontFamily: AppFonts.family, fontSize: 15, fontWeight: FontWeight.w600);
    const buttonShape = RoundedRectangleBorder(borderRadius: radius10);
    const buttonSize = Size(64, 48);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.family,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary:   AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        tertiary:  AppColors.sun,
        onTertiary: AppColors.primaryDark,
        error:     AppColors.danger,
        surface:   AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline:   AppColors.inputBorder,
        outlineVariant: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.family, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
      ),
      // Cartes : blanches, bordure fine, 16 px, ombre très légère.
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      // Boutons : 48 px, 10 px d'arrondi, 15 px / 600.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          minimumSize: buttonSize, padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape, textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
          minimumSize: buttonSize, padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape, textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary),
          minimumSize: buttonSize, padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape, textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary, shape: buttonShape, textStyle: buttonText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
      // Champs : 48 px, bordure #D0D5DD, focus bleu, erreur rouge.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(AppColors.inputBorder),
        enabledBorder: border(AppColors.inputBorder),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.5),
        hintStyle: const TextStyle(fontFamily: AppFonts.family, color: AppColors.textSecondary),
      ),
      // Étiquettes : pilule, fond bleu clair une fois choisies.
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
        selectedColor: AppColors.primarySoft,
        labelStyle: TextStyle(fontFamily: AppFonts.family, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 12,
            color: AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondary);
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
