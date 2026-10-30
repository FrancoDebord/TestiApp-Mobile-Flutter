// lib/features/auth/guest_access.dart
//
// Règles d'accès du mode invité (navigation sans compte), sans widget ni
// BuildContext (textes via L10n.current) : utilisées par le redirect du
// routeur et testées unitairement.
//
// Autorisé  : onglets (accueil, explorer, bible, téléchargements, profil),
//             fiche / lecteurs de témoignage, recherche, catégories,
//             tendances, lives en visionnage, profils publics, paramètres
//             d'affichage (langue, aide, à propos), écrans de connexion.
// Compte    : publier, commenter / signaler, notifications, journal,
//             édition du profil, mes témoignages, favoris, abonnements,
//             sécurité du compte, diffusion en direct, modération, admin.

import '../../l10n/app_localizations.dart';

/// Vrai si un invité peut ouvrir [location] (chemin sans query string).
bool guestCanAccess(String location) {
  final path = _normalize(location);

  // Écrans d'authentification (pour quitter le mode invité).
  const authPaths = {
    '/splash',
    '/onboarding',
    '/login',
    '/register',
    '/phone-auth',
    '/forgot-password',
    '/verify-email',
    // Politique de confidentialité (écran de l'application).
    '/privacy-policy',
  };
  if (authPaths.contains(path)) return true;

  // Blocages explicites, prioritaires sur les préfixes autorisés.
  if (_isBlocked(path)) return false;

  const allowedPrefixes = [
    '/home',
    '/explore',
    '/bible',
    '/downloads',
    '/testimony/',
    '/testimonies/',
    '/trending',
    '/live-discovery',
    '/lives',
    '/events',
    '/community',
    '/users/',
    '/shorts',
    // Prière : lecture libre ; confier, programmer, modifier demandent un compte.
    '/prayer-requests',
    '/prayer-sessions',
    // Adresses du site (liens partagés), traduites vers les écrans ci-dessus.
    '/videos',
    '/evenements',
    '/priere',
    '/verset-du-jour',
    '/verse-history',
    '/temoignages-de-conversion',
    // Liste de témoignages partagée (lecture libre ; « Mes listes » demande un compte).
    '/listes/',
  ];
  // Section des témoignages de conversion (pas la modification du sien).
  if (path == '/conversions') return true;
  for (final prefix in allowedPrefixes) {
    if (path == prefix || path.startsWith(prefix.endsWith('/') ? prefix : '$prefix/')) {
      return true;
    }
  }

  // Profil : l'onglet et les paramètres d'affichage uniquement.
  const allowedProfile = {
    '/profile',
    '/profile/settings',
    '/profile/settings/language',
    '/profile/settings/help',
    '/profile/settings/about',
  };
  if (allowedProfile.contains(path)) return true;

  if (path == '/404') return true;
  return false;
}

bool _isBlocked(String path) {
  if (path == '/publish' || path.startsWith('/publish/')) return true;
  if (path == '/notifications' || path.startsWith('/notifications/')) {
    return true;
  }
  if (path == '/journal' || path.startsWith('/journal/')) return true;
  if (path == '/prophecies' || path.startsWith('/prophecies/')) return true;
  if (path == '/my-feed') return true;
  if (path == '/managers') return true;
  if (path == '/following') return true;
  if (path.startsWith('/moderation') || path.startsWith('/admin')) return true;
  if (path == '/lives/new' ||
      (path.startsWith('/lives/') && path.endsWith('/studio'))) {
    return true;
  }
  if (path == '/events/new' ||
      (path.startsWith('/events/') && path.endsWith('/edit'))) {
    return true;
  }
  if (path == '/prayer-requests/new' || path == '/prayer-sessions/new' ||
      (path.startsWith('/prayer-sessions/') && path.endsWith('/edit'))) {
    return true;
  }
  if ((path.startsWith('/testimony/') || path.startsWith('/testimonies/')) &&
      (path.endsWith('/comments') || path.endsWith('/report'))) {
    return true;
  }
  return false;
}

/// Raison affichée dans la feuille « Créez un compte pour … ».
String guestBlockedReason(String location) {
  final path = _normalize(location);
  final l10n = L10n.current;
  if (path.startsWith('/publish')) return l10n.authGuestReasonPublish;
  if (path.startsWith('/notifications')) return l10n.authGuestReasonNotifications;
  if (path.startsWith('/journal')) return l10n.authGuestReasonJournal;
  if (path.startsWith('/prophecies')) return l10n.authGuestReasonProphecies;
  if (path == '/my-feed') return l10n.authGuestReasonMyFeed;
  if (path.startsWith('/prayer-requests')) return l10n.authGuestReasonPrayerRequest;
  if (path.startsWith('/prayer-sessions')) return l10n.authGuestReasonPrayerSession;
  if (path.startsWith('/events/')) return l10n.authGuestReasonEvent;
  if (path.endsWith('/comments')) return l10n.authGuestReasonComment;
  if (path.endsWith('/report')) return l10n.authGuestReasonReport;
  if (path == '/following') return l10n.authGuestReasonFollow;
  if (path.startsWith('/lives')) return l10n.authGuestReasonLive;
  if (path.startsWith('/profile/saved')) return l10n.authGuestReasonSaved;
  if (path.startsWith('/profile')) return l10n.authGuestReasonProfile;
  return l10n.authGuestReasonDefault;
}

String _normalize(String location) {
  var path = Uri.tryParse(location)?.path ?? location;
  if (path.isEmpty) path = '/';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}
