import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../moderation/widgets/testimony_type_badge.dart';
import '../models/admin_models.dart';
import '../providers/admin_provider.dart';

// =============================================================================
// AdminContentScreen — Published testimony management
//
// Widget tree:
//   ListView.builder
//     _PublishedTestimonyCard (per item)
//       Title + Author + Category chip + TypeBadge
//       Stats row (views, likes)
//       Unpublish button
// =============================================================================

class AdminContentScreen extends ConsumerWidget {
  const AdminContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testimoniesAsync = ref.watch(adminTestimoniesProvider);

    return testimoniesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (testimonies) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: testimonies.length,
        itemBuilder: (context, index) =>
            _PublishedTestimonyCard(testimony: testimonies[index]),
      ),
    );
  }
}

class _PublishedTestimonyCard extends StatelessWidget {
  const _PublishedTestimonyCard({required this.testimony});
  final PublishedTestimony testimony;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            testimony.title,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF263238),
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Author + Category + Type (passent à la ligne si besoin)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 13, color: Color(0xFF98A2B3)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      testimony.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
              _CategoryChip(label: testimony.category),
              TestimonyTypeBadge(type: testimony.type),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Row(
            children: [
              // Les statistiques passent à la ligne quand la place manque.
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _StatItem(
                      icon: Icons.remove_red_eye_outlined,
                      value: _formatNumber(testimony.views),
                      label: l10n.adminViews,
                    ),
                    _StatItem(
                      icon: Icons.favorite_border_rounded,
                      value: _formatNumber(testimony.likes),
                      label: l10n.adminLikes,
                    ),
                    _StatItem(
                      icon: Icons.calendar_today_outlined,
                      value: _formatDate(testimony.publishedAt),
                      label: l10n.adminPublishedLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Unpublish button
              OutlinedButton.icon(
                onPressed: () => _confirmUnpublish(context),
                icon: const Icon(Icons.unpublished_outlined, size: 13),
                label: Text(l10n.adminUnpublish),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD92D20),
                  side: const BorderSide(color: Color(0xFFD92D20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
            );
          }),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    String one(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    if (n >= 1000000) return '${one(n / 1000000)}M';
    if (n >= 1000) return '${one(n / 1000)}k';
    return '$n';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  void _confirmUnpublish(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.adminUnpublishConfirm,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF263238),
          ),
        ),
        content: Text(
          l10n.adminUnpublishDesc,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            color: Color(0xFF667085),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF667085))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.adminUnpublish,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF184797).withAlpha(15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF184797),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF98A2B3)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '$value $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ],
    );
  }
}
