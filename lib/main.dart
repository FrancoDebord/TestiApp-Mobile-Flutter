import 'core/media/media_http.dart';
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
import 'features/accounts/account_session.dart' show rootScaffoldMessengerKey;
import 'features/auth/providers/auth_notifier.dart'
    show AuthStateAuthenticated, authStateProvider, currentUserProvider;
import 'features/downloads/providers/downloads_provider.dart'
    show downloadsProvider;
import 'features/daily_verse/screens/daily_verse_screen.dart' show openDailyVerse;
import 'features/home/providers/home_providers.dart' show feedNotifierProvider;
import 'features/prophecies/data/prophecy_reminders.dart';
import 'firebase_options.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart' show AppFonts;
import 'features/daily_verse/design/verse_style_prefs.dart'
    show currentVerseDesignProvider, verseStylePrefsProvider;
import 'features/publish/upload/video_upload_controller.dart' show videoUploadProvider;
import 'l10n/app_localizations.dart';
import 'services/database_seed_service.dart';
import 'services/push_service.dart';
import 'features/testimony/providers/testimony_refresh.dart'
    show kVideoPushTypes, rememberVideoPush, testimonyReloaderProvider;
import 'services/sync_service.dart';

// ── FCM background handler ────────────────────────────────────────────────────
//
// Must be a top-level function. Called when a data message arrives while the
// app is killed or in background. No Riverpod/Navigator available here.
// The next foreground open triggers a full deltaSync.
// Parole prophétique modifiée ailleurs : le rappel local est reprogrammé ici,
// depuis le réglage contenu dans le message (aucun appel réseau).
// Vidéo prête ou en échec : le témoignage est noté, puis rechargé au retour
// au premier plan (TestimonyReloader.reloadPending).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ProphecyReminders.handlePush(message.data, background: true);
  await rememberVideoPush(message.data);
}

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Médias : ancien domaine redirigé, Referer exigé par Bunny (lib/core/media/media_http.dart).
  MediaHttpOverrides.install();
  // Noms de mois / jours FR et EN (dates formatées selon la langue).
  await initLocaleFormatting();

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

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerSync();
    _startPolling();
    // Notifications push : l'appareil est enregistré à chaque passage à l'état « connecté »
    // (démarrage avec une session, connexion e-mail, Google, téléphone, inscription).
    // fireImmediately : session déjà restaurée avant l'abonnement.
    ref.listenManual(authStateProvider, (prev, next) {
      final wasSignedIn = prev?.value is AuthStateAuthenticated;
      if (next.value is AuthStateAuthenticated && !wasSignedIn) _onSignedIn();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Langue du téléphone modifiée : « Langue du système » suit le changement.
  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.invalidate(systemLocalesProvider);
    if (ref.read(appLanguageProvider) == AppLanguage.system) {
      unawaited(syncLocaleToServer(ref.read));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    switch (appState) {
      case AppLifecycleState.resumed:
        // Nouveau jour : nouveau design du verset (sauf choix de l'utilisateur).
        ref.invalidate(currentVerseDesignProvider);
        // Vidéos prêtes ou en échec pendant que l'application était en arrière-plan.
        unawaited(ref.read(testimonyReloaderProvider).reloadPending());
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

  // ── Notifications push (FCM) ──────────────────────────────────────────────

  /// Connexion réussie ou session restaurée : autorisation et écoute (une fois), puis
  /// enregistrement du jeton de l'appareil pour ce compte. Jamais bloquant.
  void _onSignedIn() {
    final push = ref.read(pushServiceProvider);
    unawaited(() async {
      await push.init();
      await push.registerDevice();
    }());
    // Préférences du verset : créées maintenant pour se synchroniser avec le
    // serveur (changement en attente envoyé, sinon valeurs du serveur).
    ref.read(verseStylePrefsProvider);
    // Langue des notifications et e-mails : celle de l'application.
    unawaited(syncLocaleToServer(ref.read));
    // Envoi de vidéo interrompu par la fermeture de l'application : reprise.
    unawaited(ref.read(videoUploadProvider.notifier).restorePending());
    // Push vidéo reçus application fermée : témoignages rechargés.
    unawaited(ref.read(testimonyReloaderProvider).reloadPending());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    // Charge l'index des téléchargements dès le démarrage (lecture hors ligne).
    ref.watch(downloadsProvider);

    // Handle notification taps → navigate to the right screen.
    // App lancée par le toucher : attendre que le routeur ait quitté le splash
    // (sinon la page s'empilerait sur le splash, remplacé ensuite par l'accueil).
    ref.listen(fcmNavProvider, (_, intent) {
      if (intent == null) return;
      ref.read(fcmNavProvider.notifier).clear();
      _whenPastSplash(router, () => _handleFcmNavigation(router, intent));
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.commonAppName,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
      locale: locale,
      supportedLocales: L10n.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _AppScrollBehavior(),
      // Messages hors écran (ex. retour automatique sur son compte).
      scaffoldMessengerKey: rootScaffoldMessengerKey,
    );
  }

  // ── FCM navigation routing ────────────────────────────────────────────────

  /// Exécute [action] dès que l'écran courant n'est plus le splash.
  void _whenPastSplash(GoRouter router, VoidCallback action) {
    bool onSplash() =>
        router.routerDelegate.currentConfiguration.uri.path == AppPaths.splash;
    if (!onSplash()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
      return;
    }
    late VoidCallback listener;
    listener = () {
      if (onSplash()) return;
      router.routerDelegate.removeListener(listener);
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
    };
    router.routerDelegate.addListener(listener);
  }

  void _handleFcmNavigation(GoRouter router, FcmNavIntent intent) {
    final testimonyId = intent.testimonyId;
    switch (intent.type) {
      // Mention hors témoignage (fonctionnalites/mentions.md) : message de prière ou direct.
      case 'mention' when testimonyId == null && intent.prayerRequestId != null:
        router.push('/prayer-requests/${intent.prayerRequestId}');
      case 'mention' when testimonyId == null && intent.liveId != null:
        router.push('/lives/${intent.liveId}');
      // Événements (docs serveur fonctionnalites/evenements.md) : reporté, annulé,
      // sondage d'après l'événement, mention dans un commentaire d'événement.
      case 'mention' when testimonyId == null && intent.eventId != null:
        router.push('/events/${intent.eventId}');
      // Mention sous le verset du jour : page du verset, onglet Commentaires.
      case 'mention' when testimonyId == null && intent.dailyVerseId != null:
        final ctx = router.routerDelegate.navigatorKey.currentContext;
        if (ctx != null) {
          openDailyVerse(ctx, initialTab: 1);
        } else {
          router.pushNamed(AppRoutes.notifications);
        }
      // Nouvel abonné : son profil.
      case 'follow':
        final actorId = intent.actorId;
        if (actorId != null) {
          router.push('/users/$actorId');
        } else {
          router.pushNamed(AppRoutes.notifications);
        }
      case 'event_postponed':
      case 'event_cancelled':
      case 'event_survey':
        final eventId = intent.eventId;
        router.push(eventId != null ? '/events/$eventId' : '/events');
      case 'comment':
      case 'reply':
      case 'mention':
      case 'like':
      case 'prayer':
      // Partage d'un de mes témoignages, nouveau témoignage d'un compte suivi.
      case 'share':
      case 'new_followed_testimony':
      // Mon témoignage vidéo est en ligne (Bunny Stream), ou son encodage a
      // échoué : rechargé partout, puis ouvert (« Renvoyer la vidéo » si échec).
      case 'video_ready':
      case 'video_failed':
        if (kVideoPushTypes.contains(intent.type)) {
          ref.read(pushServiceProvider)
              .refreshFor(intent.type, testimonyId: testimonyId);
        }
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
      // Rappel de prière (notification locale) : la parole prophétique.
      case 'prophecy_reminder':
        final prophecyId = intent.prophecyId;
        router.push(prophecyId != null ? '/prophecies/$prophecyId' : '/prophecies');
      // Requêtes et sessions de prière (docs serveur fonctionnalites/sessions-de-priere.md).
      case 'prayer_encouragement':
      // « Je prie » sur une de mes requêtes : la requête concernée.
      case 'prayer_request_prayed':
      // Notification générique d'une requête de prière (`type: prayer_request`, `id`).
      case 'prayer_request':
        final requestId = intent.prayerRequestId;
        router.push(requestId != null ? '/prayer-requests/$requestId' : '/prayer-requests');
      case 'prayer_session_started':
      case 'prayer_session_reminder':
        final sessionId = intent.prayerSessionId;
        router.push(sessionId != null ? '/prayer-sessions/$sessionId' : '/prayer-sessions');
      // Administrateurs de compte : écran des comptes que j'administre.
      case 'account_manager_added':
      case 'account_manager_removed':
        router.push('/managers');
      // Témoignage publié : on l'ouvre. Refusé : « Mes publications » (motif,
      // « Modifier et renvoyer »). docs serveur fonctionnalites/gestion-des-temoignages.md
      case 'testimony_approved':
        ref.read(pushServiceProvider).refreshFor(intent.type);
        if (testimonyId != null) {
          router.pushNamed(AppRoutes.testimonyDetail, pathParameters: {'id': testimonyId});
        } else {
          router.push('${AppPaths.profilePath}/my-testimonies');
        }
      case 'testimony_rejected':
        ref.read(pushServiceProvider).refreshFor(intent.type);
        router.push('${AppPaths.profilePath}/my-testimonies');
      // Modérateurs : témoignage modifié par son auteur et renvoyé en modération.
      case 'testimony_resubmitted':
        router.push(AppPaths.moderation);
      // Badge « Approuvé » attribué ou retiré (docs serveur fonctionnalites/badge-approuve.md).
      case 'account_verified':
      case 'organization_verified':
      case 'organization_rejected':
      case 'account_approval_revoked':
        ref.read(pushServiceProvider).refreshFor(intent.type);
        router.go(AppPaths.profilePath);
      case 'account_verification_rejected':
        ref.read(pushServiceProvider).refreshFor(intent.type);
        router.go(AppPaths.profilePath);
        router.pushNamed(AppRoutes.accountVerification);
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
      colorScheme: appColorScheme(),
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
      // Puces (filtres : Événements, catégories…) : texte en bleu de la charte. Sans couleur
      // explicite, le libellé héritait d'un blanc illisible sur fond clair.
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        checkmarkColor: AppColors.primary,
        iconTheme: IconThemeData(color: AppColors.primary, size: 16),
        labelStyle: TextStyle(
            fontFamily: AppFonts.family, fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
        secondaryLabelStyle: TextStyle(
            fontFamily: AppFonts.family, fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
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
