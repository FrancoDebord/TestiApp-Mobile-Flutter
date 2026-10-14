// lib/features/daily_verse/design/verse_design_picker.dart
//
// Sélecteur de design du verset du jour :
//   • [VerseDesignStackButton] : petite vignette empilée (aperçu du design
//     actuel), en bas à droite du plein écran ;
//   • [showVerseDesignPicker] : feuille à deux onglets — « Fonds » (vignettes
//     avec le vrai verset, « Toujours utiliser mon design ») et « Texte »
//     (police, taille, alignement). Le choix s'applique aussitôt (fondu).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import 'verse_background_painter.dart';
import 'verse_design.dart';
import 'verse_design_catalog.dart';
import 'verse_layout.dart';
import 'verse_style_prefs.dart';

/// Vignette empilée (aperçu du design actuel) qui ouvre le sélecteur.
class VerseDesignStackButton extends StatelessWidget {
  const VerseDesignStackButton({
    required this.design,
    required this.ink,
    required this.onTap,
    super.key,
  });

  final VerseDesign design;

  /// Couleur de l'encre du design (contour lisible sur le fond).
  final Color ink;
  final VoidCallback onTap;

  static const _w = 40.0;
  static const _h = 52.0;

  @override
  Widget build(BuildContext context) {
    Widget card(double dx, double dy, double angle, Widget child) => Positioned(
          left: dx,
          top: dy,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: _w,
              height: _h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ink.withValues(alpha: 0.85), width: 1.5),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: ClipRRect(borderRadius: BorderRadius.circular(6.5), child: child),
            ),
          ),
        );
    // Cartes de dessous : les designs suivants de la liste de l'application.
    final next = kVerseDesigns[(kVerseDesigns.indexOf(design) + 1) % kVerseDesigns.length];
    final after = kVerseDesigns[(kVerseDesigns.indexOf(design) + 2) % kVerseDesigns.length];
    return Semantics(
      button: true,
      label: 'Changer le design du verset. Design actuel : ${design.name}',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Designs et texte',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: _w + 16,
            height: _h + 12,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                card(12, 0, 0.14, VerseBackground(design: after)),
                card(7, 3, 0.07, VerseBackground(design: next)),
                card(2, 6, 0, VerseBackground(design: design)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ouvre le sélecteur de design et de texte. [text] et [reference] servent à
/// l'aperçu réel dans les vignettes.
Future<void> showVerseDesignPicker(
  BuildContext context, {
  required String text,
  required String reference,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    // Hauteur gérée par la feuille (adaptée à l'écran et à la taille du texte).
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
    builder: (_) => _PickerSheet(text: text, reference: reference),
  );
}

class _PickerSheet extends ConsumerWidget {
  const _PickerSheet({required this.text, required this.reference});

  final String text;
  final String reference;

  /// Hauteur des onglets : 340 px au taux de texte 1, plus si le texte est
  /// agrandi, sans dépasser 85 % de l'écran (barre d'onglets comprise).
  /// Les deux onglets défilent : rien ne déborde sur un petit écran.
  static double tabsHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.textScaler.scale(100) / 100;
    final wanted = 340 + 90 * (scale - 1).clamp(0.0, 1.0);
    final max = mq.size.height * 0.85 - 120 - mq.padding.vertical;
    return wanted.clamp(160.0, max < 160 ? 160.0 : max);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.secondary,
              labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: AppTextStyles.labelMedium,
              tabs: const [
                Tab(icon: Icon(Icons.palette_outlined, size: 20), text: 'Fonds', iconMargin: EdgeInsets.only(bottom: 2)),
                Tab(icon: Icon(Icons.text_fields_rounded, size: 20), text: 'Texte', iconMargin: EdgeInsets.only(bottom: 2)),
              ],
            ),
            SizedBox(
              height: tabsHeight(context),
              child: TabBarView(
                children: [
                  _DesignsTab(text: text, reference: reference),
                  const _TextTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onglet « Fonds » ─────────────────────────────────────────────────────────

class _DesignsTab extends ConsumerWidget {
  const _DesignsTab({required this.text, required this.reference});

  final String text;
  final String reference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(verseStylePrefsProvider);
    final notifier = ref.read(verseStylePrefsProvider.notifier);
    final current = ref.watch(currentVerseDesignProvider);
    final daily = ref.watch(verseDesignOfTheDayProvider);
    // Designs actifs côté serveur (GET /verse-designs), dans l'ordre du serveur.
    final designs = ref.watch(availableVerseDesignsProvider);

    // Nom sous la vignette : réglage du téléphone respecté, plafonné à × 1,3.
    final labelHeight = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3).scale(12) * 1.4;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 14),
        SizedBox(
          height: _DesignThumb.height + labelHeight + 6,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: designs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final d = designs[i];
              return _DesignThumb(
                design: d,
                prefs: prefs,
                text: text,
                reference: reference,
                selected: d.id == current.id,
                isDaily: d.id == daily.id,
                onTap: () => notifier.chooseDesign(d),
              );
            },
          ),
        ),
        SwitchListTile(
          value: prefs.alwaysMine,
          onChanged: notifier.setAlwaysMine,
          title: Text('Toujours utiliser mon design', style: AppTextStyles.labelMedium),
          subtitle: Text(
            prefs.alwaysMine
                ? 'Le même design chaque jour.'
                : 'Sinon, votre choix vaut jusqu’à demain, puis un nouveau design s’affiche.',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _DesignThumb extends StatelessWidget {
  const _DesignThumb({
    required this.design,
    required this.prefs,
    required this.text,
    required this.reference,
    required this.selected,
    required this.isDaily,
    required this.onTap,
  });

  final VerseDesign design;
  final VerseStylePrefs prefs;
  final String text;
  final String reference;
  final bool selected;
  final bool isDaily;
  final VoidCallback onTap;

  static const _size = Size(112, 150);

  /// Hauteur de l'aperçu (cadre compris), sans le nom.
  static const double height = 150 + 6;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Design ${design.name}, ${design.mood.label}${isDaily ? ', design du jour' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: _size.width,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Aperçu réel : le verset dans ce design (repeint seul).
                    RepaintBoundary(
                      child: VerseCanvas(
                        design: design,
                        size: Size(_size.width - 5, _size.height - 5 - 8),
                        animate: false,
                        borderRadius: BorderRadius.circular(10),
                        builder: (context, r) => Padding(
                          padding: const EdgeInsets.fromLTRB(9, 10, 9, 8),
                          child: Column(
                            crossAxisAlignment: prefs.align == VerseAlign.center
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  text,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: prefs.align.textAlign,
                                  textScaler: TextScaler.noScaling,
                                  style: verseTextStyle(prefs, 9.5, r.ink),
                                ),
                              ),
                              Text(
                                reference,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textScaler: TextScaler.noScaling,
                                style: verseReferenceStyle(r.accent, size: 8.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 6),
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        isDaily ? '${design.name} · du jour' : design.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
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

// ── Onglet « Texte » ─────────────────────────────────────────────────────────

class _TextTab extends ConsumerWidget {
  const _TextTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(verseStylePrefsProvider);
    final notifier = ref.read(verseStylePrefsProvider.notifier);

    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 14),
          child: Text(t, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        title('Police'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in VerseFont.values)
              ChoiceChip(
                selected: prefs.font == f,
                onSelected: (_) => notifier.setFont(f),
                showCheckmark: false,
                selectedColor: AppColors.primarySoft,
                side: BorderSide(color: prefs.font == f ? AppColors.primary : AppColors.border),
                label: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: 'Aa  ',
                    style: TextStyle(fontFamily: f.family, fontSize: 17, color: AppColors.primaryDark),
                  ),
                  TextSpan(text: f.label, style: AppTextStyles.labelMedium),
                ])),
              ),
          ],
        ),
        title('Taille'),
        SegmentedButton<VerseTextSize>(
          showSelectedIcon: false,
          segments: [
            for (final s in VerseTextSize.values)
              ButtonSegment(value: s, label: Text(s.label)),
          ],
          selected: {prefs.size},
          onSelectionChanged: (v) => notifier.setSize(v.first),
        ),
        title('Alignement'),
        SegmentedButton<VerseAlign>(
          showSelectedIcon: false,
          segments: [
            for (final a in VerseAlign.values)
              ButtonSegment(value: a, label: Text(a.label), icon: Icon(a.icon)),
          ],
          selected: {prefs.align},
          onSelectionChanged: (v) => notifier.setAlign(v.first),
        ),
      ],
    );
  }
}
