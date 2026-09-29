import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import 'journal_offline_store.dart';
import 'journal_repository.dart';

/// Hors ligne indisponible sur le web (pas d'espace de fichiers).
const bool kJournalOfflineSupported = !kIsWeb;

class JournalOfflineState {
  const JournalOfflineState({
    this.loaded = false,
    this.settings = const JournalOfflineSettings(),
    this.syncing = false,
    this.done = 0,
    this.total = 0,
    this.sizeBytes = 0,
    this.lastResult,
    this.error,
  });

  final bool loaded;
  final JournalOfflineSettings settings;
  final bool syncing;
  final int done;
  final int total;
  final int sizeBytes;
  final JournalSyncResult? lastResult;
  final String? error;

  bool get enabled => settings.enabled;

  JournalOfflineState copyWith({
    bool? loaded,
    JournalOfflineSettings? settings,
    bool? syncing,
    int? done,
    int? total,
    int? sizeBytes,
    JournalSyncResult? lastResult,
    String? error,
    bool clearError = false,
  }) =>
      JournalOfflineState(
        loaded: loaded ?? this.loaded,
        settings: settings ?? this.settings,
        syncing: syncing ?? this.syncing,
        done: done ?? this.done,
        total: total ?? this.total,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        lastResult: lastResult ?? this.lastResult,
        error: clearError ? null : (error ?? this.error),
      );
}

final journalOfflineStoreProvider =
    Provider<JournalOfflineStore>((ref) => JournalOfflineStore());

/// Copie hors ligne du carnet de l'utilisateur connecté.
class JournalOfflineController extends Notifier<JournalOfflineState> {
  JournalOfflineStore get _store => ref.read(journalOfflineStoreProvider);
  String? get userId => ref.read(currentUserProvider)?.id;

  @override
  JournalOfflineState build() {
    // Changement de compte : recharger les réglages de ce compte.
    ref.watch(currentUserProvider.select((u) => u?.id));
    unawaited(Future.microtask(_load));
    return const JournalOfflineState();
  }

  Future<void> _load() async {
    final uid = userId;
    if (!kJournalOfflineSupported || uid == null) {
      state = state.copyWith(loaded: true);
      return;
    }
    final s = await _store.readSettings(uid);
    state = state.copyWith(
      loaded: true,
      settings: s,
      sizeBytes: s.enabled ? await _store.sizeBytes(uid) : 0,
    );
  }

  /// Réponse « oui » à la question, ou activation depuis les réglages.
  Future<void> enable() async {
    final uid = userId;
    if (uid == null) return;
    final s = state.settings.copyWith(enabled: true, asked: true);
    await _store.writeSettings(uid, s);
    state = state.copyWith(settings: s);
    await sync();
  }

  /// Réponse « non merci » : ne plus reposer la question.
  Future<void> decline() async {
    final uid = userId;
    if (uid == null) return;
    final s = state.settings.copyWith(asked: true);
    await _store.writeSettings(uid, s);
    state = state.copyWith(settings: s);
  }

  /// Désactive et efface la copie du téléphone (rien n'est supprimé en ligne).
  Future<void> disable() async {
    final uid = userId;
    if (uid == null) return;
    await _store.clear(uid);
    state = state.copyWith(
      settings: state.settings.copyWith(enabled: false, asked: true),
      sizeBytes: 0,
      done: 0,
      total: 0,
      clearError: true,
    );
  }

  /// Met la copie à jour (sans effet si l'option est désactivée).
  Future<void> sync() async {
    final uid = userId;
    if (uid == null || !state.enabled || state.syncing) return;
    state = state.copyWith(syncing: true, done: 0, total: 0, clearError: true);
    try {
      final result = await _store.sync(
        uid,
        ref.read(journalRepositoryProvider),
        onProgress: (done, total) => state = state.copyWith(done: done, total: total),
      );
      state = state.copyWith(
        syncing: false,
        lastResult: result,
        settings: await _store.readSettings(uid),
        sizeBytes: await _store.sizeBytes(uid),
      );
    } on JournalFailure catch (e) {
      state = state.copyWith(syncing: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
          syncing: false, error: 'La copie hors ligne n\'a pas pu être mise à jour.');
    }
  }
}

final journalOfflineProvider =
    NotifierProvider<JournalOfflineController, JournalOfflineState>(
  JournalOfflineController.new,
);
