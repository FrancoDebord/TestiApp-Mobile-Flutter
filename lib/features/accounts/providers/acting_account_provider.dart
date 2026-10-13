// Compte actif : la personne agit pour son propre compte (état `null`) ou pour un
// compte qu'elle administre (2 administrateurs au plus par compte).
//
// - L'id du compte actif est recopié dans [ActingAsStore] : l'intercepteur ajoute
//   alors l'en-tête X-Act-As aux requêtes (sauf chemins réservés au titulaire).
// - Persisté dans le stockage sécurisé ([kActingAccountStorageKey]) avec l'id du
//   titulaire : effacé à la déconnexion et quand un autre compte se connecte.
// - Au démarrage, le compte mémorisé est repris tout de suite (affichage
//   immédiat), puis validé par GET /users/me/accounts ; s'il n'est plus
//   administré, retour au compte de la personne.
// - currentUserProvider renvoie le compte actif : « moi » est ce compte pour tout
//   ce qui est publié, les boutons modifier/supprimer, etc.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/app_constants.dart';
import '../../../services/acting_as_interceptor.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/providers/auth_notifier.dart' show AuthStateAuthenticated, authStateProvider;
import '../account_session.dart';
import '../data/accounts_repository.dart';
import '../models/account_models.dart';

/// Clé du stockage sécurisé : `{ownerId, account, user}`.
const kActingAccountStorageKey = 'acting_account';

/// Compte pour lequel la personne agit.
class ActingAccount {
  const ActingAccount({required this.ownerId, required this.account, this.user});

  /// Titulaire réel de la session (la personne connectée).
  final String ownerId;
  final AccountSummary account;

  /// Profil chargé par GET /users/me (null tant qu'il n'est pas arrivé).
  final UserModel? user;

  String get id => account.id;
  String get displayName => user?.displayName.isNotEmpty == true ? user!.displayName : account.displayName;

  /// Utilisateur « courant » de l'application.
  UserModel get asUser => user ?? account.toPlaceholderUser();

  ActingAccount withUser(UserModel u) => ActingAccount(ownerId: ownerId, account: account, user: u);

  Map<String, dynamic> toJson() => {
        'ownerId': ownerId,
        'account': account.toJson(),
        if (user != null) 'user': user!.toJson(),
      };

  static ActingAccount? fromJson(Map<String, dynamic>? m) {
    if (m == null) return null;
    try {
      final owner = '${m['ownerId'] ?? ''}';
      final acc = m['account'];
      if (owner.isEmpty || acc is! Map) return null;
      final account = AccountSummary.fromJson(Map<String, dynamic>.from(acc));
      if (account.id.isEmpty) return null;
      final u = m['user'];
      return ActingAccount(
        ownerId: owner,
        account: account,
        user: u is Map ? UserModel.fromJson(Map<String, dynamic>.from(u)) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lit le compte actif mémorisé avant la restauration de la session, pour que
/// les toutes premières requêtes portent déjà l'en-tête X-Act-As.
Future<void> loadActingSnapshot(ActingAsStore store, FlutterSecureStorage storage) async {
  try {
    final raw = await storage.read(key: kActingAccountStorageKey);
    if (raw == null || raw.isEmpty) return;
    final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final ownerId = await storage.read(key: AppConstants.keyUserId);
    final acting = ActingAccount.fromJson(map);
    if (acting == null || ownerId == null || acting.ownerId != ownerId) {
      await storage.delete(key: kActingAccountStorageKey);
      return;
    }
    store
      ..snapshot = map
      ..accountId = acting.id;
  } catch (_) {/* stockage indisponible : on reste sur son compte */}
}

const _pending = '\u0000pending';

/// Id du titulaire connecté ; [_pending] tant que la session se charge.
final _ownerIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authStateProvider);
  final value = auth.value;
  if (value == null) return _pending;
  return value is AuthStateAuthenticated ? value.user.id : null;
});

class ActingAccountNotifier extends Notifier<ActingAccount?> {
  late ActingAsStore _store;
  String? _ownerId;

  @override
  ActingAccount? build() {
    _store = ref.read(actingAsStoreProvider);
    _store.onForbidden = _onForbidden;
    final owner = ref.watch(_ownerIdProvider);
    if (owner == _pending) return null; // l'en-tête mémorisé est conservé
    _ownerId = owner;

    final saved = ActingAccount.fromJson(_store.snapshot);
    if (owner != null && saved != null && saved.ownerId == owner) {
      _store.accountId = saved.id;
      Future.microtask(() => _validate(saved.id));
      return saved;
    }
    // Déconnexion, autre compte connecté, ou rien de mémorisé.
    _store.accountId = null;
    if (_store.snapshot != null) {
      _store.snapshot = null;
      unawaited(_deleteSaved());
    }
    return null;
  }

  AccountsRepository get _repo => ref.read(accountsRepositoryProvider);

  /// Agit au nom de [account] (ou revient à son compte si c'est le sien).
  /// Lève [AccountsFailure] si le serveur refuse.
  Future<void> actAs(AccountSummary account) async {
    final owner = _ownerId;
    if (owner == null || owner == _pending) return;
    if (account.isOwner || account.id == owner) {
      await stopActing();
      return;
    }
    final previous = _store.accountId;
    _store.accountId = account.id;
    UserModel user;
    try {
      user = await _repo.me();
    } catch (_) {
      _store.accountId = previous;
      rethrow;
    }
    _set(ActingAccount(ownerId: owner, account: account, user: user));
    invalidateAccountScopedData(ref);
  }

  /// Revient au compte de la personne.
  Future<void> stopActing() async {
    if (state == null && _store.accountId == null) return;
    _store
      ..accountId = null
      ..snapshot = null;
    state = null;
    unawaited(_deleteSaved());
    invalidateAccountScopedData(ref);
  }

  /// Profil du compte actif modifié (édition du profil, photo…).
  void updateUser(UserModel user) {
    final current = state;
    if (current == null || current.id != user.id) return;
    _set(current.withUser(user));
  }

  /// Recharge le profil du compte actif (GET /users/me).
  Future<void> refreshUser() async {
    final current = state;
    if (current == null) return;
    try {
      final user = await _repo.me();
      if (state?.id == current.id) _set(current.withUser(user));
    } catch (_) {}
  }

  void _set(ActingAccount acting) {
    final json = acting.toJson();
    _store
      ..accountId = acting.id
      ..snapshot = json;
    state = acting;
    unawaited(() async {
      try {
        await ref.read(secureStorageProvider).write(key: kActingAccountStorageKey, value: jsonEncode(json));
      } catch (_) {}
    }());
  }

  Future<void> _deleteSaved() async {
    try {
      await ref.read(secureStorageProvider).delete(key: kActingAccountStorageKey);
    } catch (_) {}
  }

  /// Au démarrage : le compte est-il toujours administré ?
  Future<void> _validate(String id) async {
    try {
      final snap = await _repo.accounts();
      if (state?.id != id) return;
      final match = snap.byId(id);
      if (match == null || match.isOwner) {
        await _returnToOwnAccount("Vous n'administrez plus ce compte.");
        return;
      }
      final user = await _repo.me();
      final current = state;
      if (current?.id != id) return;
      _set(ActingAccount(ownerId: current!.ownerId, account: match, user: user));
    } on AccountsFailure catch (e) {
      if (e.statusCode == 403 && state?.id == id) await _returnToOwnAccount(e.message);
    } catch (_) {/* hors ligne : on garde le compte mémorisé */}
  }

  void _onForbidden(String message) {
    if (state == null && _store.accountId == null) return;
    unawaited(_returnToOwnAccount(message));
  }

  Future<void> _returnToOwnAccount(String message) async {
    await stopActing();
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
  }
}

final actingAccountProvider =
    NotifierProvider<ActingAccountNotifier, ActingAccount?>(ActingAccountNotifier.new);

/// La personne agit-elle pour un autre compte ?
final isActingForOtherProvider = Provider<bool>((ref) => ref.watch(actingAccountProvider) != null);

/// Mon compte et les comptes que j'administre (GET /users/me/accounts).
final myAccountsProvider = FutureProvider.autoDispose<AccountsSnapshot>((ref) async {
  if (ref.watch(_ownerIdProvider) case null || _pending) return const AccountsSnapshot(accounts: []);
  return ref.watch(accountsRepositoryProvider).accounts();
});
