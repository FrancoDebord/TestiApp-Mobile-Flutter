import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/profile_cover.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../home/models/testimony_model.dart';
import '../../home/widgets/testimony_feed_item.dart';
import '../data/community_repository.dart';
import '../models/community_account.dart';
import '../providers/follow_provider.dart';
import '../widgets/account_tile.dart';
import '../widgets/follow_button.dart';

/// Profil public d'un auteur (personne ou organisation) : présentation, bouton Suivre, témoignages.
/// Son propre profil ouvre l'onglet « Profil ».
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  CommunityAccount? _account;
  List<Testimony> _testimonies = const [];
  String? _error;
  bool _loading = true;
  int? _followers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(currentUserProvider)?.id == widget.userId) {
        context.go('/profile');
      } else {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(communityRepositoryProvider);
    try {
      final results = await Future.wait([repo.account(widget.userId), repo.testimoniesOf(widget.userId)]);
      if (!mounted) return;
      final account = results[0] as CommunityAccount;
      if (account.isFollowing != null) ref.read(followProvider.notifier).remember(account.id, account.isFollowing!);
      setState(() {
        _account = account;
        _followers = account.followerCount;
        _testimonies = results[1] as List<Testimony>;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Ce profil n\'a pas pu être chargé.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _account;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(a?.displayName ?? 'Profil'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading && a == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && a == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text('Réessayer')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Header(
                    account: a!,
                    followers: _followers ?? a.followerCount,
                    onFollowers: (n) => setState(() => _followers = n),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Témoignages',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  if (_testimonies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun témoignage publié pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (final t in _testimonies) TestimonyFeedItem(testimony: t),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.account, required this.followers, required this.onFollowers});
  final CommunityAccount account;
  final int followers;
  final ValueChanged<int> onFollowers;

  @override
  Widget build(BuildContext context) {
    final a = account;
    Widget stat(int n, String one, String many) => Column(
      children: [
        Text(
          '$n',
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 16),
        ),
        Text(n > 1 ? many : one, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Bandeau : photo de couverture (docs/fonctionnalites/photo-de-couverture.md), sinon fond neutre.
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.border,
                  child: ProfileCoverImage(url: a.coverUrl),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -42,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: AccountAvatar(name: a.displayName, url: a.avatarUrl, initials: a.initials, size: 84),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        a.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 19),
                      ),
                    ),
                    OrganizationBadge(isOrganization: a.isOrganization, isVerified: a.isVerified, size: 18),
                  ],
                ),
                if (a.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(a.subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    stat(a.testimonyCount, 'témoignage', 'témoignages'),
                    stat(followers, 'abonné', 'abonnés'),
                    stat(a.followingCount, 'abonnement', 'abonnements'),
                  ],
                ),
                const SizedBox(height: 14),
                FollowButton(userId: a.id, displayName: a.displayName, onCountChanged: onFollowers),
                if (a.bio != null) ...[
                  const SizedBox(height: 14),
                  Text(a.bio!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
