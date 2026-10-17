import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';
import '../widgets/paged_account_list.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = context.l10n;
    final discover = FilledButton.icon(
      onPressed: () => context.push('/community'),
      icon: const Icon(Icons.groups_rounded, size: 18),
      label: Text(l10n.communityDiscover),
    );
    const headerStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary);

    return DefaultTabController(
      length: FollowsTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(l10n.communityFollowsTitle),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [Tab(text: l10n.communityFollowersTab), Tab(text: l10n.communityFollowingTab)],
          ),
        ),
        body: TabBarView(
          children: [
            PagedAccountList(
              key: const PageStorageKey('followers'),
              loader: (q, page) => repo.followers(query: q, page: page),
              searchHint: l10n.communitySearchFollowers,
              searchRecentKey: 'followers',
              followIdleLabel: l10n.communityFollowBack,
              emptyText: l10n.communityFollowersEmpty,
              emptyAction: discover,
              header: (total) => Text(
                l10n.communityFollowersCount(total),
                style: headerStyle,
              ),
            ),
            PagedAccountList(
              key: const PageStorageKey('following'),
              loader: (q, page) => repo.following(query: q, page: page),
              searchHint: l10n.communitySearchFollowing,
              searchRecentKey: 'following',
              emptyText: l10n.communityFollowingEmpty,
              emptyAction: discover,
              header: (total) => Text(l10n.communityFollowingCount(total), style: headerStyle),
            ),
          ],
        ),
      ),
    );
  }
}
