// Réactions comptées une seule fois, partages visibles partout, suppression par la modération.
// Docs serveur : fonctionnalites/reactions.md, partage-interne.md

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/community/models/community_account.dart';
import 'package:testi_app/features/events/models/event_models.dart';
import 'package:testi_app/features/home/providers/home_providers.dart';
import 'package:testi_app/features/prayer/models/prayer_models.dart';
import 'package:testi_app/features/repost/content_interactions.dart';

Map<String, dynamic> _testimonyJson({Map<String, dynamic> extra = const {}}) => {
      'id': 't1',
      'userId': 'u1',
      'user': {'id': 'u1', 'display_name': 'Awa'},
      'title': 'Guérison',
      'type': 'text',
      'category': 'guerison',
      'bodyText': 'Texte',
      'stats': {'likesCount': 5, 'prayersCount': 2, 'commentsCount': 0},
      'isLikedByMe': true,
      'isPrayedByMe': false,
      'myReaction': 'fire',
      ...extra,
    };

void main() {
  test('le témoignage lit la réaction, le droit de suppression et le partage', () {
    final t = testimonyFromApiJson(_testimonyJson(extra: {
      'canDelete': true,
      'repostId': 'r1',
      'repostedBy': {'id': 'u2', 'display_name': 'Paul'},
      'repostComment': 'À lire',
      'repostedAt': '2026-10-09T08:00:00+00:00',
    }))!;
    expect(t.myReaction, 'fire');
    expect(t.canDelete, isTrue);
    expect(t.repost?.byName, 'Paul');
    expect(t.repost?.comment, 'À lire');

    // Sans « repostedBy » : pas de bandeau.
    expect(testimonyFromApiJson(_testimonyJson())!.repost, isNull);
  });

  test("l'état du serveur fait foi tant qu'on n'a pas réagi ici", () {
    final t = testimonyFromApiJson(_testimonyJson())!;
    const empty = TestimonyInteractions();
    expect(empty.likedOf(t), isTrue);
    expect(empty.reactionOf(t), ReactionType.fire);
    expect(empty.likesOf(t), 5); // la réaction de la personne est déjà comptée par le serveur

    // Changer de réaction ne change pas le compteur ; retirer le diminue d'une seule unité.
    final switched = empty.withEntry('t1', liked: true, prayed: false, reaction: ReactionType.love, counts: (likes: 5, prayers: 2));
    expect(switched.reactionOf(t), ReactionType.love);
    expect(switched.likesOf(t), 5);
    final removed = switched.withEntry('t1', liked: false, prayed: false, reaction: null, counts: (likes: 4, prayers: 2));
    expect(removed.likedOf(t), isFalse);
    expect(removed.reactionOf(t), isNull);
  });

  test("les valeurs de l'API correspondent aux réactions de l'application", () {
    for (final type in ReactionType.values) {
      expect(reactionTypeFromApi(type.apiValue), type == ReactionType.pray ? isNull : type);
    }
    expect(reactionTypeFromApi('amen'), ReactionType.glory); // anciennes réactions « Gloire »
  });

  test('événements, requêtes et sessions lisent réactions et partage', () {
    const reactions = {
      'likesCount': 3, 'prayersCount': 1, 'repostsCount': 2,
      'myReaction': 'like', 'myPrayerReaction': null, 'isRepostedByMe': true, 'canRepost': true,
    };
    const repost = {
      'id': 'p1', 'comment': 'Venez !', 'createdAt': '2026-10-09T08:00:00+00:00',
      'user': {'id': 'u2', 'displayName': 'Paul'},
    };

    final r = ContentReactions.fromJson(reactions);
    expect(r.isLiked, isTrue);
    expect(r.isPrayed, isFalse);
    expect(r.repostsCount, 2);

    final request = PrayerRequest.fromJson({'id': 'q1', 'body': 'Priez', 'reactions': reactions, 'repost': repost});
    expect(request.reactions.likesCount, 3);
    expect(request.repost?.byName, 'Paul');
    // « Je prie » : la mise à jour locale garde réactions et partage.
    expect(request.withPrayed(true).reactions.likesCount, 3);
    expect(request.withPrayed(true).repost?.comment, 'Venez !');

    final event = ChristianEvent.fromJson({
      'id': 'e1', 'title': 'Croisade', 'startsAt': '2026-11-01T10:00:00+00:00',
      'canDelete': true, 'reactions': reactions, 'repost': repost,
    });
    expect(event.canDelete, isTrue);
    expect(event.reactions.isRepostedByMe, isTrue);
    expect(event.repost?.comment, 'Venez !');
  });

  test('Communauté : onglet « Tous » envoyé au serveur', () {
    expect(CommunityTab.values.first, CommunityTab.all);
    expect(CommunityTab.all.apiValue, 'all');
  });
}
