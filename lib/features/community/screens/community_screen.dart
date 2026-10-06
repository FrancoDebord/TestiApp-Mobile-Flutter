import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';
import '../models/community_account.dart';
import '../providers/suggestions_provider.dart';
import '../widgets/account_tile.dart';
import '../widgets/paged_account_list.dart';

/// « Communauté » : suggestions personnalisées, organisations (vérifiées d'abord) et personnes
/// qui témoignent, à suivre.
/// Backend : GET /users/suggestions, GET /community — docs/fonctionnalites/abonnements.md
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: CommunityTab.values.length + 1,
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
              const Tab(text: 'Suggestions', icon: Icon(Icons.auto_awesome_rounded, size: 18)),
              for (final t in CommunityTab.values)
                Tab(text: t.label, icon: Icon(t == CommunityTab.people ? Icons.person_rounded : Icons.church_rounded, size: 18)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SuggestionsList(),
            _AccountList(tab: CommunityTab.organizations),
            _AccountList(tab: CommunityTab.people),
          ],
        ),
      ),
    );
  }
}

/// Onglet « Suggestions » : comptes à suivre classés, avec la raison de chaque suggestion.
class _SuggestionsList extends ConsumerWidget {
  const _SuggestionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestedAccountsProvider);
    Future<void> refresh() => ref.refresh(suggestedAccountsProvider.future);

    Widget message(String text, {bool retry = false}) => ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            if (retry) ...[
              const SizedBox(height: 12),
              Center(child: OutlinedButton(onPressed: refresh, child: const Text('Réessayer'))),
            ],
          ],
        );

    return RefreshIndicator(
      onRefresh: refresh,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => message('Impossible de charger les suggestions. Vérifiez votre connexion.', retry: true),
        data: (items) => items.isEmpty
            ? message('Aucune suggestion pour le moment. Parcourez les organisations et les personnes qui témoignent.')
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 76, color: AppColors.border),
                itemBuilder: (_, i) {
                  final s = items[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AccountTile(key: ValueKey(s.id), account: s.account),
                      if (s.reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(76, 0, 16, 12),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(s.reason,
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
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
