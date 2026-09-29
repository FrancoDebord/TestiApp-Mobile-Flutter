import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/utils/rich_text_utils.dart';

void main() {
  Widget host(String text) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressiveRichText(
              text: text,
              style: const TextStyle(fontSize: 14),
              initialChars: 40,
              stepChars: 60,
            ),
          ),
        ),
      );

  testWidgets('dévoile le texte morceau par morceau jusqu’à la fin',
      (tester) async {
    final text = List.generate(12, (i) => 'Phrase numéro $i du témoignage.')
        .join(' ');
    await tester.pumpWidget(host(text));

    expect(find.textContaining('Phrase numéro 11', findRichText: true),
        findsNothing);
    expect(find.text('Lire la suite ›'), findsOneWidget);

    for (var i = 0; i < 10 && find.text('Réduire ‹').evaluate().isEmpty; i++) {
      final link = find.textContaining(RegExp(r'Lire la (suite|fin)'));
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Phrase numéro 11', findRichText: true),
        findsOneWidget);
    expect(find.text('Réduire ‹'), findsOneWidget);
  });

  testWidgets('ne coupe jamais à l’intérieur d’une balise de mise en forme',
      (tester) async {
    // La coupe initiale (40 car.) tombe au milieu du passage en gras.
    const text = 'Début court. **Ce passage en gras est assez long pour '
        'chevaucher la coupe initiale** puis la suite du texte continue ici '
        'encore un peu pour dépasser la limite.';
    await tester.pumpWidget(host(text));

    final rendered = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .join();
    expect(rendered, isNot(contains('**')));
    expect(rendered, contains('chevaucher la coupe initiale'));
  });

  testWidgets('glisser sur le texte fait défiler toute la page',
      (tester) async {
    final longText = List.generate(
        40, (i) => 'Paragraphe $i : un long témoignage qui continue encore.')
        .join('\n\n');
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: ProgressiveRichText(
                text: longText,
                style: const TextStyle(fontSize: 14),
                initialChars: 100000, // tout afficher
              ),
            ),
          ],
        ),
      ),
    ));

    // Glissement démarré au milieu d'un paragraphe (pas dans un espace).
    await tester.drag(
        find.textContaining('Paragraphe 3 :', findRichText: true),
        const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });

  test('stripFormatting retire les balises', () {
    expect(
      stripFormatting('# Titre\n**gras** et __ital__\n- point\n> cite'),
      'Titre\ngras et ital\n• point\ncite',
    );
  });
}
