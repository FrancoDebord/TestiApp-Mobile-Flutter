import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/notifications/models/notification_models.dart';
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/features/profile/models/profile_models.dart';
import 'package:testi_app/services/push_service.dart';
import 'package:testi_app/shared/models/user_model.dart';

// Alignement sur l'API (journal serveur du 2026-10-06) : notifications follow /
// share / mention / prayer / testimony_rejected, réglages, profil (bio, mot de passe).
void main() {
  Map<String, dynamic> notif(String type, [Map<String, dynamic> extra = const {}]) => {
        'id': 'n-$type',
        'type': type,
        'actorName': 'Awa',
        'createdAt': '2026-10-06T10:00:00+00:00',
        ...extra,
      };

  group('notifications', () {
    test('follow : texte du serveur et profil de l\'abonné', () {
      final n = notificationFromJson(notif('follow', {
        'actorId': 'u-1',
        'message': 'Awa vous suit maintenant',
      }))!;
      expect(n.type, NotificationType.follow);
      expect(n.actorId, 'u-1');
      expect(n.body, 'Awa vous suit maintenant');
      expect(n.title, 'Nouvel abonné');
    });

    test('share : n\'est plus présenté comme un « j\'aime »', () {
      final n = notificationFromJson(notif('share', {
        'testimonyId': 't-1',
        'testimonyTitle': 'Guérison',
        'message': 'Awa a partagé votre témoignage « Guérison »',
      }))!;
      expect(n.type, NotificationType.share);
      expect(n.body, 'Awa a partagé votre témoignage « Guérison »');
      expect(n.isReactionType, isTrue);
    });

    test('mention : message du serveur, direct et verset du jour', () {
      final live = notificationFromJson(notif('mention', {
        'liveId': 'l-1',
        'message': 'Awa vous a mentionné dans un direct',
      }))!;
      expect(live.type, NotificationType.mention);
      expect(live.liveId, 'l-1');
      expect(live.body, 'Awa vous a mentionné dans un direct');
      expect(live.isCommentType, isTrue);

      final verse = notificationFromJson(notif('mention', {'dailyVerseId': 12}))!;
      expect(verse.dailyVerseId, '12');
      expect(verse.body, 'Awa vous a mentionné');
    });

    test('prayer sur un témoignage et testimony_rejected', () {
      final prayer = notificationFromJson(notif('prayer', {'testimonyTitle': 'Guérison'}))!;
      expect(prayer.type, NotificationType.prayer);

      final rejected = notificationFromJson(notif('testimony_rejected', {
        'testimonyTitle': 'Guérison',
        'message': 'Votre témoignage "Guérison" a été rejeté : Spam',
      }))!;
      expect(rejected.type, NotificationType.rejected);
      expect(rejected.body, contains('rejeté'));
      expect(rejected.isSystemType, isTrue);
    });

    test('push : actor_id et daily_verse_id', () {
      final intent = FcmNavIntent.fromData({
        'type': 'follow',
        'actor_id': 'u-9',
        'daily_verse_id': '3',
      })!;
      expect(intent.actorId, 'u-9');
      expect(intent.dailyVerseId, '3');
    });
  });

  group('réglages', () {
    test('lecture des clés du serveur et envoi', () {
      final s = UserSettings.fromJson({
        'push_comments': true,
        'push_likes': false,
        'push_prayers': 1,
        'push_approval': '0',
        'comment_permission': 'followers',
      });
      expect(s.pushLikes, isFalse);
      expect(s.pushPrayers, isTrue);
      expect(s.pushApproval, isFalse);
      expect(s.commentPermission, CommentPermission.followers);
      expect(s.toJson()['comment_permission'], 'followers');
      expect(s.toJson()['push_likes'], isFalse);
    });

    test('valeur inconnue : tout le monde', () {
      expect(CommentPermission.fromJson(null), CommentPermission.everyone);
      expect(CommentPermission.fromJson('nobody'), CommentPermission.nobody);
    });
  });

  group('profil', () {
    test('bio et has_password lus depuis UserResource', () {
      final u = UserModel.fromJson({
        'id': 'u-1',
        'display_name': 'Awa',
        'bio': 'Servante de Dieu',
        'country': 'Bénin',
        'has_password': false,
      });
      expect(u.bio, 'Servante de Dieu');
      expect(u.hasPassword, isFalse);
      expect(UserModel.fromJson(u.toJson()).bio, 'Servante de Dieu');
    });

    test('has_password absent (ancien serveur) : mot de passe supposé', () {
      final u = UserModel.fromJson({'id': 'u-2', 'display_name': 'Paul'});
      expect(u.hasPassword, isTrue);
      expect(u.bio, '');
    });
  });
}
