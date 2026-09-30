// Lecture hors ligne d'un témoignage écrit téléchargé (texte stocké dans
// l'index des téléchargements : aucun appel réseau).

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../home/models/testimony_model.dart';
import '../models/download_models.dart';

class OfflineTextScreen extends StatelessWidget {
  const OfflineTextScreen({required this.entry, super.key});

  final DownloadEntry entry;

  @override
  Widget build(BuildContext context) {
    final cover = entry.thumbnailPath;
    final verse = entry.bibleVerse;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Lecture hors ligne',
          style: AppTextStyles.h4,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          if (!kIsWeb && cover != null && File(cover).existsSync()) ...[
            ClipRRect(
              borderRadius: AppRadius.cardRadius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.file(File(cover), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppBadge(label: entry.category.label, tone: AppBadgeTone.yellow),
              const AppBadge(
                label: 'Hors ligne',
                tone: AppBadgeTone.blue,
                icon: Icons.download_done_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(entry.title, style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  entry.authorName.isEmpty
                      ? '?'
                      : entry.authorName.characters.first.toUpperCase(),
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entry.authorName,
                  style: AppTextStyles.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            entry.textBody ?? '',
            style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
          ),
          if (verse != null && verse.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.sunSoft,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: AppColors.sunBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('« $verse »', style: AppTextStyles.bodyMedium),
                  if ((entry.bibleVerseRef ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      entry.bibleVerseRef!,
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.sunText),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
