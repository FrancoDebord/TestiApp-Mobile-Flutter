// Témoignage écrit riche : liens, images, mise en forme visible pendant la
// saisie, et aperçu avant publication.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';
import 'package:testi_app/features/publish/screens/publish_preview_screen.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/utils/rich_text_utils.dart';
import 'package:testi_app/shared/widgets/rich_mention_editing_controller.dart';

const _img = 'https://temoignage.as-krea.com/storage/media/images/a.jpg';

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

String _rendered(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((w) => w.text.toPlainText())
    .join('\n');

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('syntaxe', () {
    test('stripFormatting : images retirées, liens réduits à leur texte', () {
      const text = 'Voir [mon église](https://eglise.org) ici.\n![]($_img)\nFin **merci**';
      expect(stripFormatting(text), 'Voir mon église ici.\nFin merci');
    });

    test('richBodyImageUrls : seulement les images seules sur leur ligne', () {
      const text = 'Avant\n![photo]($_img)\nLien ![x](https://a.org/b.png) en ligne';
      expect(richBodyImageUrls(text), [_img]);
    });

    test('une mention @[Nom](user:id) n’est pas un lien', () {
      const text = '@[Jean](user:0b0e7f1e-3b3c-4a8e-9a55-111111111111) merci';
      expect(stripFormatting(text), text);
    });
  });

  testWidgets('lecture : lien rendu sans balises, en gras compris', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: buildRichBody(
          'Allez sur **[notre site](https://eglise.org)** pour la suite.',
          const TextStyle(fontSize: 14),
        ),
      ),
    ));
    final text = _rendered(tester);
    expect(text, contains('Allez sur notre site pour la suite.'));
    expect(text, isNot(contains('](')));
  });

  testWidgets('« Lire la suite » ne coupe pas une adresse de lien', (tester) async {
    const text = 'Court début. [un lien vers une page assez longue](https://exemple.org/une/adresse/longue) puis la suite.';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ProgressiveRichText(text: text, style: TextStyle(fontSize: 14), initialChars: 30),
      ),
    ));
    final shown = _rendered(tester);
    expect(shown, isNot(contains('https://')));
    expect(shown, contains('un lien vers une page assez longue'));
  });

  group('saisie avec mise en forme en direct', () {
    TextSpan span(String text, BuildContext context) =>
        RichMentionEditingController(text: text)
            .buildTextSpan(context: context, style: const TextStyle(fontSize: 15), withComposing: false);

    testWidgets('le texte affiché reste identique caractère pour caractère', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }));
      const text = '# Titre\nDu **gras** et __italique__, un [lien](https://a.org).\n> citation\n- point\n![]($_img)\n';
      expect(span(text, ctx).toPlainText(), text);
    });

    testWidgets('gras et titres stylés, balises estompées', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }));
      final root = span('# Grâce\nDu **gras**', ctx);
      final leaves = <TextSpan>[];
      root.visitChildren((s) {
        if (s is TextSpan && s.text != null) leaves.add(s);
        return true;
      });
      final bold = leaves.firstWhere((s) => s.text == 'gras');
      expect(bold.style?.fontWeight, FontWeight.w700);
      final marker = leaves.firstWhere((s) => s.text == '**');
      expect(marker.style?.fontWeight, FontWeight.w400);
      final heading = leaves.firstWhere((s) => s.text == 'Grâce');
      expect(heading.style!.fontSize!, greaterThan(15));
    });
  });

  testWidgets('étape 3 : « Aperçu » ouvre le témoignage tel qu’il sera lu', (tester) async {
    tester.view.physicalSize = const Size(780, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const UserModel(id: 'u1', displayName: 'Marie')),
        categoriesListProvider.overrideWithValue(const [CategoryModel(id: 'c2', name: 'Guérison', slug: 'guerison')]),
        publishProvider.overrideWith(() => _Draft(PublishDraft(
              format: TestimonyFormat.text,
              title: 'Guéri par la prière',
              category: 'guerison',
              bodyText: 'Le Seigneur m’a **guéri**. Voir [ce lien](https://eglise.org).',
            ))),
        publishStepProvider.overrideWith(() => _Step(3)),
      ],
      child: const MaterialApp(home: PublishPreviewScreen()),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('publish-preview-card')));
    await tester.pumpAndSettle();

    expect(find.text('Aperçu du témoignage'), findsOneWidget);
    expect(find.text('Guéri par la prière'), findsOneWidget);
    expect(find.text('Guérison'), findsOneWidget);
    expect(find.text('Marie'), findsOneWidget);
    final body = _rendered(tester);
    expect(body, contains('Le Seigneur m’a guéri. Voir ce lien.'));
    expect(body, isNot(contains('**')));

    await tester.tap(find.byKey(const ValueKey('publish-preview-back')));
    await tester.pumpAndSettle();
    expect(find.text('Aperçu du témoignage'), findsNothing);
  });
}
