import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../models/public_prophecy.dart';
import 'prophecy_widgets.dart' show prophecyDay, prophecyReceived;
import '../../../l10n/app_localizations.dart';

/// Carte d'une parole prophétique publique dans un fil : extrait de la parole et lien
/// vers le témoignage d'accomplissement (qui reste celui de son auteur).
class PublicProphecyFeedCard extends StatelessWidget {
  const PublicProphecyFeedCard({required this.prophecy, super.key});

  final PublicProphecy prophecy;

  @override
  Widget build(BuildContext context) {
    final p = prophecy;
    final meta = [
      if (p.receivedOn != null)
        context.l10n.prophecyReceivedOn(prophecyReceived(p.receivedOn!, p.receivedTime)),
      if (p.givenBy != null) context.l10n.prophecyGivenBy(p.givenBy!),
    ].join(', ');
    return Material(
      color: AppColors.sunSoft,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: const BorderSide(color: AppColors.sunBorder),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => context.push('/testimony/${p.testimonyId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.title != null) ...[
                Text(p.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
              ],
              if (meta.isNotEmpty)
                Text(meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                p.bodyText != null
                    ? context.l10n.prophecyQuoted(p.bodyText!)
                    : context.l10n.prophecyRecordedAsAudio,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic, height: 1.45),
              ),
              const SizedBox(height: 10),
              if (p.fulfilledOn != null)
                Row(children: [
                  const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(context.l10n.prophecyFulfilledOn(prophecyDay(p.fulfilledOn!)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(context.l10n.prophecyReadTestimony(p.testimonyTitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
