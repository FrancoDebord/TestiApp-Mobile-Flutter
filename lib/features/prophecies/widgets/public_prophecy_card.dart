import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/api_service.dart';
import 'prophecy_widgets.dart';
import '../models/prophecy.dart' show parseClockTime;

/// Parole prophétique accomplie d'un témoignage (champ `prophecy` de l'API),
/// présente si l'auteur l'a rendue publique (ou pour l'auteur lui-même).
final testimonyProphecyProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, testimonyId) async {
  if (testimonyId.startsWith('local_')) return null;
  try {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.testimonyById(testimonyId));
    final data = res.data;
    final p = data is Map ? data['prophecy'] : null;
    return p is Map ? Map<String, dynamic>.from(p) : null;
  } catch (_) {
    return null;
  }
});

/// Carte « Parole prophétique accomplie » sous un témoignage.
class PublicProphecyCard extends ConsumerWidget {
  const PublicProphecyCard({required this.testimonyId, super.key});
  final String testimonyId;

  static DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(testimonyProphecyProvider(testimonyId)).value;
    if (p == null) return const SizedBox.shrink();
    final received = _d(p['receivedOn']);
    final fulfilled = _d(p['fulfilledOn']);
    final text = p['bodyText'] as String?;
    final audio = p['audioUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.sunSoft,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.sunBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over_rounded, color: AppColors.sunText, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Parole prophétique accomplie',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.sunText)),
                ),
              ],
            ),
            if (p['title'] is String) ...[
              const SizedBox(height: 8),
              Text(p['title'] as String, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 6),
            Text(
              [
                if (received != null) 'Reçue le ${prophecyReceived(received, parseClockTime(p['receivedTime']))}',
                if (p['givenBy'] is String) 'donnée par ${p['givenBy']}',
              ].join(', '),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (text != null) ...[
              const SizedBox(height: 10),
              Text('« $text »', style: AppTextStyles.bodyMedium.copyWith(fontStyle: FontStyle.italic, height: 1.5)),
            ],
            if (audio != null) ...[
              const SizedBox(height: 10),
              ProphecyAudioPlayer(url: audio),
            ],
            if (fulfilled != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text('Accomplie le ${prophecyDay(fulfilled)}',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
