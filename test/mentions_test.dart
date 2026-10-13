import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/models/comment_model.dart';
import 'package:testi_app/shared/widgets/mention_text.dart';
import 'package:testi_app/shared/widgets/mention_text_field.dart';

const _paulId = '0199aaaa-bbbb-7ccc-8ddd-eeeeffff0001';
const _ruthId = '0199aaaa-bbbb-7ccc-8ddd-eeeeffff0002';

Widget _app(Widget child) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

void main() {
  group('MentionCodec', () {
    test('décode les jetons et encode les « @Nom » choisis', () {
      final d = MentionCodec.decode('Merci @[Paul Mbeki](user:$_paulId) !');
      expect(d.text, 'Merci @Paul Mbeki !');
      expect(d.mentions.single.id, _paulId);

      const paul = MentionRef(id: _paulId, displayName: 'Paul Mbeki');
      expect(MentionCodec.encode('Merci @Paul Mbeki ! @Paul Mbekix', [paul]),
          'Merci @[Paul Mbeki](user:$_paulId) ! @Paul Mbekix');
      // Déjà encodé : inchangé (pas de double jeton).
      final once = MentionCodec.encode('@Paul Mbeki', [paul]);
      expect(MentionCodec.encode(once, [paul]), once);
    });

    test('commentaire du serveur : texte lisible + mentions', () {
      final c = CommentModel.fromJson({
        'id': 'c1',
        'text': 'Bonjour @Ruth',
        'mentions': [
          {'id': _ruthId, 'displayName': 'Ruth'},
          {'id': '', 'displayName': 'invalide'},
        ],
      });
      expect(c.mentions, const [MentionRef(id: _ruthId, displayName: 'Ruth')]);
      expect(MentionCodec.ranges(c.text, c.mentions).single.start, 8);
    });
  });

  testWidgets('MentionText : la mention est cliquable', (tester) async {
    MentionRef? opened;
    await tester.pumpWidget(_app(MentionText(
      'Merci @Ruth pour ce témoignage',
      mentions: const [MentionRef(id: _ruthId, displayName: 'Ruth')],
      onMentionTap: (m) => opened = m,
    )));

    expect(find.text('Merci @Ruth pour ce témoignage', findRichText: true), findsOneWidget);
    await tester.tapOnText(find.textRange.ofSubstring('@Ruth'));
    expect(opened?.id, _ruthId);
  });

  testWidgets('MentionTextField : anti-rebond, suggestions, insertion et jeton envoyé', (tester) async {
    final queries = <String>[];
    Future<List<MentionCandidate>> search(String q, {String? testimonyId}) async {
      queries.add(q);
      return q.toLowerCase().startsWith('pa')
          ? const [MentionCandidate(id: _paulId, displayName: 'Paul Mbeki', isFollowing: true)]
          : const [];
    }

    final ctrl = MentionEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_app(MentionTextField(controller: ctrl, search: search, testimonyId: 't1')));

    await tester.enterText(find.byType(TextField), 'Merci @p');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'Merci @pa');
    expect(find.text('Recherche…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(queries, ['pa'], reason: 'une seule requête après 300 ms sans frappe');
    expect(find.text('Paul Mbeki'), findsOneWidget);
    expect(find.text('Abonné'), findsOneWidget);

    await tester.tap(find.text('Paul Mbeki'));
    await tester.pump();
    expect(ctrl.text, 'Merci @Paul Mbeki ');
    expect(ctrl.encodedText, 'Merci @[Paul Mbeki](user:$_paulId)');
    expect(ctrl.mentions.single.id, _paulId);
    expect(find.text('Paul Mbeki'), findsNothing, reason: 'panneau fermé');

    // Aucun résultat : message vide.
    await tester.enterText(find.byType(TextField), 'Merci @zz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.textContaining('Aucun compte trouvé'), findsOneWidget);

    // Effacer : plus de mention retenue.
    ctrl.clear();
    expect(ctrl.encodedText, '');
  });

  testWidgets('MentionTextField : erreur de recherche affichée sans planter', (tester) async {
    Future<List<MentionCandidate>> search(String q, {String? testimonyId}) async => throw Exception('hors ligne');
    final ctrl = MentionEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_app(MentionTextField(controller: ctrl, search: search)));

    await tester.enterText(find.byType(TextField), '@ru');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Recherche indisponible. Réessayez.'), findsOneWidget);
  });

  test('mentionQueryAt : « @ » en début de mot seulement', () {
    TextEditingValue v(String t) => TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
    expect(mentionQueryAt(v('Bonjour @Pa'))?.query, 'Pa');
    expect(mentionQueryAt(v('@'))?.query, '');
    expect(mentionQueryAt(v('mail@exemple')), isNull);
    expect(mentionQueryAt(v('Bonjour')), isNull);
  });
}
