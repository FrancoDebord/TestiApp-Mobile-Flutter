// lib/features/auth/guest_access.dart
//
// Règles d'accès du mode invité (navigation sans compte), sans dépendance
// Flutter : utilisées par le redirect du routeur et testées unitairement.
//
// Autorisé  : onglets (accueil, explorer, bible, téléchargements, profil),
//             fiche / lecteurs de témoignage, recherche, catégories,
//             tendances, lives en visionnage, profils publics, paramètres
//             d'affichage (langue, aide, à propos), écrans de connexion.
// Compte    : publier, commenter / signaler, notifications, journal,
//             édition du profil, mes témoignages, favoris, abonnements,
//             sécurité du compte, diffusion en direct, modération, admin.

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
    '/community',
    '/users/',
    '/shorts',
  ];
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
  if (path == '/following') return true;
  if (path.startsWith('/moderation') || path.startsWith('/admin')) return true;
  if (path == '/lives/new' ||
      (path.startsWith('/lives/') && path.endsWith('/studio'))) {
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
  if (path.startsWith('/publish')) return 'publier votre témoignage';
  if (path.startsWith('/notifications')) return 'recevoir vos notifications';
  if (path.startsWith('/journal')) return 'tenir votre journal spirituel';
  if (path.endsWith('/comments')) return 'commenter les témoignages';
  if (path.endsWith('/report')) return 'signaler un contenu';
  if (path == '/following') return 'suivre des membres';
  if (path.startsWith('/lives')) return 'lancer un direct';
  if (path.startsWith('/profile/saved')) return 'enregistrer vos favoris';
  if (path.startsWith('/profile')) return 'gérer votre profil';
  return 'profiter de toutes les fonctionnalités';
}

String _normalize(String location) {
  var path = Uri.tryParse(location)?.path ?? location;
  if (path.isEmpty) path = '/';
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}
