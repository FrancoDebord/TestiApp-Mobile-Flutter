import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/l10n/app_localizations.dart';
import 'package:testi_app/shared/utils/rich_text_utils.dart';
import 'package:testi_app/shared/widgets/link_preview.dart';
import 'package:testi_app/shared/widgets/mention_text.dart';
import 'package:testi_app/shared/widgets/mention_text_field.dart';

const _ruthId = '0199aaaa-bbbb-7ccc-8ddd-eeeeffff0002';

Widget _app(Widget child, {List overrides = const []}) => ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(
        locale: L10n.fr,
        supportedLocales: L10n.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    );

void main() {
  group('Adresses dans le texte', () {
    test('adresse collée : https ou www, ponctuation finale exclue', () {
      String? url(String t) => kBareUrlPattern.firstMatch(t)?.group(1);
      expect(url('Voir https://exemple.org/a?b=1.'), 'https://exemple.org/a?b=1');
      expect(url('Lien : www.exemple.org, merci'), 'www.exemple.org');
      expect(url('mail@www.exemple.org'), isNull);
      expect(normalizeLinkUrl('www.exemple.org'), 'https://www.exemple.org');
      expect(normalizeLinkUrl('http://exemple.org'), 'http://exemple.org');
    });

    test('premier lien du texte, images exclues', () {
      expect(firstLinkUrl('Rien ici'), isNull);
      expect(firstLinkUrl('![photo](https://img.org/a.jpg)\nVoir www.site.org'), 'https://www.site.org');
      expect(firstLinkUrl('Voir [le site](https://a.org) et https://b.org'), 'https://a.org');
      expect(firstLinkUrl('Voir https://b.org puis [le site](https://a.org)'), 'https://b.org');
    });

    test('réponse du serveur : aperçu ou null', () {
      final data = LinkPreviewData.fromJson({
        'url': 'https://www.exemple.org/page',
        'title': 'Un titre',
        'description': 'Une description',
        'image': 'https://www.exemple.org/a.png',
        'siteName': 'Mon site',
        'host': 'exemple.org',
      }, 'https://exemple.org');
      expect(data?.title, 'Un titre');
      expect(data?.imageUrl, 'https://www.exemple.org/a.png');
      expect(data?.siteName, 'Mon site');
      expect(data?.host, 'exemple.org');
      // Miniature en http : ignorée (comme sur le site).
      expect(LinkPreviewData.fromJson({'title': 'T', 'image': 'http://x.org/a.png'}, 'https://x.org')?.imageUrl, isNull);
      expect(LinkPreviewData.fromJson(null, 'https://x.org'), isNull);
      expect(LinkPreviewData.fromJson({'url': 'https://x.org'}, 'https://x.org'), isNull);
    });
  });

  testWidgets('MentionText : adresse cliquable (confirmation) à côté d’une mention', (tester) async {
    await tester.pumpWidget(_app(const MentionText(
      'Merci @Ruth, voir https://exemple.org.',
      mentions: [MentionRef(id: _ruthId, displayName: 'Ruth')],
    )));
    await tester.tapOnText(find.textRange.ofSubstring('https://exemple.org'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('https://exemple.org', findRichText: true), findsWidgets);
  });

  testWidgets('commentaire : carte d’aperçu du premier lien', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_app(
      const MentionText('Regardez www.exemple.org', linkPreview: true),
      overrides: [
        linkPreviewFetcherProvider.overrideWithValue((url) async {
          asked.add(url);
          return LinkPreviewData(url: url, title: 'Page d’exemple', siteName: 'Exemple');
        }),
      ],
    ));
    await tester.pumpAndSettle();
    expect(asked, ['https://www.exemple.org']);
    expect(find.text('Page d’exemple'), findsOneWidget);
    expect(find.text('EXEMPLE'), findsOneWidget);
  });

  testWidgets('aperçu indisponible : rien n’est affiché', (tester) async {
    await tester.pumpWidget(_app(
      const MentionText('Voir https://exemple.org', linkPreview: true),
      overrides: [linkPreviewFetcherProvider.overrideWithValue((url) async => throw Exception('hors ligne'))],
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LinkPreviewCard), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('saisie : l’adresse collée est soulignée', (tester) async {
    final ctrl = MentionEditingController(text: 'Voir https://exemple.org ici');
    late TextSpan span;
    await tester.pumpWidget(_app(Builder(builder: (context) {
      span = ctrl.buildTextSpan(context: context, withComposing: false);
      return const SizedBox();
    })));
    final link = span.children!.cast<TextSpan>().singleWhere((s) => s.text == 'https://exemple.org');
    expect(link.style?.decoration, TextDecoration.underline);

    final plain = LinkEditingController(text: 'Sans lien');
    expect(plain.buildTextSpan(context: tester.element(find.byType(SizedBox)), withComposing: false).children, isNull);
  });
}
