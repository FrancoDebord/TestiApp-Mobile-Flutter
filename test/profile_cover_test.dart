// Photo de couverture : lecture de `cover_url` (UserResource du serveur).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/community/models/community_account.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/widgets/profile_cover.dart';

void main() {
  test('UserModel lit, garde en cache et retire la couverture', () {
    final u = UserModel.fromJson({'id': 'u1', 'display_name': 'Awa', 'cover_url': 'https://x/c.jpg'});
    expect(u.coverUrl, 'https://x/c.jpg');
    expect(UserModel.fromJson(u.toJson()).coverUrl, 'https://x/c.jpg');
    expect(u.copyWith(displayName: 'A').coverUrl, 'https://x/c.jpg');
    expect(u.copyWith(clearCoverUrl: true).coverUrl, isNull);
    expect(UserModel.fromJson({'id': 'u2', 'cover_url': '  '}).coverUrl, isNull);
    expect(u.copyWith(clearCoverUrl: true).toJson().containsKey('cover_url'), isFalse);
  });

  test('CommunityAccount lit la couverture et la garde après copyWith', () {
    final a = CommunityAccount.fromJson({'id': 'o1', 'display_name': 'Église', 'cover_url': 'https://x/o.jpg'});
    expect(a.coverUrl, 'https://x/o.jpg');
    expect(a.copyWith(followerCount: 3).coverUrl, 'https://x/o.jpg');
    expect(CommunityAccount.fromJson({'id': 'o2'}).coverUrl, isNull);
  });

  testWidgets('ProfileCoverImage ne dessine rien sans adresse', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: ProfileCoverImage(url: null),
    ));
    expect(find.byType(Image), findsNothing);
  });
}
