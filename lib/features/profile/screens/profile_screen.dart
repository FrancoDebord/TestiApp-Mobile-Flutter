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
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/widgets/testimony_feed_item.dart';
import '../../../features/auth/providers/auth_notifier.dart' show canModerateProvider, currentUserProvider;
import '../../../features/prayer/screens/group_prayer_sessions_screen.dart';
import '../../../features/prayer/screens/prayer_requests_screen.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/guest_gate.dart' show isGuestProvider;
import '../../../shared/widgets/organization_badge.dart';
import '../../../shared/widgets/profile_cover.dart';
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_menu.dart';

/// Écran 9 de la maquette : « Profil utilisateur ».
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isGuestProvider)) return const _GuestProfile();

    final profile = ref.watch(userProfileProvider);
    final myTestimonies = ref.watch(myTestimoniesProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
          children: [
            _ProfileHeader(profile: profile),
            const SizedBox(height: AppSpacing.xl),
            _StatsRow(profile: profile),
            const SizedBox(height: AppSpacing.lg),
            const _HeaderButtons(),
            const SizedBox(height: AppSpacing.xl),
            const _MainMenu(),
            const SizedBox(height: AppSpacing.xl),
            const _SpaceMenu(),
            const SizedBox(height: AppSpacing.xl),
            _PersonalInfoCard(profile: profile),
            const SizedBox(height: AppSpacing.xl),
            _MyTestimoniesSection(testimonies: myTestimonies),
          ],
        ),
      ),
    );
  }
}

// ── Mode invité : invitation à se connecter + menu public ─────────────────

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxl, AppSpacing.screen, AppSpacing.xxxl),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: AppShadows.cardDecoration,
              child: Column(
                children: [
                  const ExcludeSemantics(child: AppLogoMark(size: 64)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.profileGuestTitle,
                    style: AppTextStyles.h3.copyWith(fontSize: 19),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.profileGuestDesc,
                    style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: l10n.profileGuestCta,
                    variant: AppButtonVariant.orange,
                    fullWidth: true,
                    onPressed: () => context.pushNamed(AppRoutes.login),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ProfileMenuCard(
              children: [
                ProfileMenuTile(
                  icon: Icons.download_rounded,
                  title: l10n.profileDownloads,
                  onTap: () => context.go(AppPaths.downloadsPath),
                ),
                ProfileMenuTile(
                  icon: Icons.language_rounded,
                  title: l10n.settingsLanguage,
                  value: l10n.isFr ? 'Français' : 'English',
                  onTap: () => context.pushNamed(AppRoutes.language),
                ),
                ProfileMenuTile(
                  icon: Icons.help_outline_rounded,
                  title: l10n.profileHelp,
                  onTap: () => context.pushNamed(AppRoutes.help),
                ),
                ProfileMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: l10n.profileAbout,
                  onTap: () => context.pushNamed(AppRoutes.about),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête : avatar (anneau d'édition), nom, badge, ancienneté ────────────

class _ProfileHeader extends ConsumerStatefulWidget {
  const _ProfileHeader({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<_ProfileHeader> {
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
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Galerie photos', style: TextStyle(fontFamily: AppFonts.family)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: const Text('Prendre une photo', style: TextStyle(fontFamily: AppFonts.family)),
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

    return Semantics(
      button: true,
      label: 'Modifier la photo de profil',
      child: GestureDetector(
        onTap: _pickAvatar,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Anneau d'édition : bleu fin + liseré blanc.
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: AppShadows.card,
              ),
              child: CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: bg,
                child: bg == null
                    ? Text(
                        p.initials,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontWeight: FontWeight.w700,
                          fontSize: 28,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: _uploading
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final isOrg = user?.isOrganization ?? false;
    final hasCover = profile.coverUrl != null;

    final avatarBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(profile),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                profile.displayName,
                style: AppTextStyles.h3.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user != null && user.isVerified) ...[
              const SizedBox(width: 6),
              OrganizationBadge(isOrganization: user.isOrganization, isVerified: true, size: 18),
            ],
          ],
        ),
        if (user != null && isOrg) _OrganizationHeaderInfo(user: user),
        if (profile.extras.title.isNotEmpty) ...[
          const SizedBox(height: 6),
          AppBadge(label: profile.extras.title, tone: AppBadgeTone.yellow, dense: true),
        ],
        const SizedBox(height: 4),
        Text(
          [l10n.profileMemberSince(profile.memberSince), if (profile.country.isNotEmpty) profile.country].join(' · '),
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            profile.bio!,
            style: AppTextStyles.bodySmall.copyWith(fontStyle: FontStyle.italic, height: 1.4),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Photo de couverture : docs/fonctionnalites/photo-de-couverture.md
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Photo de couverture',
            icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary),
            onPressed: () => showProfileCoverSheet(context, ref, hasCover: hasCover),
          ),
        ),
        if (hasCover)
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: ColoredBox(
                    color: AppColors.primarySoft,
                    child: ProfileCoverImage(url: profile.coverUrl),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 60), child: avatarBlock),
            ],
          )
        else
          avatarBlock,
      ],
    );
  }
}

// ── Statistiques : Témoignages / J'aime / Abonnés ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});
  final UserProfile profile;

  static String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatTile(_fmt(profile.testimonyCount), l10n.profileTestimonies,
                onTap: () => context.pushNamed(AppRoutes.myTestimonies)),
            _StatTile(_fmt(profile.likeCount), l10n.profileLikes),
            _StatTile(_fmt(profile.followersCount), l10n.profileFollowers),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Abonnements + prières : conservés, en ligne discrète.
        InkWell(
          onTap: () => context.push('/following'),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '${_fmt(profile.followingCount)} ${l10n.profileFollowing.toLowerCase()} · '
              '${_fmt(profile.prayerCount)} ${l10n.profilePrayers.toLowerCase()}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.value, this.label, {this.onTap});
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.h3.copyWith(fontSize: 20, height: 1.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return Expanded(
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadius.md), child: content),
    );
  }
}

// ── Boutons « Modifier le profil » / « Paramètres » ───────────────────────

class _HeaderButtons extends StatelessWidget {
  const _HeaderButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: l10n.profileEdit,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            fullWidth: true,
            onPressed: () => context.pushNamed(AppRoutes.editProfile),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: l10n.profileSettings,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
            fullWidth: true,
            onPressed: () => context.pushNamed(AppRoutes.settings),
          ),
        ),
      ],
    );
  }
}

// ── Menu principal (maquette) ─────────────────────────────────────────────

class _MainMenu extends StatelessWidget {
  const _MainMenu();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProfileMenuCard(
      children: [
        ProfileMenuTile(
          icon: Icons.auto_stories_outlined,
          title: l10n.profileMyTesti,
          onTap: () => context.pushNamed(AppRoutes.myTestimonies),
        ),
        ProfileMenuTile(
          icon: Icons.download_rounded,
          title: l10n.profileDownloads,
          onTap: () => context.go(AppPaths.downloadsPath),
        ),
        ProfileMenuTile(
          icon: Icons.notifications_none_rounded,
          title: l10n.notifTitle,
          onTap: () => context.pushNamed(AppRoutes.notifications),
        ),
        ProfileMenuTile(
          icon: Icons.language_rounded,
          title: l10n.settingsLanguage,
          value: l10n.isFr ? 'Français' : 'English',
          onTap: () => context.pushNamed(AppRoutes.language),
        ),
        ProfileMenuTile(
          icon: Icons.help_outline_rounded,
          title: l10n.profileHelp,
          onTap: () => context.pushNamed(AppRoutes.help),
        ),
        ProfileMenuTile(
          icon: Icons.info_outline_rounded,
          title: l10n.profileAbout,
          onTap: () => context.pushNamed(AppRoutes.about),
        ),
      ],
    );
  }
}

// ── Mon espace : sauvegardés, carnet, prière, communauté, modération ──────

class _SpaceMenu extends ConsumerWidget {
  const _SpaceMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canModerate = ref.watch(canModerateProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProfileMenuCard(
          title: 'Mon espace',
          children: [
            ProfileMenuTile(
              icon: Icons.bookmark_outline_rounded,
              title: l10n.profileSaved,
              subtitle: 'Vos témoignages mis de côté',
              onTap: () => context.pushNamed(AppRoutes.savedTestimonies),
            ),
            ProfileMenuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Mon carnet privé',
              subtitle: 'Ce que Dieu a fait pour moi, gardé pour moi seul',
              onTap: () => context.push('/journal'),
            ),
            ProfileMenuTile(
              icon: Icons.volunteer_activism_outlined,
              title: 'Requêtes de prière',
              subtitle: 'Soumettre et intercéder pour les autres',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrayerRequestsScreen())),
            ),
            ProfileMenuTile(
              icon: Icons.groups_outlined,
              title: 'Sessions de prière',
              subtitle: 'Rejoindre ou créer une session collective',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GroupPrayerSessionsScreen())),
            ),
            ProfileMenuTile(
              icon: Icons.person_add_alt_outlined,
              title: l10n.profileFollowing,
              subtitle: 'Les comptes que vous suivez',
              onTap: () => context.push('/following'),
            ),
            ProfileMenuTile(
              icon: Icons.diversity_3_outlined,
              title: 'Communauté',
              subtitle: 'Églises, ministères et membres à suivre',
              onTap: () => context.push('/community'),
            ),
          ],
        ),
        if (canModerate || isAdmin) ...[
          const SizedBox(height: AppSpacing.xl),
          ProfileMenuCard(
            title: 'Gestion',
            children: [
              if (canModerate)
                ProfileMenuTile(
                  icon: Icons.shield_outlined,
                  title: 'Espace modération',
                  subtitle: 'Gérer les témoignages en attente',
                  onTap: () => context.push('/moderation'),
                ),
              if (isAdmin)
                ProfileMenuTile(
                  icon: Icons.admin_panel_settings_outlined,
                  color: AppColors.danger,
                  title: 'Administration',
                  subtitle: 'Gérer les utilisateurs et le contenu',
                  onTap: () => context.push('/admin'),
                ),
            ],
          ),
        ],
      ],
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

    return DecoratedBox(
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Informations personnelles',
                    style: AppTextStyles.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).profileEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  onPressed: () => context.pushNamed(AppRoutes.editProfile),
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
                  Icon(Icons.person_add_outlined, size: 36, color: AppColors.textSecondary.withAlpha(110)),
                  const SizedBox(height: 10),
                  Text(
                    'Complétez votre profil pour que la communauté vous connaisse.',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Compléter mon profil',
                    leadingIcon: Icons.add_rounded,
                    size: AppButtonSize.small,
                    onPressed: () => context.pushNamed(AppRoutes.editProfile),
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
              Text(label, style: AppTextStyles.bodySmall),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 46, color: AppColors.border),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mes témoignages récents',
                style: AppTextStyles.h4,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.pushNamed(AppRoutes.myTestimonies),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Voir tout', style: TextStyle(fontFamily: AppFonts.family, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (testimonies.isEmpty)
          const _EmptyMyTestimonies()
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
      VerificationStatus.pending => ('Vérification en cours', Icons.hourglass_top_rounded, AppBadgeTone.yellow),
      VerificationStatus.rejected => ('Vérification refusée', Icons.error_outline_rounded, AppBadgeTone.danger),
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
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500, color: AppColors.primary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                          const Icon(Icons.language_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              website.replaceFirst(RegExp('^https?://'), ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 12,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (chip != null) AppBadge(label: chip.$1, icon: chip.$2, tone: chip.$3, dense: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyMyTestimonies extends StatelessWidget {
  const _EmptyMyTestimonies();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppShadows.cardDecoration,
      child: Column(
        children: [
          Icon(Icons.edit_note_rounded, size: 40, color: AppColors.textSecondary.withAlpha(110)),
          const SizedBox(height: 10),
          Text(
            'Vous n\'avez pas encore publié de témoignage.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Partager un témoignage',
            leadingIcon: Icons.add_rounded,
            variant: AppButtonVariant.orange,
            size: AppButtonSize.small,
            onPressed: () => context.go('/publish'),
          ),
        ],
      ),
    );
  }
}
