import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';
import '../models/community_account.dart';
import '../widgets/paged_account_list.dart';

/// « Communauté » : organisations (vérifiées d'abord) et personnes qui témoignent, à suivre.
/// Backend : GET /community — docs/fonctionnalites/abonnements.md
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: CommunityTab.values.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Communauté'),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              for (final t in CommunityTab.values)
                Tab(text: t.label, icon: Icon(t == CommunityTab.people ? Icons.person_rounded : Icons.church_rounded, size: 18)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AccountList(tab: CommunityTab.organizations),
            _AccountList(tab: CommunityTab.people),
          ],
        ),
      ),
    );
  }
}

class _AccountList extends ConsumerWidget {
  const _AccountList({required this.tab});
  final CommunityTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(communityRepositoryProvider);
    final isPeople = tab == CommunityTab.people;
    return PagedAccountList(
      loader: (q, page) => repo.community(tab, query: q, page: page),
      searchHint: isPeople ? 'Rechercher une personne' : 'Rechercher une organisation, une ville…',
      emptyText: isPeople
          ? 'Les personnes qui publient des témoignages apparaîtront ici.'
          : 'Les églises, ministères et associations inscrits apparaîtront ici.',
    );
  }
}
