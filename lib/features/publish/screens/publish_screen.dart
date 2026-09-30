import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../models/publish_models.dart';
import '../providers/publish_provider.dart';
import 'short_record_screen.dart';

// =============================================================================
// PublishScreen — « Partager un témoignage » (maquette, écran 5)
// =============================================================================
//
// Scaffold
//   AppBar                    (« Partager un témoignage » + retour)
//   ListView
//     _PublishTile × 4 (grille 2×2) : vidéo · audio · texte · importer
//     « Autres façons de partager » : Short · Carnet privé · Live (modération)
//                                     · Lien YouTube (administrateurs)
//   _StatusBarRow             (statut du brouillon — masqué sans brouillon)
//
// « Importer une image / document » : l'application n'a pas de type de
// témoignage « image ». Le fichier choisi devient l'image de couverture (image)
// ou une preuve (PDF / image justificative) d'un témoignage écrit, puis le
// formulaire texte s'ouvre.

class PublishScreen extends ConsumerWidget {
  const PublishScreen({super.key});

  void _openFormat(
    BuildContext context,
    WidgetRef ref,
    TestimonyFormat format,
  ) {
    ref.read(publishProvider.notifier).selectFormat(format);
    ref.read(publishStepProvider.notifier).goTo(1);
    context.pushNamed(AppRoutes.publishPreview, extra: format);
  }

  Future<void> _openShort(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ShortRecordScreen(),
      ),
    );
    if (result == null || !context.mounted) return;

    final path = result['path'] as String?;
    final durationSec = result['duration'] as int? ?? 0;
    if (path == null) return;

    final notifier = ref.read(publishProvider.notifier);
    notifier.selectFormat(TestimonyFormat.video);
    notifier.updateVideoPath(path);
    if (durationSec > 0) {
      notifier.updateVideoDuration(durationSec);
      notifier.updateVideoTrim(Duration.zero, Duration(seconds: durationSec));
    }
    ref.read(publishStepProvider.notifier).goTo(1);
    context.pushNamed(AppRoutes.publishPreview, extra: TestimonyFormat.video);
  }

  void _openYouTube(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(publishProvider.notifier);
    notifier.selectFormat(TestimonyFormat.video);
    notifier.setUseYouTube(true);
    ref.read(publishStepProvider.notifier).goTo(1);
    context.pushNamed(AppRoutes.publishPreview, extra: TestimonyFormat.video);
  }

  /// Importer une image (→ couverture) ou un document (→ preuve 1), puis
  /// continuer en témoignage écrit.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Importer une image / document', style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text(
                'Le fichier accompagne un témoignage écrit : une image devient '
                'la couverture, un document (PDF ou image) est joint comme '
                'preuve.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              _SheetOption(
                icon: Icons.image_outlined,
                title: 'Image de couverture',
                subtitle: 'Photo de la galerie',
                onTap: () => Navigator.of(ctx).pop('cover'),
              ),
              _SheetOption(
                icon: Icons.description_outlined,
                title: 'Document ou preuve',
                subtitle: 'PDF, JPG, PNG ou WebP · 10 Mo max.',
                onTap: () => Navigator.of(ctx).pop('proof'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final notifier = ref.read(publishProvider.notifier);
    try {
      if (choice == 'cover') {
        final img = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          maxHeight: 900,
          imageQuality: 85,
        );
        if (img == null || !context.mounted) return;
        notifier.selectFormat(TestimonyFormat.text);
        notifier.updateCoverImage(img.path);
      } else {
        final f = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: kProofExtensions,
        );
        if (f == null || f.path == null || !context.mounted) return;
        final reason = proofRejectionReason(name: f.name, size: f.size);
        if (reason != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(reason)));
          return;
        }
        notifier.selectFormat(TestimonyFormat.text);
        notifier.setProof(
          1,
          ProofAttachment(path: f.path!, name: f.name, size: f.size),
        );
      }
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    ref.read(publishStepProvider.notifier).goTo(1);
    context.pushNamed(AppRoutes.publishPreview, extra: TestimonyFormat.text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(publishProvider);
    final user = ref.watch(currentUserProvider);
    final canLive = user?.canModerate ?? false;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        titleSpacing: 0,
        title: Text(
          'Partager un témoignage',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xl,
                AppSpacing.screen,
                24,
              ),
              children: [
                Text(
                  'Quelle forme prend votre témoignage ?',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // ── Grille 2×2 (maquette) ────────────────────────────────
                _TileRow(
                  children: [
                    _PublishTile(
                      icon: Icons.videocam_rounded,
                      label: 'Enregistrer une vidéo',
                      onTap: () =>
                          _openFormat(context, ref, TestimonyFormat.video),
                    ),
                    _PublishTile(
                      icon: Icons.mic_rounded,
                      label: 'Enregistrer un audio',
                      onTap: () =>
                          _openFormat(context, ref, TestimonyFormat.audio),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _TileRow(
                  children: [
                    _PublishTile(
                      icon: Icons.article_rounded,
                      label: 'Écrire un texte',
                      onTap: () =>
                          _openFormat(context, ref, TestimonyFormat.text),
                    ),
                    _PublishTile(
                      icon: Icons.add_photo_alternate_rounded,
                      label: 'Importer une image / document',
                      onTap: () => _import(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                // ── Autres entrées ───────────────────────────────────────
                Text(
                  'Autres façons de partager',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _OptionTile(
                  icon: Icons.slow_motion_video_rounded,
                  title: 'Short Témoignage',
                  description: '60 secondes · Impact immédiat',
                  onTap: () => _openShort(context, ref),
                ),
                _OptionTile(
                  icon: Icons.lock_rounded,
                  title: 'Carnet privé',
                  description: 'Garder un témoignage pour moi, sans le publier',
                  onTap: () => context.push('/journal'),
                ),
                // Live : modérateurs / administrateurs.
                if (canLive)
                  _OptionTile(
                    icon: Icons.live_tv_rounded,
                    title: 'Live',
                    description: 'Témoignage en direct, en temps réel',
                    onTap: () => context.push('/lives/new'),
                  ),
                // Lien YouTube (administrateurs) : docs serveur
                // fonctionnalites/videos-youtube.md
                if (isAdmin)
                  _OptionTile(
                    icon: Icons.smart_display_rounded,
                    title: 'Lien YouTube',
                    description:
                        'Publier une vidéo déjà sur YouTube (administrateurs)',
                    onTap: () => _openYouTube(context, ref),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (draft.status != PublishStatus.draft || draft.title.isNotEmpty)
            _StatusBarRow(status: draft.status),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Grille : deux tuiles de même hauteur par ligne
// -----------------------------------------------------------------------------

class _TileRow extends StatelessWidget {
  const _TileRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: children[1]),
        ],
      ),
    );
  }
}

/// Grande tuile blanche (radius 16, bordure fine, ombre légère) avec une
/// bulle d'icône bleu doux et un libellé centré.
class _PublishTile extends StatelessWidget {
  const _PublishTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppShadows.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 132),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrée secondaire (Short, Carnet privé, Live, Lien YouTube).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      onTap: onTap,
    );
  }
}

// -----------------------------------------------------------------------------
// Workflow status bar
// -----------------------------------------------------------------------------

class _StatusBarRow extends StatelessWidget {
  const _StatusBarRow({required this.status});

  final PublishStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text('Statut :', style: AppTextStyles.bodySmall),
              const SizedBox(width: 8),
              ...PublishStatus.values.map((s) {
                final isActive = s.index <= status.index;
                final isCurrent = s == status;
                return Row(
                  children: [
                    _StatusChip(
                      label: s.label,
                      isActive: isActive,
                      isCurrent: isCurrent,
                    ),
                    if (s != PublishStatus.published)
                      Container(
                        width: 16,
                        height: 1,
                        color: isActive && s.index < status.index
                            ? AppColors.primary
                            : AppColors.border,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.isActive,
    required this.isCurrent,
  });

  final String label;
  final bool isActive;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary
            : isActive
            ? AppColors.primarySoft
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : isActive
              ? AppColors.primarySoft
              : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.family,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isCurrent
              ? Colors.white
              : isActive
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}
