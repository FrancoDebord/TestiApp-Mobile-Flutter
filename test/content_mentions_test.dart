// Mentions « @ » dans le texte des témoignages (formulaire Publier, lecture) et
// des requêtes de prière. Doc serveur : docs/fonctionnalites/mentions.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';
import 'package:testi_app/features/publish/screens/publish_preview_screen.dart';
import 'package:testi_app/shared/models/mention.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/utils/rich_text_utils.dart';
import 'package:testi_app/shared/widgets/mention_text_field.dart';

const _paulId = '0199aaaa-bbbb-7ccc-8ddd-eeeeffff0001';
const _paul = MentionRef(id: _paulId, displayName: 'Paul Mbeki');

class _Draft extends PublishNotifier {
  _Draft(this.initial);
  final PublishDraft initial;

  @override
  PublishDraft build() => initial;
}

class _Step extends PublishStepNotifier {
  @override
  int build() => 1;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('brouillon : seules les mentions encore présentes partent en mention_ids', () {
    final draft = PublishDraft(
      format: TestimonyFormat.text,
      bodyText: 'Merci @Paul Mbeki !',
      mentions: const [_paul, MentionRef(id: 'x', displayName: 'Ruth')],
    );
    expect(draft.mentionIdsIn(draft.bodyText), [_paulId]);
    expect(draft.mentionIdsIn('Plus de mention'), isEmpty);
    expect(draft.copyWith(title: 'T').mentions, hasLength(2));
  });

  test('témoignage et requête de prière : mentions lues depuis l’API', () {
    final t = testimonyFromApiJson({
      'id': 't1',
      'title': 'Guérie',
      'type': 'text',
      'bodyText': 'Merci @Paul Mbeki',
      'mentions': [
        {'id': _paulId, 'displayName': 'Paul Mbeki'},
      ],
      'user': {'id': 'u1', 'displayName': 'Marie'},
    });
    expect(t, isA<TextTestimony>());
    expect(t!.mentions, const [_paul]);

    final r = PrayerRequest.fromJson({
      'id': 'p1',
      'body': 'Priez avec @Paul Mbeki',
      'mentions': [
        {'id': _paulId, 'displayName': 'Paul Mbeki'},
      ],
    });
    expect(r.mentions, const [_paul]);
    expect(r.withPrayed(true).mentions, const [_paul]);
  });

  testWidgets('Publier : « @ » dans la description retient la mention', (tester) async {
    tester.view.physicalSize = const Size(780, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Future<List<MentionCandidate>> search(String q, {String? testimonyId}) async =>
        q.toLowerCase().startsWith('pa')
            ? const [MentionCandidate(id: _paulId, displayName: 'Paul Mbeki')]
            : const [];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
            const UserModel(id: 'u1', displayName: 'Marie', role: UserRole.utilisateur)),
        categoriesListProvider.overrideWithValue(
            const [CategoryModel(id: 'c1', name: 'Guérison', slug: 'guerison')]),
        publishProvider.overrideWith(() => _Draft(PublishDraft(format: TestimonyFormat.text))),
        publishStepProvider.overrideWith(_Step.new),
        mentionSearchProvider.overrideWithValue(search),
      ],
      child: const MaterialApp(home: PublishPreviewScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final field = find.descendant(of: find.byType(MentionTextField), matching: find.byType(TextField));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Merci @pa');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(find.text('Paul Mbeki'));
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(find.byType(PublishPreviewScreen)));
    final draft = container.read(publishProvider);
    expect(draft.bodyText, 'Merci @Paul Mbeki ');
    expect(draft.mentions, const [_paul]);
    expect(draft.mentionIdsIn(draft.bodyText), [_paulId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lecture : la mention du texte mis en forme est cliquable', (tester) async {
    MentionRef? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProgressiveRichText(
          text: 'Merci **beaucoup** @Paul Mbeki pour ses prières.',
          style: const TextStyle(fontSize: 15),
          mentions: const [_paul],
          onMentionTap: (m) => opened = m,
        ),
      ),
    ));

    await tester.tapOnText(find.textRange.ofSubstring('@Paul Mbeki'));
    expect(opened, _paul);
  });
}
