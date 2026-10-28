// Alignement sur le serveur du 2026-10-27 / 28 :
// - référencement : publicationWeb, isAnonymous, resume, transcription
//   (docs serveur fonctionnalites/referencement.md) ;
// - verset du jour dans la langue de l'application (verset-du-jour.md) ;
// - langue du système par défaut ; liens https:// nus comme sur le site.

import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';
import 'package:testi_app/features/publish/screens/publish_preview_screen.dart';
import 'package:testi_app/features/publish/upload/video_resend.dart';
import 'package:testi_app/features/testimony/widgets/testimony_web_publication_card.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/utils/rich_text_utils.dart';

class _Draft extends PublishNotifier {
  _Draft(this.initial);
  final PublishDraft initial;

  @override
  PublishDraft build() => initial;
}

class _Step extends PublishStepNotifier {
  _Step(this.initial);
  final int initial;

  @override
  int build() => initial;
}

/// PUT /testimonies/{id}/web : renvoie l'état demandé, ou échoue.
class _WebApi implements ApiService {
  _WebApi({this.fail = false});
  final bool fail;
  final puts = <(String, Object?)>[];

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data, Options? options}) async {
    puts.add((path, data));
    if (fail) throw const LaravelApiException(message: '', statusCode: 500);
    final d = Map<String, dynamic>.from(data as Map);
    return LaravelResponse<T>(success: true, data: <String, dynamic>{
      'publicationWeb': d['publicationWeb'] ?? true,
      'isAnonymous': d['isAnonymous'] ?? false,
      'visibility': 'public',
    } as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('publication sur le web', () {
    test('public : accord donné par défaut, non anonyme', () {
      final f = webPublicationFields(PublishDraft(), TestimonyFormat.text);
      expect(f, {'publicationWeb': true, 'isAnonymous': false});
    });

    test('abonnés ou carnet : jamais sur le site', () {
      for (final v in [TestimonyVisibility.friends, TestimonyVisibility.private]) {
        final f = webPublicationFields(
            PublishDraft(visibility: v, isAnonymous: true), TestimonyFormat.text);
        expect(f['publicationWeb'], isFalse);
        expect(f['isAnonymous'], isFalse);
      }
    });

    test('audio : résumé, et la description sert de transcription', () {
      final f = webPublicationFields(
        PublishDraft(resume: ' Guéri en une nuit. ', audioTranscript: 'Bonjour à tous…'),
        TestimonyFormat.audio,
      );
      expect(f['resume'], 'Guéri en une nuit.');
      expect(f['transcription'], 'Bonjour à tous…');
    });

    test('vidéo : transcription saisie ; texte : ni résumé ni transcription', () {
      final d = PublishDraft(resume: 'Résumé', transcription: 'Mot pour mot');
      expect(webPublicationFields(d, TestimonyFormat.video)['transcription'], 'Mot pour mot');
      final text = webPublicationFields(d, TestimonyFormat.text);
      expect(text.containsKey('resume'), isFalse);
      expect(text.containsKey('transcription'), isFalse);
    });

    test('brouillon : champs gardés ; ancien brouillon → accord donné', () {
      final d = PublishDraft(publicationWeb: false, isAnonymous: true, resume: 'R', transcription: 'T');
      final back = PublishDraft.fromDraftJson(d.toDraftJson());
      expect(back.publicationWeb, isFalse);
      expect(back.isAnonymous, isTrue);
      expect(back.resume, 'R');
      expect(back.transcription, 'T');
      expect(PublishDraft.fromDraftJson(const {}).publicationWeb, isTrue);
    });

    test('« Renvoyer la vidéo » garde les champs web', () {
      final body = resendBodyFromTestimonyJson({
        'title': 'Guéri',
        'publicationWeb': false,
        'isAnonymous': true,
        'resume': 'Résumé',
        'transcription': 'Texte',
      });
      expect(body['publicationWeb'], isFalse);
      expect(body['isAnonymous'], isTrue);
      expect(body['resume'], 'Résumé');
      expect(body['transcription'], 'Texte');
    });

    Widget step3(TestimonyVisibility v) => ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(const UserModel(id: 'u1', displayName: 'Marie')),
            categoriesListProvider.overrideWithValue(const [CategoryModel(id: 'c', name: 'Guérison', slug: 'guerison')]),
            publishProvider.overrideWith(() => _Draft(PublishDraft(
                  format: TestimonyFormat.text,
                  category: 'guerison',
                  bodyText: 'Merci Seigneur',
                  visibility: v,
                ))),
            publishStepProvider.overrideWith(() => _Step(3)),
          ],
          child: const MaterialApp(home: PublishPreviewScreen()),
        );

    testWidgets('étape 3 : « Publier aussi sur le web » coché, puis anonymat', (tester) async {
      tester.view.physicalSize = const Size(780, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(step3(TestimonyVisibility.public));
      await tester.pump();
      final sw = find.byKey(const ValueKey('publish-web-switch'));
      expect(tester.widget<SwitchListTile>(sw).value, isTrue);
      expect(find.byKey(const ValueKey('publish-web-anonymous')), findsOneWidget);

      await tester.tap(sw);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      expect(find.byKey(const ValueKey('publish-web-anonymous')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(step3(TestimonyVisibility.friends));
      await tester.pump();
      expect(find.byKey(const ValueKey('publish-web-switch')), findsNothing);
    });
  });

  group('verset du jour', () {
    test('champs de langue lus et gardés par copyWith', () {
      final v = DailyVerse.fromJson({
        'id': 3,
        'verseText': 'For God so loved the world',
        'reference': 'John 3:16',
        'language': 'en',
        'textTranslation': 'KJV',
        'textTranslationName': 'King James Version',
        'originalText': 'Car Dieu a tant aimé le monde',
        'originalReference': 'Jean 3:16',
      });
      expect(v.isLocalized, isTrue);
      expect(v.text, 'For God so loved the world');
      final c = v.copyWith(likeCount: 2);
      expect(c.textTranslationName, 'King James Version');
      expect(c.originalReference, 'Jean 3:16');
      expect(DailyVerse.fromJson(const {'verseText': 'x', 'reference': 'y'}).isLocalized, isFalse);
    });

    test('verset de secours dans la langue affichée', () {
      final before = L10n.locale;
      addTearDown(() => L10n.locale = before);
      L10n.locale = L10n.en;
      expect(fallbackDailyVerse().reference, 'Jeremiah 29:11');
      L10n.locale = L10n.fr;
      expect(fallbackDailyVerse().reference, 'Jérémie 29 : 11');
    });
  });

  group('langue', () {
    test('langue du système par défaut, choix explicite prioritaire', () {
      const es = [Locale('es', 'ES'), Locale('en', 'US')];
      expect(resolveLanguage(AppLanguage.system, es), L10n.en);
      expect(resolveLanguage(AppLanguage.system, const [Locale('fr', 'BJ')]), L10n.fr);
      expect(resolveLanguage(AppLanguage.fr, es), L10n.fr);
    });
  });

  testWidgets('adresse https:// nue : lien, sans la ponctuation finale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: buildRichBody('Voir https://eglise.org/live. Merci', const TextStyle(fontSize: 14)),
      ),
    ));
    final spans = <TextSpan>[];
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      w.text.visitChildren((s) {
        if (s is TextSpan && s.text != null) spans.add(s);
        return true;
      });
    }
    final link = spans.firstWhere((s) => s.recognizer != null);
    expect(link.text, 'https://eglise.org/live');
  });

  group('« Sur le web » après publication', () {
    test('modèle : champs lus ; absents (serveur ancien) → null', () {
      final w = TestimonyWebPublication.fromJson({'publicationWeb': false, 'isAnonymous': true, 'visibility': 'followers'})!;
      expect(w.publicationWeb, isFalse);
      expect(w.isAnonymous, isTrue);
      expect(w.canBeOnWeb, isFalse);
      expect(TestimonyWebPublication.fromJson(const {}), isNull);
    });

    Widget card(_WebApi api) => ProviderScope(
          overrides: [apiServiceProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: Scaffold(
              body: TestimonyWebPublicationCard(
                testimonyId: 't1',
                initial: TestimonyWebPublication(publicationWeb: true, visibility: 'public'),
              ),
            ),
          ),
        );

    testWidgets('retrait : PUT /testimonies/{id}/web, seulement le champ changé', (tester) async {
      final api = _WebApi();
      await tester.pumpWidget(card(api));
      await tester.tap(find.byKey(const ValueKey('testimony-web-switch')));
      await tester.pumpAndSettle();
      expect(api.puts.single.$1, AppConstants.testimonyWeb('t1'));
      expect(api.puts.single.$2, {'publicationWeb': false});
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('testimony-web-switch'))).value, isFalse);
      expect(find.byKey(const ValueKey('testimony-web-anonymous')), findsNothing);
    });

    testWidgets('échec : l’interrupteur revient à l’état précédent', (tester) async {
      await tester.pumpWidget(card(_WebApi(fail: true)));
      await tester.tap(find.byKey(const ValueKey('testimony-web-switch')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('testimony-web-switch'))).value, isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
