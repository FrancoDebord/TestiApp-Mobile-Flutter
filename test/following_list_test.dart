// « Mes abonnements » et listes de comptes : messages d'erreur, liste vide, en-tête.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/community/data/community_repository.dart';
import 'package:testi_app/features/community/widgets/paged_account_list.dart';
import 'package:testi_app/services/api_service.dart';

Widget _wrap(Widget child) => ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

void main() {
  test('un 404 indique que le serveur n\u2019a pas encore la mise à jour', () {
    expect(accountListErrorMessage(const LaravelApiException(message: 'x', statusCode: 404)),
        contains("pas encore disponible sur le serveur"));
    expect(accountListErrorMessage(const LaravelApiException(message: 'x', statusCode: 401)),
        'Connectez-vous pour voir cette liste.');
    expect(accountListErrorMessage(Exception('réseau')), contains('Vérifiez votre connexion'));
  });

  testWidgets('liste vide : texte et action ; la recherche est envoyée au chargeur', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(_wrap(PagedAccountList(
      loader: (q, page) async {
        queries.add(q);
        return const CommunityPage([], currentPage: 1, lastPage: 1, total: 0);
      },
      searchHint: 'Rechercher',
      emptyText: 'Vous ne suivez encore personne.',
      emptyAction: TextButton(onPressed: () {}, child: const Text('Découvrir la Communauté')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Vous ne suivez encore personne.'), findsOneWidget);
    expect(find.text('Découvrir la Communauté'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'lumi');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(queries.last, 'lumi');
    expect(find.text('Aucun compte ne correspond à votre recherche.'), findsOneWidget);
    expect(find.text('Découvrir la Communauté'), findsNothing);
  });

  testWidgets('erreur serveur : message et bouton Réessayer', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap(PagedAccountList(
      loader: (q, page) async {
        calls++;
        throw const LaravelApiException(message: 'Not found', statusCode: 404);
      },
      searchHint: 'Rechercher',
      emptyText: 'Vide',
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('pas encore disponible'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
