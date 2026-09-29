import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../models/community_account.dart';
import 'follow_button.dart';

/// Photo de profil ou initiales.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({required this.name, this.url, this.initials, this.size = 48, super.key});

  final String name;
  final String? url;
  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryLight.withAlpha(40),
      child: Text(
        initials ?? (name.isNotEmpty ? name.characters.first.toUpperCase() : '?'),
        style: TextStyle(color: AppColors.primary, fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: size * 0.34),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Ligne d'un compte (Communauté) : avatar, nom, coche, type / ville, compteurs, bouton Suivre.
class AccountTile extends StatefulWidget {
  const AccountTile({required this.account, super.key});
  final CommunityAccount account;

  @override
  State<AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<AccountTile> {
  late int _followers = widget.account.followerCount;

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final subtitle = a.subtitle;
    return InkWell(
      onTap: () => context.push('/users/${a.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AccountAvatar(name: a.displayName, url: a.avatarUrl, initials: a.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(a.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      OrganizationBadge(isOrganization: a.isOrganization, isVerified: a.isVerified, size: 15),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '$_followers abonné${_followers > 1 ? 's' : ''} · ${a.testimonyCount} témoignage${a.testimonyCount > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (a.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(a.bio!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            FollowButton(
              userId: a.id,
              displayName: a.displayName,
              compact: true,
              onCountChanged: (n) => setState(() => _followers = n),
            ),
          ],
        ),
      ),
    );
  }
}
