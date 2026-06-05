import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../features/home/widgets/audio_testimony_card.dart';
import '../../../features/home/widgets/text_testimony_card.dart';
import '../../../features/home/widgets/video_testimony_card.dart';

class SavedTestimoniesScreen extends ConsumerWidget {
  const SavedTestimoniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(savedIdsProvider);
    final allFeed  = ref.watch(feedNotifierProvider);

    // Tab 1 — all saved testimonies (in feed order)
    final savedList = allFeed.where((t) => savedIds.contains(t.id)).toList();

    // Tab 2 — offline-only: saved testimonies that have a local media file
    final offlineList = savedList.where(_isOffline).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Témoignages sauvegardés',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: AppColors.border,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          bottom: TabBar(
            labelStyle: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTextStyles.labelMedium,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Sauvegardés'),
              Tab(text: 'Hors ligne'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SavedTab(testimonies: savedList),
            _OfflineTab(testimonies: offlineList),
          ],
        ),
      ),
    );
  }

  static bool _isOffline(Testimony t) {
    if (t is AudioTestimony) {
      return t.mediaPath != null && t.mediaPath!.isNotEmpty;
    }
    if (t is VideoTestimony) {
      return t.mediaPath != null && t.mediaPath!.isNotEmpty;
    }
    return false;
  }
}

// ── Tab 1: Sauvegardés ────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  const _SavedTab({required this.testimonies});

  final List<Testimony> testimonies;

  @override
  Widget build(BuildContext context) {
    if (testimonies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_border_rounded,
                size: 56,
                color: AppColors.textSecondary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun témoignage sauvegardé',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Appuyez sur le signet dans un témoignage\npour le retrouver ici.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: testimonies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _card(testimonies[i]),
    );
  }

  Widget _card(Testimony t) => switch (t) {
        TextTestimony()  => TextTestimonyCard(testimony: t),
        AudioTestimony() => AudioTestimonyCard(testimony: t),
        VideoTestimony() => VideoTestimonyCard(testimony: t),
      };
}

// ── Tab 2: Hors ligne ─────────────────────────────────────────────────────────

class _OfflineTab extends StatelessWidget {
  const _OfflineTab({required this.testimonies});

  final List<Testimony> testimonies;

  @override
  Widget build(BuildContext context) {
    if (testimonies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download_for_offline_outlined,
                size: 56,
                color: AppColors.textSecondary.withAlpha(80),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucun témoignage disponible hors ligne',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sauvegardez des témoignages avec un fichier audio/vidéo\npour y accéder sans connexion.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: testimonies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _offlineCard(testimonies[i]),
    );
  }

  Widget _offlineCard(Testimony t) {
    final card = switch (t) {
      TextTestimony()  => TextTestimonyCard(testimony: t),
      AudioTestimony() => AudioTestimonyCard(testimony: t),
      VideoTestimony() => VideoTestimonyCard(testimony: t),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: 10,
          right: 10,
          child: _OfflineBadge(),
        ),
      ],
    );
  }
}

// ── Offline badge ─────────────────────────────────────────────────────────────

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📥', style: TextStyle(fontSize: 11)),
          SizedBox(width: 4),
          Text(
            'Hors ligne',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
