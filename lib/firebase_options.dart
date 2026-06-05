// lib/firebase_options.dart
// Généré à partir de google-services.json — projet testi-app-flutter

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  // ── Android ─────────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyCeH2GsD6-vW3j-2Nz00r8_pJm4XsACbvI',
    appId:             '1:308694397519:android:08d8b460e8d9d39d95b03a',
    messagingSenderId: '308694397519',
    projectId:         'testi-app-flutter',
    storageBucket:     'testi-app-flutter.firebasestorage.app',
  );

  // ── iOS (à configurer quand nécessaire) ──────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'REMPLACE_PAR_API_KEY_IOS',
    appId:             'REMPLACE_PAR_APP_ID_IOS',
    messagingSenderId: '308694397519',
    projectId:         'testi-app-flutter',
    storageBucket:     'testi-app-flutter.firebasestorage.app',
    iosBundleId:       'com.airid.testiApp',
  );

  // ── Web (à configurer si nécessaire) ─────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'REMPLACE_PAR_API_KEY_WEB',
    appId:             'REMPLACE_PAR_APP_ID_WEB',
    messagingSenderId: '308694397519',
    projectId:         'testi-app-flutter',
    storageBucket:     'testi-app-flutter.firebasestorage.app',
    authDomain:        'testi-app-flutter.firebaseapp.com',
  );
}
