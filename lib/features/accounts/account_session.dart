// Données qui dépendent du compte actif : rechargées quand la personne bascule
// entre son compte et un compte qu'elle administre.
//
// Les providers qui « watch » currentUserProvider se reconstruisent d'eux-mêmes ;
// ceux-ci lisent le compte ou chargent l'API sans le surveiller (fil, réactions,
// notifications, abonnements…) : on les invalide ici, en un seul endroit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../community/providers/follow_provider.dart' show followProvider;
import '../community/providers/suggestions_provider.dart' show suggestedAccountsProvider;
import '../daily_verse/providers/daily_verse_providers.dart' show dailyVerseCommentsProvider;
import '../events/providers/events_providers.dart';
import '../feed/feed_inserts.dart' show feedInsertsProvider;
import '../feed/personal_feed_screen.dart' show personalFeedProvider;
import '../home/providers/home_providers.dart'
    show feedNotifierProvider, interactionProvider, featuredFromApiProvider, dailyVerseProvider;
import '../live/data/live_repository.dart' show livesIndexProvider;
import '../notifications/providers/notifications_provider.dart' show notificationsNotifierProvider;
import '../prayer/providers/prayer_providers.dart';
import '../prayer/widgets/upcoming_prayer_sessions_strip.dart' show upcomingPrayerSessionsProvider;
import '../profile/providers/profile_provider.dart'
    show myTestimoniesNotifierProvider, savedTestimoniesProvider, profileExtrasProvider;
import '../repost/repost.dart' show repostedByMeProvider;
import '../repost/repost_widgets.dart' show userRepostsProvider;
import '../testimony/providers/comments_provider.dart' show commentsProvider;
import '../testimony/providers/recommendations_provider.dart' show recommendationsProvider;

/// Messages globaux (SnackBar hors d'un écran : retour automatique sur son compte).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Recharge les données propres au compte actif.
void invalidateAccountScopedData(Ref ref) {
  for (final p in <ProviderOrFamily>[
    // Fils et réactions (liked / prayed / saved viennent du serveur).
    feedNotifierProvider,
    interactionProvider,
    featuredFromApiProvider,
    personalFeedProvider,
    feedInsertsProvider,
    recommendationsProvider,
    commentsProvider,
    repostedByMeProvider,
    userRepostsProvider,
    dailyVerseProvider,
    dailyVerseCommentsProvider,
    // Notifications, profil, témoignages, sauvegardes.
    notificationsNotifierProvider,
    profileExtrasProvider,
    myTestimoniesNotifierProvider,
    savedTestimoniesProvider,
    // Communauté.
    followProvider,
    suggestedAccountsProvider,
    // Événements.
    managedOrganizationsProvider,
    eventCreatorsProvider,
    eventListProvider,
    upcomingEventsProvider,
    followingEventsProvider,
    eventDetailProvider,
    eventCommentsProvider,
    // Prière, directs.
    prayerRequestsPageProvider,
    prayerRequestListProvider,
    prayerRequestProvider,
    prayerMessagesProvider,
    prayerSessionListProvider,
    prayerSessionProvider,
    upcomingPrayerSessionsProvider,
    livesIndexProvider,
  ]) {
    ref.invalidate(p);
  }
}
