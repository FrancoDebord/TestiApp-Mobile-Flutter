import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';
import '../widgets/paged_account_list.dart';

/// « Mes abonnements » : comptes que la personne connectée suit, les plus récents d'abord.
/// Se désabonner laisse le compte dans la liste (bouton « Suivre ») jusqu'à l'actualisation.
/// Backend : GET /users/me/following — docs/fonctionnalites/abonnements.md
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(communityRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes abonnements'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: PagedAccountList(
        loader: (q, page) => repo.following(query: q, page: page),
        searchHint: 'Rechercher dans mes abonnements',
        emptyText: 'Vous ne suivez encore personne.\nSuivez des églises, des ministères et des personnes '
            'pour être prévenu de leurs témoignages et de leurs directs.',
        emptyAction: FilledButton.icon(
          onPressed: () => context.push('/community'),
          icon: const Icon(Icons.groups_rounded, size: 18),
          label: const Text('Découvrir la Communauté'),
        ),
        header: (total) => Text(
          'Vous suivez $total compte${total > 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
