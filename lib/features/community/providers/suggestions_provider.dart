// « Comptes à suivre » : suggestions du serveur (GET /users/suggestions), rechargées quand
// la personne connectée change. Les comptes suivis ensuite sont retirés à l'affichage
// (followProvider), sans nouvel appel. Backend : docs/fonctionnalites/abonnements.md

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/community_repository.dart';
import '../models/suggested_account.dart';

/// Nombre de suggestions demandées : de quoi remplacer les cartes suivies depuis l'écran.
const kSuggestedAccountsFetch = 20;

final suggestedAccountsProvider = FutureProvider<List<SuggestedAccount>>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(communityRepositoryProvider).suggestions(limit: kSuggestedAccountsFetch);
});
