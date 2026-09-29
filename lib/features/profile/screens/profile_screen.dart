import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/widgets/testimony_feed_item.dart';
import '../../../features/auth/providers/auth_notifier.dart' show canModerateProvider, currentUserProvider;
import '../../../features/prayer/screens/group_prayer_sessions_screen.dart';
import '../../../features/prayer/screens/prayer_requests_screen.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../../shared/widgets/profile_cover.dart';
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final myTestimonies = ref.watch(myTestimoniesProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _ProfileSliverAppBar(profile: profile),
          SliverToBoxAdapter(child: _StatsRow(profile: profile)),
          SliverToBoxAdapter(child: _PersonalInfoCard(profile: profile)),
          SliverToBoxAdapter(child: _MyTestimoniesSection(testimonies: myTestimonies)),
          SliverToBoxAdapter(child: _QuickActions()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── SliverAppBar hero gradient ─────────────────────────────────────────────

class _ProfileSliverAppBar extends ConsumerStatefulWidget {
  const _ProfileSliverAppBar({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_ProfileSliverAppBar> createState() => _ProfileSliverAppBarState();
}

class _ProfileSliverAppBarState extends ConsumerState<_ProfileSliverAppBar> {
  bool _uploading = false;

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF1FC),
                child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Galerie photos', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEAF1FC),
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: const Text('Prendre une photo', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(profileExtrasProvider.notifier).updateAvatar(file.path);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _buildAvatar(UserProfile p) {
    final localPath = p.extras.avatarPath;
    ImageProvider? bg;
    if (localPath != null && localPath.isNotEmpty) {
      bg = kIsWeb ? NetworkImage(localPath) : FileImage(File(localPath)) as ImageProvider;
    } else if (p.avatarUrl != null) {
      bg = NetworkImage(p.avatarUrl!);
    }

    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.white.withAlpha(35),
            backgroundImage: bg,
            child: bg == null
                ? Text(
                    p.initials,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          // Camera badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _uploading
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final user = ref.watch(currentUserProvider);
    final isOrg = user?.isOrganization ?? false;
    return SliverAppBar(
      expandedHeight: isOrg ? 390 : 340,
      pinned: true,
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      // Photo de couverture : docs/fonctionnalites/photo-de-couverture.md
      leading: IconButton(
        tooltip: 'Photo de couverture',
        icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
        onPressed: () => showProfileCoverSheet(context, ref, hasCover: profile.coverUrl != null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => context.pushNamed(AppRoutes.settings),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF103675), Color(0xFF184797), Color(0xFF2B5DB0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (profile.coverUrl != null) ...[
                ProfileCoverImage(url: profile.coverUrl),
                // Voile sombre : le texte blanc reste lisible sur toute photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x66000000), Color(0x99000000), Color(0xCC000000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(profile),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user != null && user.isVerified)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.fromLTRB(0, 1, 2, 1),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: OrganizationBadge(isOrganization: user.isOrganization, isVerified: true, size: 18),
                            ),
                        ],
                      ),
                      if (user != null && isOrg) _OrganizationHeaderInfo(user: user),
                      if (profile.extras.title.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withAlpha(60)),
                          ),
                          child: Text(
                            profile.extras.title,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [if (profile.country.isNotEmpty) profile.country, profile.memberSinceLabel].join(' · '),
                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: Colors.white.withAlpha(190)),
                        textAlign: TextAlign.center,
                      ),
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          profile.bio!,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withAlpha(170),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: () => context.pushNamed(AppRoutes.editProfile),
                          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                          label: Text(
                            AppLocalizations.of(context).profileEdit,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withAlpha(150), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                    ],
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

// ── Stats ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final UserProfile profile;

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _StatTile(
            '${profile.testimonyCount}',
            l10n.profileTestimonies,
            Icons.auto_stories_rounded,
            AppColors.primary,
          ),
          Container(width: 1, height: 48, color: AppColors.border),
          _StatTile(_fmt(profile.followersCount), l10n.profileFollowers, Icons.people_rounded, AppColors.danger),
          Container(width: 1, height: 48, color: AppColors.border),
          _StatTile(_fmt(profile.followingCount), l10n.profileFollowing, Icons.person_add_rounded, AppColors.secondary,
              onTap: () => context.push('/following')),
          Container(width: 1, height: 48, color: AppColors.border),
          _StatTile(
            _fmt(profile.prayerCount),
            l10n.profilePrayers,
            Icons.volunteer_activism_rounded,
            const Color(0xFF4B7ACB),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.value, this.label, this.icon, this.color, {this.onTap});
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          Text(label, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
        ],
      );
    return Expanded(
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: content),
    );
  }
}

// ── Informations personnelles ─────────────────────────────────────────────

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final e = profile.extras;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Text('Informations personnelles', style: AppTextStyles.h4),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  onPressed: () => context.pushNamed(AppRoutes.editProfile),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (!e.hasPersonalInfo)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.person_add_outlined, size: 40, color: AppColors.textSecondary.withAlpha(100)),
                  const SizedBox(height: 10),
                  Text(
                    'Complétez votre profil pour que\nla communauté vous connaisse.',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.pushNamed(AppRoutes.editProfile),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Compléter mon profil', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (e.gender.isNotEmpty) _InfoRow(Icons.wc_rounded, 'Sexe', e.gender),
            if (e.phone.isNotEmpty) _InfoRow(Icons.phone_outlined, 'Téléphone', e.phone),
            if (e.email.isNotEmpty) _InfoRow(Icons.email_outlined, 'Email', e.email),
            if (e.country.isNotEmpty) _InfoRow(Icons.public_rounded, 'Pays', e.country, isLast: true),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

// ── Section Mes témoignages récents ───────────────────────────────────────

class _MyTestimoniesSection extends StatelessWidget {
  const _MyTestimoniesSection({required this.testimonies});
  final List<Testimony> testimonies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mes témoignages', style: AppTextStyles.h3),
              const Spacer(),
              TextButton(
                onPressed: () => context.pushNamed(AppRoutes.myTestimonies),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Voir tout', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (testimonies.isEmpty)
            _EmptyMyTestimonies()
          else
            ...testimonies
                .take(2)
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TestimonyFeedItem(testimony: t),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Organisation : type · ville, site web, statut de vérification ─────────

class _OrganizationHeaderInfo extends StatelessWidget {
  const _OrganizationHeaderInfo({required this.user});
  final UserModel user;

  Future<void> _openWebsite(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le site web")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = [
      if (user.organizationType != null) user.organizationType!.label,
      if (user.organizationCity?.isNotEmpty ?? false) user.organizationCity!,
    ].join(' · ');
    final website = user.organizationWebsite;

    final chip = switch (user.effectiveVerificationStatus) {
      VerificationStatus.pending => ('Vérification en cours', Icons.hourglass_top_rounded, const Color(0xFFFDE68A)),
      VerificationStatus.rejected => ('Vérification refusée', Icons.error_outline_rounded, const Color(0xFFFECACA)),
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (line.isNotEmpty)
            Text(
              line,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(230),
              ),
              textAlign: TextAlign.center,
            ),
          if ((website?.isNotEmpty ?? false) || chip != null) ...[
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (website != null && website.isNotEmpty)
                  InkWell(
                    onTap: () => _openWebsite(context, website),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              website.replaceFirst(RegExp('^https?://'), ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (chip != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: chip.$3, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(chip.$2, size: 12, color: const Color(0xFF263238)),
                        const SizedBox(width: 4),
                        Text(
                          chip.$1,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF263238),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyMyTestimonies extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.edit_note_rounded, size: 40, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 10),
          Text(
            'Vous n\'avez pas encore publié\nde témoignage.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.go('/publish'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Partager un témoignage', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions rapides ───────────────────────────────────────────────────────

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canModerate = ref.watch(canModerateProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // ── Espace modération (modérateur + admin) ─────────────────────
          if (canModerate) ...[
            _ActionTile(
              icon: Icons.shield_outlined,
              color: const Color(0xFF184797),
              title: 'Espace modération',
              subtitle: 'Gérer les témoignages en attente',
              onTap: () => context.push('/moderation'),
            ),
            const SizedBox(height: 10),
          ],
          // ── Tableau de bord admin ──────────────────────────────────────
          if (isAdmin) ...[
            _ActionTile(
              icon: Icons.admin_panel_settings_outlined,
              color: const Color(0xFFD92D20),
              title: 'Administration',
              subtitle: 'Gérer les utilisateurs et le contenu',
              onTap: () => context.push('/admin'),
            ),
            const SizedBox(height: 10),
          ],
          _ActionTile(
            icon: Icons.lock_rounded,
            color: AppColors.primary,
            title: 'Mon carnet privé',
            subtitle: 'Ce que Dieu a fait pour moi, gardé pour moi seul',
            onTap: () => context.push('/journal'),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.bookmark_outline_rounded,
            color: AppColors.secondary,
            title: 'Témoignages sauvegardés',
            subtitle: 'Vos témoignages mis de côté',
            onTap: () => context.pushNamed(AppRoutes.savedTestimonies),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.volunteer_activism_rounded,
            color: const Color(0xFF4B7ACB),
            title: 'Requêtes de prière',
            subtitle: 'Soumettre et intercéder pour les autres',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrayerRequestsScreen())),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.groups_rounded,
            color: const Color(0xFF4B7ACB),
            title: 'Sessions de prière',
            subtitle: 'Rejoindre ou créer une session collective',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GroupPrayerSessionsScreen())),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.settings_outlined,
            color: AppColors.textSecondary,
            title: 'Paramètres',
            subtitle: 'Notifications, confidentialité',
            onTap: () => context.pushNamed(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
