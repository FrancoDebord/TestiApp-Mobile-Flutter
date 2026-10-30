// Liens partagés du site ouverts dans l'application : chemins déclarés côté Android
// (comme config/applinks.php du serveur) et accessibles en invité.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/guest_access.dart';

void main() {
  test('AndroidManifest : tous les chemins de partage du site', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final prefix in [
      '/testimonies/',
      '/videos/',
      '/lives/',
      '/evenements/',
      '/priere/requetes/',
      '/priere/sessions/',
      '/verset-du-jour',
      '/listes/',
    ]) {
      expect(manifest, contains('android:pathPrefix="$prefix"'), reason: prefix);
    }
    expect(manifest, contains('android:path="/temoignages-de-conversion"'));
    expect(manifest, contains('android:host="temoignage.as-krea.com"'));
  });

  test('liens partagés ouverts sans compte (lecture libre)', () {
    for (final path in [
      '/evenements/9b1c',
      '/evenements/passes',
      '/priere/requetes/9b1c',
      '/priere/sessions/9b1c',
      '/verset-du-jour',
      '/verset-du-jour/2026-10-19',
      '/videos/9b1c',
      '/temoignages-de-conversion',
      '/conversions',
      '/listes/0199aaaa-bbbb-7ccc-8ddd-eeeeffff0001',
    ]) {
      expect(guestCanAccess(path), isTrue, reason: path);
    }
    // Modifier son témoignage de conversion demande un compte.
    expect(guestCanAccess('/conversions/mine/edit'), isFalse);
    expect(guestCanAccess('/mes-listes'), isFalse);
  });
}
