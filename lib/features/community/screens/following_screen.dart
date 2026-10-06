import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';
import '../widgets/paged_account_list.dart';

/// Onglets de l'écran « Abonnés / Abonnements ».
enum FollowsTab { followers, following }

/// « Mes abonnés » (`/followers`) et « Mes abonnements » (`/following`) : un écran, deux onglets.
/// - Abonnés : comptes qui me suivent, bouton « Suivre en retour » pour ceux que je ne suis pas.
/// - Abonnements : comptes que je suis ; se désabonner laisse le compte dans la liste
///   (bouton « Suivre ») jusqu'à l'actualisation.
/// Backend : GET /users/me/followers et /users/me/following — docs/fonctionnalites/abonnements.md
class FollowsScreen extends ConsumerWidget {
  const FollowsScreen({this.initialTab = FollowsTab.following, super.key});

  final FollowsTab initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(communityRepositoryProvider);
    final discover = FilledButton.icon(
      onPressed: () => context.push('/community'),
      icon: const Icon(Icons.groups_rounded, size: 18),
      label: const Text('Découvrir la Communauté'),
    );
    const headerStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary);

    return DefaultTabController(
      length: FollowsTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Abonnés et abonnements'),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [Tab(text: 'Abonnés'), Tab(text: 'Abonnements')],
          ),
        ),
        body: TabBarView(
          children: [
            PagedAccountList(
              key: const PageStorageKey('followers'),
              loader: (q, page) => repo.followers(query: q, page: page),
              searchHint: 'Rechercher dans mes abonnés',
              followIdleLabel: 'Suivre en retour',
              emptyText: 'Personne ne vous suit encore.\nPubliez des témoignages et participez à la Communauté : '
                  'ceux qui vous suivront apparaîtront ici.',
              emptyAction: discover,
              header: (total) => Text(
                total > 1 ? '$total comptes vous suivent' : '$total compte vous suit',
                style: headerStyle,
              ),
            ),
            PagedAccountList(
              key: const PageStorageKey('following'),
              loader: (q, page) => repo.following(query: q, page: page),
              searchHint: 'Rechercher dans mes abonnements',
              emptyText: 'Vous ne suivez encore personne.\nSuivez des églises, des ministères et des personnes '
                  'pour être prévenu de leurs témoignages et de leurs directs.',
              emptyAction: discover,
              header: (total) => Text('Vous suivez $total compte${total > 1 ? 's' : ''}', style: headerStyle),
            ),
          ],
        ),
      ),
    );
  }
}
