// Vérifie que l'écran « Partager un témoignage » et le formulaire de
// publication (3 étapes, 3 formats) ne débordent pas sur un petit écran, avec
// une grande taille de police et des textes longs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';
import 'package:testi_app/features/publish/screens/publish_preview_screen.dart';
import 'package:testi_app/features/publish/screens/publish_screen.dart';
import 'package:testi_app/shared/models/user_model.dart';

const _admin = UserModel(
  id: 'u1',
  displayName: 'Administrateur',
  role: UserRole.administrateur,
);

const _categories = [
  CategoryModel(
      id: 'c1',
      name: 'Protection divine et délivrance des familles',
      slug: 'protection'),
  CategoryModel(id: 'c2', name: 'Guérison', slug: 'guerison'),
];

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

PublishDraft _draft(TestimonyFormat format,
        {TestimonyVisibility visibility = TestimonyVisibility.public}) =>
    PublishDraft(
      format: format,
      title: 'Un très long titre de témoignage pour vérifier le retour',
      category: 'protection',
      bodyText: 'Dieu a changé ma vie. ' * 20,
      proofs: const {
        1: ProofAttachment(
          path: '/tmp/preuve.pdf',
          name:
              'certificat_medical_de_guerison_complete_hopital_central_2026.pdf',
          size: 2 * 1024 * 1024,
        ),
      },
      visibility: visibility,
    );

Widget _app(
  Widget child, {
  double textScale = 1.0,
  PublishDraft? draft,
  int step = 1,
}) =>
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_admin),
        categoriesListProvider.overrideWithValue(_categories),
        if (draft != null) publishProvider.overrideWith(() => _Draft(draft)),
        publishStepProvider.overrideWith(() => _Step(step)),
      ],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

Future<void> _setPhone(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('entrée « Publier » sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const PublishScreen(), textScale: scale));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Partager un témoignage'), findsOneWidget);
        expect(find.text('Enregistrer une vidéo'), findsOneWidget);
        expect(find.text('Enregistrer un audio'), findsOneWidget);
        expect(find.text('Écrire un texte'), findsOneWidget);
        expect(find.text('Importer une image / document'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Lien YouTube'), 200);
        expect(find.text('Short Témoignage'), findsOneWidget);
        expect(find.text('Carnet privé'), findsOneWidget);
        expect(find.text('Live'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('formulaire de publication sans débordement '
          '($width px, ×$scale)', (tester) async {
        await _setPhone(tester, width);
        for (final format in TestimonyFormat.values) {
          for (final step in [1, 2, 3]) {
            for (final visibility in [
              TestimonyVisibility.public,
              TestimonyVisibility.private,
            ]) {
              if (visibility == TestimonyVisibility.private && step == 2) {
                continue;
              }
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(_app(
                const PublishPreviewScreen(),
                textScale: scale,
                draft: _draft(format, visibility: visibility),
                step: step,
              ));
              await tester.pump(const Duration(milliseconds: 400));
              expect(tester.takeException(), isNull,
                  reason: '$format, étape $step, $visibility');
            }
          }
        }
      });
    }
  }

  testWidgets('étape 1 : champs de la maquette et bouton Publier',
      (tester) async {
    await _setPhone(tester, 390);
    await tester.pumpWidget(_app(
      const PublishPreviewScreen(),
      draft: _draft(TestimonyFormat.text),
    ));
    await tester.pump();
    expect(find.text('Titre (optionnel)'), findsOneWidget);
    expect(find.text('Ex : Dieu a changé ma vie'), findsOneWidget);
    expect(find.textContaining('Description'), findsOneWidget);
    expect(find.textContaining('Catégorie'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(
      const PublishPreviewScreen(),
      draft: _draft(TestimonyFormat.text),
      step: 3,
    ));
    await tester.pump();
    expect(find.text('Publier'), findsOneWidget);
  });

  test('titre facultatif : repli sur la description', () {
    expect(
      PublishDraft(format: TestimonyFormat.text, bodyText: 'Guéri !\nSuite')
          .effectiveTitle,
      'Guéri !',
    );
    expect(PublishDraft(format: TestimonyFormat.video).effectiveTitle,
        'Mon témoignage');
    expect(PublishDraft(title: ' Mon titre ').effectiveTitle, 'Mon titre');
  });
}
