// Vérifie que les cartes de l'écran de modération ne débordent pas sur un
// petit écran, avec une grande taille de police et des textes longs.
// Flutter signale tout débordement (RenderFlex overflowed) comme une erreur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/moderation/models/moderation_models.dart';
import 'package:testi_app/features/moderation/providers/moderation_provider.dart';
import 'package:testi_app/features/moderation/screens/moderation_detail_screen.dart';
import 'package:testi_app/features/moderation/screens/moderation_screen.dart';

ModerationItem _item(String id, TestimonyType type) => ModerationItem(
      id: id,
      author: const ModerationAuthor(
        uid: 'u1',
        displayName:
            'Ministère International Lumière du Monde pour la Restauration',
        country: "République démocratique du Congo, Côte d'Ivoire",
      ),
      title: 'Un très long titre de témoignage pour vérifier le retour à la '
          'ligne dans la carte de modération',
      category: 'Protection divine et délivrance',
      type: type,
      status: ModerationStatus.pending,
      submittedAt: DateTime.now().subtract(const Duration(days: 12)),
      contentPreview: 'Texte du témoignage.',
    );

final _items = [
  _item('1', TestimonyType.text),
  _item('2', TestimonyType.audio),
  _item('3', TestimonyType.video),
];

const _stats = ModerationStats(
  pending: 123456,
  approvedToday: 98765,
  rejectedToday: 4321,
  totalThisMonth: 1234567,
);

Widget _app(Widget child, {double textScale = 1.0}) => ProviderScope(
      overrides: [
        moderationItemsProvider.overrideWithValue(_items),
        moderationStatsProvider.overrideWithValue(_stats),
        for (final i in _items)
          moderationItemByIdProvider(i.id).overrideWithValue(i),
        // Preuves privées : pas d'appel réseau dans les tests de mise en page.
        for (final i in _items)
          moderationProofsProvider(i.id).overrideWith((ref) async => const []),
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
      testWidgets('écran de modération sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const ModerationScreen(), textScale: scale));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Prévisualiser'), findsWidgets);
        expect(find.text('En attente'), findsWidgets);
      });

      testWidgets('détail de modération sans débordement ($width px, ×$scale)',
          (tester) async {
        await _setPhone(tester, width);
        for (final i in _items) {
          await tester.pumpWidget(
              _app(ModerationDetailScreen(reportId: i.id), textScale: scale));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'type ${i.type}');
        }
      });
    }
  }
}
