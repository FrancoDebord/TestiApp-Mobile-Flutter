// lib/features/home/widgets/feed_card_frame.dart
//
// Cadre commun des grandes cartes du fil (maquette « Accueil ») :
//   [média plein cadre : vignette vidéo 16:9 / lecteur audio]
//   badge catégorie ·························· ⋮
//   Titre en gras (2 lignes max)
//   Aperçu (1–2 lignes)
//   (avatar) Auteur ✓ · 3.4k vues · il y a 2 jours
//   ❤ 1.2k  🙏 34  💬 124  ↗            ⤓  🔖

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../testimony/prayer/pray_for_testimony.dart' show prayForTestimony;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../../repost/testimony_share_sheet.dart';
import '../../testimony/testimony_delete.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'testimony_action_bar.dart';
import 'testimony_card_header.dart';
import 'testimony_labels.dart';
import '../../../l10n/app_localizations.dart';

class FeedCardFrame extends ConsumerWidget {
  const FeedCardFrame({
    required this.testimony,
    this.media,
    this.mediaPadded = false,
    this.preview,
    this.shareExcerpt,
    super.key,
  });

  final Testimony testimony;

  /// Vignette ou lecteur affiché en haut de la carte.
  final Widget? media;

  /// `true` : le média est dans les marges de la carte (lecteur audio) ;
  /// `false` : il occupe toute la largeur, coins supérieurs arrondis.
  final bool mediaPadded;

  /// Aperçu du contenu sous le titre.
  final Widget? preview;

  /// Extrait ajouté au message de partage depuis le menu « ⋮ ».
  final String? shareExcerpt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = testimony;
    // État renvoyé par le serveur (une réaction « j'aime » et une « je prie » au plus).
    final state = ref.watch(interactionProvider);
    final liked = state.likedOf(t);
    final prayed = state.prayedOf(t);
    final saved = ref.watch(savedIdsProvider).contains(t.id);
    final interactions = ref.read(interactionProvider.notifier);

    Future<void> toggleSave() async {
      if (!await ensureMember(context, ref, context.l10n.homeReasonSave)) return;
      interactions.toggleSave(t.id);
    }

    Future<void> react(ReactionType? type) async {
      if (!await ensureMember(context, ref, context.l10n.homeReasonReact)) return;
      interactions.react(t, type);
    }

    Future<void> pray() async {
      if (!await ensureMember(context, ref, context.l10n.homeReasonReact)) return;
      if (context.mounted) await prayForTestimony(context, ref, t);
    }

    void shareFull() => showTestimonyShareSheet(context, ref, t, excerpt: shareExcerpt);
    void shareLink() => showTestimonyShareSheet(context, ref, t);

    return DecoratedBox(
      decoration: AppShadows.cardDecoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.push('/testimony/${t.id}'),
          borderRadius: AppRadius.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (media != null)
                mediaPadded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: media,
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.card),
                        ),
                        child: media,
                      ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Catégorie + menu ───────────────────────────────────
                    Row(
                      children: [
                        Flexible(child: CategoryBadge(category: t.category)),
                        const Spacer(),
                        TestimonyCardMenu(
                          isSaved: saved,
                          onSave: toggleSave,
                          onShare: shareFull,
                          onReport: () =>
                              context.push('/testimony/${t.id}/report'),
                          onDelete: canDeleteTestimony(ref, t)
                              ? () => confirmDeleteTestimony(context, ref, t)
                              : null,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── « À la une » / « Témoignage approuvé » ─────
                          TestimonyLabels(
                            testimony: t,
                            compact: true,
                            padding: const EdgeInsets.only(bottom: 6),
                          ),
                          // ── Titre ──────────────────────────────────────
                          Text(
                            t.title,
                            style: AppTextStyles.h4.copyWith(
                              fontSize: 17,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (preview != null) ...[
                            const SizedBox(height: 6),
                            preview!,
                          ],
                          const SizedBox(height: 12),
                          // ── Auteur ─────────────────────────────────────
                          TestimonyAuthorRow(testimony: t),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ── Actions ────────────────────────────────────────────
                    TestimonyActionBar(
                      testimony: t,
                      isLiked: liked,
                      isPrayed: prayed,
                      isSaved: saved,
                      currentReaction: state.reactionOf(t),
                      likesCount: state.likesOf(t),
                      prayersCount: state.prayersOf(t),
                      onReact: react,
                      onPray: pray,
                      onComment: () =>
                          context.push('/testimony/${t.id}/comments'),
                      onShare: shareLink,
                      onSave: toggleSave,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mode invité : `true` pour un membre ; pour un invité, affiche la feuille
/// « Créez un compte pour [reason] » et renvoie `false`.
Future<bool> ensureMember(
    BuildContext context, WidgetRef ref, String reason) async {
  if (!ref.read(isGuestProvider)) return true;
  return requireAccount(context, ref, reason: reason);
}

/// Style commun des aperçus (1–2 lignes, gris).
TextStyle feedPreviewStyle() => AppTextStyles.bodyMedium.copyWith(
      color: AppColors.textSecondary,
      height: 1.5,
    );
