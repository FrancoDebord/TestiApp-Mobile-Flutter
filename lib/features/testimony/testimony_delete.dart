// Suppression d'un témoignage depuis les cartes et la page de détail : l'auteur ou un
// administrateur, selon `canDelete` renvoyé par l'API. Un modérateur ne supprime jamais
// ce qu'un autre a soumis (il refuse ou dépublie depuis la modération).
// API : DELETE /testimonies/{id}.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import '../auth/providers/auth_notifier.dart';
import '../home/models/testimony_model.dart';
import '../home/providers/home_providers.dart';

/// Témoignages supprimés pendant la session : masqués dans toutes les listes déjà chargées
/// (accueil, Mon fil, explorer, profils…).
class DeletedTestimoniesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String id) => state = {...state, id};
}

final deletedTestimoniesProvider =
    NotifierProvider<DeletedTestimoniesNotifier, Set<String>>(DeletedTestimoniesNotifier.new);

/// Peut supprimer : `canDelete` de l'API, ou (cache local) l'auteur et les administrateurs.
bool canDeleteTestimony(WidgetRef ref, Testimony t) {
  if (t.canDelete) return true;
  final me = ref.read(currentUserProvider);
  return me != null && (me.id == t.author.uid || me.isAdmin);
}

/// Demande confirmation puis supprime. Renvoie vrai si le témoignage a été supprimé.
Future<bool> confirmDeleteTestimony(BuildContext context, WidgetRef ref, Testimony t) async {
  final me = ref.read(currentUserProvider);
  final mine = me != null && me.id == t.author.uid;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Supprimer ce témoignage ?'),
      content: Text(mine
          ? 'Cette action est irréversible. Le témoignage sera définitivement supprimé.'
          : 'Ce témoignage de ${t.author.displayName} sera définitivement supprimé, avec ses commentaires et ses réactions.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    await ref.read(apiServiceProvider).delete<void>(AppConstants.testimonyById(t.id));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is LaravelApiException ? e.message : 'Impossible de supprimer. Réessayez.')),
      );
    }
    return false;
  }
  ref.read(deletedTestimoniesProvider.notifier).add(t.id);
  ref.read(feedNotifierProvider.notifier).removeTestimony(t.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Témoignage supprimé.')));
  }
  return true;
}
