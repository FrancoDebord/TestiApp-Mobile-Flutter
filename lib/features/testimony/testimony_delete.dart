// Suppression d'un témoignage depuis les cartes et la page de détail : l'auteur ou un
// administrateur, selon `canDelete` renvoyé par l'API. Un modérateur ne supprime jamais
// ce qu'un autre a soumis (il refuse ou dépublie depuis la modération).
// API : DELETE /testimonies/{id}.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../auth/providers/auth_notifier.dart';
import '../home/models/testimony_model.dart';
import '../../shared/content_deletion.dart';

/// Témoignages supprimés pendant la session : masqués dans toutes les listes déjà chargées
/// (accueil, Mon fil, explorer, profils…). Voir [deletedContentProvider].
final deletedTestimoniesProvider = Provider<Set<String>>((ref) => {
      for (final key in ref.watch(deletedContentProvider))
        if (key.startsWith('${DeletableContent.testimony.name}:')) key.substring(DeletableContent.testimony.name.length + 1),
    });

/// Peut supprimer : `canDelete` de l'API, ou (cache local) l'auteur et les administrateurs.
bool canDeleteTestimony(WidgetRef ref, Testimony t) {
  if (t.canDelete) return true;
  final me = ref.read(currentUserProvider);
  return me != null && (me.id == t.author.uid || me.isAdmin);
}

/// Demande confirmation puis supprime (« Supprimé » ou message d'erreur).
/// Renvoie vrai si le témoignage a été supprimé.
Future<bool> confirmDeleteTestimony(BuildContext context, WidgetRef ref, Testimony t) {
  final me = ref.read(currentUserProvider);
  final mine = me != null && me.id == t.author.uid;
  return deleteTestimonyContent(context, ref, t.id,
      body: mine ? context.l10n.testimonyDeleteMineBody : context.l10n.testimonyDeleteOtherBody(t.author.displayName));
}
