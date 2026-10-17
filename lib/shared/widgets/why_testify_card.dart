import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../content/encouragements.dart';
import 'guest_gate.dart' show requireAccount;
import '../../l10n/app_localizations.dart';

/// « Pourquoi témoigner ? » : raisons bibliques de témoigner, en accordéon
/// ([whyTestifyReasons], même contenu que le site : composant `<x-why-testify />`).
///
/// Les raisons s'excluent : en ouvrir une referme la précédente.
///
/// ```dart
/// const WhyTestifyCard()                          // carte ouverte, raisons repliées, bouton « Témoigner »
/// const WhyTestifyCard(collapsible: true)         // carte repliée sur une ligne (écrans chargés)
/// const WhyTestifyCard(initiallyOpen: 0)          // première raison ouverte
/// const WhyTestifyCard(showAction: false)         // sans bouton
/// ```
class WhyTestifyCard extends ConsumerStatefulWidget {
  const WhyTestifyCard({
    this.collapsible = false,
    this.initiallyOpen,
    this.showAction = true,
    super.key,
  });

  final bool collapsible;
  final int? initiallyOpen;
  final bool showAction;

  @override
  ConsumerState<WhyTestifyCard> createState() => _WhyTestifyCardState();
}

/// Icônes des raisons, dans l'ordre de [whyTestifyReasons].
const _reasonIcons = <IconData>[
  Icons.campaign_rounded,
  Icons.shield_rounded,
  Icons.auto_awesome_rounded,
  Icons.volunteer_activism_rounded,
  Icons.groups_rounded,
  Icons.eco_rounded,
  Icons.forum_rounded,
];

const _animation = Duration(milliseconds: 220);

class _WhyTestifyCardState extends ConsumerState<WhyTestifyCard> {
  late bool _expanded = !widget.collapsible;
  late int? _open = widget.initiallyOpen;

  int get _verseCount => whyTestifyReasons.fold(0, (n, r) => n + r.verses.length);

  Future<void> _testify() async {
    if (!await requireAccount(context, ref, reason: context.l10n.sharedReasonShareTestimony)) return;
    if (mounted) context.go('/publish');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) => _card(showCount: c.maxWidth >= 420));
  }

  Widget _card({required bool showCount}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            subtitle: context.l10n.sharedWhyTestifyCount(whyTestifyReasons.length, _verseCount),
            collapsible: widget.collapsible,
            expanded: _expanded,
            onTap: widget.collapsible ? () => setState(() => _expanded = !_expanded) : null,
          ),
          AnimatedSize(
            duration: _animation,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, reason) in whyTestifyReasons.indexed) ...[
                        const Divider(height: 1, thickness: 1, color: AppColors.border),
                        _ReasonItem(
                          reason: reason,
                          icon: _reasonIcons[i % _reasonIcons.length],
                          open: _open == i,
                          onTap: () => setState(() => _open = _open == i ? null : i),
                          showCount: showCount,
                        ),
                      ],
                      if (widget.showAction) _ActionFooter(onTestify: _testify),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.subtitle,
    required this.collapsible,
    required this.expanded,
    this.onTap,
  });

  final String subtitle;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.sunSoft, shape: BoxShape.circle),
            child: const Icon(Icons.menu_book_rounded, size: 22, color: AppColors.sunText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.sharedWhyTestifyTitle,
                  style: AppTextStyles.h4.copyWith(color: AppColors.primary, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (collapsible) _Chevron(open: expanded),
        ],
      ),
    );
    if (!collapsible) return Semantics(header: true, child: content);
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

// ── Une raison (ligne dépliable) ──────────────────────────────────────────────

class _ReasonItem extends StatelessWidget {
  const _ReasonItem({
    required this.reason,
    required this.icon,
    required this.open,
    required this.onTap,
    required this.showCount,
  });

  final WhyTestifyReason reason;
  final IconData icon;
  final bool open;
  final VoidCallback onTap;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final count = reason.verses.length;
    return AnimatedContainer(
      duration: _animation,
      color: open ? AppColors.primarySoft : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: _animation,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: open ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: open ? AppColors.primary : AppColors.border),
                      ),
                      child: Icon(icon, size: 18, color: open ? Colors.white : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reason.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reason.summary,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Nombre de versets : seulement si la carte est assez large (web, tablette).
                    if (showCount)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '$count ${count > 1 ? 'versets' : 'verset'}',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    const SizedBox(width: 6),
                    _Chevron(open: open),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: _animation,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(64, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, v) in reason.verses.indexed) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _Verse(verse: v),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Verset : texte en italique, filet jaune, référence en bleu.
class _Verse extends StatelessWidget {
  const _Verse({required this.verse});

  final Encouragement verse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.sun, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '« ${verse.text} »',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            verse.reference!,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: _animation,
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 24,
        color: open ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}

// ── Pied : bouton « Témoigner » ───────────────────────────────────────────────

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({required this.onTestify});

  final VoidCallback onTestify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Text(
            context.l10n.sharedWhyTestifyPrompt,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          FilledButton.icon(
            onPressed: onTestify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(context.l10n.sharedTestify),
          ),
        ],
      ),
    );
  }
}
