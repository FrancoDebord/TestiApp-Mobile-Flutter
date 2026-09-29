import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/models/user_model.dart';

void main() {
  group('UserModel — compte personne', () {
    final json = <String, dynamic>{
      'id': 'u1',
      'display_name': 'Jean Dupont',
      'email': 'jean@exemple.com',
      'country': 'Bénin',
      'role': 'utilisateur',
      'testimony_count': 3,
      'follower_count': 5,
      'following_count': 2,
    };

    test('valeurs par défaut individuelles', () {
      final u = UserModel.fromJson(json);
      expect(u.accountType, AccountType.individual);
      expect(u.isOrganization, isFalse);
      expect(u.isVerified, isFalse);
      expect(u.organizationName, isNull);
      expect(u.effectiveVerificationStatus, isNull);
    });

    test('toJson / fromJson aller-retour', () {
      final u = UserModel.fromJson(json);
      final back = UserModel.fromJson(u.toJson());
      expect(back.toJson(), u.toJson());
      expect(back.displayName, 'Jean Dupont');
      expect(back.followerCount, 5);
      expect(back.accountType, AccountType.individual);
    });
  });

  group('UserModel — compte organisation', () {
    final json = <String, dynamic>{
      'id': 'o1',
      'display_name': 'Église de la Grâce',
      'email': 'contact@grace.org',
      'account_type': 'organization',
      'organization_name': 'Église de la Grâce',
      'organization_type': 'church',
      'organization_city': 'Cotonou',
      'organization_website': 'https://grace.org',
      'is_verified': false,
      'verification_status': 'pending',
    };

    test('parse les champs organisation', () {
      final u = UserModel.fromJson(json);
      expect(u.isOrganization, isTrue);
      expect(u.organizationType, OrganizationType.church);
      expect(u.organizationType!.label, 'Église');
      expect(u.organizationCity, 'Cotonou');
      expect(u.organizationWebsite, 'https://grace.org');
      expect(u.verificationStatus, VerificationStatus.pending);
      expect(u.effectiveVerificationStatus, VerificationStatus.pending);
    });

    test('toJson / fromJson aller-retour', () {
      final u = UserModel.fromJson(json);
      final back = UserModel.fromJson(u.toJson());
      expect(back.toJson(), u.toJson());
      expect(back.isOrganization, isTrue);
      expect(back.organizationName, 'Église de la Grâce');
      expect(back.organizationType, OrganizationType.church);
      expect(back.organizationWebsite, 'https://grace.org');
      expect(back.verificationStatus, VerificationStatus.pending);
      expect(back.toJson()['account_type'], 'organization');
      expect(back.toJson()['organization_type'], 'church');
    });

    test('organisation vérifiée (is_verified entier ou statut)', () {
      final a = UserModel.fromJson({...json, 'is_verified': 1});
      expect(a.isVerified, isTrue);
      expect(a.effectiveVerificationStatus, VerificationStatus.verified);

      final b = UserModel.fromJson({
        ...json,
        'is_verified': null,
        'verification_status': 'verified',
      });
      expect(b.isVerified, isTrue);

      final c = UserModel.fromJson({...json, 'verification_status': 'rejected'});
      expect(c.effectiveVerificationStatus, VerificationStatus.rejected);
    });

    test('organisation sans statut serveur → en cours par défaut', () {
      final u = UserModel.fromJson({
        'id': 'o2',
        'display_name': 'Ministère X',
        'account_type': 'organization',
      });
      expect(u.effectiveVerificationStatus, VerificationStatus.pending);
      expect(u.organizationType, isNull);
    });

    test('type inconnu → Autre', () {
      expect(OrganizationType.fromJson('temple'), OrganizationType.other);
      expect(OrganizationType.fromJson(null), isNull);
      expect(
        OrganizationType.values.map((t) => t.apiValue).toList(),
        ['church', 'ministry', 'association', 'ngo', 'media', 'other'],
      );
    });

    test('copyWith conserve les champs organisation', () {
      final u = UserModel.fromJson(json).copyWith(displayName: 'Grâce');
      expect(u.displayName, 'Grâce');
      expect(u.organizationCity, 'Cotonou');
      expect(u.isOrganization, isTrue);
    });
  });
}
