// Chargement des médias (ancien domaine, Referer Bunny) et témoignage de
// conversion face à un serveur sans le module.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/core/media/media_http.dart';
import 'package:testi_app/features/conversion/data/conversion_repository.dart';
import 'package:testi_app/services/api_service.dart';

class _Api implements ApiService {
  _Api({this.mineMissing = false, this.list = const []});
  final bool mineMissing;
  final List<Map<String, dynamic>> list;

  @override
  Future<LaravelResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (path == AppConstants.myConversionTestimony) {
      if (mineMissing) throw const LaravelApiException(message: 'not found', statusCode: 404);
      return LaravelResponse<T>(success: true, data: null as T, body: const {'can_create': true});
    }
    return LaravelResponse<T>(
      success: true,
      data: list as T,
      meta: const {'currentPage': 1, 'lastPage': 5},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

Map<String, dynamic> _t(String id, {String? kind}) => {
      'id': id,
      'title': 'Témoignage $id',
      'type': 'text',
      'bodyText': 'Texte',
      'category': 'guerison',
      'createdAt': '2026-10-15T10:00:00+00:00',
      'kind': ?kind,
      if (kind == 'conversion') 'isConversion': true,
      'user': {'id': 'u1', 'displayName': 'Afi'},
    };

void main() {
  group('Adresses des médias', () {
    test('ancien domaine → domaine actuel, mêmes chemins', () {
      final current = Uri.parse(AppConstants.webBaseUrl).host;
      final fixed = fixMediaUrl('https://testi.airid-africa.com/storage/media/images/a.jpg');
      expect(Uri.parse(fixed).host, current);
      expect(Uri.parse(fixed).path, '/storage/media/images/a.jpg');
    });

    test('autres adresses inchangées', () {
      const bunny = 'https://vz-1.b-cdn.net/x/thumbnail.jpg';
      expect(fixMediaUrl(bunny), bunny);
      expect(fixMediaUrl('${AppConstants.webBaseUrl}/storage/a.png'), '${AppConstants.webBaseUrl}/storage/a.png');
    });

    test('les requêtes ordinaires passent sans Referer ajouté', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? referer = 'non lu';
      server.listen((r) {
        referer = r.headers.value(HttpHeaders.refererHeader);
        r.response
          ..statusCode = 200
          ..close();
      });
      final client = MediaHttpOverrides().createHttpClient(null);
      final res = await (await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/a.png'))).close();
      expect(res.statusCode, 200);
      expect(referer, isNull);
      client.close();
      await server.close();
    });
  });

  group('Témoignage de conversion, serveur sans le module', () {
    test('GET /me/conversion-testimony absent (404) : bouton proposé, enregistrement indisponible', () async {
      final mine = await ConversionRepository(_Api(mineMissing: true)).mine();
      expect(mine.available, isFalse);
      expect(mine.canCreate, isTrue);
      final org = await ConversionRepository(_Api(mineMissing: true)).mine(isOrganization: true);
      expect(org.canCreate, isFalse);
    });

    test('serveur à jour : can_create lu à la racine de la réponse', () async {
      final mine = await ConversionRepository(_Api()).mine();
      expect(mine.available, isTrue);
      expect(mine.canCreate, isTrue);
      expect(mine.exists, isFalse);
    });

    test('?kind=conversion ignoré par le serveur : aucun témoignage ordinaire affiché, pas de pages suivantes', () async {
      final page = await ConversionRepository(_Api(list: [_t('1'), _t('2')])).list();
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('serveur à jour : seuls les témoignages de conversion', () async {
      final page = await ConversionRepository(
        _Api(list: [_t('1', kind: 'conversion'), _t('2', kind: 'standard')]),
      ).list();
      expect(page.items.map((t) => t.id), ['1']);
      expect(page.hasMore, isTrue);
    });
  });
}
