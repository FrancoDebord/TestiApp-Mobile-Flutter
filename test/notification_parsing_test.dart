import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/notifications/models/notification_models.dart';
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/services/fcm_service.dart';

void main() {
  group('notificationFromJson', () {
    test('parse live_started avec liveId et message serveur', () {
      final n = notificationFromJson({
        'id': 'n1',
        'type': 'live_started',
        'actorId': 'u1',
        'actorName': 'Marie',
        'actorAvatar': null,
        'testimonyId': null,
        'testimonyTitle': null,
        'message': 'Marie est en direct : Louange du soir',
        'liveId': 'live-42',
        'isRead': false,
        'createdAt': '2026-09-28T10:00:00+00:00',
      });

      expect(n, isNotNull);
      expect(n!.type, NotificationType.liveStarted);
      expect(n.liveId, 'live-42');
      expect(n.testimonyId, isNull);
      expect(n.type.label, 'En direct');
      expect(n.body, 'Marie est en direct : Louange du soir');
      expect(n.isSystemType, isFalse);
    });

    test('live_started sans message : texte de repli', () {
      final n = notificationFromJson({
        'id': 'n2',
        'type': 'live_started',
        'actorName': 'Paul',
        'liveId': 7,
        'createdAt': '2026-09-28T10:00:00+00:00',
      })!;
      expect(n.liveId, '7');
      expect(n.body, 'Paul est en direct');
    });

    test('parse organization_verified', () {
      final n = notificationFromJson({
        'id': 'n3',
        'type': 'organization_verified',
        'actorName': '',
        'message': 'Votre organisation est vérifiée',
        'isRead': true,
        'createdAt': '2026-09-28T10:00:00+00:00',
      })!;
      expect(n.type, NotificationType.organizationVerified);
      expect(n.isRead, isTrue);
      expect(n.isSystemType, isTrue);
      expect(n.liveId, isNull);
    });

    test('testimonyId est conservé pour un commentaire', () {
      final n = notificationFromJson({
        'id': 'n4',
        'type': 'comment',
        'actorName': 'Jean',
        'testimonyId': 't-9',
        'testimonyTitle': 'Guérison',
        'createdAt': '2026-09-28T10:00:00+00:00',
      })!;
      expect(n.type, NotificationType.comment);
      expect(n.testimonyId, 't-9');
      expect(n.copyWith(isRead: true).testimonyId, 't-9');
    });

    test('élément invalide → null', () {
      expect(notificationFromJson({'type': 'like'}), isNull);
      expect(notificationFromJson('oops'), isNull);
    });
  });

  group('FcmNavIntent.fromData', () {
    test('live_started lit live_id', () {
      final i = FcmNavIntent.fromData({
        'type': 'live_started',
        'live_id': 'live-42',
        'actor_id': 'u1',
        'notification_id': 'n1',
      })!;
      expect(i.type, 'live_started');
      expect(i.liveId, 'live-42');
      expect(i.testimonyId, isNull);
    });

    test('comment lit testimony_id', () {
      final i = FcmNavIntent.fromData({
        'type': 'comment',
        'testimony_id': 't-1',
      })!;
      expect(i.testimonyId, 't-1');
      expect(i.liveId, isNull);
    });

    test('type absent → null ; valeurs vides → null', () {
      expect(FcmNavIntent.fromData({'live_id': 'x'}), isNull);
      final i = FcmNavIntent.fromData({'type': 'live_started', 'live_id': ''})!;
      expect(i.liveId, isNull);
    });
  });
}
