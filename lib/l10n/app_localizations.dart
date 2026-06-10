// lib/l10n/app_localizations.dart
//
// Manual bilingual (FR/EN) localization.
// Usage:
//   final l10n = AppLocalizations.of(context);
//   Text(l10n.navHome)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart' show secureStorageProvider;

// ── Provider ──────────────────────────────────────────────────────────────────

const _kLocaleKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Charge la langue sauvegardée de façon asynchrone sans bloquer le build
    Future.microtask(_restore);
    return const Locale('fr');
  }

  Future<void> _restore() async {
    final storage = ref.read(secureStorageProvider);
    final code = await storage.read(key: _kLocaleKey);
    if (code == 'en') state = const Locale('en');
  }

  Future<void> setFrench() async {
    state = const Locale('fr');
    await ref.read(secureStorageProvider).write(key: _kLocaleKey, value: 'fr');
  }

  Future<void> setEnglish() async {
    state = const Locale('en');
    await ref.read(secureStorageProvider).write(key: _kLocaleKey, value: 'en');
  }

  Future<void> toggle() async {
    final next = state.languageCode == 'fr' ? 'en' : 'fr';
    state = Locale(next);
    await ref.read(secureStorageProvider).write(key: _kLocaleKey, value: next);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

// ── Delegate ──────────────────────────────────────────────────────────────────

class AppLocalizations {
  AppLocalizations(this._locale);
  final Locale _locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('fr'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isFr => _locale.languageCode == 'fr';
  String _t(String fr, String en) => isFr ? fr : en;

  // ── Navigation ───────────────────────────────────────────────────────────
  String get navHome          => _t('Accueil',      'Home');
  String get navExplore       => _t('Explorer',     'Explore');
  String get navShorts        => _t('Shorts',       'Shorts');
  String get navPublish       => _t('Publier',      'Publish');
  String get navNotifications => _t('Alertes',      'Alerts');
  String get navProfile       => _t('Profil',       'Profile');

  // ── Home ─────────────────────────────────────────────────────────────────
  String get homeTitle        => _t('Témoignages',  'Testimonies');
  String get homeSubtitle     => _t('Partagez la grâce de Dieu', 'Share God\'s grace');
  String get homeTrending     => _t('Tendances',    'Trending');
  String get homeFeatured     => _t('En vedette',   'Featured');
  String get homeLive         => _t('En direct',    'Live');
  String get homeViewAll      => _t('Voir tout',    'View all');

  // ── Explore ───────────────────────────────────────────────────────────────
  String get exploreTitle       => _t('Explorer',        'Explore');
  String get exploreSubtitle    => _t('Trouvez ce qui vous inspire', 'Find what inspires you');
  String get exploreSearchHint  => _t('Rechercher un témoignage…', 'Search a testimony…');
  String get exploreTrending    => _t('Tendances 🔥',    'Trending 🔥');
  String get exploreMostPrayed  => _t('Les plus priés 🙏', 'Most prayed 🙏');
  String get exploreRecent      => _t('Récents',         'Recent');
  String get exploreCategories  => _t('Rubriques',       'Categories');
  String get exploreNoResults   => _t('Aucun résultat',  'No results');
  String get exploreCancel      => _t('Annuler',         'Cancel');

  // ── Testimony detail ─────────────────────────────────────────────────────
  String get detailLike         => _t("J'aime",       'Like');
  String get detailPray         => _t('Je prie',      'Praying');
  String get detailComment      => _t('Commenter',    'Comment');
  String get detailSave         => _t('Sauvegarder',  'Save');
  String get detailShare        => _t('Partager',     'Share');
  String get detailSimilar      => _t('Témoignages similaires', 'Similar testimonies');
  String get detailBibleTitle   => _t('Que dit la Bible ?', 'What does the Bible say?');
  String get detailFollow       => _t('Suivre',       'Follow');
  String get detailFollowing    => _t('Suivi',        'Following');
  String get detailComments     => _t('Commentaires', 'Comments');
  String get detailAddComment   => _t('Ajouter un commentaire…', 'Add a comment…');
  String get detailFirstComment => _t('Soyez le premier à commenter.', 'Be the first to comment.');
  String get detailSeeAll       => _t('Voir tous',    'See all');
  String get detailSeeMore      => _t('Voir plus',    'See more');
  String get detailSeeLess      => _t('Voir moins',   'See less');

  // ── Publish ───────────────────────────────────────────────────────────────
  String get publishTitle       => _t('Publier',          'Publish');
  String get publishTestimony   => _t('Témoignage texte', 'Text testimony');
  String get publishAudio       => _t('Témoignage audio', 'Audio testimony');
  String get publishVideo       => _t('Témoignage vidéo', 'Video testimony');
  String get publishLive        => _t('Live',              'Go Live');
  String get publishShort       => _t('Short',             'Short');

  // ── Profile ───────────────────────────────────────────────────────────────
  String get profileTestimonies => _t('Témoignages',  'Testimonies');
  String get profileFollowers   => _t('Abonnés',      'Followers');
  String get profileFollowing   => _t('Abonnements',  'Following');
  String get profilePrayers     => _t('Prières',      'Prayers');
  String get profileEdit        => _t('Modifier le profil', 'Edit profile');
  String get profileMyTesti     => _t('Mes témoignages',    'My testimonies');
  String get profileSaved       => _t('Témoignages sauvegardés', 'Saved testimonies');
  String get profileSettings    => _t('Paramètres',   'Settings');

  // ── Settings ──────────────────────────────────────────────────────────────
  String get settingsTitle      => _t('Paramètres',    'Settings');
  String get settingsLanguage   => _t('Langue',        'Language');
  String get settingsFrench     => _t('Français',      'French');
  String get settingsEnglish    => _t('Anglais',       'English');
  String get settingsNotifs     => _t('Notifications', 'Notifications');
  String get settingsTheme      => _t('Thème',         'Theme');
  String get settingsPrivacy    => _t('Confidentialité', 'Privacy');
  String get settingsLogout     => _t('Se déconnecter', 'Sign out');
  String get settingsDelete     => _t('Supprimer le compte', 'Delete account');

  // ── Live ─────────────────────────────────────────────────────────────────
  String get liveTitle          => _t('Témoignage en Direct', 'Live Testimony');
  String get liveBadge          => _t('EN DIRECT',      'LIVE');
  String get liveStart          => _t('DÉMARRER LE LIVE', 'START LIVE');
  String get liveEnd            => _t('Terminer le live ?', 'End the live?');
  String get liveSaveReplay     => _t('Sauvegarder la rediffusion', 'Save replay');
  String get liveViewers        => _t('En ligne',       'Online');
  String get liveCommentHint    => _t('Écrire un commentaire…', 'Write a comment…');
  String get liveShareMsg       => _t('Lien copié !',   'Link copied!');

  // ── Prayer module ─────────────────────────────────────────────────────────
  String get prayerTitle        => _t('Requêtes de prière', 'Prayer requests');
  String get prayerNew          => _t('Nouvelle requête',   'New request');
  String get prayerPrayFor      => _t('Prier pour',        'Pray for');
  String get prayerSendMsg      => _t('Envoyer un message d\'inspiration', 'Send an inspired message');
  String get prayerGroupTitle   => _t('Sessions de prière', 'Prayer sessions');
  String get prayerJoin         => _t('Rejoindre',         'Join');
  String get prayerCreate       => _t('Créer une session', 'Create session');
  String get prayerPublic       => _t('Publique',          'Public');
  String get prayerFriends      => _t('Amis',              'Friends');
  String get prayerPrivate      => _t('Privée',            'Private');

  // ── Testimony detail (extra) ──────────────────────────────────────────────
  String get detailCommentHint  => _t('Commenter… (@nom pour taguer)', 'Comment… (@name to tag)');
  String get detailShareTitle   => _t('Partager ce témoignage', 'Share this testimony');
  String get detailCopyLink     => _t('Copier le lien',  'Copy link');
  String get detailLinkCopied   => _t('Lien copié dans le presse-papiers', 'Link copied to clipboard');
  String get detailShareOn      => _t('Partager sur…',   'Share on…');
  String get detailAudioLabel   => _t('Témoignage Audio', 'Audio Testimony');
  String get detailTapToOpen    => _t('appuyer pour ouvrir', 'tap to open');
  String get detailReplyingTo   => _t('En réponse à',    'Replying to');
  String get detailReply        => _t('Répondre',        'Reply');
  String get detailNoComments   => _t('Aucun commentaire.\nSoyez le premier !', 'No comments yet.\nBe the first!');

  // ── Settings (extra) ─────────────────────────────────────────────────────
  String get settingsAccount      => _t('Compte',             'Account');
  String get settingsCommunity    => _t('Communauté',         'Community');
  String get settingsInvite       => _t('Inviter des amis',   'Invite friends');
  String get settingsAppearance   => _t('Apparence',          'Appearance');
  String get settingsLogoutConfirm => _t('Voulez-vous vraiment vous déconnecter ?', 'Are you sure you want to sign out?');
  String get settingsWhoCanComment => _t('Qui peut commenter', 'Who can comment');
  String get settingsNotifComment => _t('Quand quelqu\'un commente', 'When someone comments');
  String get settingsNotifLike    => _t('Quand quelqu\'un aime votre témoignage', 'When someone likes your testimony');
  String get settingsNotifPray    => _t('Quand quelqu\'un prie avec vous', 'When someone prays with you');
  String get settingsNotifApproved => _t('Quand votre témoignage est approuvé', 'When your testimony is approved');
  String get settingsEditProfile  => _t('Modifier le profil', 'Edit profile');
  String get settingsSignOut      => _t('Se déconnecter',     'Sign out');
  String get settingsDeleteAction => _t('Supprimer le compte', 'Delete account');

  // ── Notifications ─────────────────────────────────────────────────────────
  String get notifTitle         => _t('Notifications',   'Notifications');
  String get notifMarkAllRead   => _t('Tout marquer lu', 'Mark all as read');
  String get notifToday         => _t("Aujourd'hui",     'Today');
  String get notifYesterday     => _t('Hier',            'Yesterday');
  String get notifThisWeek      => _t('Cette semaine',   'This week');
  String get notifEmpty         => _t('Aucune notification', 'No notifications');
  String get notifEmptyDesc     => _t('Vous serez notifié lorsque quelqu\'un interagit avec vos témoignages.', 'You\'ll be notified when someone interacts with your testimonies.');

  // ── Prayer (extra) ────────────────────────────────────────────────────────
  String get prayerSubmit        => _t('Soumettre',          'Submit');
  String get prayerPray          => _t('Prier',              'Pray');
  String get prayerEmpty         => _t('Aucune requête pour l\'instant', 'No requests yet');
  String get prayerEmptyDesc     => _t('Partagez vos besoins de prière avec la communauté.', 'Share your prayer needs with the community.');
  String get prayerSubmitRequest => _t('Soumettre une requête', 'Submit a request');
  String get prayerEndTitle      => _t('Terminer la session ?', 'End session?');
  String get prayerEndDesc       => _t('La session sera marquée comme terminée pour tous les participants.', 'The session will be marked as ended for all participants.');
  String get prayerEnd           => _t('Terminer',            'End');
  String get prayerLeave         => _t('Quitter',             'Leave');
  String get prayerRecording     => _t('Enregistrement',      'Recording');
  String get prayerMessageHint   => _t('Écrire un message de prière…', 'Write a prayer message…');
  String get prayerMute          => _t('Muet',    'Mute');
  String get prayerMic           => _t('Micro',   'Mic');
  String get prayerRecord        => _t('Enreg.',  'Rec.');
  String get prayerStopRec       => _t('Stop rec.', 'Stop rec.');
  String get prayerWelcome       => _t('Bienvenue dans cette session de prière. Que le Saint-Esprit soit avec nous 🙏', 'Welcome to this prayer session. May the Holy Spirit be with us 🙏');

  // ── Auth ──────────────────────────────────────────────────────────────────
  String get authWelcomeBack      => _t('Bon retour !',            'Welcome back!');
  String get authSignInSubtitle   => _t('Connectez-vous à votre compte', 'Sign in to your account');
  String get authEmailLabel       => _t('Adresse e-mail',          'Email address');
  String get authPasswordLabel    => _t('Mot de passe',            'Password');
  String get authForgotPassword   => _t('Mot de passe oublié ?',   'Forgot password?');
  String get authSignIn           => _t('Se connecter',            'Sign in');
  String get authNoAccount        => _t("Pas encore de compte ?",  "Don't have an account?");
  String get authSignUp           => _t("S'inscrire",              'Sign up');
  String get authHaveAccount      => _t('Déjà inscrit ?',          'Already have an account?');
  String get authCreateAccount    => _t('Créer un compte',         'Create account');
  String get authJoinCommunity    => _t('Rejoignez la communauté Témoignages', 'Join the Testimonies community');
  String get authFirstNameLabel   => _t('Prénom',                  'First name');
  String get authLastNameLabel    => _t('Nom',                     'Last name');
  String get authCountryLabel     => _t('Pays',                    'Country');
  String get authSelectCountry    => _t('Sélectionnez votre pays', 'Select your country');
  String get authConfirmPwdLabel  => _t('Confirmer le mot de passe', 'Confirm password');
  String get authValidateEmail    => _t('Veuillez saisir votre adresse e-mail', 'Please enter your email');
  String get authInvalidEmail     => _t('Adresse e-mail invalide', 'Invalid email address');
  String get authValidatePwd      => _t('Veuillez saisir votre mot de passe', 'Please enter your password');
  String get authPwdMin8          => _t('Le mot de passe doit contenir au moins 8 caractères', 'Password must be at least 8 characters');
  String get authPwdUppercase     => _t('Au moins une majuscule requise', 'At least one uppercase required');
  String get authPwdDigit         => _t('Au moins un chiffre requis', 'At least one digit required');
  String get authPwdMin8Short     => _t('Minimum 8 caractères', 'Min. 8 characters');
  String get authPwdMatch         => _t('Les mots de passe ne correspondent pas', "Passwords don't match");
  String get authPwdConfirmEmpty  => _t('Veuillez confirmer votre mot de passe', 'Please confirm your password');
  String get authSelectCountryErr => _t('Veuillez sélectionner votre pays', 'Please select your country');
  String get authAcceptTerms      => _t('Vous devez accepter les CGU pour continuer', 'You must accept the terms to continue');
  String get authValidateFirstName => _t('Veuillez saisir votre prénom', 'Please enter your first name');
  String get authFirstNameMin2    => _t('Le prénom doit contenir au moins 2 caractères', 'First name must be at least 2 characters');
  String get authValidateLastName => _t('Veuillez saisir votre nom', 'Please enter your last name');
  String get authLastNameMin2     => _t('Le nom doit contenir au moins 2 caractères', 'Last name must be at least 2 characters');
  String get authWrongCredentials => _t('Identifiants incorrects. Vérifiez votre e-mail et mot de passe.', 'Incorrect credentials. Check your email and password.');
  String get authCreateError      => _t("Impossible de créer le compte. Vérifiez vos informations ou réessayez.", 'Unable to create account. Check your information or try again.');
  String get authPwdVeryWeak      => _t('Très faible', 'Very weak');
  String get authPwdWeak          => _t('Faible',      'Weak');
  String get authPwdMedium        => _t('Moyen',       'Medium');
  String get authPwdStrong        => _t('Fort',        'Strong');
  String get authPwdVeryStrong    => _t('Très fort',   'Very strong');

  // ── Onboarding ────────────────────────────────────────────────────────────
  String get onboardingSkip   => _t('Passer',  'Skip');
  String get onboardingNext   => _t('Suivant', 'Next');
  String get onboardingTitle1 => _t('Partagez ce que\nDieu a fait', 'Share what\nGod has done');
  String get onboardingBody1  => _t('Votre témoignage est une arme puissante. Chaque histoire de grâce mérite d\'être racontée et peut changer une vie.', 'Your testimony is a powerful weapon. Every story of grace deserves to be told and can change a life.');
  String get onboardingTitle2 => _t("Inspirez d'autres\ncroyants", 'Inspire other\nbelievers');
  String get onboardingBody2  => _t("Des milliers de frères et sœurs attendent d'être encouragés par ce que Dieu a accompli dans votre vie.", 'Thousands of brothers and sisters are waiting to be encouraged by what God has done in your life.');
  String get onboardingTitle3 => _t('Commencez votre\nvoyage', 'Begin your\njourney');
  String get onboardingBody3  => _t("Rejoignez la communauté Témoignages et soyez une lumière dans la vie de quelqu'un aujourd'hui.", "Join the Testimonies community and be a light in someone's life today.");

  // ── Phone auth ────────────────────────────────────────────────────────────
  String get authPhoneTitle      => _t('Entrez votre numéro', 'Enter your number');
  String get authPhoneSubtitle   => _t('Nous vous enverrons un code de vérification par SMS.', "We'll send you a verification code by SMS.");
  String get authContinue        => _t('Continuer',        'Continue');
  String get authPickCountry     => _t('Choisir un pays',  'Choose a country');
  String get authVerification    => _t('Vérification',     'Verification');
  String get authResend          => _t('Renvoyer le code', 'Resend code');
  String get authWelcomeNew      => _t('Bienvenue !',      'Welcome!');
  String get authCompleteProfile => _t('Complétez votre profil pour commencer', 'Complete your profile to get started');
  String get authLetsGo          => _t("C'est parti !", "Let's go!");
  String get authPhoneError      => _t('Entrez votre numéro de téléphone', 'Enter your phone number');
  String get authOtpError        => _t('Code incorrect. Réessayez.', 'Incorrect code. Try again.');
  String get authNameError       => _t('Entrez votre prénom et votre nom', 'Enter your first and last name');
  String get authOrContinueWith  => _t('ou continuer avec', 'or continue with');

  // ── Edit profile ──────────────────────────────────────────────────────────
  String get editGallery        => _t('Galerie photos',      'Photo gallery');
  String get editCamera         => _t('Prendre une photo',   'Take a photo');
  String get editFirstRequired  => _t('Le prénom est obligatoire.', 'First name is required.');
  String get editSaved          => _t('Profil mis à jour ✓', 'Profile updated ✓');
  String get editTapToChange    => _t('Appuyez pour changer la photo', 'Tap to change photo');
  String get editIdentity       => _t('Identité',     'Identity');
  String get editContact        => _t('Contact',      'Contact');
  String get editLocation       => _t('Localisation', 'Location');
  String get editBio            => _t('Bio',          'Bio');
  String get editTitleOptional  => _t('Titre (optionnel)', 'Title (optional)');
  String get editGender         => _t('Sexe',               'Gender');
  String get editSelectCountry  => _t('Sélectionner un pays', 'Select a country');
  String get editPickCountry    => _t('Choisir un pays',      'Choose a country');
  String get editSaveProfile    => _t('Sauvegarder le profil', 'Save profile');
  String get editPhoneLabel     => _t('Téléphone',                   'Phone');
  String get editAboutOptional  => _t('À propos de vous (optionnel)', 'About you (optional)');
  String get editBioHint        => _t('Partagez quelque chose sur vous ou votre parcours de foi…', 'Share something about yourself or your faith journey…');
  String get editSpecifyTitle   => _t('Précisez votre titre',         'Specify your title');
  String get editCustomTitle    => _t('Titre personnalisé (optionnel)', 'Custom title (optional)');

  // ── Gender ────────────────────────────────────────────────────────────────
  String get genderMale         => _t('Homme', 'Male');
  String get genderFemale       => _t('Femme', 'Female');
  String get genderOther        => _t('Autre', 'Other');

  // ── Submit prayer request ──────────────────────────────────────────────────
  String get submitPrayerTitle      => _t('Partager une requête', 'Share a request');
  String get submitPrayerIntro      => _t('La communauté priera avec vous. Partagez votre besoin avec foi.', 'The community will pray with you. Share your need with faith.');
  String get submitPrayerField      => _t('Votre requête de prière', 'Your prayer request');
  String get submitPrayerHint       => _t('Décrivez votre besoin de prière. Soyez aussi précis ou vague que vous le souhaitez…', 'Describe your prayer need. Be as specific or vague as you wish…');
  String get submitPrayerValidation => _t('Veuillez écrire au moins 10 caractères', 'Please write at least 10 characters');
  String get submitPrayerVisibility => _t('Visibilité', 'Visibility');
  String get submitPrayerVisPublicDesc  => _t('Visible par tous',        'Visible to everyone');
  String get submitPrayerVisFriendsDesc => _t('Visible par vos abonnés', 'Visible to your followers');
  String get submitPrayerVisPrivateDesc => _t('Uniquement vous',         'Only you');
  String get submitPrayerButton     => _t('Partager ma requête', 'Share my request');
  String get submitPrayerSuccess    => _t('Votre requête a été partagée. La communauté prie avec vous 🙏', 'Your request has been shared. The community is praying with you 🙏');

  // ── Create prayer session ──────────────────────────────────────────────────
  String get createSessionStart       => _t('Démarrer', 'Start');
  String get createSessionCreate      => _t('Créer',    'Create');
  String get createSessionTitleField  => _t('Titre de la session', 'Session title');
  String get createSessionDescField   => _t('Description (optionnel)', 'Description (optional)');
  String get createSessionVisibility  => _t('Visibilité', 'Visibility');
  String get createSessionOptions     => _t('Options',    'Options');
  String get createSessionStartNow    => _t('Démarrer maintenant', 'Start now');
  String get createSessionStartNowDesc => _t('Lancer la session en direct immédiatement', 'Launch the live session immediately');
  String get createSessionRecord      => _t('Enregistrer la session', 'Record the session');
  String get createSessionRecordDesc  => _t('Sauvegarder pour réécouter plus tard', 'Save to replay later');
  String get createSessionStartBtn    => _t('Démarrer la session', 'Start session');
  String get createSessionScheduleBtn => _t('Créer & programmer', 'Create & schedule');
  String get createSessionTitleReq    => _t('Titre requis', 'Title required');
  String get createSessionSuccess     => _t('Session créée ! La communauté sera notifiée.', 'Session created! The community will be notified.');

  // ── Admin ─────────────────────────────────────────────────────────────────
  String get adminUnpublish        => _t('Dépublier', 'Unpublish');
  String get adminUnpublishConfirm => _t('Dépublier ce témoignage ?', 'Unpublish this testimony?');
  String get adminUnpublishDesc    => _t('Le témoignage sera masqué pour tous les utilisateurs.', 'The testimony will be hidden from all users.');
  String get adminViews            => _t('vues',   'views');
  String get adminLikes            => _t("j'aime", 'likes');
  String get adminPublishedLabel   => _t('publié', 'published');

  // ── Moderation ────────────────────────────────────────────────────────────
  String get modTestimony          => _t('Témoignage',          'Testimony');
  String get modNotFound           => _t('Témoignage introuvable.', 'Testimony not found.');
  String get modPreview            => _t('Prévisualisation',    'Preview');
  String get modSubmitted          => _t('Soumis',              'Submitted');
  String get modActionTitle        => _t('Action de modération', 'Moderation action');
  String get modApprove            => _t('Approuver le témoignage', 'Approve testimony');
  String get modRequestEdit        => _t('Demander une modification', 'Request edit');
  String get modReject             => _t('Rejeter le témoignage', 'Reject testimony');
  String get modApprovedSnack      => _t('Témoignage approuvé', 'Testimony approved');
  String get modStatusPending      => _t('En attente',  'Pending');
  String get modStatusInReview     => _t('En révision', 'In review');
  String get modStatusApproved     => _t('Approuvé',    'Approved');
  String get modStatusRejected     => _t('Rejeté',      'Rejected');
  String get modContentUnavailable => _t('Contenu du témoignage non disponible pour la prévisualisation.', 'Testimony content not available for preview.');
  String get modAudio              => _t('Témoignage audio',    'Audio testimony');
  String get modAudioPlay          => _t('Appuyer pour écouter', 'Tap to listen');
  String get modVideo              => _t('Témoignage vidéo',    'Video testimony');
  String get modVideoPlay          => _t('Appuyer pour visionner', 'Tap to watch');

  // ── Search ────────────────────────────────────────────────────────────────
  String get searchResults     => _t('Résultats',             'Results');
  String get searchResultsBody => _t('Résultats de recherche', 'Search results');

  // ── Common ────────────────────────────────────────────────────────────────
  String get commonCancel       => _t('Annuler',    'Cancel');
  String get commonConfirm      => _t('Confirmer',  'Confirm');
  String get commonSave         => _t('Enregistrer', 'Save');
  String get commonClose        => _t('Fermer',     'Close');
  String get commonBack         => _t('Retour',     'Back');
  String get commonShare        => _t('Partager',   'Share');
  String get commonSend         => _t('Envoyer',    'Send');
  String get commonLoading      => _t('Chargement…', 'Loading…');
  String get commonError        => _t('Une erreur est survenue.', 'An error occurred.');
  String get commonEmpty        => _t('Aucun contenu disponible.', 'No content available.');
}

// ── Delegate impl ─────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  static const _supported = ['fr', 'en'];

  @override
  bool isSupported(Locale locale) =>
      _supported.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
