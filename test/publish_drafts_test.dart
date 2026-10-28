// Brouillons de témoignage gardés sur le téléphone (lib/features/publish/drafts/).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/core/providers/categories_provider.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'package:testi_app/features/publish/screens/publish_preview_screen.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart' show realUserProvider;
import 'package:testi_app/features/bible/providers/bible_providers.dart' show bibleVerseToInsertProvider;
import 'package:testi_app/features/publish/drafts/publish_drafts.dart';
import 'package:testi_app/features/publish/models/publish_models.dart';
import 'package:testi_app/features/publish/providers/publish_provider.dart';
import 'package:testi_app/shared/models/mention.dart';
import 'package:testi_app/shared/models/user_model.dart';

/// Brouillons en mémoire (pas de SQLite ni de copie de fichiers).
class _Store extends PublishDraftsStore {
  final saved = <String, PublishDraft>{};
  final deleted = <String>[];
  var _n = 0;

  @override
  Future<List<SavedPublishDraft>> list(String userId) async => [
        for (final e in saved.entries) SavedPublishDraft(id: e.key, draft: e.value, updatedAt: DateTime(2026, 10, 26)),
      ];

  @override
  Future<PublishDraft> save(String userId, PublishDraft draft) async {
    final id = draft.draftId ?? 'd${++_n}';
    final kept = draft.copyWith(draftId: id, audioPath: draft.audioPath == null ? null : 'drafts/$id/a.m4a');
    saved[id] = kept;
    return kept;
  }

  @override
  Future<void> delete(String id) async {
    saved.remove(id);
    deleted.add(id);
  }
}

({ProviderContainer c, _Store store}) _setup() {
  final store = _Store();
  final c = ProviderContainer(overrides: [
    publishDraftsStoreProvider.overrideWithValue(store),
    realUserProvider.overrideWithValue(const UserModel(id: 'me', displayName: 'Awa')),
  ]);
  addTearDown(c.dispose);
  // Garde le formulaire en vie (autoDispose), comme l'écran « Publier ».
  c.listen(publishProvider, (_, _) {});
  return (c: c, store: store);
}

class _Draft extends PublishNotifier {
  _Draft(this.initial);
  final PublishDraft initial;

  @override
  PublishDraft build() => initial;
}

class _Step2 extends PublishStepNotifier {
  @override
  int build() => 2;
}

Future<_Store> _pumpForm(WidgetTester tester) async {
  tester.view.physicalSize = const Size(780, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final store = _Store();
  final router = GoRouter(initialLocation: '/publish/preview', routes: [
    GoRoute(
      path: '/publish',
      builder: (_, _) => const Scaffold(body: Text('Écran Publier')),
      routes: [GoRoute(path: 'preview', builder: (_, _) => const PublishPreviewScreen())],
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      publishDraftsStoreProvider.overrideWithValue(store),
      realUserProvider.overrideWithValue(const UserModel(id: 'me', displayName: 'Awa')),
      currentUserProvider.overrideWithValue(const UserModel(id: 'me', displayName: 'Awa')),
      categoriesListProvider.overrideWithValue(const [CategoryModel(id: 'c1', name: 'Guérison', slug: 'guerison')]),
      publishProvider.overrideWith(
          () => _Draft(PublishDraft(format: TestimonyFormat.text, title: 'Guérie', bodyText: 'Merci Seigneur'))),
      publishStepProvider.overrideWith(_Step2.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  return store;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Retour pendant la saisie (étape 2) : confirmation, « Enregistrer le brouillon »', (tester) async {
    final store = await _pumpForm(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Enregistrer le brouillon'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Continuer à écrire'), findsOneWidget);

    await tester.tap(find.text('Enregistrer le brouillon'));
    await tester.pumpAndSettle();
    expect(store.saved.values.single.title, 'Guérie');
    expect(find.text('Écran Publier'), findsOneWidget);
  });

  testWidgets('Retour puis « Continuer à écrire » : on reste sur le formulaire', (tester) async {
    final store = await _pumpForm(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer à écrire'));
    await tester.pumpAndSettle();
    expect(find.byType(PublishPreviewScreen), findsOneWidget);
    expect(store.saved, isEmpty);
  });

  test('brouillon : tous les champs repris à l\'identique', () {
    final d = PublishDraft(
      format: TestimonyFormat.audio,
      title: 'Guérie en une nuit',
      category: 'guerison',
      categoryId: 'cat-1',
      coverImagePath: '/x/cover.jpg',
      bodyText: 'Texte',
      bibleVerse: 'Jean 3:16',
      audioPath: '/x/a.m4a',
      audioDurationSeconds: 95,
      audioTranscript: 'Merci Seigneur',
      videoTrimEnd: const Duration(seconds: 12),
      proofs: {1: const ProofAttachment(path: '/x/p.pdf', name: 'p.pdf', size: 1200)},
      proofsPublic: true,
      visibility: TestimonyVisibility.friends,
      consentGiven: true,
      mentions: const [MentionRef(id: 'u1', displayName: 'Jean')],
    );
    final back = PublishDraft.fromDraftJson(d.toDraftJson(), draftId: 'd1');
    expect(back.toDraftJson(), d.toDraftJson());
    expect(back.draftId, 'd1');
    expect(back.proofs[1]!.name, 'p.pdf');
    expect(back.visibility, TestimonyVisibility.friends);
  });

  test('un formulaire vide ne crée pas de brouillon', () async {
    final s = _setup();
    final n = s.c.read(publishProvider.notifier)..selectFormat(TestimonyFormat.text);
    await n.saveDraftNow();
    expect(s.store.saved, isEmpty);
  });

  test('saisie enregistrée, identifiant et copies des fichiers repris dans le formulaire', () async {
    final s = _setup();
    final n = s.c.read(publishProvider.notifier)
      ..selectFormat(TestimonyFormat.audio)
      ..updateTitle('Ma délivrance')
      ..updateAudioPath('/tmp/rec.m4a');
    await n.saveDraftNow();
    final state = s.c.read(publishProvider);
    expect(state.draftId, 'd1');
    expect(state.audioPath, 'drafts/d1/a.m4a');
    expect(s.store.saved['d1']!.title, 'Ma délivrance');

    // Nouvelle saisie : même brouillon mis à jour.
    n.updateTitle('Ma délivrance totale');
    await n.saveDraftNow();
    expect(s.store.saved.keys, ['d1']);
    expect(s.store.saved['d1']!.title, 'Ma délivrance totale');
  });

  test('reprendre puis supprimer un brouillon', () async {
    final s = _setup();
    final n = s.c.read(publishProvider.notifier);
    s.store.saved['d7'] = PublishDraft(format: TestimonyFormat.text, title: 'Repris', draftId: 'd7');
    n.loadDraft(s.store.saved['d7']!);
    expect(s.c.read(publishProvider).title, 'Repris');
    expect(s.c.read(publishProvider).status, PublishStatus.draft);

    await n.discardDraft();
    expect(s.store.deleted, ['d7']);
    expect(s.c.read(publishProvider).hasContent, isFalse);
    // Plus rien n'est réenregistré après la suppression.
    await n.saveDraftNow();
    expect(s.store.saved, isEmpty);
  });

  test('témoignage publié : son brouillon est supprimé', () async {
    final s = _setup();
    final n = s.c.read(publishProvider.notifier)
      ..selectFormat(TestimonyFormat.text)
      ..updateTitle('Témoignage');
    await n.saveDraftNow();
    expect(s.store.saved.keys, ['d1']);

    n.state = n.state.copyWith(status: PublishStatus.inReview);
    await Future<void>.delayed(Duration.zero);
    expect(s.store.deleted, ['d1']);
  });

  test('témoigner sur un verset : repris dans le type choisi (texte, audio, vidéo), pas dans le carnet', () {
    final s = _setup();
    s.c.read(bibleVerseToInsertProvider.notifier).set('Jean 3:16');
    final n = s.c.read(publishProvider.notifier);
    for (final f in TestimonyFormat.values) {
      n.selectFormat(f);
      expect(s.c.read(publishProvider).bibleVerse, 'Jean 3:16', reason: f.name);
    }
    // Le verset reste proposé si l'on change de type avant de publier.
    expect(s.c.read(bibleVerseToInsertProvider), 'Jean 3:16');
    n.selectFormat(TestimonyFormat.text, journal: true);
    expect(s.c.read(publishProvider).bibleVerse, isEmpty);
  });
}
