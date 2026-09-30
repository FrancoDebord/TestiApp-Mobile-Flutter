// Mise en page du domaine Profil : profil (membre, organisation, invité),
// paramètres, langue, aide, à propos et notifications — sans débordement sur
// petit écran (320 / 390 px) avec une police agrandie (×1.0 / ×1.3).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/media/playback_preferences.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/notifications/models/notification_models.dart';
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/features/notifications/screens/notifications_screen.dart';
import 'package:testi_app/features/profile/models/profile_models.dart';
import 'package:testi_app/features/profile/providers/profile_provider.dart';
import 'package:testi_app/features/profile/screens/about_screen.dart';
import 'package:testi_app/features/profile/screens/help_screen.dart';
import 'package:testi_app/features/profile/screens/language_screen.dart';
import 'package:testi_app/features/profile/screens/profile_screen.dart';
import 'package:testi_app/features/profile/screens/settings_screen.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart' show isGuestProvider;

const _longName =
    'Ministère International Lumière du Monde pour la Restauration des Nations';

UserModel _user({bool org = false}) => UserModel(
      id: 'u1',
      displayName: _longName,
      role: UserRole.administrateur,
      accountType: org ? AccountType.organization : AccountType.individual,
      organizationName: org ? _longName : null,
      organizationType: org ? OrganizationType.values.first : null,
      organizationCity: org ? 'Brazzaville, République du Congo' : null,
      organizationWebsite:
          org ? 'https://www.un-site-web-tres-long-pour-le-test.org' : null,
      isVerified: !org,
      createdAt: DateTime.now()
          .subtract(const Duration(days: 95))
          .toIso8601String(),
    );

UserProfile _profile() => UserProfile(
      uid: 'u1',
      displayName: _longName,
      country: "République démocratique du Congo, Côte d'Ivoire",
      memberSince: DateTime.now().subtract(const Duration(days: 95)),
      testimonyCount: 123456,
      likeCount: 98765,
      prayerCount: 4321,
      followersCount: 1234567,
      followingCount: 8765,
      bio: 'Une très longue biographie pour vérifier le retour à la ligne '
          'sur les petits écrans avec une grande taille de police.',
      extras: const ProfileExtras(),
    );

List<AppNotification> _notifs() {
  final now = DateTime.now();
  return [
    for (final (i, t) in NotificationType.values.indexed)
      AppNotification(
        id: 'n$i',
        type: t,
        actorName: 'Marie-Christine Nkounkou Mabiala',
        testimonyTitle: 'Un miracle extraordinaire dans ma famille après '
            'des années de prière',
        createdAt: now.subtract(Duration(hours: i * 20)),
        isRead: i.isOdd,
        liveId: t == NotificationType.liveStarted ? 'l1' : null,
      ),
  ];
}

class _FixedLocale extends LocaleNotifier {
  @override
  Locale build() => const Locale('fr');
}

class _Prefs extends PlaybackPreferencesNotifier {
  @override
  PlaybackPreferences build() => const PlaybackPreferences();
}

class _Notifs extends NotificationsNotifier {
  @override
  Future<List<AppNotification>> build() async => _notifs();
}

Widget _app(Widget child,
        {double textScale = 1.0, bool org = false, bool guest = false}) =>
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(_FixedLocale.new),
        playbackPreferencesProvider.overrideWith(_Prefs.new),
        notificationsNotifierProvider.overrideWith(_Notifs.new),
        isGuestProvider.overrideWithValue(guest),
        currentUserProvider.overrideWithValue(guest ? null : _user(org: org)),
        userProfileProvider.overrideWithValue(guest ? null : _profile()),
        myTestimoniesProvider.overrideWithValue(const <Testimony>[]),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

Future<void> _setPhone(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Fait défiler jusqu'en bas pour construire tous les éléments paresseux.
Future<void> _scrollAll(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 12; i++) {
    await tester.drag(scrollables.first, const Offset(0, -400),
        warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final screens = <String, (Widget, bool, bool)>{
    'profil membre': (const ProfileScreen(), false, false),
    'profil organisation': (const ProfileScreen(), true, false),
    'profil invité': (const ProfileScreen(), false, true),
    'paramètres': (const SettingsScreen(), false, false),
    'langue': (const LanguageScreen(), false, false),
    'aide et support': (const HelpScreen(), false, false),
    'à propos': (const AboutScreen(), false, false),
    'notifications': (const NotificationsScreen(), false, false),
  };

  for (final MapEntry(key: name, value: (screen, org, guest))
      in screens.entries) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$name sans débordement ($width px, ×$scale)',
            (tester) async {
          await _setPhone(tester, width);
          await tester.pumpWidget(
              _app(screen, textScale: scale, org: org, guest: guest));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull);
          await _scrollAll(tester);
        });
      }
    }
  }

  testWidgets('notifications : onglets Nouveaux et Populaires filtrent',
      (tester) async {
    await _setPhone(tester, 390);
    await tester.pumpWidget(_app(const NotificationsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Toutes'), findsOneWidget);

    await tester.tap(find.text('Nouveaux'));
    await tester.pumpAndSettle();
    // Seules les non lues (index pair) restent.
    expect(find.text('Nouveau commentaire'), findsOneWidget); // index 0
    expect(find.text('Témoignage populaire'), findsNothing); // index 1, lue

    await tester.tap(find.text('Populaires'));
    await tester.pumpAndSettle();
    expect(find.text('Témoignage populaire'), findsOneWidget);
    expect(find.text('Prière pour vous'), findsOneWidget);
    expect(find.text('Nouveau commentaire'), findsNothing);
  });

  testWidgets('langue : seuls Français et English sont proposés',
      (tester) async {
    await _setPhone(tester, 390);
    await tester.pumpWidget(_app(const LanguageScreen()));
    await tester.pump();
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Lingala'), findsNothing);
    expect(find.text('Changer de langue'), findsOneWidget);
  });

  testWidgets('profil : statistiques et menu de la maquette', (tester) async {
    await _setPhone(tester, 390);
    await tester.pumpWidget(_app(const ProfileScreen()));
    await tester.pump();
    expect(find.text('Témoignages'), findsOneWidget);
    expect(find.text("J'aime"), findsOneWidget);
    expect(find.text('Abonnés'), findsOneWidget);
    expect(find.textContaining('Membre depuis 3 mois'), findsOneWidget);
    expect(find.text('Modifier le profil'), findsOneWidget);
    expect(find.text('Mes téléchargements'), findsOneWidget);
  });

  testWidgets('profil invité : invitation à se connecter', (tester) async {
    await _setPhone(tester, 390);
    await tester.pumpWidget(_app(const ProfileScreen(), guest: true));
    await tester.pump();
    expect(find.text('Vous naviguez en invité'), findsOneWidget);
    expect(find.text('Se connecter / Créer un compte'), findsOneWidget);
    expect(find.text("J'aime"), findsNothing);
  });
}
