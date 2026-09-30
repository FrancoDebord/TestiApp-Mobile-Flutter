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
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';
import 'testimony_action_bar.dart';
import 'testimony_card_header.dart';

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
    final liked = ref.watch(likedIdsProvider).contains(t.id);
    final prayed = ref.watch(prayedIdsProvider).contains(t.id);
    final saved = ref.watch(savedIdsProvider).contains(t.id);
    final interactions = ref.read(interactionProvider.notifier);

    Future<void> toggleSave() async {
      if (!await ensureMember(context, ref, 'enregistrer vos favoris')) return;
      interactions.toggleSave(t.id);
    }

    Future<void> react(ReactionType? type) async {
      if (!await ensureMember(context, ref, 'réagir aux témoignages')) return;
      type == null
          ? interactions.removeReaction(t.id)
          : interactions.setReaction(t.id, type);
    }

    Future<void> pray() async {
      if (!await ensureMember(context, ref, 'réagir aux témoignages')) return;
      interactions.togglePray(t.id);
    }

    void shareFull() {
      final excerpt = shareExcerpt?.trim() ?? '';
      SharePlus.instance.share(ShareParams(
        text: '${t.title}\n\n'
            '${excerpt.isEmpty ? '' : '$excerpt\n\n'}'
            '${t.shareLink}\n\n'
            'Partagé depuis l\'application Témoignages ✝️',
      ));
      interactions.recordShare(t.id);
    }

    void shareLink() {
      SharePlus.instance.share(ShareParams(text: '${t.title}\n\n${t.shareLink}'));
      interactions.recordShare(t.id);
    }

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
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                      currentReaction: ref.watch(reactionsMapProvider)[t.id],
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
