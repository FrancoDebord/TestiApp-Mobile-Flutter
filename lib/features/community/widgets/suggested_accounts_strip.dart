// Bandeau « Comptes à suivre » (accueil, Mon fil, Communauté…) : cartes horizontales avec
// avatar, nom, coche vérifiée, raison de la suggestion et bouton Suivre.
// - une carte suivie disparaît et la suggestion suivante prend sa place ;
// - rien n'est affiché pendant le chargement, si la liste est vide ou en cas d'erreur.
// Backend : GET /users/suggestions — docs/fonctionnalites/abonnements.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/suggested_account.dart';
import '../providers/follow_provider.dart';
import '../providers/suggestions_provider.dart';
import 'account_tile.dart' show AccountAvatar;
import 'follow_button.dart';

class SuggestedAccountsStrip extends ConsumerWidget {
  const SuggestedAccountsStrip({
    this.title = 'Comptes à suivre',
    this.maxCards = 10,
    this.showMore = true,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    super.key,
  });

  final String title;
  final int maxCards;

  /// Lien « Voir plus » vers la Communauté.
  final bool showMore;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(suggestedAccountsProvider);
    final followed = ref.watch(followProvider.select((s) => s.following));
    final items = (async.value ?? const <SuggestedAccount>[])
        .where((s) => !followed.contains(s.id) && s.account.isFollowing != true)
        .take(maxCards)
        .toList();
    if (async.hasError || items.isEmpty) return const SizedBox.shrink();

    // Hauteur des cartes selon la taille du texte (aucun débordement à 130 %).
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardHeight = 140 + 74 * scale;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (showMore)
                  TextButton(
                    onPressed: () => context.push('/community'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary, visualDensity: VisualDensity.compact),
                    child: const Text('Voir plus'),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SuggestedCard(key: ValueKey(items[i].id), suggestion: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({required this.suggestion, super.key});

  final SuggestedAccount suggestion;

  @override
  Widget build(BuildContext context) {
    final a = suggestion.account;
    return SizedBox(
      width: 156,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/users/${a.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(
              children: [
                AccountAvatar(name: a.displayName, url: a.avatarUrl, initials: a.initials, size: 52),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        a.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (a.isVerified) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary, semanticLabel: 'Compte vérifié'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    suggestion.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, height: 1.3, color: AppColors.textSecondary),
                  ),
                ),
                FollowButton(userId: a.id, displayName: a.displayName, compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
