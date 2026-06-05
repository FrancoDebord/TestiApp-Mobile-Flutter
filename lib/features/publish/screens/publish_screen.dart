import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../testimony/screens/live_screen.dart';
import '../models/publish_models.dart';
import '../providers/publish_provider.dart';
import 'short_record_screen.dart';

// =============================================================================
// PublishScreen — type selector (Accueil → Publier tab root)
// =============================================================================
//
// Widget tree:
//
// Scaffold
//   SafeArea
//     Column
//       _PublishHeader          (title + subtitle)
//       Expanded
//         ListView
//           _SpecialCard(short)  ← NEW (top)
//           _SpecialCard(live)   ← NEW (top)
//           _FormatCard(text)
//           _FormatCard(audio)
//           _FormatCard(video)
//       _StatusBarRow           (workflow status chips — hidden until draft exists)

class PublishScreen extends ConsumerWidget {
  const PublishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(publishProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PublishHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── Card A: Short Témoignage ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SpecialCard(
                      icon: Icons.slow_motion_video_rounded,
                      iconColor: const Color(0xFFEF4444),
                      iconBg: const Color(0xFFFEE2E2),
                      title: 'Short Témoignage',
                      description: '60 secondes · Impact immédiat',
                      onTap: () async {
                        final path = await Navigator.of(context).push<String?>(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => const ShortRecordScreen(),
                          ),
                        );
                        if (path != null && context.mounted) {
                          ref
                              .read(publishProvider.notifier)
                              .selectFormat(TestimonyFormat.video);
                          ref
                              .read(publishProvider.notifier)
                              .updateVideoPath(path);
                          ref.read(publishStepProvider.notifier).goTo(1);
                          context.pushNamed(AppRoutes.publishPreview,
                              extra: TestimonyFormat.video);
                        }
                      },
                    ),
                  ),
                  // ── Card B: Live ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SpecialCard(
                      icon: Icons.live_tv_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBg: const Color(0xFFFEE2E2),
                      title: 'Live',
                      description: 'Témoignage en temps réel',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const LiveScreen(),
                        ),
                      ),
                    ),
                  ),
                  // ── Standard format cards ─────────────────────────────────
                  ...TestimonyFormat.values.map((format) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _FormatCard(
                        format: format,
                        onTap: () {
                          ref.read(publishProvider.notifier).selectFormat(format);
                          ref.read(publishStepProvider.notifier).goTo(1);
                          context.pushNamed(
                            AppRoutes.publishPreview,
                            extra: format,
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            if (draft.status != PublishStatus.draft ||
                draft.title.isNotEmpty)
              _StatusBarRow(status: draft.status),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Header
// -----------------------------------------------------------------------------

class _PublishHeader extends StatelessWidget {
  const _PublishHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Partagez votre témoignage',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Quelle forme prend votre témoignage ?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Special card (Short Témoignage / Live) — fully custom fields
// -----------------------------------------------------------------------------

class _SpecialCard extends StatelessWidget {
  const _SpecialCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Format card
// -----------------------------------------------------------------------------

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.format,
    required this.onTap,
  });

  final TestimonyFormat format;
  final VoidCallback onTap;

  static const Map<TestimonyFormat, IconData> _icons = {
    TestimonyFormat.text: Icons.edit_note_rounded,
    TestimonyFormat.audio: Icons.mic_rounded,
    TestimonyFormat.video: Icons.videocam_rounded,
  };

  static const Map<TestimonyFormat, Color> _iconColors = {
    TestimonyFormat.text: AppColors.primary,
    TestimonyFormat.audio: Color(0xFFEF4444),   // danger-red for mic
    TestimonyFormat.video: AppColors.secondary,
  };

  static const Map<TestimonyFormat, Color> _iconBg = {
    TestimonyFormat.text: Color(0xFFF3E8FF),
    TestimonyFormat.audio: Color(0xFFFEE2E2),
    TestimonyFormat.video: Color(0xFFFEF3C7),
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _iconBg[format],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icons[format],
                  color: _iconColors[format],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Title + description
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      format.label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      format.description,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              Text(
                'Statut :',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary
            : isActive
                ? AppColors.primaryLight.withAlpha(40)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : isActive
                  ? AppColors.primaryLight
                  : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w500,
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
