import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../daily_verse/screens/daily_verse_screen.dart' show openDailyVerse;
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';

/// Collapsible card that shows the daily Bible verse with a gradient
/// background and Playfair Display Italic text. Un tap sur le verset ouvre la
/// page plein écran (versions, prière, commentaires, témoignages) :
/// [openDailyVerse] — docs serveur fonctionnalites/verset-du-jour.md
///
/// Widget tree:
/// AnimatedCrossFade
///   ├─ [collapsed] → _CollapsedBanner
///   └─ [expanded]  → _ExpandedBanner
///       └─ Container (gradient)
///           └─ Column
///               ├─ Row (header: icon + "Verset du jour" + chevron)
///               ├─ Text (quote — Playfair Italic)
///               ├─ Align → Text (reference — Playfair Bold Italic)
///               └─ Row (like / pray / share)
class DailyVerseBanner extends ConsumerWidget {
  const DailyVerseBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded   = ref.watch(verseBannerExpandedProvider);
    final verseAsync = ref.watch(dailyVerseProvider);

    // Pendant le chargement ou en erreur, utiliser le fallback silencieusement
    final verse = verseAsync.value ?? const DailyVerse(
      text: '« Car je connais les projets que j\'ai formés sur vous, dit l\'Éternel, '
          'projets de paix et non de malheur, afin de vous donner un avenir et de l\'espérance. »',
      reference: 'Jérémie 29 : 11',
    );

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      crossFadeState:
          expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild:  _CollapsedBanner(verse: verse),
      secondChild: _ExpandedBanner(verse: verse),
    );
  }
}

// ── Collapsed state ──────────────────────────────────────────────────────────

class _CollapsedBanner extends ConsumerWidget {
  const _CollapsedBanner({required this.verse});
  final DailyVerse verse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => openDailyVerse(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_stories_rounded,
                color: AppColors.secondary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Verset du jour · ',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                verse.reference,
                style: AppTextStyles.verseReference.copyWith(
                  color: AppColors.primaryDark,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Le chevron déplie la bannière ; le reste ouvre le plein écran.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  ref.read(verseBannerExpandedProvider.notifier).update(true),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary, size: 20,
                    semanticLabel: 'Déplier le verset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded state ────────────────────────────────────────────────────────────

class _ExpandedBanner extends ConsumerWidget {
  const _ExpandedBanner({required this.verse});
  final DailyVerse verse;

  Future<void> _share(DailyVerse v) async {
    final text = '${v.text}\n— ${v.reference}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyVerseProvider.notifier);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // Dégradé autorisé par la charte : bleu → bleu foncé.
        gradient: const LinearGradient(
          colors: AppColors.blueGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verset du jour',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => openDailyVerse(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.open_in_full_rounded,
                        color: Colors.white70, size: 18,
                        semanticLabel: 'Ouvrir en plein écran'),
                  ),
                ),
                GestureDetector(
                  onTap: () => ref
                      .read(verseBannerExpandedProvider.notifier)
                      .update(false),
                  child: const Icon(Icons.keyboard_arrow_up_rounded,
                      color: Colors.white70, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Quote + reference : ouvrent le plein écran ──────────────────
            GestureDetector(
              key: const ValueKey('daily-verse-open'),
              behavior: HitTestBehavior.opaque,
              onTap: () => openDailyVerse(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    verse.text,
                    style: AppTextStyles.verseQuote.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.9,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— ${verse.reference}',
                      style: AppTextStyles.verseReference.copyWith(
                        color: AppColors.sun,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Interactions ─────────────────────────────────────────────────
            Row(
              children: [
                Flexible(child: _InteractionButton(
                  icon:    verse.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label:   verse.likeCount > 0
                      ? '${verse.likeCount}'
                      : 'J\'aime',
                  active:  verse.isLiked,
                  onTap:   notifier.toggleLike,
                )),
                const SizedBox(width: 16),
                Flexible(child: _InteractionButton(
                  icon:    verse.isPrayed
                      ? Icons.volunteer_activism
                      : Icons.volunteer_activism_outlined,
                  label:   verse.prayerCount > 0
                      ? '${verse.prayerCount}'
                      : 'Prier',
                  active:  verse.isPrayed,
                  onTap:   notifier.togglePray,
                )),
                const Spacer(),
                Flexible(child: _InteractionButton(
                  icon:    Icons.share_outlined,
                  label:   'Partager',
                  active:  false,
                  onTap:   () async {
                    await _share(verse);
                    await notifier.recordShare();
                  },
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Interaction button ────────────────────────────────────────────────────────

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: active ? AppColors.sun : Colors.white70,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.sun : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
