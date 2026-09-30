// Mode invité : règles d'accès du routeur et persistance de l'état.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/auth/guest_access.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guestCanAccess', () {
    test('onglets, lecture et paramètres d\'affichage autorisés', () {
      for (final path in [
        '/home',
        '/home/featured/42',
        '/explore',
        '/explore/search?q=paix',
        '/explore/category/guerison',
        '/bible',
        '/bible/jn',
        '/downloads',
        '/profile',
        '/profile/settings',
        '/profile/settings/language',
        '/profile/settings/about',
        '/testimony/abc',
        '/testimonies/abc',
        '/trending',
        '/lives',
        '/lives/12',
        '/users/7',
        '/login',
        '/register',
        '/onboarding',
      ]) {
        expect(guestCanAccess(path), isTrue, reason: path);
      }
    });

    test('actions réservées aux membres bloquées', () {
      for (final path in [
        '/publish',
        '/publish/preview',
        '/notifications',
        '/journal',
        '/journal/new',
        '/profile/edit',
        '/profile/my-testimonies',
        '/profile/saved',
        '/profile/settings/change-password',
        '/profile/settings/delete-account',
        '/following',
        '/testimony/abc/comments',
        '/testimony/abc/report',
        '/lives/new',
        '/lives/12/studio',
        '/moderation',
        '/moderation/3',
        '/admin',
      ]) {
        expect(guestCanAccess(path), isFalse, reason: path);
      }
    });

    test('raison de la feuille « compte requis »', () {
      expect(guestBlockedReason('/publish'), 'publier votre témoignage');
      expect(guestBlockedReason('/testimony/1/comments'),
          'commenter les témoignages');
    });
  });

  group('AuthNotifier — mode invité', () {
    Future<AuthState> restore() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container.read(authStateProvider.future);
    }

    test('sans session ni invité : non connecté', () async {
      FlutterSecureStorage.setMockInitialValues({});
      expect(await restore(), isA<AuthStateUnauthenticated>());
    });

    test('continueAsGuest est persisté au redémarrage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      await container.read(authStateProvider.notifier).continueAsGuest();
      expect(container.read(authStateProvider).value, isA<AuthStateGuest>());
      expect(container.read(isGuestProvider), isTrue);

      // « Redémarrage » : nouveau conteneur, même stockage.
      expect(await restore(), isA<AuthStateGuest>());
    });

    test('leaveGuestMode quitte le mode invité', () async {
      FlutterSecureStorage.setMockInitialValues({kGuestModeStorageKey: '1'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(authStateProvider.future),
          isA<AuthStateGuest>());
      await container.read(authStateProvider.notifier).leaveGuestMode();
      expect(container.read(authStateProvider).value,
          isA<AuthStateUnauthenticated>());
      expect(await restore(), isA<AuthStateUnauthenticated>());
    });
  });
}
