import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/widgets/audio_testimony_card.dart';
import '../../../features/home/widgets/text_testimony_card.dart';
import '../../../features/home/widgets/video_testimony_card.dart';
import '../providers/profile_provider.dart';

class MyTestimoniesScreen extends ConsumerStatefulWidget {
  const MyTestimoniesScreen({super.key});

  @override
  ConsumerState<MyTestimoniesScreen> createState() =>
      _MyTestimoniesScreenState();
}

class _MyTestimoniesScreenState
    extends ConsumerState<MyTestimoniesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(myTestimoniesProvider);

    // Filtres : pour l'instant tous sont "publiés" (pas de draft dans le feed)
    final published = all.toList();
    final drafts    = <Testimony>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes témoignages',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.textPrimary,
            )),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        iconTheme:
            const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13),
          unselectedLabelStyle: const TextStyle(
              fontFamily: 'Inter', fontSize: 13),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(text: 'Tous (${all.length})'),
            Tab(text: 'Publiés (${published.length})'),
            Tab(text: 'Brouillons (${drafts.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TestimonyList(testimonies: all),
          _TestimonyList(testimonies: published),
          _TestimonyList(testimonies: drafts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/publish'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau',
            style: TextStyle(fontFamily: 'Poppins',
                fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

class _TestimonyList extends StatelessWidget {
  const _TestimonyList({required this.testimonies});
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
              Icon(Icons.auto_stories_outlined,
                  size: 56,
                  color: AppColors.textSecondary.withAlpha(80)),
              const SizedBox(height: 16),
              Text('Aucun témoignage ici.',
                  style: AppTextStyles.h4
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text('Partagez ce que Dieu a fait dans votre vie.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/publish'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Publier un témoignage',
                    style:
                        TextStyle(fontFamily: 'Inter', fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
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
