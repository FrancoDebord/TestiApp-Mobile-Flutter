import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Reproduit la structure du routeur de l'app : onglets (profil, publier) dans
// un StatefulShellRoute, carnet au niveau racine, ouvert depuis le profil.
GoRouter _router({required String publishLocation}) => GoRouter(
      initialLocation: '/profile',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profile',
                builder: (context, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => context.push('/journal'),
                    child: const Text('carnet'),
                  ),
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/publish',
                builder: (_, _) => const Text('publier'),
                routes: [
                  GoRoute(path: 'preview', builder: (_, _) => const Text('parcours')),
                ],
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/journal',
          builder: (context, _) => Scaffold(
            body: Column(children: [
              TextButton(
                onPressed: () => context.push(publishLocation),
                child: const Text('nouveau'),
              ),
              TextButton(
                onPressed: () => context.push('/journal/abc'),
                child: const Text('entree'),
              ),
            ]),
          ),
          routes: [
            // Comme dans l'app : 'new' avant ':id'.
            GoRoute(path: 'new', builder: (_, _) => const Text('parcours')),
            GoRoute(path: ':id', builder: (_, s) => Text('detail:${s.pathParameters['id']}')),
          ],
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('carnet'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ouvrir une entrée du carnet', (tester) async {
    await _pump(tester, _router(publishLocation: '/journal/new'));
    await tester.tap(find.text('entree'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('detail:abc'), findsOneWidget);
  });

  // Pousser /publish/preview (route du shell) depuis le carnet faisait
  // planter go_router (deux pages shell de même clé) : d'où /journal/new.

  testWidgets('correctif : parcours hors du shell depuis le carnet', (tester) async {
    await _pump(tester, _router(publishLocation: '/journal/new'));
    await tester.tap(find.text('nouveau'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('parcours'), findsOneWidget);
  });
}
