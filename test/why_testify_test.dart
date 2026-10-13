import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/content/encouragements.dart';
import 'package:testi_app/shared/widgets/why_testify_card.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  test('même contenu que le site : 7 raisons, 17 versets, tous référencés', () {
    expect(whyTestifyReasons, hasLength(7));
    final verses = whyTestifyReasons.expand((r) => r.verses).toList();
    expect(verses, hasLength(17));
    expect(verses.every((v) => v.isVerse && v.text.isNotEmpty), isTrue);
  });

  testWidgets('accordéon : une seule raison ouverte à la fois', (tester) async {
    await tester.pumpWidget(_wrap(const WhyTestifyCard()));

    expect(find.text('Pourquoi témoigner ?'), findsOneWidget);
    expect(find.text('7 raisons et 17 versets de la Bible'), findsOneWidget);
    expect(find.text('Témoigner'), findsOneWidget);
    expect(find.text('Marc 5:19'), findsNothing);

    await tester.tap(find.text("C'est l'appel du Seigneur"));
    await tester.pumpAndSettle();
    expect(find.text('Marc 5:19'), findsOneWidget);
    expect(find.text('Actes 1:8'), findsOneWidget);

    await tester.tap(find.text('Le témoignage donne la victoire'));
    await tester.pumpAndSettle();
    expect(find.text('Marc 5:19'), findsNothing);
    expect(find.text('Apocalypse 12:11'), findsOneWidget);

    // Un second appui referme la raison.
    await tester.tap(find.text('Le témoignage donne la victoire'));
    await tester.pumpAndSettle();
    expect(find.text('Apocalypse 12:11'), findsNothing);
  });

  testWidgets('replié : une ligne, se déplie au toucher ; sans bouton', (tester) async {
    await tester.pumpWidget(_wrap(const WhyTestifyCard(collapsible: true, showAction: false)));

    expect(find.text('Pourquoi témoigner ?'), findsOneWidget);
    expect(find.text("C'est l'appel du Seigneur"), findsNothing);

    await tester.tap(find.text('Pourquoi témoigner ?'));
    await tester.pumpAndSettle();
    expect(find.text("C'est l'appel du Seigneur"), findsOneWidget);
    expect(find.text('Témoigner'), findsNothing);
  });

  testWidgets('initiallyOpen : première raison ouverte', (tester) async {
    await tester.pumpWidget(_wrap(const WhyTestifyCard(initiallyOpen: 0)));
    expect(find.text('Ésaïe 43:10'), findsOneWidget);
  });
}
