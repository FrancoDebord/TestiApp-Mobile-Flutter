import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import 'create_prayer_session_screen.dart';
import 'prayer_session_live_screen.dart';

// =============================================================================
// GroupPrayerSessionsScreen — liste des sessions de prière collective
// =============================================================================

class GroupPrayerSessionsScreen extends ConsumerWidget {
  const GroupPrayerSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(groupSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        title: const Text(
          'Sessions de prière',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Créer une session',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const CreatePrayerSessionScreen(),
              ),
            ),
          ),
        ],
      ),
      body: asyncSessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Impossible de charger les sessions'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(groupSessionsProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer',
                    style: TextStyle(fontFamily: 'Inter')),
              ),
            ],
          ),
        ),
        data: (sessions) {
          final live     = sessions.where((s) => s.isLive).toList();
          final upcoming = sessions
              .where((s) => s.status == PrayerSessionStatus.scheduled)
              .toList();
          final past = sessions.where((s) => s.isEnded).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (live.isNotEmpty) ...[
                _SectionHeader(title: 'En direct 🔴', count: live.length),
                const SizedBox(height: 8),
                ...live.map((s) => _SessionCard(
                      session: s,
                      onTap: () => _joinSession(context, s),
                    )),
                const SizedBox(height: 20),
              ],
              _SectionHeader(title: 'À venir', count: upcoming.length),
              const SizedBox(height: 8),
              if (upcoming.isEmpty)
                _EmptySectionHint(
                  label: 'Aucune session prévue',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const CreatePrayerSessionScreen(),
                    ),
                  ),
                )
              else
                ...upcoming.map((s) => _SessionCard(
                      session: s,
                      onTap: () => _joinSession(context, s),
                    )),
              const SizedBox(height: 20),
              if (past.isNotEmpty) ...[
                _SectionHeader(title: 'Terminées', count: past.length),
                const SizedBox(height: 8),
                ...past.map((s) => _SessionCard(session: s, onTap: null)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const CreatePrayerSessionScreen(),
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.video_call_rounded),
        label: const Text(
          'Créer une session',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _joinSession(BuildContext context, GroupPrayerSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrayerSessionLiveScreen(session: session),
      ),
    );
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});
  final GroupPrayerSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLive = session.isLive;
    final isEnded = session.isEnded;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isLive ? const Color(0xFFEF4444) : AppColors.border,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isEnded ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon column
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isLive
                      ? const Color(0xFFEF4444).withAlpha(15)
                      : isEnded
                          ? AppColors.border.withAlpha(80)
                          : AppColors.primary.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLive
                      ? Icons.radio_button_on_rounded
                      : isEnded
                          ? Icons.check_circle_outline_rounded
                          : Icons.upcoming_rounded,
                  color: isLive
                      ? const Color(0xFFEF4444)
                      : isEnded
                          ? AppColors.textSecondary
                          : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isLive)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'EN DIRECT',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            session.title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isEnded
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.hostName,
                      style: AppTextStyles.bodySmall,
                    ),
                    if (session.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        session.description!,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _VisibilityChip(visibility: session.visibility),
                        const SizedBox(width: 8),
                        Icon(Icons.people_outline_rounded,
                            size: 13,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          '${session.participantCount}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action
              if (!isEnded)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    isLive ? 'Rejoindre' : 'Inscrire',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color:
                          isLive ? const Color(0xFFEF4444) : AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Visibility chip ───────────────────────────────────────────────────────────

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.visibility});
  final PrayerVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (visibility) {
      PrayerVisibility.public => ('Publique', Icons.public_rounded),
      PrayerVisibility.friends => ('Amis', Icons.group_rounded),
      PrayerVisibility.private => ('Privée', Icons.lock_rounded),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
