// lib/shared/widgets/testimony_proofs_card.dart
//
// Carte « Preuves du témoignage » : détail du témoignage (auteur, équipe, et
// public quand l'auteur a accepté leur publication), fiche de modération.
// Les fichiers privés exigent l'en-tête `Authorization: Bearer <jeton>` lu dans
// le stockage sécurisé (sans effet pour des preuves publiques).

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/home/models/testimony_model.dart';
import '../../services/api_service.dart';

/// Jeton d'accès courant (pour les images protégées chargées hors Dio).
final proofAuthHeadersProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
      final token = await ref
          .read(secureStorageProvider)
          .read(key: AppConstants.keyAccessToken);
      return {
        'Accept': '*/*',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
    });

class TestimonyProofsCard extends ConsumerWidget {
  const TestimonyProofsCard({
    super.key,
    required this.proofs,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 20),
    this.forStaffOrAuthor = true,
  });

  final List<TestimonyProof> proofs;
  final EdgeInsetsGeometry margin;

  /// Vrai pour l'auteur et l'équipe : les preuves peuvent être privées.
  /// Faux pour le public : le serveur ne les renvoie que si l'auteur les a publiées.
  final bool forStaffOrAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (proofs.isEmpty) return const SizedBox.shrink();
    final headers = ref.watch(proofAuthHeadersProvider).value;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Preuves du témoignage', style: AppTextStyles.h4),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            forStaffOrAuthor
                ? "Visibles de l'auteur et de l'équipe de modération ; aussi du "
                    "public si l'auteur a accepté leur publication (une fois le "
                    'témoignage publié).'
                : "Documents partagés par l'auteur pour confirmer ce témoignage.",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final p in proofs) ...[
            _ProofRow(proof: p, headers: headers),
            if (p != proofs.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ProofRow extends ConsumerWidget {
  const _ProofRow({required this.proof, required this.headers});

  final TestimonyProof proof;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      'Preuve ${proof.position}',
      if (proof.formattedSize.isNotEmpty) proof.formattedSize,
    ].join(' · ');

    final Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: proof.isPdf || headers == null
            ? Container(
                color: AppColors.primarySoft,
                alignment: Alignment.center,
                child: Icon(
                  proof.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              )
            : Image.network(
                proof.url,
                headers: headers,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.primarySoft,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => proof.isPdf ? _openPdf(context, ref) : _openImage(context),
      child: Row(
        children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proof.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            proof.isPdf ? Icons.ios_share_rounded : Icons.zoom_in_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context) {
    if (headers == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  proof.url,
                  headers: headers,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Fermer',
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Télécharge le PDF (requête authentifiée) puis le propose au partage,
  /// pour l'ouvrir dans le lecteur PDF de l'appareil.
  Future<void> _openPdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Téléchargement de la preuve…')),
    );
    try {
      final dir = await getTemporaryDirectory();
      final safe = proof.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '${dir.path}${Platform.pathSeparator}preuve_${proof.id}_$safe';
      await ref
          .read(apiServiceProvider)
          .rawDio
          .download(
            proof.url,
            path,
            options: Options(headers: {'Accept': 'application/pdf'}),
          );
      messenger.hideCurrentSnackBar();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/pdf')],
          title: proof.name,
        ),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("La preuve n'a pas pu être téléchargée."),
          ),
        );
    }
  }
}
