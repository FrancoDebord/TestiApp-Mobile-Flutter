import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/accounts/providers/acting_account_provider.dart'
    show actingAccountProvider, myAccountsProvider;
import '../../features/accounts/widgets/account_widgets.dart' show showAccountSwitcher;
import '../../features/auth/providers/auth_notifier.dart' show currentUserProvider;
import 'organization_badge.dart';

/// Menu latéral (ouvert depuis l'accueil) : accès aux écrans qui n'ont pas d'onglet
/// — Communauté, Bible, Directs, Mes abonnements, Carnet, Mes témoignages, Sauvegardes, Paramètres, et
/// Modération / Administration selon le rôle.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Bascule : seulement si la personne administre au moins un autre compte.
    final acting = ref.watch(actingAccountProvider);
    final canSwitch = user != null &&
        (acting != null || (ref.watch(myAccountsProvider).value?.managed.isNotEmpty ?? false));

    // Ferme le menu puis ouvre l'écran : [tab] = chemin d'un onglet (go), sinon écran empilé (push).
    void open(String path, {bool tab = false}) {
      Navigator.of(context).pop();
      tab ? context.go(path) : context.push(path);
    }

    Widget item(IconData icon, String label, String path, {bool tab = false, String? subtitle}) => ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w500)),
          subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
          onTap: () => open(path, tab: tab),
        );

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // En-tête : la personne connectée (ou invitation à se connecter).
            InkWell(
              onTap: () => open(user == null ? '/login' : '/profile', tab: user != null),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryLight.withAlpha(40),
                      backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                      child: user?.avatarUrl == null
                          ? Icon(user == null ? Icons.person_outline_rounded : Icons.person_rounded, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(user?.displayName ?? 'Se connecter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                            if (user != null)
                              OrganizationBadge(isOrganization: user.isOrganization, isVerified: user.isVerified, size: 15),
                          ]),
                          Text(
                              user == null
                                  ? 'Pour suivre des comptes et témoigner'
                                  : acting != null
                                      ? 'Compte administré · voir le profil'
                                      : 'Voir mon profil',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (canSwitch)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                title: const Text('Changer de compte',
                    style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600)),
                subtitle: const Text("Agir au nom d'un compte que vous administrez", style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(context).pop();
                  showAccountSwitcher(context);
                },
              ),
            const Divider(height: 1),
            item(Icons.groups_rounded, 'Communauté', '/community', subtitle: 'Organisations et personnes à suivre'),
            // Bible : branche du shell (pas d'onglet dans la barre du bas) → go.
            item(Icons.auto_stories_rounded, 'Bible', '/bible',
                subtitle: 'Lire, rechercher, comparer les versions', tab: true),
            item(Icons.sensors_rounded, 'Directs', '/lives'),
            item(Icons.event_rounded, 'Événements', '/events',
                subtitle: 'Croisades, conférences, camps…', tab: true),
            // Prière (docs serveur fonctionnalites/requetes-de-priere.md, sessions-de-priere.md)
            item(Icons.volunteer_activism_outlined, 'Requêtes de prière', '/prayer-requests',
                subtitle: 'Confiez un besoin, priez pour les autres'),
            item(Icons.groups_2_outlined, 'Sessions de prière', '/prayer-sessions',
                subtitle: 'Priez ensemble, en direct'),
            if (user != null)
              item(Icons.dynamic_feed_rounded, 'Mon fil', '/my-feed',
                  subtitle: 'Vos abonnements et des témoignages pour vous'),
            item(Icons.download_for_offline_outlined, 'Téléchargements', '/downloads'),
            if (user != null) ...[
              item(Icons.how_to_reg_outlined, 'Mes abonnements', '/following'),
              item(Icons.people_alt_outlined, 'Mes abonnés', '/followers'),
              item(Icons.menu_book_rounded, 'Mon carnet privé', '/journal'),
              item(Icons.record_voice_over_outlined, 'Paroles prophétiques', '/prophecies',
                  subtitle: 'Gardez-les, priez, témoignez de leur accomplissement'),
              item(Icons.video_library_outlined, 'Mes témoignages', '/profile/my-testimonies', tab: true),
              item(Icons.bookmark_outline_rounded, 'Sauvegardés', '/profile/saved', tab: true),
              // Administrateurs du compte (tous les comptes) et comptes que j'administre.
              item(Icons.manage_accounts_outlined, 'Administrateurs du compte', '/managers',
                  subtitle: 'Deux personnes au plus agissent en votre nom'),
            ],
            if (user?.canModerate ?? false) ...[
              const Divider(height: 1),
              item(Icons.shield_outlined, 'Modération', '/moderation'),
              if (user!.isAdmin) item(Icons.admin_panel_settings_outlined, 'Administration', '/admin'),
            ],
            const Divider(height: 1),
            if (user != null) item(Icons.settings_outlined, 'Paramètres', '/profile/settings', tab: true),
          ],
        ),
      ),
    );
  }
}
