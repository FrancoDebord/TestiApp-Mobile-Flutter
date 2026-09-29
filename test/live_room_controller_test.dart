import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/live/controllers/live_room_controller.dart';
import 'package:testi_app/features/live/data/live_repository.dart';
import 'package:testi_app/features/live/models/live_models.dart';

/// Faux dépôt : seules les méthodes appelées par les tests répondent.
class _FakeRepo implements LiveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

// JSON au format de LiveSessionResource (backend).
final _liveJson = {
  'id': '01a0d43f-0000-0000-0000-000000000001',
  'title': 'Guéri par la grâce',
  'description': null,
  'category': 'guerison',
  'status': 'live',
  'statusLabel': 'En direct',
  'commentsEnabled': true,
  'host': {'id': 'h1', 'displayName': 'Pasteur Jean', 'initials': 'PJ', 'avatarUrl': null},
  'stats': {'peakViewers': 12, 'commentCount': 3, 'reactions': {'like': 4, 'pray': 2, 'amen': 0, 'fire': 1}},
  'isHost': false,
  'canModerate': false,
  'webUrl': 'https://testi.airid-africa.com/lives/01a0d43f',
  'startedAt': '2026-09-25T10:00:00+00:00',
  'endedAt': null,
  'endReason': null,
  'createdAt': '2026-09-25T09:55:00+00:00',
};

Map<String, dynamic> _comment(String id, String userId, String body) => {
      'id': id,
      'body': body,
      'createdAt': '2026-09-25T10:01:00+00:00',
      'user': {'id': userId, 'displayName': 'Marie', 'initials': 'M', 'avatarUrl': null},
    };

LiveRoomController _controller({String? me}) => LiveRoomController(
      repository: _FakeRepo(),
      live: LiveSession.fromJson(_liveJson),
      isHostMode: false,
      currentUserId: me,
    );

void main() {
  test('lit un direct au format LiveSessionResource', () {
    final live = LiveSession.fromJson(_liveJson);
    expect(live.isOnAir, isTrue);
    expect(live.host.displayName, 'Pasteur Jean');
    expect(live.peakViewers, 12);
    expect(live.reactions[LiveReactionType.like], 4);
    expect(live.reactions.total, 7);
    expect(live.startedAt, DateTime.utc(2026, 9, 25, 10));
  });

  test('lit la réponse de GET /lives', () {
    final index = LivesIndex.fromJson({
      'configured': true,
      'canGoLive': true,
      'active': [_liveJson],
      'recent': [
        {..._liveJson, 'id': 'x2', 'status': 'ended', 'endReason': 'moderator'}
      ],
    });
    expect(index.active.single.title, 'Guéri par la grâce');
    expect(index.recent.single.status, LiveStatus.ended);
    expect(index.recent.single.endReasonLabel, 'Coupé par la modération');
  });

  test('commentaires : ajout sans doublon, masquage', () {
    final c = _controller();
    final ev = LiveEvent.fromJson({'type': 'comment', 'comment': _comment('c1', 'u1', 'Amen !')})!;
    c.handleEvent(ev);
    c.handleEvent(ev); // même message reçu deux fois (temps réel + secours)
    expect(c.comments.map((x) => x.id), ['c1']);

    c.handleEvent(LiveEvent.fromJson({'type': 'comment_hidden', 'id': 'c1'})!);
    expect(c.comments, isEmpty);
  });

  test('exclusion : retire ses commentaires et bloque si c\'est moi', () {
    final c = _controller(me: 'u2');
    c.handleEvent(LiveEvent.fromJson({'type': 'comment', 'comment': _comment('c1', 'u1', 'a')})!);
    c.handleEvent(LiveEvent.fromJson({'type': 'comment', 'comment': _comment('c2', 'u2', 'b')})!);

    c.handleEvent(LiveEvent.fromJson({'type': 'user_banned', 'userId': 'u1'})!);
    expect(c.comments.map((x) => x.id), ['c2']);
    expect(c.banned, isFalse);

    c.handleEvent(LiveEvent.fromJson({'type': 'user_banned', 'userId': 'u2'})!);
    expect(c.comments, isEmpty);
    expect(c.banned, isTrue);
  });

  test('réaction : compteurs du serveur + animation', () {
    final c = _controller();
    c.handleEvent(LiveEvent.fromJson({
      'type': 'reaction',
      'reaction': 'amen',
      'counts': {'like': 4, 'pray': 2, 'amen': 5, 'fire': 1},
    })!);
    expect(c.reactions[LiveReactionType.amen], 5);
    expect(c.floatingReactions.single.type, LiveReactionType.amen);
  });

  test('commentaire épinglé : lecture initiale, épinglage, désépinglage', () {
    final live = LiveSession.fromJson({
      ..._liveJson,
      'pinnedComment': _comment('p0', 'h1', 'Bienvenue !'),
    });
    expect(live.pinnedComment?.body, 'Bienvenue !');

    final c = _controller();
    expect(c.pinnedComment, isNull);

    c.handleEvent(LiveEvent.fromJson(
        {'type': 'comment_pinned', 'comment': _comment('c9', 'h1', 'Priez avec moi')})!);
    expect(c.pinnedComment?.id, 'c9');

    c.handleEvent(LiveEvent.fromJson({'type': 'comment_unpinned'})!);
    expect(c.pinnedComment, isNull);
  });

  test('masquer ou exclure retire aussi l\'épinglage', () {
    final c = _controller();
    c.handleEvent(LiveEvent.fromJson(
        {'type': 'comment_pinned', 'comment': _comment('c1', 'u1', 'x')})!);
    c.handleEvent(LiveEvent.fromJson({'type': 'comment_hidden', 'id': 'c1'})!);
    expect(c.pinnedComment, isNull);

    c.handleEvent(LiveEvent.fromJson(
        {'type': 'comment_pinned', 'comment': _comment('c2', 'u2', 'y')})!);
    c.handleEvent(LiveEvent.fromJson({'type': 'user_banned', 'userId': 'u2'})!);
    expect(c.pinnedComment, isNull);
  });

  test('réaction « Adorer » (worship) reconnue', () {
    final counts = LiveReactionCounts.fromJson({'worship': 3});
    expect(counts[LiveReactionType.worship], 3);
  });

  test('fin du direct', () {
    final c = _controller();
    c.handleEvent(LiveEvent.fromJson({'type': 'ended', 'reason': 'host'})!);
    expect(c.ended, isTrue);
    expect(c.endReason, 'host');
    expect(liveEndReasonLabel(c.endReason), 'Terminé par le diffuseur');
  });

  // ── Intervenants (docs/fonctionnalites/lives-intervenants.md du backend) ──

  Map<String, dynamic> speaker(String id, String userId, String status, {int? position, String? message}) => {
        'id': id,
        'status': status,
        'camera': status == 'on_stage',
        'position': ?position,
        'message': ?message,
        'expiresAt': status == 'invited' ? '2026-09-29T10:01:00+00:00' : null,
        'user': {'id': userId, 'displayName': 'Awa', 'initials': 'A', 'avatarUrl': null},
      };

  test('lit l\'état de la scène (GET /lives/{id}/stage)', () {
    final s = LiveStageState.fromJson({
      'enabled': true,
      'current': speaker('s1', 'u1', 'on_stage'),
      'queueCount': 2,
      'queue': [speaker('s2', 'u2', 'waiting', position: 1, message: 'Guérison')],
      'mine': speaker('s3', 'me', 'waiting', position: 2),
      'canRequest': false,
      'refusal': 'Vous avez déjà une demande en cours.',
      'inviteTimeout': 60,
    });
    expect(s.onStage?.user.id, 'u1');
    expect(s.onStage?.camera, isTrue);
    expect(s.queue!.single.message, 'Guérison');
    expect(s.queue!.single.position, 1);
    expect(s.mine?.status, LiveSpeakerStatus.waiting);
    expect(s.refusal, contains('déjà'));

    // Spectateur : pas de file détaillée ; invité → pas encore « à l'antenne ».
    final viewer = LiveStageState.fromJson({'queueCount': 3, 'queue': null, 'current': speaker('s1', 'u1', 'invited')});
    expect(viewer.queue, isNull);
    expect(viewer.current?.isInvited, isTrue);
    expect(viewer.onStage, isNull);
  });

  test('message temps réel « stage » reconnu', () {
    final e = LiveEvent.fromJson({'type': 'stage', 'event': 'ended', 'reason': 'removed', 'speaker': speaker('s1', 'u1', 'done')});
    expect(e, isA<LiveStageEvent>());
    final stage = e! as LiveStageEvent;
    expect(stage.event, 'ended');
    expect(stage.reason, 'removed');
    expect(stage.speaker?.status, LiveSpeakerStatus.closed);
  });

  test('invitation reçue : exposée une fois, pas pour les autres', () {
    final c = _controller(me: 'me');
    c.applyStageForTest(LiveStageState.fromJson({'mine': speaker('s9', 'me', 'waiting', position: 1)}));
    expect(c.pendingInvitation, isNull);

    c.applyStageForTest(LiveStageState.fromJson({
      'current': speaker('s9', 'me', 'invited'),
      'mine': speaker('s9', 'me', 'invited'),
    }));
    expect(c.pendingInvitation?.id, 's9');
    expect(c.pendingInvitation?.expiresAt, isNotNull);
  });

  test('nouvelle demande : prévient le diffuseur, pas les spectateurs', () {
    final host = LiveRoomController(
      repository: _FakeRepo(),
      live: LiveSession.fromJson(_liveJson),
      isHostMode: true,
      currentUserId: 'h1',
    );
    host.handleEvent(LiveEvent.fromJson({'type': 'stage', 'event': 'requested', 'speaker': speaker('s1', 'u1', 'waiting')})!);
    expect(host.takeStageNotice(), 'Awa demande à intervenir.');
    expect(host.takeStageNotice(), isNull, reason: 'lu une seule fois');

    final viewer = _controller(me: 'u2');
    viewer.handleEvent(LiveEvent.fromJson({'type': 'stage', 'event': 'requested', 'speaker': speaker('s1', 'u1', 'waiting')})!);
    expect(viewer.takeStageNotice(), isNull);
  });

  test('seul le diffuseur (host-…) va dans le lecteur principal', () {
    expect(LiveRoomController.isHostIdentity('host-01a0'), isTrue);
    expect(LiveRoomController.isHostIdentity('user-01a0-abcd1234'), isFalse);
  });

  test('messages inconnus ou mal formés ignorés', () {
    expect(LiveEvent.fromJson({'type': 'autre'}), isNull);
    expect(LiveEvent.fromJson({'type': 'comment', 'comment': 'oops'}), isNull);
  });
}
