// Designs du verset : catalogue serveur, design affiché (serveur → secours
// local) et synchronisation des préférences avec GET · PUT /me/verse-style.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/daily_verse/design/verse_design.dart';
import 'package:testi_app/features/daily_verse/design/verse_design_catalog.dart';
import 'package:testi_app/features/daily_verse/design/verse_style_prefs.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/models/models.dart';

const _me = UserModel(id: 'me', displayName: 'Awa Kossou');

class _Auth extends AuthNotifier {
  _Auth(this.initial);
  final AuthState initial;

  @override
  Future<AuthState> build() async => initial;

  void signOut() => state = const AsyncData(AuthStateUnauthenticated());
}

class _Verse extends DailyVerseNotifier {
  _Verse(this.verse);
  final DailyVerse verse;

  @override
  Future<DailyVerse> build() async => verse;
}

/// API simulée : catalogue, préférences du membre, PUT enregistrés.
class _Api implements ApiService {
  Map<String, dynamic> serverStyle = {
    'design_id': 'encre',
    'design_chosen_on': null,
    'design_always': true,
    'font': 'inter',
    'text_size': 'large',
    'text_align': 'center',
  };
  final puts = <Map<String, dynamic>>[];
  int gets = 0;
  Object? putError;

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (path == AppConstants.myVerseStyle) {
      gets++;
      return LaravelResponse<T>(success: true, data: Map<String, dynamic>.from(serverStyle) as T);
    }
    if (path == AppConstants.verseDesigns) {
      return LaravelResponse<T>(success: true, data: <String, dynamic>{
        'designs': [
          {'id': 'or', 'name': 'Or doux', 'mood': 'warm', 'order': 3},
          {'id': 'futur', 'name': 'Inconnu de l’app', 'mood': 'deep', 'order': 1},
          {'id': 'aube', 'name': 'Aube', 'mood': 'dawn', 'order': 2},
        ],
      } as T);
    }
    throw StateError('GET $path');
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data}) async {
    if (putError != null) throw putError!;
    puts.add(Map<String, dynamic>.from(data as Map));
    serverStyle = {...serverStyle, ...puts.last};
    return LaravelResponse<T>(success: true, data: serverStyle as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

DailyVerse _verse({Map<String, dynamic>? userStyle, String? effective, String day = 'nuit'}) => DailyVerse(
      id: 7,
      text: 'Béni soit l’homme qui se confie dans l’Éternel.',
      reference: 'Jérémie 17:7',
      designOfTheDay: day,
      effectiveDesignId: effective ?? day,
      userStyle: userStyle,
    );

ProviderContainer _container(_Api api, {AuthState auth = const AuthStateAuthenticated(_me), DailyVerse? verse}) {
  final c = ProviderContainer(overrides: [
    apiServiceProvider.overrideWithValue(api),
    authStateProvider.overrideWith(() => _Auth(auth)),
    dailyVerseProvider.overrideWith(() => _Verse(verse ?? _verse())),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Laisse se terminer chargement, synchronisation et envoi différé.
Future<void> _settle([Duration d = const Duration(milliseconds: 50)]) => Future<void>.delayed(d);

Future<VerseStylePrefs> _start(ProviderContainer c) async {
  await c.read(authStateProvider.future);
  c.listen(verseStylePrefsProvider, (_, _) {});
  await _settle();
  return c.read(verseStylePrefsProvider);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Catalogue GET /verse-designs', () {
    test('trié par « order », ids inconnus de l’app ignorés', () {
      final catalog = VerseDesignCatalog.fromJson({
        'designs': [
          {'id': 'or', 'order': 3},
          {'id': 'futur', 'order': 1},
          {'id': 'aube', 'order': 2},
        ],
      });
      expect(catalog.ids, ['futur', 'aube', 'or']);
      expect(catalog.resolve().map((d) => d.id), ['aube', 'or']);
    });

    test('mis en cache 24 h, sinon tous les designs de l’app', () async {
      final api = _Api();
      final c = _container(api);
      expect(c.read(availableVerseDesignsProvider), kVerseDesigns);
      await c.read(verseDesignCatalogProvider.future);
      expect(c.read(availableVerseDesignsProvider).map((d) => d.id), ['aube', 'or']);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('verse_designs_catalog'), isNotNull);
      expect(p.getString('verse_designs_catalog_at'), isNotNull);
    });
  });

  group('Design affiché', () {
    final now = DateTime.utc(2026, 10, 13, 9);
    const today = '2026-10-13';

    test('choix du jour > design du serveur > secours local', () {
      const none = VerseStylePrefs();
      expect(none.resolveDesign(now: now, serverDesignId: 'or').id, 'or');
      // Id inconnu de l'app : design du jour calculé localement.
      expect(none.resolveDesign(now: now, serverDesignId: 'futur').id, dailyVerseDesign(verseDay(now)).id);
      expect(none.resolveDesign(now: now).id, dailyVerseDesign(verseDay(now)).id);

      const mine = VerseStylePrefs(designId: 'encre', chosenOn: today);
      expect(mine.resolveDesign(now: now, serverDesignId: 'or').id, 'encre');
      // Choix d'hier : retour au design du serveur.
      const old = VerseStylePrefs(designId: 'encre', chosenOn: '2026-10-12');
      expect(old.resolveDesign(now: now, serverDesignId: 'or').id, 'or');
      // Design retiré du catalogue : ignoré.
      expect(
        mine.resolveDesign(now: now, serverDesignId: 'or', available: [verseDesignById('or')!]).id,
        'or',
      );
    });

    test('jour du verset : date de Porto-Novo (UTC+1)', () {
      expect(verseDay(DateTime.utc(2026, 10, 13, 23, 30)), DateTime(2026, 10, 14));
      expect(verseDay(DateTime.utc(2026, 10, 13, 22, 59)), DateTime(2026, 10, 13));
    });

    test('visiteur : design_of_the_day, jamais l’effective d’un autre compte', () async {
      final c = _container(_Api(),
          auth: const AuthStateUnauthenticated(), verse: _verse(effective: 'encre', day: 'or'));
      await c.read(dailyVerseProvider.future);
      await c.read(authStateProvider.future);
      expect(c.read(serverVerseDesignIdProvider), 'or');
    });
  });

  group('Préférences ⇄ serveur', () {
    test('API : noms d’enum, valeur inconnue → défaut', () {
      final p = VerseStylePrefs.fromApiJson({
        'design_id': 'or',
        'design_chosen_on': '2026-10-13',
        'design_always': false,
        'font': 'sourceSerif',
        'text_size': 'small',
        'text_align': 'diagonal',
      });
      expect(p.font, VerseFont.sourceSerif);
      expect(p.size, VerseTextSize.small);
      expect(p.align, VerseAlign.start);
      expect(p.toApiJson(), {
        'design_id': 'or',
        'design_chosen_on': '2026-10-13',
        'design_always': false,
        'font': 'sourceSerif',
        'text_size': 'small',
        'text_align': 'start',
      });
    });

    test('démarrage connecté : user_style du verset prioritaire sur le local', () async {
      SharedPreferences.setMockInitialValues({'verse_font': 'lora', 'verse_design_id': 'aube'});
      final api = _Api();
      final c = _container(api, verse: _verse(userStyle: api.serverStyle));
      final prefs = await _start(c);
      expect(prefs.designId, 'encre');
      expect(prefs.font, VerseFont.inter);
      expect(prefs.alwaysMine, isTrue);
      expect(api.gets, 0, reason: 'user_style déjà reçu avec le verset');
      final p = await SharedPreferences.getInstance();
      expect(p.getString('verse_font'), 'inter');
      expect(p.getString('verse_design_id'), 'encre');
    });

    test('sans user_style dans le verset : GET /me/verse-style', () async {
      final api = _Api();
      final c = _container(api);
      final prefs = await _start(c);
      expect(api.gets, 1);
      expect(prefs.size, VerseTextSize.large);
    });

    test('changements rapides : affichage immédiat, un seul PUT après 1 s', () async {
      final api = _Api();
      final c = _container(api, verse: _verse(userStyle: api.serverStyle));
      await _start(c);
      final n = c.read(verseStylePrefsProvider.notifier);
      n.setFont(VerseFont.nunitoSans);
      n.setSize(VerseTextSize.small);
      n.chooseDesign(verseDesignById('aube')!);
      expect(c.read(verseStylePrefsProvider).font, VerseFont.nunitoSans);
      expect(c.read(currentVerseDesignProvider).id, 'aube');
      expect(api.puts, isEmpty);
      await _settle(const Duration(milliseconds: 1300));
      expect(api.puts, hasLength(1));
      expect(api.puts.single['font'], 'nunitoSans');
      expect(api.puts.single['text_size'], 'small');
      expect(api.puts.single['design_id'], 'aube');
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('verse_style_pending_sync'), isNull);
    });

    test('échec réseau : choix local gardé, envoyé au prochain lancement', () async {
      final api = _Api()..putError = Exception('hors connexion');
      final c = _container(api, verse: _verse(userStyle: api.serverStyle));
      await _start(c);
      c.read(verseStylePrefsProvider.notifier).setAlign(VerseAlign.start);
      await _settle(const Duration(milliseconds: 1300));
      expect(c.read(verseStylePrefsProvider).align, VerseAlign.start);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool('verse_style_pending_sync'), isTrue);
      expect(p.getString('verse_text_align'), 'start');

      // Prochain lancement : le choix local part d'abord, le serveur ne l'écrase pas.
      final api2 = _Api();
      final c2 = _container(api2, verse: _verse(userStyle: api2.serverStyle));
      final prefs = await _start(c2);
      expect(api2.puts, hasLength(1));
      expect(api2.puts.single['text_align'], 'start');
      expect(prefs.align, VerseAlign.start);
      expect(p.getBool('verse_style_pending_sync'), isNull);
    });

    test('valeur refusée (422) : on reprend celles du serveur', () async {
      final api = _Api();
      final c = _container(api, verse: _verse(userStyle: api.serverStyle));
      await _start(c);
      api.putError = const LaravelApiException(message: 'Design inconnu.', statusCode: 422);
      c.read(verseStylePrefsProvider.notifier).setFont(VerseFont.lora);
      await _settle(const Duration(milliseconds: 1300));
      expect(c.read(verseStylePrefsProvider).font, VerseFont.inter);
    });

    test('visiteur : local uniquement, aucun appel', () async {
      final api = _Api();
      final c = _container(api, auth: const AuthStateUnauthenticated());
      await _start(c);
      c.read(verseStylePrefsProvider.notifier).setFont(VerseFont.inter);
      await _settle(const Duration(milliseconds: 1300));
      expect(api.puts, isEmpty);
      expect(api.gets, 0);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('verse_font'), 'inter');
    });

    test('déconnexion : préférences locales effacées', () async {
      final api = _Api();
      final c = _container(api, verse: _verse(userStyle: api.serverStyle));
      await _start(c);
      (c.read(authStateProvider.notifier) as _Auth).signOut();
      await _settle();
      expect(c.read(verseStylePrefsProvider), const VerseStylePrefs());
      final p = await SharedPreferences.getInstance();
      expect(p.getKeys().where((k) => k.startsWith('verse_') && !k.startsWith('verse_designs_catalog')), isEmpty);
    });
  });
}
