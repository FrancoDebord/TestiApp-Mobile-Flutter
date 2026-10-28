// File d'envoi hors connexion.
//
// Ce que la personne fait sans réseau (témoignage, requête ou session de prière,
// événement, commentaire, encouragement, réaction, enregistrement) est gardé dans
// SQLite (table `outbox`), avec une copie des fichiers joints, puis envoyé dans
// l'ordre au retour de la connexion : changement de réseau (connectivity_plus),
// retour au premier plan et rafraîchissement toutes les 30 s (main.dart),
// connexion au compte.
//
// Chaque action part avec l'en-tête `Idempotency-Key` (identifiant de l'action,
// suffixé par étape) : si la réponse s'est perdue, le serveur renvoie la première
// réponse au lieu de créer un doublon (docs serveur fonctionnalites/hors-connexion.md).
// Elle part aussi au nom du compte choisi au moment de l'action (`X-Act-As`).
//
// Refus du serveur (4xx) : l'action passe dans « Non envoyés » (écran « À envoyer »)
// avec le message du serveur ; serveur indisponible (5xx, 429) : nouvelles
// tentatives espacées ; coupure : on attend le réseau. Un contenu créé hors ligne a
// un identifiant provisoire « local_… », remplacé par celui du serveur dans les
// actions suivantes (ex. commentaire sur un témoignage pas encore envoyé).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_constants.dart';
import '../../core/local_db/daos/outbox_dao.dart';
import '../../core/local_db/database_service.dart';
import '../../core/network/network_failure.dart';
import '../../core/router/app_router.dart' show appRouterProvider;
import '../../l10n/app_localizations.dart';
import '../../services/acting_as_interceptor.dart' show kActingAsOverride;
import '../../services/api_service.dart';
import '../accounts/account_session.dart' show rootScaffoldMessengerKey;
import '../auth/providers/auth_notifier.dart' show realUserProvider;
import '../daily_verse/providers/daily_verse_providers.dart' show dailyVerseCommentsProvider;
import '../events/providers/events_providers.dart'
    show eventCommentsProvider, eventDetailProvider, eventListProvider, upcomingEventsProvider;
import '../home/providers/home_providers.dart' show feedNotifierProvider;
import '../journal/data/journal_repository.dart' show journalRefreshProvider;
import '../prayer/providers/prayer_providers.dart'
    show
        prayerMessagesProvider,
        prayerRequestListProvider,
        prayerRequestProvider,
        prayerRequestsPageProvider,
        prayerSessionListProvider;
import '../profile/providers/profile_provider.dart' show myTestimoniesNotifierProvider;
import '../publish/upload/video_upload_controller.dart' show videoUploadProvider;
import '../testimony/providers/comments_provider.dart' show commentsProvider;
import 'outbox_models.dart';

export 'outbox_models.dart';

/// Ce qu'il faut garder pour rejouer une action.
class OutboxDraft {
  const OutboxDraft({
    required this.kind,
    required this.label,
    this.request,
    this.before = const [],
    this.after = const [],
    this.video,
    this.targetId,
    this.localId,
    this.dedupeKey,
    this.preview = const {},
  });

  final OutboxKind kind;
  final String label;
  final OutboxRequest? request;
  final List<OutboxFile> before;
  final List<OutboxFile> after;

  /// Témoignage vidéo : `sourcePath`, `title`, `body`, `proofs` ([{position, path}]).
  final Map<String, dynamic>? video;
  final String? targetId;
  final String? localId;
  final String? dedupeKey;
  final Map<String, dynamic> preview;

  bool get hasFiles => before.isNotEmpty || after.isNotEmpty || video != null;
}

class OutboxState {
  const OutboxState({this.items = const [], this.online = true, this.syncing = false});

  /// Actions du compte connecté, plus anciennes d'abord.
  final List<OutboxItem> items;
  final bool online;
  final bool syncing;

  int get pendingCount => items.where((i) => !i.isFailed).length;
  int get failedCount => items.where((i) => i.isFailed).length;

  /// Actions en attente sur un contenu (commentaires à afficher « en attente d'envoi »).
  List<OutboxItem> pendingFor(OutboxKind kind, String targetId) =>
      [for (final i in items) if (i.kind == kind && i.targetId == targetId) i];

  OutboxState copyWith({List<OutboxItem>? items, bool? online, bool? syncing}) => OutboxState(
        items: items ?? this.items,
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
      );
}

enum _Outcome { done, skip, stop }

/// État du réseau (connectivity_plus ; remplacé dans les tests).
class OutboxNetwork {
  const OutboxNetwork();

  Stream<bool> get changes =>
      Connectivity().onConnectivityChanged.map((r) => r.any((c) => c != ConnectivityResult.none));

  Future<bool> isOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.any((c) => c != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}

/// Copies des fichiers joints, un dossier par action (remplacé dans les tests).
class OutboxFiles {
  const OutboxFiles();

  Future<String> dir(String id) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}outbox'
        '${Platform.pathSeparator}$id');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Copie le fichier choisi (le dossier temporaire du sélecteur peut être vidé).
  Future<String> keep(String id, String path) async {
    final folder = await dir(id);
    final name = path.split(RegExp(r'[\\/]')).last;
    final copy = await File(path).copy('$folder${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$name');
    return copy.path;
  }

  Future<void> delete(String id) async {
    if (kIsWeb) return;
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}outbox'
          '${Platform.pathSeparator}$id');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

final outboxDaoProvider = Provider<OutboxDao>((_) => OutboxDao(DatabaseService()));
final outboxNetworkProvider = Provider<OutboxNetwork>((_) => const OutboxNetwork());
final outboxFilesProvider = Provider<OutboxFiles>((_) => const OutboxFiles());

class OutboxController extends Notifier<OutboxState> {
  static const _maxAttempts = 8;

  late final OutboxDao _dao = ref.read(outboxDaoProvider);
  late final OutboxNetwork _network = ref.read(outboxNetworkProvider);
  late final OutboxFiles _files = ref.read(outboxFilesProvider);
  StreamSubscription<bool>? _connectivity;
  /// Envoi en cours : un nouvel appel attend sa fin (et le relance une fois).
  Future<void>? _current;
  bool _flushAgain = false;

  @override
  OutboxState build() {
    _connectivity = _network.changes.listen((online) {
      if (online != state.online) state = state.copyWith(online: online);
      if (online) unawaited(flush());
    }, onError: (Object _) {});
    ref.onDispose(() => _connectivity?.cancel());
    // Changement de personne connectée : sa propre file, envoyée aussitôt.
    ref.listen(realUserProvider.select((u) => u?.id), (prev, next) {
      unawaited(reload().then((_) => flush()));
    });
    unawaited(() async {
      final online = await _isOnline();
      state = state.copyWith(online: online);
      await reload();
      await flush();
    }());
    return const OutboxState();
  }

  Future<bool> _isOnline() => _network.isOnline();

  /// Personne réellement connectée (propriétaire de la file), même quand elle agit
  /// pour un compte qu'elle administre : ce compte est gardé dans [OutboxItem.actAs].
  String? get _userId => ref.read(realUserProvider)?.id;

  Future<void> reload() async {
    final uid = _userId;
    if (uid == null) {
      if (ref.mounted) state = state.copyWith(items: const []);
      return;
    }
    try {
      final items = await _dao.forUser(uid);
      if (ref.mounted) state = state.copyWith(items: items);
    } catch (e) {
      debugPrint('Outbox ✗ lecture : $e');
    }
  }

  // ── Ajout ──────────────────────────────────────────────────────────────────

  /// La file peut-elle garder cette action ? (Web : pas de copie de fichiers.)
  bool canQueue(OutboxDraft draft) => _userId != null && !(kIsWeb && draft.hasFiles);

  /// Fait l'action en ligne ; sans réseau, la garde dans la file et renvoie null.
  /// Les refus du serveur sont relancés tels quels.
  Future<T?> sendOrQueue<T>(Future<T> Function() online, OutboxDraft Function() offline) async {
    if (!await _isOnline() || refersToLocal(offline())) {
      final draft = offline();
      if (canQueue(draft)) {
        await enqueue(draft);
        return null;
      }
    }
    try {
      return await online();
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow;
      final draft = offline();
      if (!canQueue(draft)) rethrow;
      await enqueue(draft);
      return null;
    }
  }

  /// L'action vise un contenu créé hors ligne, pas encore envoyé (identifiant « local_… ») :
  /// elle ne peut partir qu'après lui.
  bool refersToLocal(OutboxDraft d) {
    final r = d.request;
    return r != null && localIdPattern.hasMatch('${r.path} ${jsonEncode(r.body ?? const {})}');
  }

  /// Une action « fire and forget » a échoué : gardée si c'est une coupure.
  /// Renvoie vrai si l'action est en file (l'état affiché peut rester tel quel).
  Future<bool> queueIfOffline(Object error, OutboxDraft draft) async {
    if (!isNetworkFailure(error) && !refersToLocal(draft)) return false;
    if (!canQueue(draft)) return false;
    return await enqueue(draft) != null;
  }

  /// Garde l'action (et une copie de ses fichiers) puis tente l'envoi si le réseau est là.
  Future<OutboxItem?> enqueue(OutboxDraft d) async {
    final uid = _userId;
    if (uid == null) return null;
    final id = outboxRandomId();

    final before = [for (final f in d.before) f.withFile(await _files.keep(id, f.file))];
    final after = [for (final f in d.after) f.withFile(await _files.keep(id, f.file))];
    Map<String, dynamic>? video;
    if (d.video case final v?) {
      video = {
        ...v,
        'sourcePath': await _files.keep(id, v['sourcePath'] as String),
        'proofs': [
          for (final p in (v['proofs'] as List? ?? const []))
            {'position': (p as Map)['position'], 'path': await _files.keep(id, p['path'] as String)},
        ],
        'ownedDir': await _files.dir(id),
      };
    }

    final item = OutboxItem(
      id: id,
      userId: uid,
      actAs: ref.read(actingAsStoreProvider).accountId,
      kind: d.kind,
      targetId: d.targetId,
      localId: d.localId,
      dedupeKey: d.dedupeKey,
      payload: OutboxPayload(request: d.request, before: before, after: after, video: video, preview: d.preview),
      label: d.label.length > 140 ? '${d.label.substring(0, 140)}…' : d.label,
      status: OutboxStatus.pending,
      createdAt: DateTime.now(),
    );
    final replaced = await _dao.insert(item);
    for (final r in replaced) {
      await _files.delete(r.id);
    }
    await reload();
    // Coupure brève : l'envoi part dès que possible.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (ref.mounted) unawaited(flush());
    });
    return item;
  }

  // ── Gestion depuis « À envoyer » ──────────────────────────────────────────

  Future<void> retry(String id) async {
    await _dao.resetForRetry(id);
    await reload();
    await flush();
  }

  /// Supprime l'action, et celles qui visent ce qu'elle devait créer.
  Future<void> remove(String id) async {
    final item = await _dao.byId(id);
    if (item == null) return;
    await _dao.delete(id);
    await _files.delete(id);
    final local = item.localId;
    if (local != null) {
      for (final other in state.items) {
        if (other.id != id && other.payload.encode().contains(local)) {
          await _dao.delete(other.id);
          await _files.delete(other.id);
        }
      }
      if (item.kind == OutboxKind.testimony) {
        ref.read(feedNotifierProvider.notifier).removeTestimony(local);
      }
    }
    await reload();
  }

  // ── Envoi ──────────────────────────────────────────────────────────────────

  /// Envoie les actions en attente, dans l'ordre. Sans effet hors ligne.
  Future<void> flush() {
    if (!ref.mounted) return Future.value();
    if (_current case final running?) {
      _flushAgain = true;
      return running;
    }
    final run = _flushAll().whenComplete(() => _current = null);
    _current = run;
    return run;
  }

  Future<void> _flushAll() async {
    var sent = 0;
    var failed = 0;
    try {
      do {
        _flushAgain = false;
        final uid = _userId;
        if (uid == null || !await _isOnline()) break;
        await _dao.adoptOrphans(uid);
        final now = DateTime.now();
        final items = (await _dao.forUser(uid))
            .where((i) => !i.isFailed && (i.nextTryAt == null || !i.nextTryAt!.isAfter(now)))
            .toList();
        if (items.isEmpty) break;
        if (ref.mounted) state = state.copyWith(syncing: true, online: true);
        for (final item in items) {
          final (outcome, ok) = await _process(item);
          if (ok == true) sent++;
          if (ok == false) failed++;
          if (outcome == _Outcome.stop) {
            _flushAgain = false;
            break;
          }
        }
      } while (_flushAgain && ref.mounted);
    } catch (e) {
      debugPrint('Outbox ✗ $e');
    } finally {
      if (ref.mounted) {
        state = state.copyWith(syncing: false);
        await reload();
        _announce(sent, failed);
      }
    }
  }

  /// (suite, réussite : true envoyé, false refusé, null ni l'un ni l'autre).
  Future<(_Outcome, bool?)> _process(OutboxItem item) async {
    var p = item.payload;

    // Identifiants provisoires remplacés par ceux du serveur.
    final encoded = p.encode();
    final tokens = localIdPattern.allMatches(encoded).map((m) => m[0]!).where((t) => t != item.localId).toSet();
    if (tokens.isNotEmpty) {
      final map = await _dao.idMap(tokens);
      for (final t in tokens.where((t) => !map.containsKey(t))) {
        // Le contenu visé attend encore son envoi : on attend avec lui.
        if (await _dao.isQueuedCreation(t)) return (_Outcome.skip, null);
        await _dao.markFailed(item.id, L10n.current.outboxParentMissing);
        return (_Outcome.done, false);
      }
      var resolved = encoded;
      map.forEach((local, remote) => resolved = resolved.replaceAll(local, remote));
      p = OutboxPayload.fromJson(Map<String, dynamic>.from(jsonDecode(resolved) as Map));
    }

    Options options(String key) => Options(
          headers: {'Idempotency-Key': key}, // i18n-ignore
          extra: {kActingAsOverride: item.actAs},
        );
    final api = ref.read(apiServiceProvider);

    try {
      if (p.video != null) return await _startVideo(item, p);

      while (p.before.isNotEmpty) {
        final f = p.before.first;
        final res = await api.upload<dynamic>(f.path,
            filePath: f.file, fieldName: f.field, extraFields: f.fields, options: options('${item.id}-b${p.before.length}'));
        final data = res.data;
        final url = absoluteMediaUrl(data is Map ? data[f.urlKey]?.toString() : null);
        if (f.into != null && p.request?.body != null) p.request!.body![f.into!] = url;
        p.before.removeAt(0);
        await _dao.savePayload(item.id, p);
      }

      if (p.request case final r? when p.createdId == null) {
        final key = options(item.id);
        final res = switch (r.method.toUpperCase()) {
          'PUT' => await api.put<dynamic>(r.path, data: r.body, options: key),
          'DELETE' => await api.delete<dynamic>(r.path, data: r.body, query: r.query, options: key),
          _ => await api.post<dynamic>(r.path, data: r.body, query: r.query, options: key),
        };
        final data = res.data;
        p.createdId = data is Map ? (data['id']?.toString() ?? '') : '';
        await _dao.savePayload(item.id, p);
        if (item.localId != null && p.createdId!.isNotEmpty) {
          await _dao.mapId(item.localId!, p.createdId!);
        }
      }

      while (p.after.isNotEmpty) {
        final f = p.after.first;
        try {
          await api.upload<dynamic>(f.path.replaceAll('{id}', p.createdId ?? ''),
              filePath: f.file, fieldName: f.field, extraFields: f.fields, options: options('${item.id}-a${p.after.length}'));
        } on LaravelApiException catch (e) {
          // Fichier refusé (format, taille) : le contenu est créé, on passe au suivant.
          if (e.statusCode == 401 || e.statusCode == 408 || e.statusCode == 429) rethrow;
          debugPrint('Outbox ✗ fichier refusé ${f.path} : ${e.displayMessage}');
        }
        p.after.removeAt(0);
        await _dao.savePayload(item.id, p);
      }

      await _dao.delete(item.id);
      await _files.delete(item.id);
      // Retirée tout de suite : les listes rechargées ne la montrent plus « en attente ».
      if (ref.mounted) state = state.copyWith(items: [for (final i in state.items) if (i.id != item.id) i]);
      _afterSync(item, p.createdId);
      return (_Outcome.done, true);
    } catch (e) {
      return _onError(item, e);
    }
  }

  Future<(_Outcome, bool?)> _startVideo(OutboxItem item, OutboxPayload p) async {
    final upload = ref.read(videoUploadProvider.notifier);
    // Une seule vidéo à la fois : celle-ci part quand la précédente est finie.
    if (upload.hasPendingJob) return (_Outcome.skip, null);
    final v = p.video!;
    await upload.start(
      sourcePath: v['sourcePath'] as String,
      title: v['title'] as String? ?? item.label,
      body: Map<String, dynamic>.from(v['body'] as Map? ?? const {}),
      proofs: [
        for (final pr in (v['proofs'] as List? ?? const []))
          (position: ((pr as Map)['position'] as num).toInt(), path: pr['path'] as String),
      ],
      ownedDir: v['ownedDir'] as String?,
    );
    // Les fichiers appartiennent maintenant à l'envoi vidéo (effacés à la fin).
    await _dao.delete(item.id);
    return (_Outcome.done, true);
  }

  Future<(_Outcome, bool?)> _onError(OutboxItem item, Object e) async {
    if (isNetworkFailure(e)) return (_Outcome.stop, null);
    if (e is LaravelApiException) {
      // Session expirée : on attend la reconnexion.
      if (e.statusCode == 401) return (_Outcome.stop, null);
      if (e.statusCode == 408 || e.statusCode == 409 || e.statusCode == 429) return _postpone(item);
      await _dao.markFailed(item.id, e.displayMessage);
      return (_Outcome.done, false);
    }
    if (e is DioException) return _postpone(item); // 5xx
    if (e is FileSystemException) {
      await _dao.markFailed(item.id, L10n.current.outboxFileMissing);
      return (_Outcome.done, false);
    }
    debugPrint('Outbox ✗ ${item.kind.name} : $e');
    return _postpone(item);
  }

  Future<(_Outcome, bool?)> _postpone(OutboxItem item) async {
    final attempts = item.attempts + 1;
    if (attempts >= _maxAttempts) {
      await _dao.markFailed(item.id, L10n.current.outboxGaveUp);
      return (_Outcome.done, false);
    }
    final wait = Duration(seconds: (30 * (1 << (attempts - 1))).clamp(30, 3600));
    await _dao.postpone(item.id, attempts, DateTime.now().add(wait));
    return (_Outcome.done, null);
  }

  /// Listes et compteurs rechargés : le contenu envoyé remplace sa version « en attente ».
  void _afterSync(OutboxItem item, String? createdId) {
    try {
      final target = item.targetId;
      switch (item.kind) {
        case OutboxKind.testimony:
          if (item.localId != null) ref.read(feedNotifierProvider.notifier).removeTestimony(item.localId!);
          unawaited(ref.read(feedNotifierProvider.notifier).refresh());
          ref.invalidate(myTestimoniesNotifierProvider);
          ref.read(journalRefreshProvider.notifier).bump();
        case OutboxKind.prayerRequest:
          ref.invalidate(prayerRequestListProvider);
          ref.invalidate(prayerRequestsPageProvider);
        case OutboxKind.prayerSession:
          ref.invalidate(prayerSessionListProvider);
        case OutboxKind.event:
          ref.invalidate(eventListProvider);
          ref.invalidate(upcomingEventsProvider);
          if (target != null) ref.invalidate(eventDetailProvider(target));
        case OutboxKind.testimonyComment when target != null:
          ref.invalidate(commentsProvider(target));
        case OutboxKind.eventComment when target != null:
          ref.invalidate(eventCommentsProvider(target));
          ref.invalidate(eventDetailProvider(target));
        case OutboxKind.verseComment when target != null:
          final id = int.tryParse(target);
          if (id != null) ref.invalidate(dailyVerseCommentsProvider(id));
        case OutboxKind.prayerMessage when target != null:
          ref.invalidate(prayerMessagesProvider(target));
          ref.invalidate(prayerRequestProvider(target));
        default:
          break;
      }
    } catch (e) {
      debugPrint('Outbox ✗ rafraîchissement : $e');
    }
  }

  void _announce(int sent, int failed) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null || (sent == 0 && failed == 0)) return;
    final l = L10n.current;
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(failed > 0 ? l.outboxFailedSnack(failed) : l.outboxSyncedSnack(sent)),
      action: failed > 0
          ? SnackBarAction(label: l.outboxView, onPressed: () => ref.read(appRouterProvider).push('/outbox'))
          : null,
    ));
  }
}

final outboxProvider = NotifierProvider<OutboxController, OutboxState>(OutboxController.new);

/// URL absolue d'un média renvoyé par le serveur (« /storage/x.jpg » → https://…/storage/x.jpg).
String? absoluteMediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return raw;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  final root = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/v1.*$'), '');
  return raw.startsWith('/') ? '$root$raw' : '$root/$raw';
}

/// Message après une action gardée hors connexion (« Voir » ouvre « À envoyer »).
void showQueuedSnack(BuildContext context) {
  final l = context.l10n;
  final router = GoRouter.maybeOf(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 5),
    content: Text(l.outboxQueuedSnack),
    action: SnackBarAction(label: l.outboxView, onPressed: () => router?.push('/outbox')),
  ));
}
