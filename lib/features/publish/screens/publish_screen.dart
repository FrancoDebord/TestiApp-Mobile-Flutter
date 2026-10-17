import '../../../shared/content/encouragements.dart';
import '../../../shared/widgets/encouragement_card.dart';
import '../../../shared/widgets/why_testify_card.dart';
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
import '../../../l10n/app_localizations.dart';
import '../../conversion/providers/conversion_providers.dart' show myConversionProvider;
import '../../conversion/widgets/conversion_widgets.dart' show ConversionInviteCard, canStartConversion, conversionIcon;

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
              Text(ctx.l10n.publishImportTitle, style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text(
                ctx.l10n.publishImportHint,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              _SheetOption(
                icon: Icons.image_outlined,
                title: ctx.l10n.publishImportCover,
                subtitle: ctx.l10n.publishImportCoverHint,
                onTap: () => Navigator.of(ctx).pop('cover'),
              ),
              _SheetOption(
                icon: Icons.description_outlined,
                title: ctx.l10n.publishImportProof,
                subtitle: ctx.l10n.publishImportProofHint,
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
    // Événements : organisations vérifiées et administrateurs (docs serveur
    // fonctionnalites/evenements.md).
    final canCreateEvents =
        isAdmin || ((user?.isOrganization ?? false) && (user?.isVerified ?? false));
    final forEvent = ref.watch(publishEventProvider);
    final forProphecy = ref.watch(publishProphecyProvider);
    // Témoignage de conversion : un seul par compte personnel (docs serveur
    // fonctionnalites/temoignage-de-conversion.md).
    final forConversion = ref.watch(publishConversionProvider);
    final myConversion = ref.watch(myConversionProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
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
          context.l10n.publishShareTitle,
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
                // Témoignage officiel d'un événement (choisi depuis sa page).
                if (forEvent != null) ...[
                  _EventAttachBanner(
                    title: forEvent.title,
                    onClear: () => ref.read(publishEventProvider.notifier).clear(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Témoignage de l'accomplissement d'une parole prophétique.
                if (forProphecy != null) ...[
                  _ProphecyAttachBanner(
                    prophecy: forProphecy,
                    onPublicChanged: (v) => ref.read(publishProphecyProvider.notifier).setPublic(v),
                    onClear: () => ref.read(publishProphecyProvider.notifier).clear(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                // Mon témoignage de conversion (année, lieu et verset à l'étape suivante).
                if (forConversion != null) ...[
                  _ConversionAttachBanner(
                    onClear: () => ref.read(publishConversionProvider.notifier).clear(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else if (forEvent == null &&
                    forProphecy == null &&
                    (myConversion?.canCreate ?? false)) ...[
                  ConversionInviteCard(
                    onTap: () {
                      if (canStartConversion(context, ref)) {
                        ref.read(publishConversionProvider.notifier).start();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (forEvent == null && forProphecy == null && forConversion == null) ...[
                  EncouragementCard(
                    message: encouragementVerses[2], // Psaume 66:16
                    compact: true,
                    showAction: false,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const WhyTestifyCard(collapsible: true, showAction: false),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  context.l10n.publishWhichForm,
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
                      label: context.l10n.publishRecordVideo,
                      onTap: () =>
                          _openFormat(context, ref, TestimonyFormat.video),
                    ),
                    _PublishTile(
                      icon: Icons.mic_rounded,
                      label: context.l10n.publishRecordAudio,
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
                      label: context.l10n.publishWriteText,
                      onTap: () =>
                          _openFormat(context, ref, TestimonyFormat.text),
                    ),
                    _PublishTile(
                      icon: Icons.add_photo_alternate_rounded,
                      label: context.l10n.publishImportTitle,
                      onTap: () => _import(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                // ── Autres entrées ───────────────────────────────────────
                Text(
                  context.l10n.publishOtherWays,
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _OptionTile(
                  icon: Icons.slow_motion_video_rounded,
                  title: context.l10n.publishShortTitle,
                  description: context.l10n.publishShortHint,
                  onTap: () => _openShort(context, ref),
                ),
                // Témoignage de conversion déjà raconté : le modifier.
                if (myConversion?.exists ?? false)
                  _OptionTile(
                    icon: conversionIcon,
                    title: context.l10n.conversionMineTitle,
                    description: context.l10n.conversionMineHint,
                    onTap: () => context.push('/conversions/mine/edit'),
                  ),
                _OptionTile(
                  icon: Icons.lock_rounded,
                  title: context.l10n.publishJournalOption,
                  description: context.l10n.publishJournalOptionHint,
                  onTap: () => context.push('/journal'),
                ),
                // Événement chrétien : organisations vérifiées / administrateurs.
                if (canCreateEvents)
                  _OptionTile(
                    icon: Icons.event_rounded,
                    title: context.l10n.publishCreateEvent,
                    description: context.l10n.publishCreateEventHint,
                    onTap: () => context.push('/events/new'),
                  ),
                // Live : modérateurs / administrateurs.
                if (canLive)
                  _OptionTile(
                    icon: Icons.live_tv_rounded,
                    title: context.l10n.publishLive,
                    description: context.l10n.publishLiveHint,
                    onTap: () => context.push('/lives/new'),
                  ),
                // Lien YouTube (administrateurs) : docs serveur
                // fonctionnalites/videos-youtube.md
                if (isAdmin)
                  _OptionTile(
                    icon: Icons.smart_display_rounded,
                    title: context.l10n.publishYouTubeLink,
                    description: context.l10n.publishYouTubeHint,
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
              Text(context.l10n.publishStatusLabel, style: AppTextStyles.bodySmall),
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

/// « Mon témoignage de conversion » : le témoignage publié sera celui-là.
class _ConversionAttachBanner extends StatelessWidget {
  const _ConversionAttachBanner({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.sunSoft,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.sunBorder),
      ),
      child: Row(
        children: [
          const Icon(conversionIcon, color: AppColors.secondaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${context.l10n.conversionTestimonyTitle}\n',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
                TextSpan(text: context.l10n.conversionPublishHint),
              ]),
              style: AppTextStyles.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: context.l10n.conversionPublishCancel,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// « Témoignage pour l'événement … » : le témoignage publié y sera rattaché.
class _EventAttachBanner extends StatelessWidget {
  const _EventAttachBanner({required this.title, required this.onClear});

  final String title;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${context.l10n.publishEventTestimony}\n'),
                TextSpan(
                  text: title,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          IconButton(
            tooltip: context.l10n.publishEventDetach,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// « Accomplissement de la parole … » : le témoignage y sera rattaché ;
/// interrupteur pour montrer la parole avec le témoignage.
class _ProphecyAttachBanner extends StatelessWidget {
  const _ProphecyAttachBanner({
    required this.prophecy,
    required this.onPublicChanged,
    required this.onClear,
  });

  final PublishProphecy prophecy;
  final ValueChanged<bool> onPublicChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
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
              const Icon(Icons.record_voice_over_rounded, color: AppColors.sunText),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${context.l10n.publishProphecyFulfillment}\n'),
                    TextSpan(
                      text: prophecy.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: context.l10n.publishProphecyDetach,
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.only(right: 10),
            dense: true,
            value: prophecy.makePublic,
            onChanged: onPublicChanged,
            title: Text(context.l10n.publishProphecyMakePublic),
            subtitle: Text(context.l10n.publishProphecyMakePublicHint),
          ),
        ],
      ),
    );
  }
}
