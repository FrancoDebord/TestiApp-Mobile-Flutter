import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../data/live_repository.dart';
import '../models/live_models.dart';

/// État de la liaison avec la salle vidéo.
enum LiveLinkState { idle, connecting, connected, reconnecting, disconnected }

/// Réaction affichée brièvement à l'écran (animation « qui monte »).
class FloatingReaction {
  FloatingReaction(this.type) : id = _next++;
  static int _next = 0;
  final int id;
  final LiveReactionType type;
}

/// Pilote une salle de direct, côté spectateur ou diffuseur.
///
/// - La vidéo passe par LiveKit (`livekit_client`).
/// - Commentaires et réactions passent **toujours par l'API Laravel**
///   (contrôles, limites, modération), qui les rediffuse dans la salle :
///   ils arrivent ici via `DataReceivedEvent` (sujet `live`).
/// - Secours si un message se perd : audience toutes les 15 s,
///   commentaires toutes les 30 s.
class LiveRoomController extends ChangeNotifier {
  LiveRoomController({
    required LiveRepository repository,
    required LiveSession live,
    required this.isHostMode,
    this.currentUserId,
  })  : _repo = repository,
        _live = live,
        _reactions = live.liveStats?.reactions ?? live.reactions,
        _viewers = live.liveStats?.viewers ?? 0,
        _pinned = live.pinnedComment;

  final LiveRepository _repo;
  final bool isHostMode;
  final String? currentUserId;

  static const _maxComments = 200;

  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  Timer? _statsTimer;
  Timer? _commentsTimer;
  bool _disposed = false;

  // ── État exposé ──────────────────────────────────────────────────────────

  LiveSession _live;
  LiveSession get live => _live;

  LiveLinkState _link = LiveLinkState.idle;
  LiveLinkState get link => _link;

  lk.VideoTrack? _video;

  /// Vidéo à afficher en grand : la caméra du diffuseur (distante ou locale),
  /// jamais celle d'un intervenant.
  lk.VideoTrack? get video => _video;

  lk.VideoTrack? _guestVideo;

  /// Vidéo de l'intervenant à l'antenne (médaillon), ou sa propre caméra
  /// quand la personne connectée est elle-même à l'antenne.
  lk.VideoTrack? get guestVideo => _guestVideo;

  // ── Intervenants (un à la fois) — docs/fonctionnalites/lives-intervenants.md

  LiveStageState _stage = LiveStageState.empty;
  LiveStageState get stage => _stage;

  bool _onStage = false;

  /// La personne connectée est elle-même à l'antenne (micro ouvert).
  bool get onStage => _onStage;

  bool _stageBusy = false;
  bool get stageBusy => _stageBusy;

  bool _stageMic = true;
  bool get stageMicEnabled => _stageMic;

  bool _stageCamera = false;
  bool get stageCameraEnabled => _stageCamera;

  String? _stageNotice;

  /// Message ponctuel à afficher (fin d'intervention…), lu une seule fois.
  String? takeStageNotice() {
    final n = _stageNotice;
    _stageNotice = null;
    return n;
  }

  /// Invitation reçue par la personne connectée et pas encore acceptée.
  LiveSpeaker? get pendingInvitation =>
      !_onStage && _stage.mine?.isInvited == true ? _stage.mine : null;

  /// Identité LiveKit du diffuseur (« host-{id} ») : sa caméra va dans le lecteur principal.
  static bool isHostIdentity(String identity) => identity.startsWith('host-');

  final List<LiveComment> _comments = [];
  List<LiveComment> get comments => List.unmodifiable(_comments);

  LiveReactionCounts _reactions;
  LiveReactionCounts get reactions => _reactions;

  LiveComment? _pinned;

  /// Commentaire épinglé en haut du direct (null : aucun).
  LiveComment? get pinnedComment => _pinned;

  /// Peut épingler, désépingler ou remplacer le message épinglé : le message écrit par le
  /// diffuseur ne se retire que par lui (un modérateur qui regarde est un spectateur).
  /// Même règle côté serveur (403).
  bool get canChangePin =>
      canModerate && (isHostMode || _pinned == null || _pinned!.user.id != _live.host.id);

  final List<FloatingReaction> _floating = [];
  List<FloatingReaction> get floatingReactions => List.unmodifiable(_floating);

  int _viewers;
  int get viewers => _viewers;

  int _peakViewers = 0;
  int get peakViewers => _peakViewers;

  bool _ended = false;
  bool get ended => _ended;

  String? _endReason;
  String? get endReason => _endReason;

  /// Exclu du direct par la modération : ne peut plus commenter ni réagir.
  bool _banned = false;
  bool get banned => _banned;

  String? _error;
  String? get error => _error;

  bool _micEnabled = true;
  bool get micEnabled => _micEnabled;

  bool _cameraEnabled = true;
  bool get cameraEnabled => _cameraEnabled;

  lk.CameraPosition _cameraPosition = lk.CameraPosition.front;
  lk.CameraPosition get cameraPosition => _cameraPosition;

  lk.ConnectionQuality _quality = lk.ConnectionQuality.unknown;
  lk.ConnectionQuality get connectionQuality => _quality;

  bool get canModerate => _live.canModerate || isHostMode;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Connexion ────────────────────────────────────────────────────────────

  /// Spectateur : jeton lecture seule, puis connexion à la salle.
  Future<void> joinAsViewer() async {
    _setLink(LiveLinkState.connecting);
    try {
      await _loadComments();
      final creds = await _repo.viewerToken(_live.id);
      await _connect(creds);
      _grabRemoteVideo();
      unawaited(_loadStage());
      _startPolling();
    } on LiveFailure catch (e) {
      if (e.isEnded) {
        _markEnded(null);
      } else {
        _fail(e.message);
      }
    } catch (e) {
      _fail('Impossible de rejoindre le direct.');
      debugPrint('[Live] joinAsViewer: $e');
    }
  }

  /// Diffuseur : connexion avec son jeton puis publication de la caméra et
  /// du micro. Le direct reste « en préparation » (invisible du public)
  /// jusqu'à [goLive]. Renvoie true si la caméra est bien publiée.
  ///
  /// [previewTrack] : piste caméra déjà ouverte pour l'aperçu (réutilisée,
  /// pour ne pas rouvrir la caméra).
  Future<bool> connectAsHost(
    LiveCredentials creds, {
    lk.LocalVideoTrack? previewTrack,
    lk.CameraPosition cameraPosition = lk.CameraPosition.front,
  }) async {
    _cameraPosition = cameraPosition;
    _setLink(LiveLinkState.connecting);
    try {
      await _loadComments();
      await _connect(creds);
      final local = _room!.localParticipant!;

      if (previewTrack != null) {
        await local.publishVideoTrack(previewTrack);
        _video = previewTrack;
      } else {
        await local.setCameraEnabled(
          true,
          cameraCaptureOptions: lk.CameraCaptureOptions(
            cameraPosition: cameraPosition,
          ),
        );
        _video = _localVideo();
      }
      await local.setMicrophoneEnabled(true);
      unawaited(_loadStage());
      _startPolling();
      _notify();
      return true;
    } on LiveFailure catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail("La caméra n'a pas pu être diffusée. Réessayez.");
      debugPrint('[Live] connectAsHost: $e');
    }
    return false;
  }

  bool _goingLive = false;
  bool get goingLive => _goingLive;

  /// Passage à l'antenne : le direct devient public.
  /// Renvoie un message d'erreur, ou null si réussi.
  Future<String?> goLive() async {
    if (_live.isOnAir || _goingLive) return null;
    _goingLive = true;
    _notify();
    try {
      _live = await _repo.goLive(_live.id);
      return null;
    } on LiveFailure catch (e) {
      return e.message;
    } finally {
      _goingLive = false;
      _notify();
    }
  }

  Future<void> _connect(LiveCredentials creds) async {
    if (creds.url.isEmpty || creds.token.isEmpty) {
      throw const LiveFailure('Le service vidéo n\'est pas configuré.',
          statusCode: 503);
    }
    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        // Qualité adaptée à la taille d'affichage et au réseau de chacun.
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    _room = room;
    _listener = room.createListener()
      ..on<lk.DataReceivedEvent>(_onData)
      // Caméra du diffuseur en grand ; celle d'un intervenant dans le médaillon.
      ..on<lk.TrackSubscribedEvent>((e) {
        if (e.track is! lk.VideoTrack) return;
        if (!isHostMode && isHostIdentity(e.participant.identity)) {
          _video = e.track as lk.VideoTrack;
        } else if (!_onStage) {
          _guestVideo = e.track as lk.VideoTrack;
        }
        _notify();
      })
      ..on<lk.TrackUnsubscribedEvent>((e) {
        if (identical(e.track, _video)) _video = null;
        if (identical(e.track, _guestVideo)) _guestVideo = null;
        _notify();
      })
      ..on<lk.TrackMutedEvent>((_) => _notify())
      ..on<lk.TrackUnmutedEvent>((_) => _notify())
      ..on<lk.ParticipantDisconnectedEvent>((_) => _notify())
      // Droits retirés par le serveur (fin de l'intervention) : micro et caméra coupés ici aussi.
      ..on<lk.ParticipantPermissionsUpdatedEvent>((e) {
        if (e.participant is lk.LocalParticipant &&
            _onStage &&
            !e.permissions.canPublish) {
          unawaited(_stopStageLocally('removed'));
        }
      })
      ..on<lk.RoomReconnectingEvent>((_) => _setLink(LiveLinkState.reconnecting))
      ..on<lk.RoomReconnectedEvent>((_) {
        _setLink(LiveLinkState.connected);
        // Rattraper ce qui a pu être manqué pendant la coupure.
        unawaited(_refreshStats());
        unawaited(_loadComments());
      })
      ..on<lk.ParticipantConnectionQualityUpdatedEvent>((e) {
        if (e.participant is lk.LocalParticipant) {
          _quality = e.connectionQuality;
          _notify();
        }
      })
      ..on<lk.RoomDisconnectedEvent>((e) {
        if (e.reason == lk.DisconnectReason.roomDeleted ||
            e.reason == lk.DisconnectReason.participantRemoved) {
          _markEnded(_endReason);
        } else if (!_ended && !_disposed) {
          _setLink(LiveLinkState.disconnected);
        }
      });

    await room.connect(creds.url, creds.token);
    _setLink(LiveLinkState.connected);
  }

  /// Pistes déjà présentes à l'arrivée : diffuseur en grand, intervenant en médaillon.
  void _grabRemoteVideo() {
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (t == null) continue;
        if (!isHostMode && isHostIdentity(p.identity)) {
          _video = t;
        } else {
          _guestVideo = t;
        }
      }
    }
    _notify();
  }

  /// Participant LiveKit de l'intervenant annoncé par le serveur (identité « user-{id}-… »).
  lk.RemoteParticipant? get guestParticipant {
    final userId = _stage.onStage?.user.id;
    if (userId == null) return null;
    for (final p in _room?.remoteParticipants.values ?? const <lk.RemoteParticipant>[]) {
      if (p.identity.startsWith('user-$userId-')) return p;
    }
    return null;
  }

  /// Micro de l'intervenant coupé (médaillon).
  bool get guestMicMuted {
    if (_onStage) return !_stageMic;
    final p = guestParticipant;
    if (p == null) return false;
    final mic = p.audioTrackPublications;
    return mic.isEmpty || mic.every((pub) => pub.muted);
  }

  lk.LocalVideoTrack? _localVideo() {
    final pubs = _room?.localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return null;
    return pubs.first.track;
  }

  // ── Messages temps réel ──────────────────────────────────────────────────

  void _onData(lk.DataReceivedEvent e) {
    if (e.topic != null && e.topic != 'live') return;
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(e.data));
      if (decoded is! Map) return;
      json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    final event = LiveEvent.fromJson(json);
    if (event != null) handleEvent(event);
  }

  /// Applique un message temps réel (public pour les tests).
  @visibleForTesting
  void handleEvent(LiveEvent event) {
    switch (event) {
      case LiveStatusEvent(:final status):
        if (status == LiveStatus.live && !_live.isOnAir) {
          unawaited(_reloadLive());
        }
      case LiveCommentEvent(:final comment):
        _addComment(comment);
      case LiveCommentHiddenEvent(:final commentId):
        _comments.removeWhere((c) => c.id == commentId);
        if (_pinned?.id == commentId) _pinned = null;
      case LiveUserBannedEvent(:final userId):
        _comments.removeWhere((c) => c.user.id == userId);
        if (_pinned?.user.id == userId) _pinned = null;
        if (currentUserId != null && userId == currentUserId) _banned = true;
      case LiveCommentPinnedEvent(:final comment):
        _pinned = comment;
      case LiveCommentUnpinnedEvent():
        _pinned = null;
      case LiveReactionEvent(:final reaction, :final counts):
        _reactions = counts;
        if (reaction != null) _pushFloating(reaction);
      case LiveEndedEvent(:final reason):
        _markEnded(reason);
        return;
      case LiveStageEvent(:final event, :final speaker, :final reason):
        // Fin de sa propre intervention : micro et caméra coupés aussitôt.
        if (event == 'ended' && _onStage && speaker?.user.id == currentUserId) {
          unawaited(_stopStageLocally(reason));
        }
        if (event == 'requested' && canModerate && speaker != null) {
          _stageNotice = '${speaker.user.displayName} demande à intervenir.';
        }
        // Le message ne contient pas tout (ni le sujet ni la file) : état rechargé.
        unawaited(_loadStage());
    }
    _notify();
  }

  void _addComment(LiveComment c) {
    if (_comments.any((x) => x.id == c.id)) return;
    _comments.add(c);
    if (_comments.length > _maxComments) {
      _comments.removeRange(0, _comments.length - _maxComments);
    }
  }

  void _pushFloating(LiveReactionType type) {
    final f = FloatingReaction(type);
    _floating.add(f);
    if (_floating.length > 12) _floating.removeAt(0);
    Future<void>.delayed(const Duration(milliseconds: 2400), () {
      _floating.remove(f);
      _notify();
    });
  }

  // ── Rafraîchissements de secours ─────────────────────────────────────────

  void _startPolling() {
    _statsTimer?.cancel();
    _commentsTimer?.cancel();
    unawaited(_refreshStats());
    _statsTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => unawaited(_refreshStats()));
    _commentsTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => unawaited(_loadComments()));
  }

  Future<void> _refreshStats() async {
    if (_ended || _disposed) return;
    try {
      final s = await _repo.stats(_live.id);
      _viewers = s.viewers;
      _peakViewers = s.peakViewers;
      _reactions = s.reactions;
      _pinned = s.pinnedComment; // secours si un message d'épinglage s'est perdu
      if (s.status == LiveStatus.ended) {
        _markEnded(_endReason);
        return;
      }
      if (s.status == LiveStatus.live && !_live.isOnAir) {
        await _reloadLive();
      }
      await _loadStage(); // secours si un message « stage » s'est perdu
      _notify();
    } on LiveFailure catch (e) {
      if (e.isEnded) _markEnded(_endReason);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    if (_disposed) return;
    try {
      final list = await _repo.comments(_live.id);
      // Liste serveur = vérité (commentaires masqués retirés), plus les
      // éventuels messages temps réel arrivés entre-temps.
      final serverIds = list.map((c) => c.id).toSet();
      final newer = _comments.where((c) => !serverIds.contains(c.id)).toList();
      _comments
        ..clear()
        ..addAll(list)
        ..addAll(newer);
      _notify();
    } catch (_) {}
  }

  Future<void> _reloadLive() async {
    try {
      _live = await _repo.show(_live.id);
      _notify();
    } catch (_) {}
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  /// Publie un commentaire ; [pin] l'épingle aussitôt (diffuseur /
  /// modérateurs). Renvoie un message d'erreur, ou null si réussi.
  Future<String?> sendComment(String body, {bool pin = false}) async {
    final text = body.trim();
    if (text.isEmpty) return null;
    try {
      final c = await _repo.postComment(_live.id, text);
      _addComment(c);
      _notify();
      return pin ? await pinComment(c) : null;
    } on LiveFailure catch (e) {
      if (e.statusCode == 403) _banned = true;
      _notify();
      return e.message;
    }
  }

  /// Envoie une réaction (affichée tout de suite). Renvoie une erreur ou null.
  Future<String?> react(LiveReactionType type) async {
    _pushFloating(type);
    _notify();
    try {
      _reactions = await _repo.react(_live.id, type);
      _notify();
      return null;
    } on LiveFailure catch (e) {
      return e.statusCode == 429
          ? 'Doucement ! Trop de réactions en peu de temps.'
          : e.message;
    }
  }

  Future<String?> pinComment(LiveComment c) async {
    try {
      _pinned = await _repo.pinComment(_live.id, c.id);
      _notify();
      return null;
    } on LiveFailure catch (e) {
      return e.message;
    }
  }

  Future<String?> unpinComment() async {
    final previous = _pinned;
    _pinned = null; // retrait immédiat, rétabli en cas d'échec
    _notify();
    try {
      await _repo.unpinComment(_live.id);
      return null;
    } on LiveFailure catch (e) {
      _pinned = previous;
      _notify();
      return e.message;
    }
  }

  Future<String?> hideComment(LiveComment c) async {
    try {
      await _repo.hideComment(_live.id, c.id);
      _comments.removeWhere((x) => x.id == c.id);
      if (_pinned?.id == c.id) _pinned = null;
      _notify();
      return null;
    } on LiveFailure catch (e) {
      return e.message;
    }
  }

  Future<String?> banUser(LivePerson user) async {
    try {
      await _repo.ban(_live.id, user.id);
      _comments.removeWhere((x) => x.user.id == user.id);
      if (_pinned?.user.id == user.id) _pinned = null;
      _notify();
      return null;
    } on LiveFailure catch (e) {
      return e.message;
    }
  }

  /// Terminer (diffuseur) ou couper (modérateur).
  Future<String?> endLive() async {
    try {
      _live = await _repo.end(_live.id);
      _markEnded(_live.endReason ?? (isHostMode ? 'host' : 'moderator'));
      return null;
    } on LiveFailure catch (e) {
      if (e.isEnded) {
        _markEnded(_endReason);
        return null;
      }
      return e.message;
    }
  }

  // ── Intervenants ─────────────────────────────────────────────────────────

  Future<void> _loadStage() async {
    if (_ended || _disposed) return;
    try {
      _applyStage(await _repo.stage(_live.id));
    } catch (_) {}
  }

  @visibleForTesting
  void applyStageForTest(LiveStageState s) => _applyStage(s);

  void _applyStage(LiveStageState s) {
    _stage = s;
    // Plus à l'antenne selon le serveur (retiré, coupure…) : on coupe localement.
    if (_onStage && s.mine?.isOnStage != true) {
      unawaited(_stopStageLocally(null));
    }
    // Personne à l'antenne : le médaillon disparaît.
    if (!_onStage && s.onStage == null) _guestVideo = null;
    _notify();
  }

  /// Exécute une action de scène ; renvoie un message d'erreur, ou null.
  Future<String?> _stageAction(Future<LiveStageState> Function() call) async {
    if (_stageBusy) return null;
    _stageBusy = true;
    _notify();
    try {
      _applyStage(await call());
      return null;
    } on LiveFailure catch (e) {
      unawaited(_loadStage());
      return e.message;
    } finally {
      _stageBusy = false;
      _notify();
    }
  }

  /// Spectateur connecté : demander à intervenir ([message] : sujet, facultatif).
  Future<String?> requestToSpeak({String? message}) =>
      _stageAction(() => _repo.requestStage(_live.id, message: message));

  /// Retirer sa demande, ou refuser l'invitation reçue.
  Future<String?> withdrawStageRequest() =>
      _stageAction(() => _repo.withdrawStage(_live.id));

  /// Accepter l'invitation : le serveur ouvre micro (et caméra) sur la connexion
  /// en cours, puis on publie. Renvoie un message d'erreur, ou null.
  Future<String?> acceptInvitation({required bool camera}) async {
    final local = _room?.localParticipant;
    if (local == null) return 'Vous n\'êtes pas connecté au direct.';
    final err = await _stageAction(() =>
        _repo.acceptStage(_live.id, identity: local.identity, camera: camera));
    if (err != null) return err;

    // Le droit de publier arrive par la salle juste après la réponse du serveur.
    for (var i = 0; i < 40 && !local.permissions.canPublish; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!local.permissions.canPublish) {
      return 'Le service vidéo n\'a pas encore ouvert votre micro. Réessayez.';
    }
    try {
      _onStage = true;
      _stageMic = true;
      _stageCamera = camera;
      await local.setMicrophoneEnabled(true);
      if (camera) {
        await local.setCameraEnabled(true,
            cameraCaptureOptions:
                const lk.CameraCaptureOptions(cameraPosition: lk.CameraPosition.front));
        _guestVideo = _localVideo();
      } else {
        _guestVideo = null;
      }
      _notify();
      return null;
    } catch (e) {
      debugPrint('[Live] acceptInvitation: $e');
      await _stopStageLocally(null, silent: true);
      await _repo.withdrawStage(_live.id).catchError((_) => _stage);
      return 'Micro inaccessible. Autorisez-le dans les réglages du téléphone.';
    }
  }

  /// Terminer sa propre intervention.
  Future<String?> leaveStage() async {
    await _stopStageLocally('left');
    return _stageAction(() => _repo.withdrawStage(_live.id));
  }

  Future<void> toggleStageMic() async {
    final local = _room?.localParticipant;
    if (local == null || !_onStage) return;
    _stageMic = !_stageMic;
    _notify();
    await local.setMicrophoneEnabled(_stageMic);
  }

  Future<void> toggleStageCamera() async {
    final local = _room?.localParticipant;
    if (local == null || !_onStage) return;
    _stageCamera = !_stageCamera;
    _notify();
    try {
      await local.setCameraEnabled(_stageCamera,
          cameraCaptureOptions:
              const lk.CameraCaptureOptions(cameraPosition: lk.CameraPosition.front));
    } catch (_) {
      _stageCamera = !_stageCamera;
    }
    _guestVideo = _stageCamera ? _localVideo() : null;
    _notify();
  }

  /// Fin de l'intervention côté téléphone : micro et caméra libérés.
  Future<void> _stopStageLocally(String? reason, {bool silent = false}) async {
    if (!_onStage) return;
    _onStage = false;
    _guestVideo = null;
    final local = _room?.localParticipant;
    try {
      await local?.setMicrophoneEnabled(false);
      await local?.setCameraEnabled(false);
    } catch (_) {
      // Déjà dépubliés par le serveur.
    }
    if (!silent) {
      _stageNotice = switch (reason) {
        'removed' => 'Le diffuseur a terminé votre intervention. Merci pour votre témoignage !',
        'banned' => 'Un modérateur vous a retiré de l\'antenne.',
        'disconnected' => 'Connexion perdue : vous n\'êtes plus à l\'antenne.',
        _ => 'Votre intervention est terminée. Merci pour votre témoignage !',
      };
    }
    _notify();
  }

  /// Diffuseur / modération : inviter la personne (une seule à la fois).
  Future<String?> inviteSpeaker(LiveSpeaker s) =>
      _stageAction(() => _repo.speakerAction(_live.id, s.id, 'invite'));

  /// Diffuseur / modération : retirer de la file, ou annuler l'invitation.
  Future<String?> declineSpeaker(LiveSpeaker s) =>
      _stageAction(() => _repo.speakerAction(_live.id, s.id, 'decline'));

  /// Diffuseur / modération : terminer l'intervention (micro et caméra coupés pour tous).
  Future<String?> removeSpeaker(LiveSpeaker s) =>
      _stageAction(() => _repo.speakerAction(_live.id, s.id, 'remove'));

  Future<String?> setStageEnabled(bool enabled) =>
      _stageAction(() => _repo.stageSettings(_live.id, enabled: enabled));

  // ── Contrôles du diffuseur ───────────────────────────────────────────────

  Future<void> toggleMic() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    _micEnabled = !_micEnabled;
    _notify();
    await local.setMicrophoneEnabled(_micEnabled);
  }

  Future<void> toggleCamera() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    _cameraEnabled = !_cameraEnabled;
    _notify();
    await local.setCameraEnabled(
      _cameraEnabled,
      cameraCaptureOptions:
          lk.CameraCaptureOptions(cameraPosition: _cameraPosition),
    );
    _video = _cameraEnabled ? _localVideo() : null;
    _notify();
  }

  Future<void> switchCamera() async {
    final track = _localVideo();
    if (track == null) return;
    final next = _cameraPosition == lk.CameraPosition.front
        ? lk.CameraPosition.back
        : lk.CameraPosition.front;
    try {
      await track.setCameraPosition(next);
      _cameraPosition = next;
      _notify();
    } catch (e) {
      debugPrint('[Live] switchCamera: $e');
    }
  }

  // ── Fin / nettoyage ──────────────────────────────────────────────────────

  void _markEnded(String? reason) {
    if (_ended) return;
    _ended = true;
    _endReason = reason;
    _statsTimer?.cancel();
    _commentsTimer?.cancel();
    unawaited(_disconnect());
    _notify();
  }

  void _setLink(LiveLinkState s) {
    _link = s;
    _notify();
  }

  void _fail(String message) {
    _error = message;
    _link = LiveLinkState.disconnected;
    _notify();
  }

  Future<void> _disconnect() async {
    final room = _room;
    _room = null;
    await _listener?.dispose();
    _listener = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
      await room.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _statsTimer?.cancel();
    _commentsTimer?.cancel();
    unawaited(_disconnect());
    super.dispose();
  }
}
