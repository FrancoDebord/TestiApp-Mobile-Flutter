// Types d'événements gérés par les administrateurs : lecture, repli, écran d'administration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/admin/screens/admin_event_types_screen.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/events/providers/event_types_providers.dart';
import 'package:testi_app/services/api_service.dart';

Map<String, dynamic> _t(int id, String slug, String name,
        {String icon = 'calendar', int pos = 0, bool active = true, int count = 0}) =>
    {
      'id': id,
      'slug': slug,
      'name': name,
      'nameFr': name,
      'nameEn': null,
      'icon': icon,
      'position': pos,
      'isActive': active,
      'eventsCount': count,
    };

class _Api implements ApiService {
  final calls = <String>[];
  final bodies = <Object?>[];
  var types = [
    _t(1, 'crusade', 'Croisade', icon: 'bullhorn', pos: 1, count: 3),
    _t(2, 'jeunesse', 'Rencontre jeunesse', icon: 'users', pos: 0),
    _t(3, 'retreat', 'Retraite', icon: 'dove', pos: 2, active: false),
  ];

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    expect(path, AppConstants.eventTypes);
    calls.add('GET ${query?['all'] ?? ''}');
    final list = query?['all'] == 1 ? types : types.where((t) => t['isActive'] == true).toList();
    return LaravelResponse<T>(success: true, data: list as T);
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    calls.add('POST $path');
    bodies.add(data);
    types = [...types, _t(9, 'louange-nuit', data['name_fr'] as String, icon: data['icon'] as String, pos: 9)];
    return LaravelResponse<T>(success: true, data: null as T);
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data}) async {
    calls.add('PUT $path');
    bodies.add(data);
    return LaravelResponse<T>(success: true, data: null as T);
  }

  @override
  Future<LaravelResponse<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    calls.add('DELETE $path ${query?['replace_with'] ?? ''}'.trim());
    if (path.endsWith('/1') && query?['replace_with'] == null) {
      throw const LaravelApiException(message: 'Type utilisé', statusCode: 409);
    }
    return LaravelResponse<T>(success: true, data: null as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Future<_Api> _pump(WidgetTester tester, {double width = 390, double scale = 1}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _Api();
  await tester.pumpWidget(ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api)],
    child: MaterialApp(
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: const Scaffold(body: AdminEventTypesScreen()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  tearDown(() => EventType.register(EventType.builtins));

  test('types d\'origine en repli, puis liste du serveur', () {
    expect(EventType.values.map((t) => t.apiValue), contains('crusade'));
    EventType.register([
      EventType.fromJson(_t(2, 'jeunesse', 'Rencontre jeunesse', icon: 'users', pos: 1)),
      EventType.fromJson(_t(1, 'crusade', 'Croisade', icon: 'bullhorn', pos: 0)),
      EventType.fromJson(_t(3, 'retreat', 'Retraite', pos: 2, active: false)),
    ]);
    // Actifs seulement, dans l'ordre choisi.
    expect(EventType.values.map((t) => t.apiValue), ['crusade', 'jeunesse']);
    // Un événement ne porte que le slug : nom et icône viennent de la liste.
    final t = EventType.parse('jeunesse');
    expect(t.label, 'Rencontre jeunesse');
    expect(t.icon, 'users');
    // Type inconnu (supprimé depuis) : nom de l'événement, sinon slug lisible.
    expect(EventType.parse('veillee', label: 'Veillée').label, 'Veillée');
    expect(EventType.parse('nuit_de_priere').label, 'nuit de priere');
    expect(EventType.parse('jeunesse'), EventType.parse('jeunesse', label: 'x'));
  });

  test('eventTypesProvider : serveur indisponible → types d\'origine', () async {
    final c = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(_FailingApi())]);
    addTearDown(c.dispose);
    final list = await c.read(eventTypesProvider.future);
    expect(list.length, EventType.builtins.length);
  });

  testWidgets('écran : liste, ajout, désactivation, suppression avec remplacement', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Rencontre jeunesse'), findsOneWidget);
    expect(find.text('3 événements'), findsOneWidget);
    expect(find.text('Aucun événement · désactivé'), findsOneWidget);

    // Ajout.
    await tester.tap(find.byKey(const ValueKey('add-event-type')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Louange de nuit');
    await tester.tap(find.byKey(const ValueKey('icon-music')));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST ${AppConstants.adminEventTypes}'));
    expect(api.bodies.last, {'name_fr': 'Louange de nuit', 'icon': 'music'});
    expect(find.text('Louange de nuit'), findsOneWidget);

    // Désactiver « Rencontre jeunesse ».
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(api.calls, contains('PUT ${AppConstants.adminEventType(2)}'));

    // Supprimer « Croisade » (3 événements) : choisir le remplaçant.
    final card = find.byKey(const ValueKey('event-type-crusade'));
    await tester.tap(find.descendant(of: card, matching: find.byIcon(Icons.delete_outline_rounded)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(SimpleDialog), matching: find.text('Rencontre jeunesse')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE ${AppConstants.adminEventType(1)} jeunesse'));
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('sans débordement (320 px, ×$scale)', (tester) async {
      await _pump(tester, width: 320, scale: scale);
      await tester.tap(find.byKey(const ValueKey('add-event-type')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _FailingApi implements ApiService {
  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async =>
      throw const LaravelApiException(message: 'hors ligne');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}
