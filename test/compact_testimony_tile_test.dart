import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/widgets/compact_testimony_tile.dart';

final _testimony = TextTestimony(
  id: 't1',
  author: const TestimonyAuthor(
    uid: 'u1',
    displayName: 'Église de la Grâce',
    isOrganization: true,
    isVerified: true,
  ),
  title: 'Guéri après des années de maladie',
  category: TestimonyCategory.guerison,
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  stats: const TestimonyStats(views: 10, comments: 2, likes: 5, prayers: 3),
  preview: 'Le Seigneur a **transformé** ma vie. Voici mon histoire.',
  bibleVerseRef: 'Jean 3:16',
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            CompactTestimonyTile(
              key: ValueKey(_testimony.id),
              testimony: _testimony,
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ligne compacte : titre et méta visibles, repliée par défaut',
      (tester) async {
    await _pump(tester);

    expect(find.text(_testimony.title), findsOneWidget);
    expect(find.textContaining('Guérison'), findsOneWidget);
    expect(find.textContaining('il y a 2 h'), findsOneWidget);
    expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    expect(find.text('Voir le témoignage'), findsNothing);
  });

  testWidgets('un tap sur la ligne déplie puis replie les détails',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text(_testimony.title));
    await tester.pumpAndSettle();

    expect(find.text('Voir le témoignage'), findsOneWidget);
    expect(find.text('Jean 3:16'), findsOneWidget);
    expect(find.textContaining('transformé'), findsOneWidget);

    await tester.tap(find.byTooltip('Replier'));
    await tester.pumpAndSettle();
    expect(find.text('Voir le témoignage'), findsNothing);
  });
}
