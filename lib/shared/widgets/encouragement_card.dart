import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../content/encouragements.dart';
import 'guest_gate.dart' show requireAccount;

/// Carte « Témoignez » : un verset (ou une invitation) et le bouton Témoigner.
///
/// [compact] : bandeau discret (en tête de page) ; sinon carte insérée dans un fil.
/// [actionLabel] / [onAction] : remplacent l'ouverture de Publier.
class EncouragementCard extends ConsumerWidget {
  const EncouragementCard({
    required this.message,
    this.compact = false,
    this.actionLabel = 'Témoigner',
    this.onAction,
    this.showAction = true,
    super.key,
  });

  final Encouragement message;
  final bool compact;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool showAction;

  Future<void> _testify(BuildContext context, WidgetRef ref) async {
    if (onAction != null) return onAction!();
    if (!await requireAccount(context, ref, reason: 'partager votre témoignage')) return;
    if (context.mounted) context.go('/publish');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = message;
    return Semantics(
      container: true,
      label: m.isVerse ? 'Verset ${m.reference}' : 'Invitation à témoigner',
      child: Container(
        padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, compact ? 12 : 14),
        decoration: BoxDecoration(
          color: AppColors.sunSoft,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.sunBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.sun,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    m.isVerse ? Icons.menu_book_rounded : Icons.campaign_rounded,
                    size: 19,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.isVerse ? '« ${m.text} »' : m.text,
                        maxLines: compact ? 3 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.45,
                          fontStyle: m.isVerse ? FontStyle.italic : FontStyle.normal,
                          fontWeight: m.isVerse ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                      if (m.isVerse) ...[
                        const SizedBox(height: 4),
                        Text(
                          m.reference!,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.sunText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (showAction) ...[
              SizedBox(height: compact ? 6 : 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _testify(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  icon: const Icon(Icons.campaign_rounded, size: 18),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
