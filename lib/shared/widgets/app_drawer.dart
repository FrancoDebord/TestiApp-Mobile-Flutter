import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/daily_verse/screens/daily_verse_screen.dart' show openDailyVerse;
import '../../features/bible/models/bible_models.dart' show kDefaultBibleTranslation;
import '../../core/theme/app_colors.dart';
import '../../features/accounts/providers/acting_account_provider.dart'
    show actingAccountProvider, myAccountsProvider;
import '../../features/accounts/widgets/account_widgets.dart' show showAccountSwitcher;
import '../../features/auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../features/offline/outbox_controller.dart' show outboxProvider;
import '../../l10n/app_localizations.dart';
import 'organization_badge.dart';

/// Menu latéral (ouvert depuis l'accueil) : accès aux écrans qui n'ont pas d'onglet
/// — Communauté, Bible, Directs, Mes abonnements, Carnet, Mes témoignages, Sauvegardes, Paramètres, et
/// Modération / Administration selon le rôle.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final l10n = context.l10n;
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
                              child: Text(user?.displayName ?? l10n.authSignIn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                            if (user != null)
                              OrganizationBadge(isOrganization: user.isOrganization, isVerified: user.isVerified, approvalBadge: user.approvalBadge, size: 15),
                          ]),
                          Text(
                              user == null
                                  ? l10n.sharedDrawerGuestSubtitle
                                  : acting != null
                                      ? l10n.sharedDrawerManagedAccount
                                      : l10n.sharedDrawerViewProfile,
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
                title: Text(l10n.sharedDrawerSwitchAccount,
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600)),
                subtitle: Text(l10n.sharedDrawerSwitchAccountSubtitle, style: const TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(context).pop();
                  showAccountSwitcher(context);
                },
              ),
            const Divider(height: 1),
            item(Icons.groups_rounded, l10n.settingsCommunity, '/community', subtitle: l10n.sharedDrawerCommunitySubtitle),
            // Verset du jour et historique des versets (page dédiée).
            ListTile(
              key: const ValueKey('drawer-daily-verse'),
              leading: const Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
              title: Text(l10n.verseOfTheDayMenu,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w500)), // i18n-ignore
              subtitle: Text(l10n.verseOfTheDayMenuSubtitle, style: const TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(context).pop();
                openDailyVerse(context);
              },
            ),
            item(Icons.history_rounded, l10n.verseHistoryTitle, '/verse-history',
                subtitle: l10n.verseHistoryMenuSubtitle),
            // Bible : branche du shell (pas d'onglet dans la barre du bas) → go.
            // Ouvre directement la Louis Segond (retour : liste des versions).
            item(Icons.auto_stories_rounded, l10n.sharedDrawerBible, '/bible/$kDefaultBibleTranslation',
                subtitle: l10n.sharedDrawerBibleSubtitle, tab: true),
            item(Icons.sensors_rounded, l10n.sharedDrawerLives, '/lives'),
            // Écran empilé (hors onglets) : « Retour » revient où l'on était.
            item(Icons.event_rounded, l10n.navEvents, '/events',
                subtitle: l10n.sharedDrawerEventsSubtitle),
            // Prière (docs serveur fonctionnalites/requetes-de-priere.md, sessions-de-priere.md)
            item(Icons.volunteer_activism_outlined, l10n.prayerTitle, '/prayer-requests',
                subtitle: l10n.sharedDrawerPrayerRequestsSubtitle),
            item(Icons.groups_2_outlined, l10n.prayerGroupTitle, '/prayer-sessions',
                subtitle: l10n.sharedDrawerPrayerSessionsSubtitle),
            if (user != null)
              item(Icons.dynamic_feed_rounded, l10n.feedTitle, '/my-feed',
                  subtitle: l10n.sharedDrawerFeedSubtitle),
            item(Icons.download_for_offline_outlined, l10n.navDownloads, '/downloads'),
            // Fait hors connexion, en attente d'envoi (visible seulement s'il y a quelque chose).
            if (user != null && ref.watch(outboxProvider.select((s) => s.items.length)) > 0)
              item(Icons.cloud_upload_outlined, l10n.outboxTitle, '/outbox',
                  subtitle: l10n.outboxCount(ref.watch(outboxProvider.select((s) => s.items.length)))),
            if (user != null) ...[
              item(Icons.how_to_reg_outlined, l10n.sharedDrawerFollowing, '/following'),
              item(Icons.people_alt_outlined, l10n.sharedDrawerFollowers, '/followers'),
              item(Icons.menu_book_rounded, l10n.sharedDrawerJournal, '/journal'),
              item(Icons.record_voice_over_outlined, l10n.sharedDrawerProphecies, '/prophecies',
                  subtitle: l10n.sharedDrawerPropheciesSubtitle),
              item(Icons.video_library_outlined, l10n.profileMyTesti, '/profile/my-testimonies', tab: true),
              item(Icons.playlist_play_rounded, l10n.playlistsMine, '/mes-listes'),
              item(Icons.bookmark_outline_rounded, l10n.sharedDrawerSaved, '/profile/saved', tab: true),
              // Administrateurs du compte (tous les comptes) et comptes que j'administre.
              item(Icons.manage_accounts_outlined, l10n.sharedDrawerManagers, '/managers',
                  subtitle: l10n.sharedDrawerManagersSubtitle),
            ],
            if (user?.canModerate ?? false) ...[
              const Divider(height: 1),
              item(Icons.shield_outlined, l10n.sharedDrawerModeration, '/moderation'),
              if (user!.isAdmin) item(Icons.admin_panel_settings_outlined, l10n.sharedDrawerAdministration, '/admin'),
            ],
            const Divider(height: 1),
            if (user != null) item(Icons.settings_outlined, l10n.settingsTitle, '/profile/settings', tab: true),
          ],
        ),
      ),
    );
  }
}
