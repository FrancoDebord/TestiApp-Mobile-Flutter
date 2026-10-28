// Types de témoignages (catégories) : nom anglais géré par les administrateurs ;
// nom de l'application « My Testimony ».

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart' show Options;
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/admin/screens/admin_categories_screen.dart';
import 'package:testi_app/services/api_service.dart';
import 'package:testi_app/shared/widgets/app_logo.dart';

Map<String, dynamic> _cat(String id, String fr, String? en, {int count = 3, bool active = true, int order = 1}) => {
      'id': id,
      'name': fr,
      'nameFr': fr,
      'nameEn': en,
      'slug': id,
      'testimonyCount': count,
      'displayOrder': order,
      'isActive': active,
    };

class _Api implements ApiService {
  final calls = <(String, String, Object?)>[];

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add(('GET', path, null));
    return LaravelResponse<T>(
      success: true,
      data: [
        _cat('guerison', 'Guérison', 'Healing', count: 42, order: 1),
        _cat('delivrance', 'Délivrance', null, count: 7, order: 2, active: false),
      ] as T,
    );
  }

  @override
  Future<LaravelResponse<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query, Options? options}) async {
    calls.add(('POST', path, data));
    final d = data as Map;
    return LaravelResponse<T>(success: true, data: _cat('new', d['name'] as String, d['name_en'] as String?) as T);
  }

  @override
  Future<LaravelResponse<T>> put<T>(String path, {dynamic data, Options? options}) async {
    calls.add(('PUT', path, data));
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
      builder: (context, child) =>
          MediaQuery.withClampedTextScaling(minScaleFactor: scale, maxScaleFactor: scale, child: child!),
      home: const Scaffold(body: AdminCategoriesScreen()),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('liste : nom français, nom anglais, compteurs (clés camelCase)', (tester) async {
    await _pump(tester);
    expect(find.text('Guérison'), findsOneWidget);
    expect(find.text('EN · Healing'), findsOneWidget);
    expect(find.text('Pas de nom anglais'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value), [true, false]);
  });

  testWidgets('ajouter un type avec son nom anglais', (tester) async {
    final api = await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('new-category-fr')), 'Restauration');
    await tester.enterText(find.byKey(const ValueKey('new-category-en')), 'Restoration');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    final post = api.calls.firstWhere((c) => c.$1 == 'POST');
    expect(post.$2, AppConstants.adminCategories);
    expect(post.$3, {'name': 'Restauration', 'name_en': 'Restoration'});
    expect(find.text('EN · Restoration'), findsOneWidget);
  });

  testWidgets('modifier : nom anglais ajouté, puis effacé', (tester) async {
    final api = await _pump(tester);
    await tester.tap(find.byTooltip('Modifier').at(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-name-fr')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('category-name-en')), 'Deliverance');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    final put = api.calls.lastWhere((c) => c.$1 == 'PUT');
    expect(put.$2, AppConstants.adminCategoryById('delivrance'));
    expect(put.$3, {'name': 'Délivrance', 'name_en': 'Deliverance'});
    expect(find.text('EN · Deliverance'), findsOneWidget);

    await tester.tap(find.byTooltip('Modifier').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('category-name-en')), '');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(api.calls.last.$3, {'name': 'Guérison', 'name_en': ''});
    expect(find.text('Pas de nom anglais'), findsNWidgets(1));
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('sans débordement (320 px, ×$scale)', (tester) async {
      await _pump(tester, width: 320, scale: scale);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('logo : « My Testimony »', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: AppLogo()))));
    expect(find.bySemanticsLabel('My Testimony'), findsOneWidget);
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox(width: 300, child: AppLogo.horizontal()))));
    expect(tester.takeException(), isNull);
  });
}
