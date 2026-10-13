import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../daily_verse/design/verse_background_painter.dart';
import '../../daily_verse/design/verse_design.dart' show VerseAccent;
import '../../daily_verse/design/verse_layout.dart';
import '../../daily_verse/design/verse_share_image.dart';
import '../../daily_verse/design/verse_style_prefs.dart';
import '../../daily_verse/screens/daily_verse_screen.dart' show openDailyVerse;
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';

/// Carte repliable du verset du jour : le verset dans le design du jour (ou
/// celui choisi dans le sélecteur du plein écran). Un tap sur le verset ouvre la
/// page plein écran (versions, prière, commentaires, témoignages) :
/// [openDailyVerse] — docs serveur fonctionnalites/verset-du-jour.md
///
/// Widget tree:
/// AnimatedCrossFade
///   ├─ [collapsed] → _CollapsedBanner
///   └─ [expanded]  → _ExpandedBanner
///       └─ VerseCanvas (fond du design, hauteur calculée d'après le texte)
///           └─ Column
///               ├─ Row (en-tête : icône + « Verset du jour » + ouvrir / replier)
///               ├─ VersePassageText (police et taille choisies, ≥ 18 sp)
///               ├─ Text (référence, couleur d'accent)
///               └─ Row (j'aime / prier / partage en image)
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
            // Pastille : aperçu du design du jour (ou choisi).
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox.square(
                  dimension: 20,
                  child: VerseBackground(design: ref.watch(currentVerseDesignProvider)),
                ),
              ),
            ),
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
                style: verseReferenceStyle(AppColors.primaryDark, size: 13),
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

/// Carte dépliée : le verset dans le design du jour (ou celui choisi), avec
/// la police, la taille et l'alignement choisis dans le sélecteur.
class _ExpandedBanner extends ConsumerWidget {
  const _ExpandedBanner({required this.verse});
  final DailyVerse verse;

  /// Lignes affichées au plus ; au-delà, « Lire en entier » ouvre le plein écran.
  static const _maxLines = 8;
  static const _pad = EdgeInsets.fromLTRB(20, 16, 20, 14);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dailyVerseProvider.notifier);
    final design = ref.watch(currentVerseDesignProvider);
    final prefs = ref.watch(verseStylePrefsProvider);
    final scale = verseTextScale(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final textWidth = width - _pad.horizontal;
        final fontSize = fitVerseFontSize(
          text: verse.text,
          surface: VerseSurface.card,
          prefs: prefs,
          maxWidth: textWidth,
          scale: scale,
        );
        final textHeight =
            measureVerseHeight(verse.text, prefs, fontSize, textWidth, maxLines: _maxLines);
        final truncated = measureVerseHeight(verse.text, prefs, fontSize, textWidth) > textHeight + 1;
        // Hauteurs réelles : référence mesurée, en-tête (boutons de 40 px),
        // « Lire en entier », actions ; marge de sécurité de 8 px.
        double lineHeight(String text, TextStyle style) {
          final p = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
          )..layout(maxWidth: textWidth);
          final h = p.height;
          p.dispose();
          return h;
        }

        final label = verseLabelStyle(Colors.black);
        final header = math.max(40.0, lineHeight('Verset du jour', label));
        final referenceHeight = lineHeight('— ${verse.reference}', verseReferenceStyle(Colors.black));
        final readMore = truncated ? 4 + lineHeight('Lire en entier', label) : 0.0;
        final actions = 12 + math.max(19.0, lineHeight('128', label));
        final height = _pad.vertical +
            header +
            4 +
            (design.accent == VerseAccent.line ? 17 : 0) +
            textHeight +
            10 +
            referenceHeight +
            readMore +
            10 +
            actions +
            8;

        return Semantics(
          container: true,
          label: 'Verset du jour, ${verse.reference}, ${verse.text}',
          hint: 'Touchez pour ouvrir en plein écran',
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: AppRadius.cardRadius, boxShadow: AppShadows.card),
            child: VerseCanvas(
              design: design,
              size: Size(width, height),
              borderRadius: AppRadius.cardRadius,
              builder: (context, r) {
                final align = prefs.align;
                final cross =
                    align == VerseAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
                return Padding(
                  padding: _pad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── En-tête ──────────────────────────────────────────
                      Row(
                        children: [
                          Icon(Icons.auto_stories_rounded, color: r.accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verset du jour',
                              style: verseLabelStyle(r.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Ouvrir en plein écran',
                            onPressed: () => openDailyVerse(context),
                            icon: Icon(Icons.open_in_full_rounded, color: r.ink, size: 18),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Replier le verset',
                            onPressed: () =>
                                ref.read(verseBannerExpandedProvider.notifier).update(false),
                            icon: Icon(Icons.keyboard_arrow_up_rounded, color: r.ink, size: 22),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // ── Verset + référence : ouvrent le plein écran ──────
                      Expanded(
                        child: GestureDetector(
                          key: const ValueKey('daily-verse-open'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => openDailyVerse(context),
                          child: ExcludeSemantics(
                            child: Column(
                              crossAxisAlignment: cross,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                VerseAccentLine(resolved: r, align: align),
                                VersePassageText(
                                  text: verse.text,
                                  accent: r.accent,
                                  textAlign: align.textAlign,
                                  maxLines: _maxLines,
                                  style: verseTextStyle(prefs, fontSize, r.ink),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '— ${verse.reference}',
                                  textAlign: align.textAlign,
                                  style: verseReferenceStyle(r.accent),
                                ),
                                if (truncated)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Lire en entier',
                                      style: verseLabelStyle(r.ink).copyWith(
                                        decoration: TextDecoration.underline,
                                        decorationColor: r.ink,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── Interactions ─────────────────────────────────────
                      Row(
                        children: [
                          Flexible(child: _InteractionButton(
                            icon: verse.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: verse.likeCount > 0 ? '${verse.likeCount}' : 'J\'aime',
                            active: verse.isLiked,
                            ink: r.ink,
                            accent: r.accent,
                            onTap: notifier.toggleLike,
                          )),
                          const SizedBox(width: 16),
                          Flexible(child: _InteractionButton(
                            icon: verse.isPrayed
                                ? Icons.volunteer_activism
                                : Icons.volunteer_activism_outlined,
                            label: verse.prayerCount > 0 ? '${verse.prayerCount}' : 'Prier',
                            active: verse.isPrayed,
                            ink: r.ink,
                            accent: r.accent,
                            onTap: notifier.togglePray,
                          )),
                          const Spacer(),
                          Flexible(child: _InteractionButton(
                            icon: Icons.share_outlined,
                            label: '',
                            semanticLabel: 'Partager le verset',
                            active: false,
                            ink: r.ink,
                            accent: r.accent,
                            onTap: () async {
                              await shareVerseImage(
                                context,
                                design: design,
                                prefs: prefs,
                                text: verse.text,
                                reference: verse.reference,
                                shareText: '${verse.text}\n— ${verse.reference}',
                              );
                              await notifier.recordShare();
                            },
                          )),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}

// ── Interaction button ────────────────────────────────────────────────────────

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.ink,
    required this.accent,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData     icon;
  final String       label;
  final bool         active;

  /// Couleurs du design (contraste garanti sur son fond).
  final Color        ink;
  final Color        accent;
  final VoidCallback onTap;
  final String?      semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : ink;
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              // Libellé vide : icône seule (partage).
              if (label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
