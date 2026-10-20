import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navExplore.
  ///
  /// In fr, this message translates to:
  /// **'Explorer'**
  String get navExplore;

  /// No description provided for @navShorts.
  ///
  /// In fr, this message translates to:
  /// **'Shorts'**
  String get navShorts;

  /// No description provided for @navPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get navPublish;

  /// No description provided for @navNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get navNotifications;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @navDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements'**
  String get navDownloads;

  /// No description provided for @navEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements'**
  String get navEvents;

  /// No description provided for @homeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Partagez la grâce de Dieu'**
  String get homeSubtitle;

  /// No description provided for @homeTrending.
  ///
  /// In fr, this message translates to:
  /// **'Tendances'**
  String get homeTrending;

  /// No description provided for @homeFeatured.
  ///
  /// In fr, this message translates to:
  /// **'En vedette'**
  String get homeFeatured;

  /// No description provided for @homeLive.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get homeLive;

  /// No description provided for @homeViewAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get homeViewAll;

  /// No description provided for @exploreTitle.
  ///
  /// In fr, this message translates to:
  /// **'Explorer'**
  String get exploreTitle;

  /// No description provided for @exploreSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Trouvez ce qui vous inspire'**
  String get exploreSubtitle;

  /// No description provided for @exploreSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un témoignage…'**
  String get exploreSearchHint;

  /// No description provided for @exploreTrending.
  ///
  /// In fr, this message translates to:
  /// **'Tendances 🔥'**
  String get exploreTrending;

  /// No description provided for @exploreMostPrayed.
  ///
  /// In fr, this message translates to:
  /// **'Les plus priés 🙏'**
  String get exploreMostPrayed;

  /// No description provided for @exploreRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get exploreRecent;

  /// No description provided for @exploreCategories.
  ///
  /// In fr, this message translates to:
  /// **'Rubriques'**
  String get exploreCategories;

  /// No description provided for @exploreNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get exploreNoResults;

  /// No description provided for @exploreCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get exploreCancel;

  /// No description provided for @detailLike.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get detailLike;

  /// No description provided for @detailPray.
  ///
  /// In fr, this message translates to:
  /// **'Je prie'**
  String get detailPray;

  /// No description provided for @detailComment.
  ///
  /// In fr, this message translates to:
  /// **'Commenter'**
  String get detailComment;

  /// No description provided for @detailSave.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get detailSave;

  /// No description provided for @detailShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get detailShare;

  /// No description provided for @detailSimilar.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages similaires'**
  String get detailSimilar;

  /// No description provided for @detailBibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Que dit la Bible ?'**
  String get detailBibleTitle;

  /// No description provided for @detailFollow.
  ///
  /// In fr, this message translates to:
  /// **'Suivre'**
  String get detailFollow;

  /// No description provided for @detailFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get detailFollowing;

  /// No description provided for @detailComments.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires'**
  String get detailComments;

  /// No description provided for @detailAddComment.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire…'**
  String get detailAddComment;

  /// No description provided for @detailFirstComment.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à commenter.'**
  String get detailFirstComment;

  /// No description provided for @detailSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tous'**
  String get detailSeeAll;

  /// No description provided for @detailSeeMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get detailSeeMore;

  /// No description provided for @detailSeeLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get detailSeeLess;

  /// No description provided for @publishTitle.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publishTitle;

  /// No description provided for @publishTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage texte'**
  String get publishTestimony;

  /// No description provided for @publishAudio.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage audio'**
  String get publishAudio;

  /// No description provided for @publishVideo.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage vidéo'**
  String get publishVideo;

  /// No description provided for @publishLive.
  ///
  /// In fr, this message translates to:
  /// **'Live'**
  String get publishLive;

  /// No description provided for @publishShort.
  ///
  /// In fr, this message translates to:
  /// **'Short'**
  String get publishShort;

  /// No description provided for @profileTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages'**
  String get profileTestimonies;

  /// No description provided for @profileFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés'**
  String get profileFollowers;

  /// No description provided for @profileFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get profileFollowing;

  /// No description provided for @profilePrayers.
  ///
  /// In fr, this message translates to:
  /// **'Prières'**
  String get profilePrayers;

  /// No description provided for @profileEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get profileEdit;

  /// No description provided for @profileMyTesti.
  ///
  /// In fr, this message translates to:
  /// **'Mes témoignages'**
  String get profileMyTesti;

  /// No description provided for @profileSaved.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages sauvegardés'**
  String get profileSaved;

  /// No description provided for @profileSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get profileSettings;

  /// No description provided for @profileLikes.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get profileLikes;

  /// No description provided for @profileDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Mes téléchargements'**
  String get profileDownloads;

  /// No description provided for @profileHelp.
  ///
  /// In fr, this message translates to:
  /// **'Aide et support'**
  String get profileHelp;

  /// No description provided for @profileAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get profileAbout;

  /// No description provided for @profileGuestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous naviguez en invité'**
  String get profileGuestTitle;

  /// No description provided for @profileGuestDesc.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour publier, suivre et retrouver vos témoignages.'**
  String get profileGuestDesc;

  /// No description provided for @profileGuestCta.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter / Créer un compte'**
  String get profileGuestCta;

  /// No description provided for @settingsAccountSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Compte et sécurité'**
  String get settingsAccountSecurity;

  /// No description provided for @settingsOffline.
  ///
  /// In fr, this message translates to:
  /// **'Mode hors ligne'**
  String get settingsOffline;

  /// No description provided for @settingsOfflineDesc.
  ///
  /// In fr, this message translates to:
  /// **'Lire uniquement les témoignages téléchargés'**
  String get settingsOfflineDesc;

  /// No description provided for @settingsStorage.
  ///
  /// In fr, this message translates to:
  /// **'Stockage'**
  String get settingsStorage;

  /// No description provided for @settingsPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Lecture et données'**
  String get settingsPlayback;

  /// No description provided for @languageChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer de langue'**
  String get languageChange;

  /// No description provided for @notifTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get notifTabAll;

  /// No description provided for @notifTabNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux'**
  String get notifTabNew;

  /// No description provided for @notifTabPopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaires'**
  String get notifTabPopular;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get settingsFrench;

  /// No description provided for @settingsEnglish.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get settingsEnglish;

  /// No description provided for @settingsNotifs.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get settingsNotifs;

  /// No description provided for @settingsPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get settingsPrivacy;

  /// No description provided for @settingsLogout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get settingsLogout;

  /// No description provided for @settingsDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get settingsDelete;

  /// No description provided for @liveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage en Direct'**
  String get liveTitle;

  /// No description provided for @liveBadge.
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get liveBadge;

  /// No description provided for @liveStart.
  ///
  /// In fr, this message translates to:
  /// **'DÉMARRER LE LIVE'**
  String get liveStart;

  /// No description provided for @liveEnd.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le live ?'**
  String get liveEnd;

  /// No description provided for @liveSaveReplay.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder la rediffusion'**
  String get liveSaveReplay;

  /// No description provided for @liveViewers.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get liveViewers;

  /// No description provided for @liveCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un commentaire…'**
  String get liveCommentHint;

  /// No description provided for @liveShareMsg.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié !'**
  String get liveShareMsg;

  /// No description provided for @prayerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes de prière'**
  String get prayerTitle;

  /// No description provided for @prayerNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle requête'**
  String get prayerNew;

  /// No description provided for @prayerPrayFor.
  ///
  /// In fr, this message translates to:
  /// **'Prier pour'**
  String get prayerPrayFor;

  /// No description provided for @prayerSendMsg.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un message d\'inspiration'**
  String get prayerSendMsg;

  /// No description provided for @prayerGroupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sessions de prière'**
  String get prayerGroupTitle;

  /// No description provided for @prayerJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get prayerJoin;

  /// No description provided for @prayerCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer une session'**
  String get prayerCreate;

  /// No description provided for @prayerPublic.
  ///
  /// In fr, this message translates to:
  /// **'Publique'**
  String get prayerPublic;

  /// No description provided for @prayerFriends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get prayerFriends;

  /// No description provided for @prayerPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Privée'**
  String get prayerPrivate;

  /// No description provided for @detailCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Commenter… (@nom pour taguer)'**
  String get detailCommentHint;

  /// No description provided for @detailShareTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partager ce témoignage'**
  String get detailShareTitle;

  /// No description provided for @detailCopyLink.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get detailCopyLink;

  /// No description provided for @detailLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié dans le presse-papiers'**
  String get detailLinkCopied;

  /// No description provided for @detailShareOn.
  ///
  /// In fr, this message translates to:
  /// **'Partager sur…'**
  String get detailShareOn;

  /// No description provided for @detailAudioLabel.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage Audio'**
  String get detailAudioLabel;

  /// No description provided for @detailTapToOpen.
  ///
  /// In fr, this message translates to:
  /// **'appuyer pour ouvrir'**
  String get detailTapToOpen;

  /// No description provided for @detailReplyingTo.
  ///
  /// In fr, this message translates to:
  /// **'En réponse à'**
  String get detailReplyingTo;

  /// No description provided for @detailReply.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get detailReply;

  /// No description provided for @detailNoComments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire.\nSoyez le premier !'**
  String get detailNoComments;

  /// No description provided for @settingsAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get settingsAccount;

  /// No description provided for @settingsCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get settingsCommunity;

  /// No description provided for @settingsInvite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter des amis'**
  String get settingsInvite;

  /// No description provided for @settingsAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settingsAppearance;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous vraiment vous déconnecter ?'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsWhoCanComment.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut commenter'**
  String get settingsWhoCanComment;

  /// No description provided for @settingsNotifComment.
  ///
  /// In fr, this message translates to:
  /// **'Quand quelqu\'un commente'**
  String get settingsNotifComment;

  /// No description provided for @settingsNotifLike.
  ///
  /// In fr, this message translates to:
  /// **'Quand quelqu\'un aime votre témoignage'**
  String get settingsNotifLike;

  /// No description provided for @settingsNotifPray.
  ///
  /// In fr, this message translates to:
  /// **'Quand quelqu\'un prie avec vous'**
  String get settingsNotifPray;

  /// No description provided for @settingsNotifApproved.
  ///
  /// In fr, this message translates to:
  /// **'Quand votre témoignage est approuvé'**
  String get settingsNotifApproved;

  /// No description provided for @settingsEditProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get settingsEditProfile;

  /// No description provided for @settingsSignOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get settingsSignOut;

  /// No description provided for @settingsDeleteAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get settingsDeleteAction;

  /// No description provided for @notifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer lu'**
  String get notifMarkAllRead;

  /// No description provided for @notifToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get notifToday;

  /// No description provided for @notifYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get notifYesterday;

  /// No description provided for @notifThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'Cette semaine'**
  String get notifThisWeek;

  /// No description provided for @notifEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune notification'**
  String get notifEmpty;

  /// No description provided for @notifEmptyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Vous serez notifié lorsque quelqu\'un interagit avec vos témoignages.'**
  String get notifEmptyDesc;

  /// No description provided for @prayerSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre'**
  String get prayerSubmit;

  /// No description provided for @prayerPray.
  ///
  /// In fr, this message translates to:
  /// **'Prier'**
  String get prayerPray;

  /// No description provided for @prayerEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune requête pour l\'instant'**
  String get prayerEmpty;

  /// No description provided for @prayerEmptyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Partagez vos besoins de prière avec la communauté.'**
  String get prayerEmptyDesc;

  /// No description provided for @prayerSubmitRequest.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre une requête'**
  String get prayerSubmitRequest;

  /// No description provided for @prayerEndTitle.
  ///
  /// In fr, this message translates to:
  /// **'Terminer la session ?'**
  String get prayerEndTitle;

  /// No description provided for @prayerEndDesc.
  ///
  /// In fr, this message translates to:
  /// **'La session sera marquée comme terminée pour tous les participants.'**
  String get prayerEndDesc;

  /// No description provided for @prayerEnd.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get prayerEnd;

  /// No description provided for @prayerLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get prayerLeave;

  /// No description provided for @prayerRecording.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement'**
  String get prayerRecording;

  /// No description provided for @prayerMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un message de prière…'**
  String get prayerMessageHint;

  /// No description provided for @prayerMute.
  ///
  /// In fr, this message translates to:
  /// **'Muet'**
  String get prayerMute;

  /// No description provided for @prayerMic.
  ///
  /// In fr, this message translates to:
  /// **'Micro'**
  String get prayerMic;

  /// No description provided for @prayerRecord.
  ///
  /// In fr, this message translates to:
  /// **'Enreg.'**
  String get prayerRecord;

  /// No description provided for @prayerStopRec.
  ///
  /// In fr, this message translates to:
  /// **'Stop rec.'**
  String get prayerStopRec;

  /// No description provided for @prayerWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans cette session de prière. Que le Saint-Esprit soit avec nous 🙏'**
  String get prayerWelcome;

  /// No description provided for @authWelcomeBack.
  ///
  /// In fr, this message translates to:
  /// **'Bon retour !'**
  String get authWelcomeBack;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à votre compte'**
  String get authSignInSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPasswordLabel;

  /// No description provided for @authForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get authForgotPassword;

  /// No description provided for @authSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get authNoAccount;

  /// No description provided for @authSignUp.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get authSignUp;

  /// No description provided for @authHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà inscrit ?'**
  String get authHaveAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authCreateAccount;

  /// No description provided for @authJoinCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez la communauté My Testimony'**
  String get authJoinCommunity;

  /// No description provided for @authFirstNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Prénom'**
  String get authFirstNameLabel;

  /// No description provided for @authLastNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get authLastNameLabel;

  /// No description provided for @authCountryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get authCountryLabel;

  /// No description provided for @authSelectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre pays'**
  String get authSelectCountry;

  /// No description provided for @authConfirmPwdLabel.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get authConfirmPwdLabel;

  /// No description provided for @authValidateEmail.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre adresse e-mail'**
  String get authValidateEmail;

  /// No description provided for @authInvalidEmail.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide'**
  String get authInvalidEmail;

  /// No description provided for @authValidatePwd.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre mot de passe'**
  String get authValidatePwd;

  /// No description provided for @authPwdMin8.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe doit contenir au moins 8 caractères'**
  String get authPwdMin8;

  /// No description provided for @authPwdUppercase.
  ///
  /// In fr, this message translates to:
  /// **'Au moins une majuscule requise'**
  String get authPwdUppercase;

  /// No description provided for @authPwdDigit.
  ///
  /// In fr, this message translates to:
  /// **'Au moins un chiffre requis'**
  String get authPwdDigit;

  /// No description provided for @authPwdMin8Short.
  ///
  /// In fr, this message translates to:
  /// **'Minimum 8 caractères'**
  String get authPwdMin8Short;

  /// No description provided for @authPwdMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get authPwdMatch;

  /// No description provided for @authPwdConfirmEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez confirmer votre mot de passe'**
  String get authPwdConfirmEmpty;

  /// No description provided for @authSelectCountryErr.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez sélectionner votre pays'**
  String get authSelectCountryErr;

  /// No description provided for @authAcceptTerms.
  ///
  /// In fr, this message translates to:
  /// **'Vous devez accepter les CGU pour continuer'**
  String get authAcceptTerms;

  /// No description provided for @authValidateFirstName.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre prénom'**
  String get authValidateFirstName;

  /// No description provided for @authFirstNameMin2.
  ///
  /// In fr, this message translates to:
  /// **'Le prénom doit contenir au moins 2 caractères'**
  String get authFirstNameMin2;

  /// No description provided for @authValidateLastName.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre nom'**
  String get authValidateLastName;

  /// No description provided for @authLastNameMin2.
  ///
  /// In fr, this message translates to:
  /// **'Le nom doit contenir au moins 2 caractères'**
  String get authLastNameMin2;

  /// No description provided for @authWrongCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Identifiants incorrects. Vérifiez votre e-mail et mot de passe.'**
  String get authWrongCredentials;

  /// No description provided for @authCreateError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer le compte. Vérifiez vos informations ou réessayez.'**
  String get authCreateError;

  /// No description provided for @authPwdVeryWeak.
  ///
  /// In fr, this message translates to:
  /// **'Très faible'**
  String get authPwdVeryWeak;

  /// No description provided for @authPwdWeak.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get authPwdWeak;

  /// No description provided for @authPwdMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get authPwdMedium;

  /// No description provided for @authPwdStrong.
  ///
  /// In fr, this message translates to:
  /// **'Fort'**
  String get authPwdStrong;

  /// No description provided for @authPwdVeryStrong.
  ///
  /// In fr, this message translates to:
  /// **'Très fort'**
  String get authPwdVeryStrong;

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get onboardingNext;

  /// No description provided for @onboardingTitle1.
  ///
  /// In fr, this message translates to:
  /// **'Partagez ce que\nDieu a fait'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage est une arme puissante. Chaque histoire de grâce mérite d\'être racontée et peut changer une vie.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In fr, this message translates to:
  /// **'Inspirez d\'autres\ncroyants'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In fr, this message translates to:
  /// **'Des milliers de frères et sœurs attendent d\'être encouragés par ce que Dieu a accompli dans votre vie.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In fr, this message translates to:
  /// **'Commencez votre\nvoyage'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez la communauté My Testimony et soyez une lumière dans la vie de quelqu\'un aujourd\'hui.'**
  String get onboardingBody3;

  /// No description provided for @authPhoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre numéro'**
  String get authPhoneTitle;

  /// No description provided for @authPhoneSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous vous enverrons un code de vérification par SMS.'**
  String get authPhoneSubtitle;

  /// No description provided for @authContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get authContinue;

  /// No description provided for @authPickCountry.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un pays'**
  String get authPickCountry;

  /// No description provided for @authVerification.
  ///
  /// In fr, this message translates to:
  /// **'Vérification'**
  String get authVerification;

  /// No description provided for @authResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get authResend;

  /// No description provided for @authWelcomeNew.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue !'**
  String get authWelcomeNew;

  /// No description provided for @authCompleteProfile.
  ///
  /// In fr, this message translates to:
  /// **'Complétez votre profil pour commencer'**
  String get authCompleteProfile;

  /// No description provided for @authLetsGo.
  ///
  /// In fr, this message translates to:
  /// **'C\'est parti !'**
  String get authLetsGo;

  /// No description provided for @authPhoneError.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre numéro de téléphone'**
  String get authPhoneError;

  /// No description provided for @authOtpError.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect. Réessayez.'**
  String get authOtpError;

  /// No description provided for @authNameError.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre prénom et votre nom'**
  String get authNameError;

  /// No description provided for @authOrContinueWith.
  ///
  /// In fr, this message translates to:
  /// **'ou continuer avec'**
  String get authOrContinueWith;

  /// No description provided for @editGallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie photos'**
  String get editGallery;

  /// No description provided for @editCamera.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get editCamera;

  /// No description provided for @editFirstRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le prénom est obligatoire.'**
  String get editFirstRequired;

  /// No description provided for @editSaved.
  ///
  /// In fr, this message translates to:
  /// **'Profil mis à jour ✓'**
  String get editSaved;

  /// No description provided for @editTapToChange.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour changer la photo'**
  String get editTapToChange;

  /// No description provided for @editIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get editIdentity;

  /// No description provided for @editContact.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get editContact;

  /// No description provided for @editLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get editLocation;

  /// No description provided for @editBio.
  ///
  /// In fr, this message translates to:
  /// **'Bio'**
  String get editBio;

  /// No description provided for @editTitleOptional.
  ///
  /// In fr, this message translates to:
  /// **'Titre (optionnel)'**
  String get editTitleOptional;

  /// No description provided for @editGender.
  ///
  /// In fr, this message translates to:
  /// **'Sexe'**
  String get editGender;

  /// No description provided for @editSelectCountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un pays'**
  String get editSelectCountry;

  /// No description provided for @editPickCountry.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un pays'**
  String get editPickCountry;

  /// No description provided for @editSaveProfile.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder le profil'**
  String get editSaveProfile;

  /// No description provided for @editPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get editPhoneLabel;

  /// No description provided for @editAboutOptional.
  ///
  /// In fr, this message translates to:
  /// **'À propos de vous (optionnel)'**
  String get editAboutOptional;

  /// No description provided for @editBioHint.
  ///
  /// In fr, this message translates to:
  /// **'Partagez quelque chose sur vous ou votre parcours de foi…'**
  String get editBioHint;

  /// No description provided for @editSpecifyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Précisez votre titre'**
  String get editSpecifyTitle;

  /// No description provided for @editCustomTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre personnalisé (optionnel)'**
  String get editCustomTitle;

  /// No description provided for @genderMale.
  ///
  /// In fr, this message translates to:
  /// **'Masculin'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In fr, this message translates to:
  /// **'Féminin'**
  String get genderFemale;

  /// No description provided for @submitPrayerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partager une requête'**
  String get submitPrayerTitle;

  /// No description provided for @submitPrayerIntro.
  ///
  /// In fr, this message translates to:
  /// **'La communauté priera avec vous. Partagez votre besoin avec foi.'**
  String get submitPrayerIntro;

  /// No description provided for @submitPrayerField.
  ///
  /// In fr, this message translates to:
  /// **'Votre requête de prière'**
  String get submitPrayerField;

  /// No description provided for @submitPrayerHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre besoin de prière. Soyez aussi précis ou vague que vous le souhaitez…'**
  String get submitPrayerHint;

  /// No description provided for @submitPrayerValidation.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez écrire au moins 10 caractères'**
  String get submitPrayerValidation;

  /// No description provided for @submitPrayerVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité'**
  String get submitPrayerVisibility;

  /// No description provided for @submitPrayerVisPublicDesc.
  ///
  /// In fr, this message translates to:
  /// **'Visible par tous'**
  String get submitPrayerVisPublicDesc;

  /// No description provided for @submitPrayerVisFriendsDesc.
  ///
  /// In fr, this message translates to:
  /// **'Visible par vos abonnés'**
  String get submitPrayerVisFriendsDesc;

  /// No description provided for @submitPrayerVisPrivateDesc.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement vous'**
  String get submitPrayerVisPrivateDesc;

  /// No description provided for @submitPrayerButton.
  ///
  /// In fr, this message translates to:
  /// **'Partager ma requête'**
  String get submitPrayerButton;

  /// No description provided for @submitPrayerSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Votre requête a été partagée. La communauté prie avec vous 🙏'**
  String get submitPrayerSuccess;

  /// No description provided for @createSessionStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get createSessionStart;

  /// No description provided for @createSessionCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get createSessionCreate;

  /// No description provided for @createSessionTitleField.
  ///
  /// In fr, this message translates to:
  /// **'Titre de la session'**
  String get createSessionTitleField;

  /// No description provided for @createSessionDescField.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get createSessionDescField;

  /// No description provided for @createSessionVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité'**
  String get createSessionVisibility;

  /// No description provided for @createSessionOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get createSessionOptions;

  /// No description provided for @createSessionStartNow.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer maintenant'**
  String get createSessionStartNow;

  /// No description provided for @createSessionStartNowDesc.
  ///
  /// In fr, this message translates to:
  /// **'Lancer la session en direct immédiatement'**
  String get createSessionStartNowDesc;

  /// No description provided for @createSessionRecord.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la session'**
  String get createSessionRecord;

  /// No description provided for @createSessionRecordDesc.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder pour réécouter plus tard'**
  String get createSessionRecordDesc;

  /// No description provided for @createSessionStartBtn.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer la session'**
  String get createSessionStartBtn;

  /// No description provided for @createSessionScheduleBtn.
  ///
  /// In fr, this message translates to:
  /// **'Créer & programmer'**
  String get createSessionScheduleBtn;

  /// No description provided for @createSessionTitleReq.
  ///
  /// In fr, this message translates to:
  /// **'Titre requis'**
  String get createSessionTitleReq;

  /// No description provided for @createSessionSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Session créée ! La communauté sera notifiée.'**
  String get createSessionSuccess;

  /// No description provided for @adminUnpublish.
  ///
  /// In fr, this message translates to:
  /// **'Dépublier'**
  String get adminUnpublish;

  /// No description provided for @adminUnpublishConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Dépublier ce témoignage ?'**
  String get adminUnpublishConfirm;

  /// No description provided for @adminUnpublishDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le témoignage sera masqué pour tous les utilisateurs.'**
  String get adminUnpublishDesc;

  /// No description provided for @adminViews.
  ///
  /// In fr, this message translates to:
  /// **'vues'**
  String get adminViews;

  /// No description provided for @adminLikes.
  ///
  /// In fr, this message translates to:
  /// **'j\'aime'**
  String get adminLikes;

  /// No description provided for @adminPublishedLabel.
  ///
  /// In fr, this message translates to:
  /// **'publié'**
  String get adminPublishedLabel;

  /// No description provided for @modTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage'**
  String get modTestimony;

  /// No description provided for @modNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage introuvable.'**
  String get modNotFound;

  /// No description provided for @modPreview.
  ///
  /// In fr, this message translates to:
  /// **'Prévisualisation'**
  String get modPreview;

  /// No description provided for @modSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Soumis'**
  String get modSubmitted;

  /// No description provided for @modActionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Action de modération'**
  String get modActionTitle;

  /// No description provided for @modApprove.
  ///
  /// In fr, this message translates to:
  /// **'Approuver le témoignage'**
  String get modApprove;

  /// No description provided for @modRequestEdit.
  ///
  /// In fr, this message translates to:
  /// **'Demander une modification'**
  String get modRequestEdit;

  /// No description provided for @modReject.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter le témoignage'**
  String get modReject;

  /// No description provided for @modApprovedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage approuvé'**
  String get modApprovedSnack;

  /// No description provided for @modStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get modStatusPending;

  /// No description provided for @modStatusInReview.
  ///
  /// In fr, this message translates to:
  /// **'En révision'**
  String get modStatusInReview;

  /// No description provided for @modStatusApproved.
  ///
  /// In fr, this message translates to:
  /// **'Approuvé'**
  String get modStatusApproved;

  /// No description provided for @modStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get modStatusRejected;

  /// No description provided for @modContentUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Contenu du témoignage non disponible pour la prévisualisation.'**
  String get modContentUnavailable;

  /// No description provided for @modAudio.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage audio'**
  String get modAudio;

  /// No description provided for @modAudioPlay.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour écouter'**
  String get modAudioPlay;

  /// No description provided for @modVideo.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage vidéo'**
  String get modVideo;

  /// No description provided for @modVideoPlay.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour visionner'**
  String get modVideoPlay;

  /// No description provided for @searchResults.
  ///
  /// In fr, this message translates to:
  /// **'Résultats'**
  String get searchResults;

  /// No description provided for @searchResultsBody.
  ///
  /// In fr, this message translates to:
  /// **'Résultats de recherche'**
  String get searchResultsBody;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get commonBack;

  /// No description provided for @commonShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get commonShare;

  /// No description provided for @commonSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get commonSend;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get commonError;

  /// No description provided for @commonEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu disponible.'**
  String get commonEmpty;

  /// No description provided for @adminRoleVisitor.
  ///
  /// In fr, this message translates to:
  /// **'Visiteur'**
  String get adminRoleVisitor;

  /// No description provided for @adminRoleUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get adminRoleUser;

  /// No description provided for @adminRoleModerator.
  ///
  /// In fr, this message translates to:
  /// **'Modérateur'**
  String get adminRoleModerator;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminStatusActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get adminStatusActive;

  /// No description provided for @adminStatusSuspended.
  ///
  /// In fr, this message translates to:
  /// **'Suspendu'**
  String get adminStatusSuspended;

  /// No description provided for @adminStatusBanned.
  ///
  /// In fr, this message translates to:
  /// **'Banni'**
  String get adminStatusBanned;

  /// No description provided for @adminErrorWithDetail.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String adminErrorWithDetail(String error);

  /// No description provided for @adminEditCategory.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la catégorie'**
  String get adminEditCategory;

  /// No description provided for @adminCategoryNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get adminCategoryNameHint;

  /// No description provided for @adminNewCategoryHint.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle catégorie…'**
  String get adminNewCategoryHint;

  /// No description provided for @adminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get adminTitle;

  /// No description provided for @adminModerationQueue.
  ///
  /// In fr, this message translates to:
  /// **'File de modération'**
  String get adminModerationQueue;

  /// No description provided for @adminAccountVerification.
  ///
  /// In fr, this message translates to:
  /// **'Vérification des comptes'**
  String get adminAccountVerification;

  /// No description provided for @adminManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion'**
  String get adminManagement;

  /// No description provided for @adminUsers.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get adminUsers;

  /// No description provided for @adminMetricTotal.
  ///
  /// In fr, this message translates to:
  /// **'total'**
  String get adminMetricTotal;

  /// No description provided for @adminMetricNewToday.
  ///
  /// In fr, this message translates to:
  /// **'nouveaux aujourd\'hui'**
  String get adminMetricNewToday;

  /// No description provided for @adminTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages'**
  String get adminTestimonies;

  /// No description provided for @adminMetricPublished.
  ///
  /// In fr, this message translates to:
  /// **'publiés'**
  String get adminMetricPublished;

  /// No description provided for @adminMetricViewsThisMonth.
  ///
  /// In fr, this message translates to:
  /// **'vues ce mois'**
  String get adminMetricViewsThisMonth;

  /// No description provided for @adminApproval.
  ///
  /// In fr, this message translates to:
  /// **'Approbation'**
  String get adminApproval;

  /// No description provided for @adminMetricApprovalRate.
  ///
  /// In fr, this message translates to:
  /// **'taux d\'approbation'**
  String get adminMetricApprovalRate;

  /// No description provided for @adminMetricPending.
  ///
  /// In fr, this message translates to:
  /// **'en attente'**
  String get adminMetricPending;

  /// No description provided for @adminEngagement.
  ///
  /// In fr, this message translates to:
  /// **'Engagement'**
  String get adminEngagement;

  /// No description provided for @adminMetricAvgInteractions.
  ///
  /// In fr, this message translates to:
  /// **'moy. interactions'**
  String get adminMetricAvgInteractions;

  /// No description provided for @adminMetricCommentsPerMonth.
  ///
  /// In fr, this message translates to:
  /// **'commentaires/mois'**
  String get adminMetricCommentsPerMonth;

  /// No description provided for @adminUsersSub.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les comptes'**
  String get adminUsersSub;

  /// No description provided for @adminContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenus'**
  String get adminContent;

  /// No description provided for @adminContentSub.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages publiés'**
  String get adminContentSub;

  /// No description provided for @adminModerators.
  ///
  /// In fr, this message translates to:
  /// **'Modérateurs'**
  String get adminModerators;

  /// No description provided for @adminModeratorsSub.
  ///
  /// In fr, this message translates to:
  /// **'Assigner / retirer le rôle'**
  String get adminModeratorsSub;

  /// No description provided for @adminCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get adminCategories;

  /// No description provided for @adminCategoriesSub.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter, modifier, réordonner'**
  String get adminCategoriesSub;

  /// No description provided for @adminStats.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get adminStats;

  /// No description provided for @adminStatsSub.
  ///
  /// In fr, this message translates to:
  /// **'Graphiques et tendances'**
  String get adminStatsSub;

  /// No description provided for @adminSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get adminSettings;

  /// No description provided for @adminSettingsSub.
  ///
  /// In fr, this message translates to:
  /// **'Configuration de l\'app'**
  String get adminSettingsSub;

  /// No description provided for @adminUsersManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des utilisateurs'**
  String get adminUsersManagement;

  /// No description provided for @adminContentManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion des contenus'**
  String get adminContentManagement;

  /// No description provided for @adminActiveModerators.
  ///
  /// In fr, this message translates to:
  /// **'Modérateurs actifs'**
  String get adminActiveModerators;

  /// No description provided for @adminRemoveModeratorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le rôle de modérateur ?'**
  String get adminRemoveModeratorTitle;

  /// No description provided for @adminRemoveModeratorBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} redeviendra un utilisateur standard.'**
  String adminRemoveModeratorBody(String name);

  /// No description provided for @adminPromoteCandidates.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs — Promouvoir'**
  String get adminPromoteCandidates;

  /// No description provided for @adminPromoteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir {name} ?'**
  String adminPromoteTitle(String name);

  /// No description provided for @adminPromoteModeratorBody.
  ///
  /// In fr, this message translates to:
  /// **'Cet utilisateur pourra modérer les témoignages soumis.'**
  String get adminPromoteModeratorBody;

  /// No description provided for @adminRemoveRole.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le rôle'**
  String get adminRemoveRole;

  /// No description provided for @adminPromote.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir'**
  String get adminPromote;

  /// No description provided for @adminSettingsAccess.
  ///
  /// In fr, this message translates to:
  /// **'Accès'**
  String get adminSettingsAccess;

  /// No description provided for @adminSettingsNewSignups.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelles inscriptions'**
  String get adminSettingsNewSignups;

  /// No description provided for @adminSettingsNewSignupsSub.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les nouveaux comptes'**
  String get adminSettingsNewSignupsSub;

  /// No description provided for @adminSettingsGuestAccess.
  ///
  /// In fr, this message translates to:
  /// **'Accès visiteur'**
  String get adminSettingsGuestAccess;

  /// No description provided for @adminSettingsGuestAccessSub.
  ///
  /// In fr, this message translates to:
  /// **'Consulter sans compte'**
  String get adminSettingsGuestAccessSub;

  /// No description provided for @adminSettingsEmailVerification.
  ///
  /// In fr, this message translates to:
  /// **'Vérification e-mail'**
  String get adminSettingsEmailVerification;

  /// No description provided for @adminSettingsEmailVerificationSub.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire à l\'inscription'**
  String get adminSettingsEmailVerificationSub;

  /// No description provided for @adminSettingsModeration.
  ///
  /// In fr, this message translates to:
  /// **'Modération'**
  String get adminSettingsModeration;

  /// No description provided for @adminSettingsAutoModeration.
  ///
  /// In fr, this message translates to:
  /// **'Modération automatique'**
  String get adminSettingsAutoModeration;

  /// No description provided for @adminSettingsAutoModerationSub.
  ///
  /// In fr, this message translates to:
  /// **'Filtres IA pré-approbation'**
  String get adminSettingsAutoModerationSub;

  /// No description provided for @adminSettingsNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get adminSettingsNotifications;

  /// No description provided for @adminSettingsPush.
  ///
  /// In fr, this message translates to:
  /// **'Notifications push'**
  String get adminSettingsPush;

  /// No description provided for @adminSettingsPushSub.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer des notifications aux utilisateurs'**
  String get adminSettingsPushSub;

  /// No description provided for @adminMaintenanceActive.
  ///
  /// In fr, this message translates to:
  /// **'Mode maintenance actif'**
  String get adminMaintenanceActive;

  /// No description provided for @adminMaintenanceActiveBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'application est inaccessible aux utilisateurs.'**
  String get adminMaintenanceActiveBody;

  /// No description provided for @adminDisable.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver'**
  String get adminDisable;

  /// No description provided for @adminEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get adminEnable;

  /// No description provided for @adminBeta.
  ///
  /// In fr, this message translates to:
  /// **'Bêta'**
  String get adminBeta;

  /// No description provided for @adminDangerZone.
  ///
  /// In fr, this message translates to:
  /// **'Zone dangereuse'**
  String get adminDangerZone;

  /// No description provided for @adminMaintenanceMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode maintenance'**
  String get adminMaintenanceMode;

  /// No description provided for @adminMaintenanceOnSub.
  ///
  /// In fr, this message translates to:
  /// **'Application hors ligne pour les utilisateurs'**
  String get adminMaintenanceOnSub;

  /// No description provided for @adminMaintenanceOffSub.
  ///
  /// In fr, this message translates to:
  /// **'Mettre l\'app en mode maintenance'**
  String get adminMaintenanceOffSub;

  /// No description provided for @adminStatsWeekTitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages cette semaine'**
  String get adminStatsWeekTitle;

  /// No description provided for @adminStatsWeekSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Soumis vs approuvés'**
  String get adminStatsWeekSubtitle;

  /// No description provided for @adminDayMon.
  ///
  /// In fr, this message translates to:
  /// **'Lun'**
  String get adminDayMon;

  /// No description provided for @adminDayTue.
  ///
  /// In fr, this message translates to:
  /// **'Mar'**
  String get adminDayTue;

  /// No description provided for @adminDayWed.
  ///
  /// In fr, this message translates to:
  /// **'Mer'**
  String get adminDayWed;

  /// No description provided for @adminDayThu.
  ///
  /// In fr, this message translates to:
  /// **'Jeu'**
  String get adminDayThu;

  /// No description provided for @adminDayFri.
  ///
  /// In fr, this message translates to:
  /// **'Ven'**
  String get adminDayFri;

  /// No description provided for @adminDaySat.
  ///
  /// In fr, this message translates to:
  /// **'Sam'**
  String get adminDaySat;

  /// No description provided for @adminDaySun.
  ///
  /// In fr, this message translates to:
  /// **'Dim'**
  String get adminDaySun;

  /// No description provided for @adminStatsGrowthTitle.
  ///
  /// In fr, this message translates to:
  /// **'Croissance mensuelle'**
  String get adminStatsGrowthTitle;

  /// No description provided for @adminStatsGrowthSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux utilisateurs — 6 derniers mois'**
  String get adminStatsGrowthSubtitle;

  /// No description provided for @adminMonthDec.
  ///
  /// In fr, this message translates to:
  /// **'Déc'**
  String get adminMonthDec;

  /// No description provided for @adminMonthJan.
  ///
  /// In fr, this message translates to:
  /// **'Jan'**
  String get adminMonthJan;

  /// No description provided for @adminMonthFeb.
  ///
  /// In fr, this message translates to:
  /// **'Fév'**
  String get adminMonthFeb;

  /// No description provided for @adminMonthMar.
  ///
  /// In fr, this message translates to:
  /// **'Mar'**
  String get adminMonthMar;

  /// No description provided for @adminMonthApr.
  ///
  /// In fr, this message translates to:
  /// **'Avr'**
  String get adminMonthApr;

  /// No description provided for @adminMonthMay.
  ///
  /// In fr, this message translates to:
  /// **'Mai'**
  String get adminMonthMay;

  /// No description provided for @adminStatsByCategoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Répartition par catégorie'**
  String get adminStatsByCategoryTitle;

  /// No description provided for @adminStatsByCategorySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Top 5 catégories les plus actives'**
  String get adminStatsByCategorySubtitle;

  /// No description provided for @adminTopCategories.
  ///
  /// In fr, this message translates to:
  /// **'Top catégories'**
  String get adminTopCategories;

  /// No description provided for @adminTestimonyCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, other{{count} témoignages}}'**
  String adminTestimonyCount(int count);

  /// No description provided for @adminSearchUsersHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom ou e-mail…'**
  String get adminSearchUsersHint;

  /// No description provided for @adminResultCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 résultat} other{{count} résultats}}'**
  String adminResultCount(int count);

  /// No description provided for @adminNoUserFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé.'**
  String get adminNoUserFound;

  /// No description provided for @adminSuspendTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suspendre {name} ?'**
  String adminSuspendTitle(String name);

  /// No description provided for @adminSuspendBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'utilisateur ne pourra plus se connecter temporairement.'**
  String get adminSuspendBody;

  /// No description provided for @adminBanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bannir {name} ?'**
  String adminBanTitle(String name);

  /// No description provided for @adminBanBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est définitive. Le compte sera désactivé.'**
  String get adminBanBody;

  /// No description provided for @adminPromoteUserBody.
  ///
  /// In fr, this message translates to:
  /// **'Cet utilisateur deviendra modérateur.'**
  String get adminPromoteUserBody;

  /// No description provided for @adminRestoreTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver {name} ?'**
  String adminRestoreTitle(String name);

  /// No description provided for @adminRestoreBody.
  ///
  /// In fr, this message translates to:
  /// **'Le compte sera de nouveau accessible.'**
  String get adminRestoreBody;

  /// No description provided for @adminSearchUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un utilisateur'**
  String get adminSearchUserTitle;

  /// No description provided for @adminSearchUserBody.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un nom ou une adresse e-mail\npour trouver un compte.'**
  String get adminSearchUserBody;

  /// No description provided for @adminRestore.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver'**
  String get adminRestore;

  /// No description provided for @adminSuspend.
  ///
  /// In fr, this message translates to:
  /// **'Suspendre'**
  String get adminSuspend;

  /// No description provided for @adminBan.
  ///
  /// In fr, this message translates to:
  /// **'Bannir'**
  String get adminBan;

  /// No description provided for @adminPromoteModerator.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir modérateur'**
  String get adminPromoteModerator;

  /// No description provided for @adminPromoteAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Promouvoir admin'**
  String get adminPromoteAdmin;

  /// No description provided for @adminDocumentFallback.
  ///
  /// In fr, this message translates to:
  /// **'Pièce'**
  String get adminDocumentFallback;

  /// No description provided for @adminVerifTabPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get adminVerifTabPending;

  /// No description provided for @adminVerifTabApproved.
  ///
  /// In fr, this message translates to:
  /// **'Approuvées'**
  String get adminVerifTabApproved;

  /// No description provided for @adminVerifTabRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusées'**
  String get adminVerifTabRejected;

  /// No description provided for @adminVerifTabRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Retirées'**
  String get adminVerifTabRevoked;

  /// No description provided for @adminLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible.'**
  String get adminLoadFailed;

  /// No description provided for @adminNoRequests.
  ///
  /// In fr, this message translates to:
  /// **'Aucune demande.'**
  String get adminNoRequests;

  /// No description provided for @adminVerifRequestSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{role} · {church}\n{count} pièce(s)'**
  String adminVerifRequestSubtitle(String role, String church, int count);

  /// No description provided for @adminActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible. Vérifiez votre connexion.'**
  String get adminActionFailed;

  /// No description provided for @adminReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif (communiqué à la personne)'**
  String get adminReasonLabel;

  /// No description provided for @adminVerifRequestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande de vérification'**
  String get adminVerifRequestTitle;

  /// No description provided for @adminVerifStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get adminVerifStatus;

  /// No description provided for @adminVerifFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get adminVerifFullName;

  /// No description provided for @adminVerifRole.
  ///
  /// In fr, this message translates to:
  /// **'Fonction'**
  String get adminVerifRole;

  /// No description provided for @adminVerifChurch.
  ///
  /// In fr, this message translates to:
  /// **'Église ou ministère'**
  String get adminVerifChurch;

  /// No description provided for @adminVerifAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get adminVerifAccount;

  /// No description provided for @adminVerifLinks.
  ///
  /// In fr, this message translates to:
  /// **'Liens publics'**
  String get adminVerifLinks;

  /// No description provided for @adminVerifMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get adminVerifMessage;

  /// No description provided for @adminVerifReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get adminVerifReason;

  /// No description provided for @adminVerifDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Pièces justificatives (privées)'**
  String get adminVerifDocuments;

  /// No description provided for @adminVerifNoDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucune pièce disponible.'**
  String get adminVerifNoDocuments;

  /// No description provided for @adminApprove.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get adminApprove;

  /// No description provided for @adminVerifApprovedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Compte vérifié. La personne a été prévenue.'**
  String get adminVerifApprovedSnack;

  /// No description provided for @adminReject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get adminReject;

  /// No description provided for @adminRejectRequest.
  ///
  /// In fr, this message translates to:
  /// **'Refuser la demande'**
  String get adminRejectRequest;

  /// No description provided for @adminVerifRejectedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée. La personne a été prévenue.'**
  String get adminVerifRejectedSnack;

  /// No description provided for @adminRevokeVerification.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la vérification'**
  String get adminRevokeVerification;

  /// No description provided for @adminVerifRevokedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Vérification retirée. La personne a été prévenue.'**
  String get adminVerifRevokedSnack;

  /// No description provided for @adminVerifPdfHint.
  ///
  /// In fr, this message translates to:
  /// **'Document PDF : à consulter sur le site d’administration'**
  String get adminVerifPdfHint;

  /// No description provided for @adminVerifDocumentUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Pièce indisponible'**
  String get adminVerifDocumentUnavailable;

  /// No description provided for @authGuestReasonPublish.
  ///
  /// In fr, this message translates to:
  /// **'publier votre témoignage'**
  String get authGuestReasonPublish;

  /// No description provided for @authGuestReasonNotifications.
  ///
  /// In fr, this message translates to:
  /// **'recevoir vos notifications'**
  String get authGuestReasonNotifications;

  /// No description provided for @authGuestReasonJournal.
  ///
  /// In fr, this message translates to:
  /// **'tenir votre journal spirituel'**
  String get authGuestReasonJournal;

  /// No description provided for @authGuestReasonProphecies.
  ///
  /// In fr, this message translates to:
  /// **'garder vos paroles prophétiques'**
  String get authGuestReasonProphecies;

  /// No description provided for @authGuestReasonMyFeed.
  ///
  /// In fr, this message translates to:
  /// **'suivre les témoignages de vos abonnements'**
  String get authGuestReasonMyFeed;

  /// No description provided for @authGuestReasonPrayerRequest.
  ///
  /// In fr, this message translates to:
  /// **'confier une requête de prière'**
  String get authGuestReasonPrayerRequest;

  /// No description provided for @authGuestReasonPrayerSession.
  ///
  /// In fr, this message translates to:
  /// **'programmer une session de prière'**
  String get authGuestReasonPrayerSession;

  /// No description provided for @authGuestReasonEvent.
  ///
  /// In fr, this message translates to:
  /// **'gérer un événement'**
  String get authGuestReasonEvent;

  /// No description provided for @authGuestReasonComment.
  ///
  /// In fr, this message translates to:
  /// **'commenter les témoignages'**
  String get authGuestReasonComment;

  /// No description provided for @authGuestReasonReport.
  ///
  /// In fr, this message translates to:
  /// **'signaler un contenu'**
  String get authGuestReasonReport;

  /// No description provided for @authGuestReasonFollow.
  ///
  /// In fr, this message translates to:
  /// **'suivre des membres'**
  String get authGuestReasonFollow;

  /// No description provided for @authGuestReasonLive.
  ///
  /// In fr, this message translates to:
  /// **'lancer un direct'**
  String get authGuestReasonLive;

  /// No description provided for @authGuestReasonSaved.
  ///
  /// In fr, this message translates to:
  /// **'enregistrer vos favoris'**
  String get authGuestReasonSaved;

  /// No description provided for @authGuestReasonProfile.
  ///
  /// In fr, this message translates to:
  /// **'gérer votre profil'**
  String get authGuestReasonProfile;

  /// No description provided for @authGuestReasonDefault.
  ///
  /// In fr, this message translates to:
  /// **'profiter de toutes les fonctionnalités'**
  String get authGuestReasonDefault;

  /// No description provided for @authErrInvalidPhone.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone invalide.'**
  String get authErrInvalidPhone;

  /// No description provided for @authErrTooManyRequests.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessayez dans quelques minutes.'**
  String get authErrTooManyRequests;

  /// No description provided for @authErrSmsQuota.
  ///
  /// In fr, this message translates to:
  /// **'Quota SMS dépassé. Réessayez plus tard.'**
  String get authErrSmsQuota;

  /// No description provided for @authErrorWithDetail.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String authErrorWithDetail(String error);

  /// No description provided for @authErrInvalidServerResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse serveur invalide.'**
  String get authErrInvalidServerResponse;

  /// No description provided for @authDefaultUserName.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get authDefaultUserName;

  /// No description provided for @authGoogleIdentityRejected.
  ///
  /// In fr, this message translates to:
  /// **'Google n’a pas pu confirmer votre identité. Réessayez.'**
  String get authGoogleIdentityRejected;

  /// No description provided for @authAccountCannotSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte ne peut pas se connecter.'**
  String get authAccountCannotSignIn;

  /// No description provided for @authServerUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur est indisponible pour le moment. Réessayez plus tard.'**
  String get authServerUnavailable;

  /// No description provided for @authNoInternet.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion Internet. Vérifiez votre réseau et réessayez.'**
  String get authNoInternet;

  /// No description provided for @authGoogleFailed.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google a échoué. Réessayez.'**
  String get authGoogleFailed;

  /// No description provided for @authGoogleUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google n’est pas disponible sur cet appareil.'**
  String get authGoogleUnavailable;

  /// No description provided for @authGoogleInterrupted.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google a été interrompue. Réessayez.'**
  String get authGoogleInterrupted;

  /// No description provided for @authGoogleMisconfigured.
  ///
  /// In fr, this message translates to:
  /// **'La connexion avec Google est mal configurée. Contactez le support.'**
  String get authGoogleMisconfigured;

  /// No description provided for @authGoogleUiUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’ouvrir la fenêtre de connexion Google. Réessayez.'**
  String get authGoogleUiUnavailable;

  /// No description provided for @authJoinTagline.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez une communauté qui partage la gloire de Dieu.'**
  String get authJoinTagline;

  /// No description provided for @authSignInWithPhone.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec numéro'**
  String get authSignInWithPhone;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authSignInWithEmail.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec Email'**
  String get authSignInWithEmail;

  /// No description provided for @authOrContinueWithoutAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ou continuer sans compte'**
  String get authOrContinueWithoutAccount;

  /// No description provided for @authGuestMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode invité'**
  String get authGuestMode;

  /// No description provided for @authEmailSignInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par e-mail'**
  String get authEmailSignInTitle;

  /// No description provided for @authEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'exemple@email.com'**
  String get authEmailHint;

  /// No description provided for @authShowPassword.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le mot de passe'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In fr, this message translates to:
  /// **'Masquer le mot de passe'**
  String get authHidePassword;

  /// No description provided for @authOr.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get authOr;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authResetEmailFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'envoyer l\'e-mail. Vérifiez l\'adresse saisie.'**
  String get authResetEmailFailed;

  /// No description provided for @authResetSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nous vous enverrons un lien de réinitialisation'**
  String get authResetSubtitle;

  /// No description provided for @authResetInstructions.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez l\'adresse e-mail associée à votre compte. Vous recevrez un lien pour créer un nouveau mot de passe.'**
  String get authResetInstructions;

  /// No description provided for @authSendLink.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le lien'**
  String get authSendLink;

  /// No description provided for @authBackToSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Retour à la connexion'**
  String get authBackToSignIn;

  /// No description provided for @authEmailSent.
  ///
  /// In fr, this message translates to:
  /// **'E-mail envoyé !'**
  String get authEmailSent;

  /// No description provided for @authResetEmailSentBody.
  ///
  /// In fr, this message translates to:
  /// **'Nous avons envoyé un lien de réinitialisation à\n{email}\n\nVérifiez également vos courriers indésirables.'**
  String authResetEmailSentBody(String email);

  /// No description provided for @authResendEmail.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer l\'e-mail'**
  String get authResendEmail;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue sur'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In fr, this message translates to:
  /// **'Découvrez, partagez et vivez des témoignages qui édifient et changent des vies.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingShareTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partagez ce que Dieu a fait'**
  String get onboardingShareTitle;

  /// No description provided for @onboardingShareBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage est une arme puissante : chaque histoire de grâce mérite d\'être racontée et peut changer une vie.'**
  String get onboardingShareBody;

  /// No description provided for @onboardingInspireTitle.
  ///
  /// In fr, this message translates to:
  /// **'Inspirez d\'autres croyants'**
  String get onboardingInspireTitle;

  /// No description provided for @onboardingInspireBody.
  ///
  /// In fr, this message translates to:
  /// **'Des milliers de frères et sœurs attendent d\'être encouragés par ce que Dieu a accompli dans votre vie.'**
  String get onboardingInspireBody;

  /// No description provided for @onboardingStartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commencez votre voyage'**
  String get onboardingStartTitle;

  /// No description provided for @onboardingStartBody.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez la communauté et soyez une lumière dans la vie de quelqu\'un aujourd\'hui.'**
  String get onboardingStartBody;

  /// No description provided for @onboardingStart.
  ///
  /// In fr, this message translates to:
  /// **'Commencer'**
  String get onboardingStart;

  /// No description provided for @onboardingPageOf.
  ///
  /// In fr, this message translates to:
  /// **'Page {current} sur {total}'**
  String onboardingPageOf(int current, int total);

  /// No description provided for @authCountryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get authCountryOther;

  /// No description provided for @authTagline.
  ///
  /// In fr, this message translates to:
  /// **'Partagez les œuvres de Dieu'**
  String get authTagline;

  /// No description provided for @authCodeSentToPhone.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé au {phone}'**
  String authCodeSentToPhone(String phone);

  /// No description provided for @authResendIn.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer dans {time}'**
  String authResendIn(String time);

  /// No description provided for @authFirstNameHintFemale.
  ///
  /// In fr, this message translates to:
  /// **'Marie'**
  String get authFirstNameHintFemale;

  /// No description provided for @authFirstNameHintMale.
  ///
  /// In fr, this message translates to:
  /// **'Jean'**
  String get authFirstNameHintMale;

  /// No description provided for @authLastNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Dupont'**
  String get authLastNameHint;

  /// No description provided for @authLogoUploadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Logo non envoyé, vous pourrez l\'ajouter depuis votre profil'**
  String get authLogoUploadFailed;

  /// No description provided for @authInvalidWebsite.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du site web invalide'**
  String get authInvalidWebsite;

  /// No description provided for @authValidateNewPwd.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir un mot de passe'**
  String get authValidateNewPwd;

  /// No description provided for @authCreateAccountFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer le compte. Vérifiez vos informations.'**
  String get authCreateAccountFailed;

  /// No description provided for @authOrgNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'organisation'**
  String get authOrgNameLabel;

  /// No description provided for @authOrgNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Église de la Grâce'**
  String get authOrgNameHint;

  /// No description provided for @authOrgNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir le nom de l\'organisation'**
  String get authOrgNameRequired;

  /// No description provided for @authCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get authCityLabel;

  /// No description provided for @authCityRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir la ville'**
  String get authCityRequired;

  /// No description provided for @authWebsiteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Site web (optionnel)'**
  String get authWebsiteLabel;

  /// No description provided for @authWebsiteHint.
  ///
  /// In fr, this message translates to:
  /// **'www.exemple.org'**
  String get authWebsiteHint;

  /// No description provided for @authOptionalNote.
  ///
  /// In fr, this message translates to:
  /// **'(facultatif)'**
  String get authOptionalNote;

  /// No description provided for @authPickOrgLogo.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le logo de l\'organisation'**
  String get authPickOrgLogo;

  /// No description provided for @authPickProfilePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une photo de profil'**
  String get authPickProfilePhoto;

  /// No description provided for @authLogo.
  ///
  /// In fr, this message translates to:
  /// **'Logo'**
  String get authLogo;

  /// No description provided for @authProfilePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get authProfilePhoto;

  /// No description provided for @authAccountType.
  ///
  /// In fr, this message translates to:
  /// **'Type de compte'**
  String get authAccountType;

  /// No description provided for @authAccountTypeIndividual.
  ///
  /// In fr, this message translates to:
  /// **'Je suis une personne'**
  String get authAccountTypeIndividual;

  /// No description provided for @authAccountTypeIndividualSub.
  ///
  /// In fr, this message translates to:
  /// **'Partagez vos témoignages personnels'**
  String get authAccountTypeIndividualSub;

  /// No description provided for @authAccountTypeOrg.
  ///
  /// In fr, this message translates to:
  /// **'Je représente une organisation'**
  String get authAccountTypeOrg;

  /// No description provided for @authAccountTypeOrgSub.
  ///
  /// In fr, this message translates to:
  /// **'Église, ministère, association…'**
  String get authAccountTypeOrgSub;

  /// No description provided for @authOrgVerificationNote.
  ///
  /// In fr, this message translates to:
  /// **'Votre organisation sera vérifiée par notre équipe. Le badge vérifié apparaîtra ensuite sur votre profil et vos témoignages.'**
  String get authOrgVerificationNote;

  /// No description provided for @authOrgTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'organisation'**
  String get authOrgTypeLabel;

  /// No description provided for @authOrgTypeHint.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez le type'**
  String get authOrgTypeHint;

  /// No description provided for @authOrgTypeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir un type'**
  String get authOrgTypeRequired;

  /// No description provided for @authAcceptPrefix.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte les '**
  String get authAcceptPrefix;

  /// No description provided for @authTermsOfUse.
  ///
  /// In fr, this message translates to:
  /// **'Conditions Générales d\'Utilisation'**
  String get authTermsOfUse;

  /// No description provided for @authAcceptAnd.
  ///
  /// In fr, this message translates to:
  /// **' et la '**
  String get authAcceptAnd;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get authPrivacyPolicy;

  /// No description provided for @authEnterFullName.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez entrer votre prénom et votre nom.'**
  String get authEnterFullName;

  /// No description provided for @authCreateMyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get authCreateMyAccount;

  /// No description provided for @authSimpleRegisterIntro.
  ///
  /// In fr, this message translates to:
  /// **'Entrez juste votre prénom et votre nom.\nAucun mot de passe requis.'**
  String get authSimpleRegisterIntro;

  /// No description provided for @authCompleteProfileLater.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez compléter votre profil plus tard.'**
  String get authCompleteProfileLater;

  /// No description provided for @authSplashSemantics.
  ///
  /// In fr, this message translates to:
  /// **'My Testimony. Des vies transformées pour la gloire de Dieu.'**
  String get authSplashSemantics;

  /// No description provided for @authSplashTagline.
  ///
  /// In fr, this message translates to:
  /// **'Des vies transformées\npour la gloire de Dieu'**
  String get authSplashTagline;

  /// No description provided for @authLoadingSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Chargement'**
  String get authLoadingSemantics;

  /// No description provided for @authCodeInvalidOrExpired.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect ou expiré. Veuillez réessayer.'**
  String get authCodeInvalidOrExpired;

  /// No description provided for @authCheckEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre e-mail'**
  String get authCheckEmailTitle;

  /// No description provided for @authCodeSentToEmail.
  ///
  /// In fr, this message translates to:
  /// **'Code envoyé à {email}'**
  String authCodeSentToEmail(String email);

  /// No description provided for @authEnterSixDigitCode.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code à 6 chiffres que nous venons de vous envoyer.'**
  String get authEnterSixDigitCode;

  /// No description provided for @authNotMyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ce n\'est pas mon compte ? '**
  String get authNotMyAccount;

  /// No description provided for @authSignOut.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get authSignOut;

  /// No description provided for @authNoCodeReceived.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas reçu de code ? '**
  String get authNoCodeReceived;

  /// No description provided for @authLoadingProgress.
  ///
  /// In fr, this message translates to:
  /// **'{percent} %'**
  String authLoadingProgress(int percent);

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get commonEdit;

  /// No description provided for @commonOk.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get commonNo;

  /// No description provided for @commonContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get commonContinue;

  /// No description provided for @commonNext.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get commonPrevious;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get commonSearch;

  /// No description provided for @commonSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get commonSeeAll;

  /// No description provided for @commonSeeMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get commonSeeMore;

  /// No description provided for @commonSeeLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get commonSeeLess;

  /// No description provided for @commonDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get commonDone;

  /// No description provided for @commonApply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get commonApply;

  /// No description provided for @commonReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get commonReset;

  /// No description provided for @commonCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get commonCopied;

  /// No description provided for @commonReport.
  ///
  /// In fr, this message translates to:
  /// **'Signaler'**
  String get commonReport;

  /// No description provided for @commonPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get commonPublish;

  /// No description provided for @commonAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get commonRemove;

  /// No description provided for @commonValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get commonValidate;

  /// No description provided for @commonRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get commonRefresh;

  /// No description provided for @commonOptional.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif'**
  String get commonOptional;

  /// No description provided for @commonRequired.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire'**
  String get commonRequired;

  /// No description provided for @commonRequiredField.
  ///
  /// In fr, this message translates to:
  /// **'Ce champ est obligatoire.'**
  String get commonRequiredField;

  /// No description provided for @commonErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez.'**
  String get commonErrorGeneric;

  /// No description provided for @commonErrorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Vérifiez votre réseau puis réessayez.'**
  String get commonErrorNetwork;

  /// No description provided for @commonNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get commonNoResults;

  /// No description provided for @commonAnonymous.
  ///
  /// In fr, this message translates to:
  /// **'Anonyme'**
  String get commonAnonymous;

  /// No description provided for @commonYou.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get commonYou;

  /// No description provided for @commonUntitled.
  ///
  /// In fr, this message translates to:
  /// **'(Sans titre)'**
  String get commonUntitled;

  /// No description provided for @commonAppName.
  ///
  /// In fr, this message translates to:
  /// **'My Testimony'**
  String get commonAppName;

  /// No description provided for @timeJustNow.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} min'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} h'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} j'**
  String timeDaysAgo(int count);

  /// No description provided for @timeWeeksAgo.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} sem.'**
  String timeWeeksAgo(int count);

  /// No description provided for @timeMonthsAgo.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} mois'**
  String timeMonthsAgo(int count);

  /// No description provided for @timeYearsAgo.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{il y a 1 an} other{il y a {count} ans}}'**
  String timeYearsAgo(int count);

  /// No description provided for @timeToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get timeToday;

  /// No description provided for @timeYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get timeYesterday;

  /// No description provided for @timeTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get timeTomorrow;

  /// No description provided for @profileMemberSinceYears.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Membre depuis 1 an} other{Membre depuis {count} ans}}'**
  String profileMemberSinceYears(int count);

  /// No description provided for @profileMemberSinceMonths.
  ///
  /// In fr, this message translates to:
  /// **'Membre depuis {count} mois'**
  String profileMemberSinceMonths(int count);

  /// No description provided for @profileMemberSinceDays.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Membre depuis 1 jour} other{Membre depuis {count} jours}}'**
  String profileMemberSinceDays(int count);

  /// No description provided for @languageScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageScreenTitle;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Langue du système'**
  String get languageSystem;

  /// No description provided for @languageSystemCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Actuellement : {language}'**
  String languageSystemCurrent(String language);

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHint.
  ///
  /// In fr, this message translates to:
  /// **'L\'application, les notifications et les e-mails utilisent cette langue. Les témoignages restent dans la langue de leur auteur.'**
  String get languageHint;

  /// No description provided for @languageChanged.
  ///
  /// In fr, this message translates to:
  /// **'Langue mise à jour.'**
  String get languageChanged;

  /// No description provided for @pushTestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tester les notifications'**
  String get pushTestTitle;

  /// No description provided for @pushTestSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir une notification de test sur cet appareil'**
  String get pushTestSubtitle;

  /// No description provided for @pushTestSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi de la notification de test…'**
  String get pushTestSending;

  /// No description provided for @pushTestSent.
  ///
  /// In fr, this message translates to:
  /// **'Notification de test envoyée. Elle doit arriver dans quelques secondes.'**
  String get pushTestSent;

  /// No description provided for @pushTestSentDevices.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Notification envoyée à 1 appareil. Elle doit arriver dans quelques secondes.} other{Notification envoyée à {count} appareils. Elle doit arriver dans quelques secondes.}}'**
  String pushTestSentDevices(int count);

  /// No description provided for @pushTestPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Les notifications sont désactivées pour Témoignages. Autorisez-les dans les réglages du téléphone, puis réessayez.'**
  String get pushTestPermissionDenied;

  /// No description provided for @pushTestNoToken.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil n\'a pas pu s\'enregistrer pour les notifications (services Google ou Apple indisponibles, ou simulateur).'**
  String get pushTestNoToken;

  /// No description provided for @pushTestNotDeployed.
  ///
  /// In fr, this message translates to:
  /// **'Le test des notifications n\'est pas encore disponible sur le serveur. Réessayez après sa mise à jour.'**
  String get pushTestNotDeployed;

  /// No description provided for @pushTestServerError.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a pas pu envoyer la notification : {message}'**
  String pushTestServerError(String message);

  /// No description provided for @pushTestNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Vérifiez votre connexion.'**
  String get pushTestNetworkError;

  /// No description provided for @pushTestNotReceived.
  ///
  /// In fr, this message translates to:
  /// **'Rien reçu ? Vérifiez que les notifications sont autorisées et que le mode « Ne pas déranger » est désactivé.'**
  String get pushTestNotReceived;

  /// No description provided for @pushFallbackTitle.
  ///
  /// In fr, this message translates to:
  /// **'My Testimony'**
  String get pushFallbackTitle;

  /// No description provided for @pushChannelName.
  ///
  /// In fr, this message translates to:
  /// **'Notifications Témoignages'**
  String get pushChannelName;

  /// No description provided for @pushChannelDescription.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires, réactions, approbations et prières.'**
  String get pushChannelDescription;

  /// No description provided for @eventsTypeCrusade.
  ///
  /// In fr, this message translates to:
  /// **'Croisade d\'évangélisation'**
  String get eventsTypeCrusade;

  /// No description provided for @eventsTypeConference.
  ///
  /// In fr, this message translates to:
  /// **'Conférence'**
  String get eventsTypeConference;

  /// No description provided for @eventsTypeSeminar.
  ///
  /// In fr, this message translates to:
  /// **'Séminaire'**
  String get eventsTypeSeminar;

  /// No description provided for @eventsTypeCamp.
  ///
  /// In fr, this message translates to:
  /// **'Camp'**
  String get eventsTypeCamp;

  /// No description provided for @eventsTypeTour.
  ///
  /// In fr, this message translates to:
  /// **'Tournée'**
  String get eventsTypeTour;

  /// No description provided for @eventsTypeWorship.
  ///
  /// In fr, this message translates to:
  /// **'Concert de louange'**
  String get eventsTypeWorship;

  /// No description provided for @eventsTypeRetreat.
  ///
  /// In fr, this message translates to:
  /// **'Retraite spirituelle'**
  String get eventsTypeRetreat;

  /// No description provided for @eventsTypeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre événement'**
  String get eventsTypeOther;

  /// No description provided for @eventsStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get eventsStatusDraft;

  /// No description provided for @eventsStatusPublished.
  ///
  /// In fr, this message translates to:
  /// **'Publié'**
  String get eventsStatusPublished;

  /// No description provided for @eventsStatusPostponedTbc.
  ///
  /// In fr, this message translates to:
  /// **'Reporté — date à confirmer'**
  String get eventsStatusPostponedTbc;

  /// No description provided for @eventsStatusCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulé'**
  String get eventsStatusCancelled;

  /// No description provided for @eventsAttendanceYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui, il a eu lieu'**
  String get eventsAttendanceYes;

  /// No description provided for @eventsAttendanceNo.
  ///
  /// In fr, this message translates to:
  /// **'Non, il n\'a pas eu lieu'**
  String get eventsAttendanceNo;

  /// No description provided for @eventsAttendanceAbsent.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'y étais pas'**
  String get eventsAttendanceAbsent;

  /// No description provided for @eventsReportNotChristian.
  ///
  /// In fr, this message translates to:
  /// **'Pas un événement chrétien'**
  String get eventsReportNotChristian;

  /// No description provided for @eventsReportFake.
  ///
  /// In fr, this message translates to:
  /// **'Événement faux / n\'existe pas'**
  String get eventsReportFake;

  /// No description provided for @eventsReportInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get eventsReportInappropriate;

  /// No description provided for @eventsReportScam.
  ///
  /// In fr, this message translates to:
  /// **'Arnaque / demande d\'argent'**
  String get eventsReportScam;

  /// No description provided for @eventsReportOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get eventsReportOther;

  /// No description provided for @eventsSurveyConfirmedPercent.
  ///
  /// In fr, this message translates to:
  /// **'{percent} % confirment qu\'il a eu lieu'**
  String eventsSurveyConfirmedPercent(int percent);

  /// No description provided for @eventsReviewCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 avis} =1{1 avis} other{{count} avis}}'**
  String eventsReviewCount(int count);

  /// No description provided for @eventsDefaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get eventsDefaultTitle;

  /// No description provided for @eventsPhaseOngoing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get eventsPhaseOngoing;

  /// No description provided for @eventsPhasePast.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get eventsPhasePast;

  /// No description provided for @eventsPhaseUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get eventsPhaseUpcoming;

  /// No description provided for @eventsServerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur du serveur ({status}).'**
  String eventsServerError(int status);

  /// No description provided for @eventsConnectionError.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre accès à Internet.'**
  String get eventsConnectionError;

  /// No description provided for @eventsTestimonySaved.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage enregistré.'**
  String get eventsTestimonySaved;

  /// No description provided for @eventsReportThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci. Votre signalement sera examiné par la modération.'**
  String get eventsReportThanks;

  /// No description provided for @eventsTabUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get eventsTabUpcoming;

  /// No description provided for @eventsTabOngoing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get eventsTabOngoing;

  /// No description provided for @eventsTabGoing.
  ///
  /// In fr, this message translates to:
  /// **'J\'y participe'**
  String get eventsTabGoing;

  /// No description provided for @eventsTabPast.
  ///
  /// In fr, this message translates to:
  /// **'Passés'**
  String get eventsTabPast;

  /// No description provided for @eventsTabMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes événements'**
  String get eventsTabMine;

  /// No description provided for @eventsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher : titre, ville, lieu…'**
  String get eventsSearchHint;

  /// No description provided for @eventsCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer un événement'**
  String get eventsCreate;

  /// No description provided for @eventsLayoutCards.
  ///
  /// In fr, this message translates to:
  /// **'Affichage : cartes'**
  String get eventsLayoutCards;

  /// No description provided for @eventsLayoutCompact.
  ///
  /// In fr, this message translates to:
  /// **'Affichage : liste compacte'**
  String get eventsLayoutCompact;

  /// No description provided for @eventsAllTypes.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get eventsAllTypes;

  /// No description provided for @eventsEmptyUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement à venir pour le moment.'**
  String get eventsEmptyUpcoming;

  /// No description provided for @eventsEmptyGoing.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez encore répondu « Je participe » à aucun événement.'**
  String get eventsEmptyGoing;

  /// No description provided for @eventsEmptyOngoing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement en cours en ce moment.'**
  String get eventsEmptyOngoing;

  /// No description provided for @eventsEmptyPast.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement passé.'**
  String get eventsEmptyPast;

  /// No description provided for @eventsEmptyMine.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore créé d\'événement.\nCroisade, conférence, camp… lancez-vous !'**
  String get eventsEmptyMine;

  /// No description provided for @eventsEmptyFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement à venir des comptes que vous suivez.'**
  String get eventsEmptyFollowing;

  /// No description provided for @eventsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les événements.'**
  String get eventsLoadError;

  /// No description provided for @eventsDateTbd.
  ///
  /// In fr, this message translates to:
  /// **'Date à préciser'**
  String get eventsDateTbd;

  /// No description provided for @eventsDateTbc.
  ///
  /// In fr, this message translates to:
  /// **'Date à confirmer'**
  String get eventsDateTbc;

  /// No description provided for @eventsLiveBadge.
  ///
  /// In fr, this message translates to:
  /// **'EN DIRECT'**
  String get eventsLiveBadge;

  /// No description provided for @eventsImageOf.
  ///
  /// In fr, this message translates to:
  /// **'Image {index} sur {total}'**
  String eventsImageOf(int index, int total);

  /// No description provided for @eventsFlagPostponed.
  ///
  /// In fr, this message translates to:
  /// **'Reporté'**
  String get eventsFlagPostponed;

  /// No description provided for @eventsFlagUnconfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Non confirmé'**
  String get eventsFlagUnconfirmed;

  /// No description provided for @eventsFlagHidden.
  ///
  /// In fr, this message translates to:
  /// **'Masqué'**
  String get eventsFlagHidden;

  /// No description provided for @eventsOriginalDate.
  ///
  /// In fr, this message translates to:
  /// **'Date initiale : {date}'**
  String eventsOriginalDate(String date);

  /// No description provided for @eventsManagerSearchError.
  ///
  /// In fr, this message translates to:
  /// **'Recherche impossible. Vérifiez votre connexion.'**
  String get eventsManagerSearchError;

  /// No description provided for @eventsManagerSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom ou adresse e-mail'**
  String get eventsManagerSearchHint;

  /// No description provided for @eventsManagerTypeTwoLetters.
  ///
  /// In fr, this message translates to:
  /// **'Tapez au moins deux lettres du nom de la personne.'**
  String get eventsManagerTypeTwoLetters;

  /// No description provided for @eventsManagerNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte personnel trouvé.'**
  String get eventsManagerNoAccount;

  /// No description provided for @eventsManagerAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un co-gestionnaire'**
  String get eventsManagerAdd;

  /// No description provided for @eventsManagerAdded.
  ///
  /// In fr, this message translates to:
  /// **'{name} peut maintenant gérer l\'événement.'**
  String eventsManagerAdded(String name);

  /// No description provided for @eventsManagerLeft.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne gérez plus cet événement.'**
  String get eventsManagerLeft;

  /// No description provided for @eventsManagerRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Co-gestionnaire retiré.'**
  String get eventsManagerRemoved;

  /// No description provided for @eventsManagersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Co-gestionnaires ({count}/{max})'**
  String eventsManagersTitle(int count, int max);

  /// No description provided for @eventsManagersHelp.
  ///
  /// In fr, this message translates to:
  /// **'Ils modifient la page, enregistrent les témoignages et lancent le direct. Seul l\'organisateur les désigne et peut supprimer l\'événement.'**
  String get eventsManagersHelp;

  /// No description provided for @eventsOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur'**
  String get eventsOrganizer;

  /// No description provided for @eventsCoManager.
  ///
  /// In fr, this message translates to:
  /// **'Co-gestionnaire'**
  String get eventsCoManager;

  /// No description provided for @eventsManagerRemoveMe.
  ///
  /// In fr, this message translates to:
  /// **'Me retirer'**
  String get eventsManagerRemoveMe;

  /// No description provided for @eventsManagersMax.
  ///
  /// In fr, this message translates to:
  /// **'Deux co-gestionnaires au plus'**
  String get eventsManagersMax;

  /// No description provided for @eventsUpcomingAndOngoing.
  ///
  /// In fr, this message translates to:
  /// **'Événements à venir et en cours'**
  String get eventsUpcomingAndOngoing;

  /// No description provided for @eventsPastEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements passés'**
  String get eventsPastEvents;

  /// No description provided for @eventsUpcomingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événements à venir'**
  String get eventsUpcomingTitle;

  /// No description provided for @eventsSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get eventsSeeAll;

  /// No description provided for @eventsOsmAttribution.
  ///
  /// In fr, this message translates to:
  /// **'© contributeurs OpenStreetMap'**
  String get eventsOsmAttribution;

  /// No description provided for @eventsPlacePin.
  ///
  /// In fr, this message translates to:
  /// **'Lieu de l\'événement'**
  String get eventsPlacePin;

  /// No description provided for @eventsLocationServiceOff.
  ///
  /// In fr, this message translates to:
  /// **'La localisation est désactivée. Activez-la dans les réglages du téléphone, ou touchez la carte pour placer le repère.'**
  String get eventsLocationServiceOff;

  /// No description provided for @eventsLocationDenied.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la position refusé. Touchez la carte pour placer le repère.'**
  String get eventsLocationDenied;

  /// No description provided for @eventsLocationBlockedWeb.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la position bloqué : autorisez la localisation pour ce site dans les réglages du navigateur, ou touchez la carte.'**
  String get eventsLocationBlockedWeb;

  /// No description provided for @eventsLocationDeniedForever.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la position refusé. Autorisez-le dans les réglages de l\'application, ou touchez la carte pour placer le repère.'**
  String get eventsLocationDeniedForever;

  /// No description provided for @eventsLocationNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Position introuvable pour le moment. Touchez la carte pour placer le repère.'**
  String get eventsLocationNotFound;

  /// No description provided for @eventsPinOnPosition.
  ///
  /// In fr, this message translates to:
  /// **'Repère placé sur votre position.'**
  String get eventsPinOnPosition;

  /// No description provided for @eventsEnterAddressFirst.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez d\'abord le lieu, l\'adresse ou la ville.'**
  String get eventsEnterAddressFirst;

  /// No description provided for @eventsAddressNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Adresse introuvable sur la carte : touchez la carte pour placer le repère.'**
  String get eventsAddressNotFound;

  /// No description provided for @eventsAddressFound.
  ///
  /// In fr, this message translates to:
  /// **'Adresse trouvée : ajustez le repère si besoin.'**
  String get eventsAddressFound;

  /// No description provided for @eventsAddressSearchFailed.
  ///
  /// In fr, this message translates to:
  /// **'Recherche impossible pour le moment : touchez la carte pour placer le repère.'**
  String get eventsAddressSearchFailed;

  /// No description provided for @eventsMyPosition.
  ///
  /// In fr, this message translates to:
  /// **'Ma position'**
  String get eventsMyPosition;

  /// No description provided for @eventsSearchAddress.
  ///
  /// In fr, this message translates to:
  /// **'Chercher l\'adresse'**
  String get eventsSearchAddress;

  /// No description provided for @eventsClearPin.
  ///
  /// In fr, this message translates to:
  /// **'Effacer le repère'**
  String get eventsClearPin;

  /// No description provided for @eventsMapPickerSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Carte : touchez pour placer le repère du lieu de l\'événement'**
  String get eventsMapPickerSemantics;

  /// No description provided for @eventsNoPin.
  ///
  /// In fr, this message translates to:
  /// **'Aucun repère placé. Touchez la carte pour indiquer le lieu.'**
  String get eventsNoPin;

  /// No description provided for @eventsPinPlaced.
  ///
  /// In fr, this message translates to:
  /// **'Repère placé'**
  String get eventsPinPlaced;

  /// No description provided for @eventsDirectionsFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir l\'itinéraire sur cet appareil.'**
  String get eventsDirectionsFailed;

  /// No description provided for @eventsAddressCopied.
  ///
  /// In fr, this message translates to:
  /// **'Adresse copiée.'**
  String get eventsAddressCopied;

  /// No description provided for @eventsPlace.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get eventsPlace;

  /// No description provided for @eventsPlaceMap.
  ///
  /// In fr, this message translates to:
  /// **'Carte du lieu de l\'événement'**
  String get eventsPlaceMap;

  /// No description provided for @eventsDirections.
  ///
  /// In fr, this message translates to:
  /// **'Itinéraire'**
  String get eventsDirections;

  /// No description provided for @eventsCopyAddress.
  ///
  /// In fr, this message translates to:
  /// **'Copier l\'adresse'**
  String get eventsCopyAddress;

  /// No description provided for @eventsReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif : {reason}'**
  String eventsReasonLabel(String reason);

  /// No description provided for @eventsHiddenByModeration.
  ///
  /// In fr, this message translates to:
  /// **'Masqué par la modération'**
  String get eventsHiddenByModeration;

  /// No description provided for @eventsHiddenText.
  ///
  /// In fr, this message translates to:
  /// **'L\'événement n\'apparaît plus au public.'**
  String get eventsHiddenText;

  /// No description provided for @eventsCancelledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événement annulé'**
  String get eventsCancelledTitle;

  /// No description provided for @eventsCancelledText.
  ///
  /// In fr, this message translates to:
  /// **'Les réponses ne sont plus possibles.'**
  String get eventsCancelledText;

  /// No description provided for @eventsPostponedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événement reporté'**
  String get eventsPostponedTitle;

  /// No description provided for @eventsNewDate.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle date : {date}.'**
  String eventsNewDate(String date);

  /// No description provided for @eventsGoingKept.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse « Je participe » est conservée.'**
  String get eventsGoingKept;

  /// No description provided for @eventsUnconfirmedText.
  ///
  /// In fr, this message translates to:
  /// **'La majorité des personnes qui ont répondu au sondage disent que cet événement n\'a pas eu lieu. La modération vérifie.'**
  String get eventsUnconfirmedText;

  /// No description provided for @eventsPostponeChooseDates.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez les nouvelles dates, ou « Date à confirmer ».'**
  String get eventsPostponeChooseDates;

  /// No description provided for @eventsEndAfterStart.
  ///
  /// In fr, this message translates to:
  /// **'La fin doit être après le début.'**
  String get eventsEndAfterStart;

  /// No description provided for @eventsLabeledValue.
  ///
  /// In fr, this message translates to:
  /// **'{label} : {value}'**
  String eventsLabeledValue(String label, String value);

  /// No description provided for @eventsPostponeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Reporter l\'événement'**
  String get eventsPostponeTitle;

  /// No description provided for @eventsPostponeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Les personnes qui participent sont prévenues. La date initiale reste affichée, barrée.'**
  String get eventsPostponeHelp;

  /// No description provided for @eventsPostponeTbdHelp.
  ///
  /// In fr, this message translates to:
  /// **'La nouvelle date sera annoncée plus tard.'**
  String get eventsPostponeTbdHelp;

  /// No description provided for @eventsNewStart.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau début'**
  String get eventsNewStart;

  /// No description provided for @eventsNewEnd.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle fin'**
  String get eventsNewEnd;

  /// No description provided for @eventsReasonOptional.
  ///
  /// In fr, this message translates to:
  /// **'Motif (facultatif)'**
  String get eventsReasonOptional;

  /// No description provided for @eventsPostpone.
  ///
  /// In fr, this message translates to:
  /// **'Reporter'**
  String get eventsPostpone;

  /// No description provided for @eventsCancelConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'événement ?'**
  String get eventsCancelConfirmTitle;

  /// No description provided for @eventsCancelConfirmText.
  ///
  /// In fr, this message translates to:
  /// **'La page reste visible avec la mention « Annulé ». Les personnes qui participent sont prévenues.'**
  String get eventsCancelConfirmText;

  /// No description provided for @eventsCancelEvent.
  ///
  /// In fr, this message translates to:
  /// **'Annuler l\'événement'**
  String get eventsCancelEvent;

  /// No description provided for @eventsReportChooseReason.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la raison du signalement.'**
  String get eventsReportChooseReason;

  /// No description provided for @eventsReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler l\'événement'**
  String get eventsReportTitle;

  /// No description provided for @eventsReportHelp.
  ///
  /// In fr, this message translates to:
  /// **'Votre signalement est anonyme pour l\'organisateur et examiné par la modération.'**
  String get eventsReportHelp;

  /// No description provided for @eventsCommentOptional.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (facultatif)'**
  String get eventsCommentOptional;

  /// No description provided for @eventsReportSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get eventsReportSend;

  /// No description provided for @eventsSurveyTellUs.
  ///
  /// In fr, this message translates to:
  /// **'Dites-nous si l\'événement a eu lieu.'**
  String get eventsSurveyTellUs;

  /// No description provided for @eventsSurveyGiveRating.
  ///
  /// In fr, this message translates to:
  /// **'Donnez une note de 1 à 5.'**
  String get eventsSurveyGiveRating;

  /// No description provided for @eventsSurveyThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre avis !'**
  String get eventsSurveyThanks;

  /// No description provided for @eventsSurveyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis'**
  String get eventsSurveyTitle;

  /// No description provided for @eventsSurveyNoReviews.
  ///
  /// In fr, this message translates to:
  /// **'Aucun avis pour le moment.'**
  String get eventsSurveyNoReviews;

  /// No description provided for @eventsSurveyManagersExcluded.
  ///
  /// In fr, this message translates to:
  /// **'Les organisateurs et gestionnaires ne répondent pas au sondage de leur propre événement.'**
  String get eventsSurveyManagersExcluded;

  /// No description provided for @eventsSurveyQuestion.
  ///
  /// In fr, this message translates to:
  /// **'L\'événement a-t-il eu lieu ?'**
  String get eventsSurveyQuestion;

  /// No description provided for @eventsSurveyYourRating.
  ///
  /// In fr, this message translates to:
  /// **'Votre note'**
  String get eventsSurveyYourRating;

  /// No description provided for @eventsSurveyBodyOptional.
  ///
  /// In fr, this message translates to:
  /// **'Votre avis (facultatif)'**
  String get eventsSurveyBodyOptional;

  /// No description provided for @eventsSurveySend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer mon avis'**
  String get eventsSurveySend;

  /// No description provided for @eventsSurveyYourAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Votre réponse : {answer}'**
  String eventsSurveyYourAnswer(String answer);

  /// No description provided for @eventsSurveyEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier mon avis'**
  String get eventsSurveyEdit;

  /// No description provided for @eventsSurveyEditableUntil.
  ///
  /// In fr, this message translates to:
  /// **'Modifiable jusqu\'au {date}.'**
  String eventsSurveyEditableUntil(String date);

  /// No description provided for @eventsSurveyLoginToReview.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter pour donner son avis'**
  String get eventsSurveyLoginToReview;

  /// No description provided for @eventsRatingOutOf5.
  ///
  /// In fr, this message translates to:
  /// **'{rating} sur 5'**
  String eventsRatingOutOf5(int rating);

  /// No description provided for @eventsModHidden.
  ///
  /// In fr, this message translates to:
  /// **'Événement masqué.'**
  String get eventsModHidden;

  /// No description provided for @eventsModRestored.
  ///
  /// In fr, this message translates to:
  /// **'Événement rétabli.'**
  String get eventsModRestored;

  /// No description provided for @eventsModDismissed.
  ///
  /// In fr, this message translates to:
  /// **'Signalements classés.'**
  String get eventsModDismissed;

  /// No description provided for @eventsModeration.
  ///
  /// In fr, this message translates to:
  /// **'Modération'**
  String get eventsModeration;

  /// No description provided for @eventsModReportCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 signalement} =1{1 signalement} other{{count} signalements}}'**
  String eventsModReportCount(int count);

  /// No description provided for @eventsModPending.
  ///
  /// In fr, this message translates to:
  /// **'{count} à traiter'**
  String eventsModPending(int count);

  /// No description provided for @eventsModReliability.
  ///
  /// In fr, this message translates to:
  /// **'Fiabilité de l\'organisateur ({events})'**
  String eventsModReliability(String events);

  /// No description provided for @eventsModEventCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 événement} =1{1 événement} other{{count} événements}}'**
  String eventsModEventCount(int count);

  /// No description provided for @eventsModConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Confirmés'**
  String get eventsModConfirmed;

  /// No description provided for @eventsModUnconfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Non confirmés'**
  String get eventsModUnconfirmed;

  /// No description provided for @eventsModReported.
  ///
  /// In fr, this message translates to:
  /// **'Signalés'**
  String get eventsModReported;

  /// No description provided for @eventsModRestore.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir'**
  String get eventsModRestore;

  /// No description provided for @eventsModHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get eventsModHide;

  /// No description provided for @eventsModDismiss.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter les signalements'**
  String get eventsModDismiss;

  /// No description provided for @eventsFormMaxImages.
  ///
  /// In fr, this message translates to:
  /// **'Six images au plus.'**
  String get eventsFormMaxImages;

  /// No description provided for @eventsFormDatesRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez les dates de début et de fin.'**
  String get eventsFormDatesRequired;

  /// No description provided for @eventsFormUploadingImages.
  ///
  /// In fr, this message translates to:
  /// **'Envoi des images {current}/{total}…'**
  String eventsFormUploadingImages(int current, int total);

  /// No description provided for @eventsFormImagesFailed.
  ///
  /// In fr, this message translates to:
  /// **'Événement enregistré, mais {count} image(s) n\'ont pas pu être envoyées.'**
  String eventsFormImagesFailed(int count);

  /// No description provided for @eventsFormUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Événement mis à jour.'**
  String get eventsFormUpdated;

  /// No description provided for @eventsFormCreated.
  ///
  /// In fr, this message translates to:
  /// **'Événement créé !'**
  String get eventsFormCreated;

  /// No description provided for @eventsFormEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'événement'**
  String get eventsFormEditTitle;

  /// No description provided for @eventsFormNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel événement'**
  String get eventsFormNewTitle;

  /// No description provided for @eventsFormSaving.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get eventsFormSaving;

  /// No description provided for @eventsFormSaveChanges.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer les modifications'**
  String get eventsFormSaveChanges;

  /// No description provided for @eventsFormSaveDraft.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le brouillon'**
  String get eventsFormSaveDraft;

  /// No description provided for @eventsFormPublish.
  ///
  /// In fr, this message translates to:
  /// **'Publier l\'événement'**
  String get eventsFormPublish;

  /// No description provided for @eventsFormCoverImages.
  ///
  /// In fr, this message translates to:
  /// **'Images de couverture'**
  String get eventsFormCoverImages;

  /// No description provided for @eventsFormCoverImagesHelp.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'à 6 images, affichées en carrousel. La première sert de vignette.'**
  String get eventsFormCoverImagesHelp;

  /// No description provided for @eventsFormInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get eventsFormInfo;

  /// No description provided for @eventsFormTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre *'**
  String get eventsFormTitleLabel;

  /// No description provided for @eventsFormTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Croisade de guérison 2026'**
  String get eventsFormTitleHint;

  /// No description provided for @eventsFormTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un titre à l\'événement.'**
  String get eventsFormTitleRequired;

  /// No description provided for @eventsFormTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type d\'événement *'**
  String get eventsFormTypeLabel;

  /// No description provided for @eventsFormDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get eventsFormDescription;

  /// No description provided for @eventsFormDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Programme, thème, public attendu, informations pratiques…'**
  String get eventsFormDescriptionHint;

  /// No description provided for @eventsFormDates.
  ///
  /// In fr, this message translates to:
  /// **'Dates'**
  String get eventsFormDates;

  /// No description provided for @eventsFormStart.
  ///
  /// In fr, this message translates to:
  /// **'Début *'**
  String get eventsFormStart;

  /// No description provided for @eventsFormEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin *'**
  String get eventsFormEnd;

  /// No description provided for @eventsFormPlaceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Stade de l\'Amitié, église…'**
  String get eventsFormPlaceHint;

  /// No description provided for @eventsFormAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse'**
  String get eventsFormAddress;

  /// No description provided for @eventsFormAddressHint.
  ///
  /// In fr, this message translates to:
  /// **'Rue, quartier, point de repère…'**
  String get eventsFormAddressHint;

  /// No description provided for @eventsFormCity.
  ///
  /// In fr, this message translates to:
  /// **'Ville'**
  String get eventsFormCity;

  /// No description provided for @eventsFormCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get eventsFormCountry;

  /// No description provided for @eventsFormMapPosition.
  ///
  /// In fr, this message translates to:
  /// **'Position sur la carte'**
  String get eventsFormMapPosition;

  /// No description provided for @eventsFormMapPositionHelp.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif : touchez la carte pour placer le repère du lieu. Les participants pourront lancer l\'itinéraire.'**
  String get eventsFormMapPositionHelp;

  /// No description provided for @eventsFormGuests.
  ///
  /// In fr, this message translates to:
  /// **'Invités principaux'**
  String get eventsFormGuests;

  /// No description provided for @eventsFormGuestsHelp.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif : orateurs, chantres, groupes…'**
  String get eventsFormGuestsHelp;

  /// No description provided for @eventsFormAddGuest.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un invité'**
  String get eventsFormAddGuest;

  /// No description provided for @eventsFormPublication.
  ///
  /// In fr, this message translates to:
  /// **'Publication'**
  String get eventsFormPublication;

  /// No description provided for @eventsFormDraftHelp.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon : visible de vous seul, à publier plus tard.'**
  String get eventsFormDraftHelp;

  /// No description provided for @eventsFormPublishedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Visible de tous : chacun peut répondre « Je participe ».'**
  String get eventsFormPublishedHelp;

  /// No description provided for @eventsFormCancelledHelp.
  ///
  /// In fr, this message translates to:
  /// **'Reste visible avec la mention « Annulé » ; plus de participation.'**
  String get eventsFormCancelledHelp;

  /// No description provided for @eventsFormPostponedHelp.
  ///
  /// In fr, this message translates to:
  /// **'Reporté, date à confirmer : modifiez les dates pour le reprogrammer.'**
  String get eventsFormPostponedHelp;

  /// No description provided for @eventsFormCommentsOpen.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires ouverts'**
  String get eventsFormCommentsOpen;

  /// No description provided for @eventsFormCommentsOpenHelp.
  ///
  /// In fr, this message translates to:
  /// **'Les participants partagent ce qu\'ils ont vécu.'**
  String get eventsFormCommentsOpenHelp;

  /// No description provided for @eventsFormPickDateTime.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date et l\'heure'**
  String get eventsFormPickDateTime;

  /// No description provided for @eventsFormGuestName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get eventsFormGuestName;

  /// No description provided for @eventsFormGuestRole.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get eventsFormGuestRole;

  /// No description provided for @eventsFormGuestRoleHint.
  ///
  /// In fr, this message translates to:
  /// **'Orateur…'**
  String get eventsFormGuestRoleHint;

  /// No description provided for @eventsFormRemoveGuest.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'invité'**
  String get eventsFormRemoveGuest;

  /// No description provided for @eventsFormOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get eventsFormOptions;

  /// No description provided for @eventsFormMakeFirst.
  ///
  /// In fr, this message translates to:
  /// **'Mettre en premier'**
  String get eventsFormMakeFirst;

  /// No description provided for @eventsFormThumbnail.
  ///
  /// In fr, this message translates to:
  /// **'Vignette'**
  String get eventsFormThumbnail;

  /// No description provided for @eventsFormOnBehalfOf.
  ///
  /// In fr, this message translates to:
  /// **'Au nom de qui créer l\'événement ?'**
  String get eventsFormOnBehalfOf;

  /// No description provided for @eventsFormPublishedAs.
  ///
  /// In fr, this message translates to:
  /// **'L\'événement sera publié au nom de ce compte.'**
  String get eventsFormPublishedAs;

  /// No description provided for @exploreTypeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get exploreTypeAll;

  /// No description provided for @exploreTypeText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get exploreTypeText;

  /// No description provided for @exploreTypeAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get exploreTypeAudio;

  /// No description provided for @exploreTypeVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get exploreTypeVideo;

  /// No description provided for @exploreTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get exploreTabAll;

  /// No description provided for @exploreTabTexts.
  ///
  /// In fr, this message translates to:
  /// **'Textes'**
  String get exploreTabTexts;

  /// No description provided for @exploreTabAudios.
  ///
  /// In fr, this message translates to:
  /// **'Audios'**
  String get exploreTabAudios;

  /// No description provided for @exploreTabVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get exploreTabVideos;

  /// No description provided for @exploreTypeAllTypes.
  ///
  /// In fr, this message translates to:
  /// **'Tous les types'**
  String get exploreTypeAllTypes;

  /// No description provided for @exploreSortRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récent'**
  String get exploreSortRecent;

  /// No description provided for @exploreSortPopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaire'**
  String get exploreSortPopular;

  /// No description provided for @exploreSortLiked.
  ///
  /// In fr, this message translates to:
  /// **'Plus aimés'**
  String get exploreSortLiked;

  /// No description provided for @exploreSortRecommended.
  ///
  /// In fr, this message translates to:
  /// **'Recommandé'**
  String get exploreSortRecommended;

  /// No description provided for @exploreSortNewest.
  ///
  /// In fr, this message translates to:
  /// **'Plus récents'**
  String get exploreSortNewest;

  /// No description provided for @exploreSortMostViewed.
  ///
  /// In fr, this message translates to:
  /// **'Plus vus'**
  String get exploreSortMostViewed;

  /// No description provided for @exploreSortMostPrayed.
  ///
  /// In fr, this message translates to:
  /// **'Plus priés'**
  String get exploreSortMostPrayed;

  /// No description provided for @exploreSearchFiltersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recherche & filtres'**
  String get exploreSearchFiltersTitle;

  /// No description provided for @exploreTestimonyCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 témoignage} =1{1 témoignage} other{{count} témoignages}}'**
  String exploreTestimonyCount(int count);

  /// No description provided for @exploreCategoryTestimonyCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 témoignage} other{{count} témoignages}}'**
  String exploreCategoryTestimonyCount(int count);

  /// No description provided for @exploreCategoriesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Parcourez par thème'**
  String get exploreCategoriesSubtitle;

  /// No description provided for @exploreTrendingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les plus consultés en ce moment'**
  String get exploreTrendingSubtitle;

  /// No description provided for @exploreMostPrayedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages qui touchent le cœur'**
  String get exploreMostPrayedSubtitle;

  /// No description provided for @exploreRecentSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Derniers témoignages publiés'**
  String get exploreRecentSubtitle;

  /// No description provided for @exploreStatViews.
  ///
  /// In fr, this message translates to:
  /// **'vues'**
  String get exploreStatViews;

  /// No description provided for @exploreStatPrayers.
  ///
  /// In fr, this message translates to:
  /// **'prières'**
  String get exploreStatPrayers;

  /// No description provided for @exploreNoTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage'**
  String get exploreNoTestimony;

  /// No description provided for @exploreNoTestimonyFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage trouvé'**
  String get exploreNoTestimonyFound;

  /// No description provided for @exploreNoTestimonyFoundHint.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre mot-clé ou\nparcourez les rubriques.'**
  String get exploreNoTestimonyFoundHint;

  /// No description provided for @exploreSortTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Trier : {sort}'**
  String exploreSortTooltip(String sort);

  /// No description provided for @exploreSortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get exploreSortBy;

  /// No description provided for @exploreCategoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage pour l\'instant'**
  String get exploreCategoryEmpty;

  /// No description provided for @exploreCategoryEmptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à partager\ndans cette rubrique.'**
  String get exploreCategoryEmptyHint;

  /// No description provided for @exploreTrendingCategories.
  ///
  /// In fr, this message translates to:
  /// **'Catégories tendance'**
  String get exploreTrendingCategories;

  /// No description provided for @exploreFilters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get exploreFilters;

  /// No description provided for @exploreFilterType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get exploreFilterType;

  /// No description provided for @exploreFilterCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get exploreFilterCategory;

  /// No description provided for @exploreFilterAllCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les catégories'**
  String get exploreFilterAllCategories;

  /// No description provided for @exploreFilterPopularity.
  ///
  /// In fr, this message translates to:
  /// **'Popularité'**
  String get exploreFilterPopularity;

  /// No description provided for @exploreApplyFilters.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer les filtres'**
  String get exploreApplyFilters;

  /// No description provided for @exploreMicUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Microphone non disponible'**
  String get exploreMicUnavailable;

  /// No description provided for @exploreSearchHintDots.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un témoignage...'**
  String get exploreSearchHintDots;

  /// No description provided for @exploreClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get exploreClear;

  /// No description provided for @exploreSpeakNow.
  ///
  /// In fr, this message translates to:
  /// **'Parlez maintenant…'**
  String get exploreSpeakNow;

  /// No description provided for @locationNoZone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune zone connue : vos fils restent classés selon vos goûts.'**
  String get locationNoZone;

  /// No description provided for @locationSourceGps.
  ///
  /// In fr, this message translates to:
  /// **'position de l’appareil'**
  String get locationSourceGps;

  /// No description provided for @locationSourceProfile.
  ///
  /// In fr, this message translates to:
  /// **'ville et pays du profil'**
  String get locationSourceProfile;

  /// No description provided for @locationSourcePhone.
  ///
  /// In fr, this message translates to:
  /// **'indicatif du téléphone'**
  String get locationSourcePhone;

  /// No description provided for @locationSourceLanguage.
  ///
  /// In fr, this message translates to:
  /// **'langue de l’appareil'**
  String get locationSourceLanguage;

  /// No description provided for @locationSourceDefault.
  ///
  /// In fr, this message translates to:
  /// **'profil'**
  String get locationSourceDefault;

  /// No description provided for @locationDeniedCity.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la position refusé. Autorisez-le dans les réglages de l\'application, ou indiquez votre ville.'**
  String get locationDeniedCity;

  /// No description provided for @locationUnavailableCity.
  ///
  /// In fr, this message translates to:
  /// **'Position indisponible pour le moment. Réessayez, ou indiquez votre ville.'**
  String get locationUnavailableCity;

  /// No description provided for @locationOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get locationOpenSettings;

  /// No description provided for @locationActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible pour le moment. Réessayez.'**
  String get locationActionFailed;

  /// No description provided for @locationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get locationTitle;

  /// No description provided for @locationSaved.
  ///
  /// In fr, this message translates to:
  /// **'Position enregistrée.'**
  String get locationSaved;

  /// No description provided for @locationCleared.
  ///
  /// In fr, this message translates to:
  /// **'Position effacée.'**
  String get locationCleared;

  /// No description provided for @locationUseGpsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ma position pour personnaliser mes fils'**
  String get locationUseGpsTitle;

  /// No description provided for @locationUseGpsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les témoignages, prières et événements proches de vous d’abord. Position arrondie (environ 1 km), jamais montrée aux autres.'**
  String get locationUseGpsSubtitle;

  /// No description provided for @locationUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Position mise à jour.'**
  String get locationUpdated;

  /// No description provided for @locationUpdate.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour ma position'**
  String get locationUpdate;

  /// No description provided for @locationHomeCityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ma ville (sans position)'**
  String get locationHomeCityTitle;

  /// No description provided for @locationHomeCityHelp.
  ///
  /// In fr, this message translates to:
  /// **'Utilisée quand la position est désactivée ; le pays est celui de votre profil.'**
  String get locationHomeCityHelp;

  /// No description provided for @locationHomeCityHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Cotonou'**
  String get locationHomeCityHint;

  /// No description provided for @locationCitySaved.
  ///
  /// In fr, this message translates to:
  /// **'Ville enregistrée.'**
  String get locationCitySaved;

  /// No description provided for @locationErased.
  ///
  /// In fr, this message translates to:
  /// **'Votre position a été supprimée.'**
  String get locationErased;

  /// No description provided for @locationErase.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ma position'**
  String get locationErase;

  /// No description provided for @locationNearbySemantics.
  ///
  /// In fr, this message translates to:
  /// **'Près de chez vous : {place}. Réglage de localisation'**
  String locationNearbySemantics(String place);

  /// No description provided for @locationNearbyChip.
  ///
  /// In fr, this message translates to:
  /// **'Près de chez vous · {place}'**
  String locationNearbyChip(String place);

  /// No description provided for @locationPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Activez votre position pour des témoignages proches de vous'**
  String get locationPrompt;

  /// No description provided for @locationEnable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get locationEnable;

  /// No description provided for @eventsPostponedNotified.
  ///
  /// In fr, this message translates to:
  /// **'Événement reporté. Les participants sont prévenus.'**
  String get eventsPostponedNotified;

  /// No description provided for @eventsCancelledNotified.
  ///
  /// In fr, this message translates to:
  /// **'Événement annulé. Les participants sont prévenus.'**
  String get eventsCancelledNotified;

  /// No description provided for @eventsAlreadyReportedThanks.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà signalé cet événement. Merci.'**
  String get eventsAlreadyReportedThanks;

  /// No description provided for @eventsReasonParticipate.
  ///
  /// In fr, this message translates to:
  /// **'indiquer votre participation'**
  String get eventsReasonParticipate;

  /// No description provided for @eventsReasonReport.
  ///
  /// In fr, this message translates to:
  /// **'signaler un événement'**
  String get eventsReasonReport;

  /// No description provided for @eventsReasonSurvey.
  ///
  /// In fr, this message translates to:
  /// **'donner votre avis'**
  String get eventsReasonSurvey;

  /// No description provided for @eventsReasonComment.
  ///
  /// In fr, this message translates to:
  /// **'partager ce que vous avez vécu'**
  String get eventsReasonComment;

  /// No description provided for @eventsDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'événement ?'**
  String get eventsDeleteConfirmTitle;

  /// No description provided for @eventsDeleteConfirmText.
  ///
  /// In fr, this message translates to:
  /// **'La page, les images, les réponses et les commentaires seront supprimés. Les témoignages déjà enregistrés restent publiés.'**
  String get eventsDeleteConfirmText;

  /// No description provided for @eventsDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Événement supprimé.'**
  String get eventsDeleted;

  /// No description provided for @eventsDetailLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l\'événement.'**
  String get eventsDetailLoadError;

  /// No description provided for @eventsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos de l\'événement'**
  String get eventsAbout;

  /// No description provided for @eventsTellExperience.
  ///
  /// In fr, this message translates to:
  /// **'Raconter ce que j\'ai vécu'**
  String get eventsTellExperience;

  /// No description provided for @eventsMoreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d\'options'**
  String get eventsMoreOptions;

  /// No description provided for @eventsAlreadyReported.
  ///
  /// In fr, this message translates to:
  /// **'Déjà signalé'**
  String get eventsAlreadyReported;

  /// No description provided for @eventsDateRangeDays.
  ///
  /// In fr, this message translates to:
  /// **'Du {start} au {end}'**
  String eventsDateRangeDays(String start, String end);

  /// No description provided for @eventsReliableOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur fiable'**
  String get eventsReliableOrganizer;

  /// No description provided for @eventsVerifiedOrganization.
  ///
  /// In fr, this message translates to:
  /// **'Organisation vérifiée'**
  String get eventsVerifiedOrganization;

  /// No description provided for @eventsLiveOnAir.
  ///
  /// In fr, this message translates to:
  /// **'L\'événement est en direct'**
  String get eventsLiveOnAir;

  /// No description provided for @eventsLivePreparing.
  ///
  /// In fr, this message translates to:
  /// **'Direct en préparation'**
  String get eventsLivePreparing;

  /// No description provided for @eventsOpenStudio.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le studio'**
  String get eventsOpenStudio;

  /// No description provided for @eventsJoinBroadcast.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez la diffusion maintenant'**
  String get eventsJoinBroadcast;

  /// No description provided for @eventsLivePrivateUntilOnAir.
  ///
  /// In fr, this message translates to:
  /// **'Visible de vous seul jusqu\'au passage à l\'antenne'**
  String get eventsLivePrivateUntilOnAir;

  /// No description provided for @eventsIsCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement est annulé'**
  String get eventsIsCancelled;

  /// No description provided for @eventsIsOver.
  ///
  /// In fr, this message translates to:
  /// **'Cet événement est terminé'**
  String get eventsIsOver;

  /// No description provided for @eventsYouAreGoing.
  ///
  /// In fr, this message translates to:
  /// **'Vous participez à cet événement 🙌'**
  String get eventsYouAreGoing;

  /// No description provided for @eventsYouAreNotGoing.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne participez pas'**
  String get eventsYouAreNotGoing;

  /// No description provided for @eventsAreYouGoing.
  ///
  /// In fr, this message translates to:
  /// **'Allez-vous participer ?'**
  String get eventsAreYouGoing;

  /// No description provided for @eventsBeFirstToAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à répondre.'**
  String get eventsBeFirstToAnswer;

  /// No description provided for @eventsGoingCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 personne participe} other{{count} personnes participent}}'**
  String eventsGoingCount(int count);

  /// No description provided for @eventsGoing.
  ///
  /// In fr, this message translates to:
  /// **'Je participe'**
  String get eventsGoing;

  /// No description provided for @eventsNotGoing.
  ///
  /// In fr, this message translates to:
  /// **'Je ne participe pas'**
  String get eventsNotGoing;

  /// No description provided for @eventsTapAgainToRemove.
  ///
  /// In fr, this message translates to:
  /// **'Touchez de nouveau votre réponse pour la retirer.'**
  String get eventsTapAgainToRemove;

  /// No description provided for @eventsParticipantsCount.
  ///
  /// In fr, this message translates to:
  /// **'Participants ({count})'**
  String eventsParticipantsCount(int count);

  /// No description provided for @eventsManageDraft.
  ///
  /// In fr, this message translates to:
  /// **'Gestion · brouillon (invisible du public)'**
  String get eventsManageDraft;

  /// No description provided for @eventsManagePage.
  ///
  /// In fr, this message translates to:
  /// **'Gestion de la page'**
  String get eventsManagePage;

  /// No description provided for @eventsManageHelp.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez un commentaire comme témoignage avec « Enregistrer comme témoignage » dans l\'onglet Commentaires.'**
  String get eventsManageHelp;

  /// No description provided for @eventsNoParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'a encore répondu « Je participe ».'**
  String get eventsNoParticipants;

  /// No description provided for @eventsRespondedOn.
  ///
  /// In fr, this message translates to:
  /// **'Réponse le {date}'**
  String eventsRespondedOn(String date);

  /// No description provided for @eventsReadMore.
  ///
  /// In fr, this message translates to:
  /// **'Lire la suite'**
  String get eventsReadMore;

  /// No description provided for @eventsTabTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages ({count})'**
  String eventsTabTestimonies(int count);

  /// No description provided for @eventsTabComments.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires ({count})'**
  String eventsTabComments(int count);

  /// No description provided for @eventsNoTestimoniesManager.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage enregistré. Publiez-en un, ou enregistrez un commentaire de participant.'**
  String get eventsNoTestimoniesManager;

  /// No description provided for @eventsNoTestimoniesPublic.
  ///
  /// In fr, this message translates to:
  /// **'Les témoignages de cet événement seront publiés ici par les organisateurs.'**
  String get eventsNoTestimoniesPublic;

  /// No description provided for @eventsTestimoniesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les témoignages.'**
  String get eventsTestimoniesLoadError;

  /// No description provided for @eventsCommentPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Racontez ce que Dieu a fait pour vous…'**
  String get eventsCommentPrompt;

  /// No description provided for @eventsCommentsClosed.
  ///
  /// In fr, this message translates to:
  /// **'Les commentaires sont fermés pour cet événement.'**
  String get eventsCommentsClosed;

  /// No description provided for @eventsNoComments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire pour le moment. Partagez le premier témoignage !'**
  String get eventsNoComments;

  /// No description provided for @eventsMoreComments.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus de commentaires'**
  String get eventsMoreComments;

  /// No description provided for @eventsCommentsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les commentaires.'**
  String get eventsCommentsLoadError;

  /// No description provided for @eventsCommentThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre témoignage !'**
  String get eventsCommentThanks;

  /// No description provided for @eventsComposerHelp.
  ///
  /// In fr, this message translates to:
  /// **'Racontez ce que vous avez vécu pendant l\'événement. Les organisateurs pourront l\'enregistrer comme témoignage officiel.'**
  String get eventsComposerHelp;

  /// No description provided for @eventsComposerHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : pendant la prière, j\'ai été guéri… (@ pour mentionner)'**
  String get eventsComposerHint;

  /// No description provided for @eventsDeleteCommentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce commentaire ?'**
  String get eventsDeleteCommentTitle;

  /// No description provided for @eventsCommentDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire supprimé.'**
  String get eventsCommentDeleted;

  /// No description provided for @eventsSavedAsTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré comme témoignage'**
  String get eventsSavedAsTestimony;

  /// No description provided for @eventsSaveAsTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer comme témoignage'**
  String get eventsSaveAsTestimony;

  /// No description provided for @eventsPromoteHelp.
  ///
  /// In fr, this message translates to:
  /// **'Le témoignage de {name} sera publié sous son nom, rattaché à l\'événement.'**
  String eventsPromoteHelp(String name);

  /// No description provided for @eventsPromoteTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Guéri pendant la croisade'**
  String get eventsPromoteTitleHint;

  /// No description provided for @eventsAgoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count} min'**
  String eventsAgoMinutes(int count);

  /// No description provided for @eventsAgoHours.
  ///
  /// In fr, this message translates to:
  /// **'{count} h'**
  String eventsAgoHours(int count);

  /// No description provided for @eventsAgoDays.
  ///
  /// In fr, this message translates to:
  /// **'{count} j'**
  String eventsAgoDays(int count);

  /// No description provided for @eventsParticipantCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String eventsParticipantCount(int count);

  /// No description provided for @categoryHealing.
  ///
  /// In fr, this message translates to:
  /// **'Guérison'**
  String get categoryHealing;

  /// No description provided for @categoryDeliverance.
  ///
  /// In fr, this message translates to:
  /// **'Délivrance'**
  String get categoryDeliverance;

  /// No description provided for @categoryConversion.
  ///
  /// In fr, this message translates to:
  /// **'Conversion'**
  String get categoryConversion;

  /// No description provided for @categoryMarriage.
  ///
  /// In fr, this message translates to:
  /// **'Mariage'**
  String get categoryMarriage;

  /// No description provided for @categoryFamily.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get categoryFamily;

  /// No description provided for @categoryFinances.
  ///
  /// In fr, this message translates to:
  /// **'Finances'**
  String get categoryFinances;

  /// No description provided for @categoryMiracles.
  ///
  /// In fr, this message translates to:
  /// **'Miracles'**
  String get categoryMiracles;

  /// No description provided for @categoryProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection divine'**
  String get categoryProtection;

  /// No description provided for @categoryMinistry.
  ///
  /// In fr, this message translates to:
  /// **'Ministère'**
  String get categoryMinistry;

  /// No description provided for @categorySalvation.
  ///
  /// In fr, this message translates to:
  /// **'Salut'**
  String get categorySalvation;

  /// No description provided for @homeProofDefaultName.
  ///
  /// In fr, this message translates to:
  /// **'Preuve'**
  String get homeProofDefaultName;

  /// No description provided for @homeReactionLove.
  ///
  /// In fr, this message translates to:
  /// **'J\'adore Dieu'**
  String get homeReactionLove;

  /// No description provided for @homeReactionGlory.
  ///
  /// In fr, this message translates to:
  /// **'Gloire à Dieu !'**
  String get homeReactionGlory;

  /// No description provided for @homeReactionInspiring.
  ///
  /// In fr, this message translates to:
  /// **'Inspirant'**
  String get homeReactionInspiring;

  /// No description provided for @homeReactionPowerful.
  ///
  /// In fr, this message translates to:
  /// **'Puissant'**
  String get homeReactionPowerful;

  /// No description provided for @homeReactionTouched.
  ///
  /// In fr, this message translates to:
  /// **'Touché'**
  String get homeReactionTouched;

  /// No description provided for @homeSortForYou.
  ///
  /// In fr, this message translates to:
  /// **'Pour vous'**
  String get homeSortForYou;

  /// No description provided for @homeSortRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get homeSortRecent;

  /// No description provided for @homeSortPopular.
  ///
  /// In fr, this message translates to:
  /// **'Populaires'**
  String get homeSortPopular;

  /// No description provided for @homeSortMostViewed.
  ///
  /// In fr, this message translates to:
  /// **'Plus vus'**
  String get homeSortMostViewed;

  /// No description provided for @homeMenu.
  ///
  /// In fr, this message translates to:
  /// **'Menu'**
  String get homeMenu;

  /// No description provided for @homeNotificationsUnread.
  ///
  /// In fr, this message translates to:
  /// **'Notifications ({count} non lues)'**
  String homeNotificationsUnread(int count);

  /// No description provided for @homeReasonNotifications.
  ///
  /// In fr, this message translates to:
  /// **'recevoir vos notifications'**
  String get homeReasonNotifications;

  /// No description provided for @homeLayoutTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Affichage : {label}'**
  String homeLayoutTooltip(String label);

  /// No description provided for @homeLayoutSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Affichage {label}'**
  String homeLayoutSemantics(String label);

  /// No description provided for @homeLayoutCards.
  ///
  /// In fr, this message translates to:
  /// **'Cartes'**
  String get homeLayoutCards;

  /// No description provided for @homeLayoutList.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get homeLayoutList;

  /// No description provided for @homeEmptyFilter.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage pour ce filtre'**
  String get homeEmptyFilter;

  /// No description provided for @homeBibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bible'**
  String get homeBibleTitle;

  /// No description provided for @homeBibleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger et lire hors connexion'**
  String get homeBibleSubtitle;

  /// No description provided for @homeFeaturedTab.
  ///
  /// In fr, this message translates to:
  /// **'À la une'**
  String get homeFeaturedTab;

  /// No description provided for @homeMostPrayed.
  ///
  /// In fr, this message translates to:
  /// **'Plus priés'**
  String get homeMostPrayed;

  /// No description provided for @homeTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get homeTabAll;

  /// No description provided for @homeTabVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get homeTabVideos;

  /// No description provided for @homeTabAudios.
  ///
  /// In fr, this message translates to:
  /// **'Audios'**
  String get homeTabAudios;

  /// No description provided for @homeTabTexts.
  ///
  /// In fr, this message translates to:
  /// **'Textes'**
  String get homeTabTexts;

  /// No description provided for @homeEmptyFeatured.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage à la une'**
  String get homeEmptyFeatured;

  /// No description provided for @homeEmptyTrending.
  ///
  /// In fr, this message translates to:
  /// **'Aucune tendance disponible'**
  String get homeEmptyTrending;

  /// No description provided for @homeEmptyRecent.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage récent'**
  String get homeEmptyRecent;

  /// No description provided for @homeEmptyPrayed.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage prié'**
  String get homeEmptyPrayed;

  /// No description provided for @homeEmptyVideos.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vidéo disponible'**
  String get homeEmptyVideos;

  /// No description provided for @homeEmptyAudios.
  ///
  /// In fr, this message translates to:
  /// **'Aucun audio disponible'**
  String get homeEmptyAudios;

  /// No description provided for @homeEmptyTexts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte disponible'**
  String get homeEmptyTexts;

  /// No description provided for @homeEmptyShorts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun short disponible'**
  String get homeEmptyShorts;

  /// No description provided for @homeCategoryAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get homeCategoryAll;

  /// No description provided for @homeReasonSave.
  ///
  /// In fr, this message translates to:
  /// **'enregistrer vos favoris'**
  String get homeReasonSave;

  /// No description provided for @homeReasonReact.
  ///
  /// In fr, this message translates to:
  /// **'réagir aux témoignages'**
  String get homeReasonReact;

  /// No description provided for @homeFilterApproved.
  ///
  /// In fr, this message translates to:
  /// **'Approuvés'**
  String get homeFilterApproved;

  /// No description provided for @homeFilterApprovedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Seulement les témoignages vérifiés par l\'équipe de modération'**
  String get homeFilterApprovedTooltip;

  /// No description provided for @homeSortTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Trier les témoignages'**
  String get homeSortTooltip;

  /// No description provided for @homeSortWithoutApproved.
  ///
  /// In fr, this message translates to:
  /// **'{sort} (sans « Approuvés »)'**
  String homeSortWithoutApproved(String sort);

  /// No description provided for @homeSortLabel.
  ///
  /// In fr, this message translates to:
  /// **'Tri : {sort}'**
  String homeSortLabel(String sort);

  /// No description provided for @homeStatsAndOthers.
  ///
  /// In fr, this message translates to:
  /// **'{total} · et {others} autres'**
  String homeStatsAndOthers(String total, String others);

  /// No description provided for @homeTypeText.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage écrit'**
  String get homeTypeText;

  /// No description provided for @homeCompactSemantics.
  ///
  /// In fr, this message translates to:
  /// **'{type} : {title}, par {author}. '**
  String homeCompactSemantics(String type, String title, String author);

  /// No description provided for @homeTapToCollapse.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour replier'**
  String get homeTapToCollapse;

  /// No description provided for @homeTapToExpand.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour déplier'**
  String get homeTapToExpand;

  /// No description provided for @homePlayVideo.
  ///
  /// In fr, this message translates to:
  /// **'Lire la vidéo'**
  String get homePlayVideo;

  /// No description provided for @homeListenAudio.
  ///
  /// In fr, this message translates to:
  /// **'Écouter l\'audio'**
  String get homeListenAudio;

  /// No description provided for @homeCollapse.
  ///
  /// In fr, this message translates to:
  /// **'Replier'**
  String get homeCollapse;

  /// No description provided for @homeExpand.
  ///
  /// In fr, this message translates to:
  /// **'Déplier'**
  String get homeExpand;

  /// No description provided for @homeViewTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Voir le témoignage'**
  String get homeViewTestimony;

  /// No description provided for @homeDaysAgoLong.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{il y a 1 jour} other{il y a {count} jours}}'**
  String homeDaysAgoLong(int count);

  /// No description provided for @homeVerseOfTheDayPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour · '**
  String get homeVerseOfTheDayPrefix;

  /// No description provided for @homeVerseExpand.
  ///
  /// In fr, this message translates to:
  /// **'Déplier le verset'**
  String get homeVerseExpand;

  /// No description provided for @homeVerseCollapse.
  ///
  /// In fr, this message translates to:
  /// **'Replier le verset'**
  String get homeVerseCollapse;

  /// No description provided for @homeVerseSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour, {reference}, {text}'**
  String homeVerseSemantics(String reference, String text);

  /// No description provided for @homeVerseOpenHint.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour ouvrir en plein écran'**
  String get homeVerseOpenHint;

  /// No description provided for @homeVerseOpenFullScreen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir en plein écran'**
  String get homeVerseOpenFullScreen;

  /// No description provided for @verseOfTheDay.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour'**
  String get verseOfTheDay;

  /// No description provided for @verseReadInFull.
  ///
  /// In fr, this message translates to:
  /// **'Lire en entier'**
  String get verseReadInFull;

  /// No description provided for @verseShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager le verset'**
  String get verseShare;

  /// No description provided for @homeUnsave.
  ///
  /// In fr, this message translates to:
  /// **'Enlever des sauvegardes'**
  String get homeUnsave;

  /// No description provided for @homeMoreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’options'**
  String get homeMoreOptions;

  /// No description provided for @prophecyDayAtTime.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String prophecyDayAtTime(String date, String time);

  /// No description provided for @prophecyToday.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui'**
  String get prophecyToday;

  /// No description provided for @prophecyYesterday.
  ///
  /// In fr, this message translates to:
  /// **'hier'**
  String get prophecyYesterday;

  /// No description provided for @prophecyOnDate.
  ///
  /// In fr, this message translates to:
  /// **'le {date}'**
  String prophecyOnDate(String date);

  /// No description provided for @prophecyStatusFulfilled.
  ///
  /// In fr, this message translates to:
  /// **'Accomplie'**
  String get prophecyStatusFulfilled;

  /// No description provided for @prophecyStatusOverdue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance passée'**
  String get prophecyStatusOverdue;

  /// No description provided for @prophecyStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get prophecyStatusPending;

  /// No description provided for @prophecyDueOn.
  ///
  /// In fr, this message translates to:
  /// **'Échéance : {date}'**
  String prophecyDueOn(String date);

  /// No description provided for @prophecyFulfilledOn.
  ///
  /// In fr, this message translates to:
  /// **'Accomplie le {date}'**
  String prophecyFulfilledOn(String date);

  /// No description provided for @prophecyPrayedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Pas encore priée} other{Priée {count} fois}}'**
  String prophecyPrayedCount(int count);

  /// No description provided for @prophecyAudioPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get prophecyAudioPause;

  /// No description provided for @prophecyAudioListen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get prophecyAudioListen;

  /// No description provided for @prophecyAudioUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Audio indisponible'**
  String get prophecyAudioUnavailable;

  /// No description provided for @prophecyDeleteRecording.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'enregistrement'**
  String get prophecyDeleteRecording;

  /// No description provided for @prophecyEveryDay.
  ///
  /// In fr, this message translates to:
  /// **'Chaque jour'**
  String get prophecyEveryDay;

  /// No description provided for @prophecyEveryWeek.
  ///
  /// In fr, this message translates to:
  /// **'Chaque semaine'**
  String get prophecyEveryWeek;

  /// No description provided for @prophecyMonday.
  ///
  /// In fr, this message translates to:
  /// **'lundi'**
  String get prophecyMonday;

  /// No description provided for @prophecyTuesday.
  ///
  /// In fr, this message translates to:
  /// **'mardi'**
  String get prophecyTuesday;

  /// No description provided for @prophecyWednesday.
  ///
  /// In fr, this message translates to:
  /// **'mercredi'**
  String get prophecyWednesday;

  /// No description provided for @prophecyThursday.
  ///
  /// In fr, this message translates to:
  /// **'jeudi'**
  String get prophecyThursday;

  /// No description provided for @prophecyFriday.
  ///
  /// In fr, this message translates to:
  /// **'vendredi'**
  String get prophecyFriday;

  /// No description provided for @prophecySaturday.
  ///
  /// In fr, this message translates to:
  /// **'samedi'**
  String get prophecySaturday;

  /// No description provided for @prophecySunday.
  ///
  /// In fr, this message translates to:
  /// **'dimanche'**
  String get prophecySunday;

  /// No description provided for @prophecyReminderDaily.
  ///
  /// In fr, this message translates to:
  /// **'Chaque jour à {time}'**
  String prophecyReminderDaily(String time);

  /// No description provided for @prophecyReminderWeekly.
  ///
  /// In fr, this message translates to:
  /// **'Chaque {day} à {time}'**
  String prophecyReminderWeekly(String day, String time);

  /// No description provided for @prophecyWordOf.
  ///
  /// In fr, this message translates to:
  /// **'Parole du {date}'**
  String prophecyWordOf(String date);

  /// No description provided for @prophecyNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre accès à Internet.'**
  String get prophecyNetworkError;

  /// No description provided for @prophecyReminderChannel.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de prière'**
  String get prophecyReminderChannel;

  /// No description provided for @prophecyReminderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Temps de prière'**
  String get prophecyReminderTitle;

  /// No description provided for @prophecyReminderBody.
  ///
  /// In fr, this message translates to:
  /// **'Priez pour la parole : « {title} »'**
  String prophecyReminderBody(String title);

  /// No description provided for @prophecyReminderChannelDesc.
  ///
  /// In fr, this message translates to:
  /// **'Rappels pour prier sur vos paroles prophétiques.'**
  String get prophecyReminderChannelDesc;

  /// No description provided for @prophecyReminderLabel.
  ///
  /// In fr, this message translates to:
  /// **'Rappel de prière'**
  String get prophecyReminderLabel;

  /// No description provided for @prophecyReminderSheetIntro.
  ///
  /// In fr, this message translates to:
  /// **'Une notification sur ce téléphone pour prier sur la parole, jusqu\'à son accomplissement.'**
  String get prophecyReminderSheetIntro;

  /// No description provided for @prophecyReminderNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get prophecyReminderNone;

  /// No description provided for @prophecyReminderTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get prophecyReminderTime;

  /// No description provided for @prophecyListTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paroles prophétiques'**
  String get prophecyListTitle;

  /// No description provided for @prophecyTabPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente ({count})'**
  String prophecyTabPending(int count);

  /// No description provided for @prophecyTabFulfilled.
  ///
  /// In fr, this message translates to:
  /// **'Accomplies ({count})'**
  String prophecyTabFulfilled(int count);

  /// No description provided for @prophecyNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle parole'**
  String get prophecyNew;

  /// No description provided for @prophecyLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos paroles.'**
  String get prophecyLoadError;

  /// No description provided for @prophecyPrivateNotice.
  ///
  /// In fr, this message translates to:
  /// **'Visibles de vous seul. Gardez-les, priez, puis témoignez de leur accomplissement.'**
  String get prophecyPrivateNotice;

  /// No description provided for @prophecyEmptyFulfilled.
  ///
  /// In fr, this message translates to:
  /// **'Aucune parole accomplie pour le moment. Quand une parole s\'accomplit, ouvrez-la et touchez « Elle s\'est accomplie ».'**
  String get prophecyEmptyFulfilled;

  /// No description provided for @prophecyEmptyPending.
  ///
  /// In fr, this message translates to:
  /// **'Une parole reçue lors d\'un culte, d\'une prière, d\'un rêve ? Notez-la ici (texte ou audio) pour la garder et prier dessus.'**
  String get prophecyEmptyPending;

  /// No description provided for @prophecyPrayerSaved.
  ///
  /// In fr, this message translates to:
  /// **'Prière enregistrée. Dieu veille sur sa parole pour l\'accomplir.'**
  String get prophecyPrayerSaved;

  /// No description provided for @prophecyReminderRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Rappel supprimé.'**
  String get prophecyReminderRemoved;

  /// No description provided for @prophecyReminderSet.
  ///
  /// In fr, this message translates to:
  /// **'Rappel : {label}.'**
  String prophecyReminderSet(String label);

  /// No description provided for @prophecyFulfilledSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Gloire à Dieu ! La parole s\'est accomplie'**
  String get prophecyFulfilledSheetTitle;

  /// No description provided for @prophecyTestify.
  ///
  /// In fr, this message translates to:
  /// **'Témoigner de son accomplissement'**
  String get prophecyTestify;

  /// No description provided for @prophecyTestifySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Publiez votre témoignage ; vous choisirez de montrer la parole avec lui.'**
  String get prophecyTestifySubtitle;

  /// No description provided for @prophecyMarkFulfilledOnly.
  ///
  /// In fr, this message translates to:
  /// **'Marquer accomplie, sans témoigner pour l\'instant'**
  String get prophecyMarkFulfilledOnly;

  /// No description provided for @prophecyMarkedFulfilled.
  ///
  /// In fr, this message translates to:
  /// **'Parole marquée comme accomplie.'**
  String get prophecyMarkedFulfilled;

  /// No description provided for @prophecyDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette parole ?'**
  String get prophecyDeleteTitle;

  /// No description provided for @prophecyDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'La parole et son journal de prière seront supprimés. Un témoignage déjà publié reste publié.'**
  String get prophecyDeleteBody;

  /// No description provided for @prophecyDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Parole supprimée.'**
  String get prophecyDeleted;

  /// No description provided for @prophecyDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parole prophétique'**
  String get prophecyDetailTitle;

  /// No description provided for @prophecyOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get prophecyOptions;

  /// No description provided for @prophecyBackToPending.
  ///
  /// In fr, this message translates to:
  /// **'Parole remise en attente.'**
  String get prophecyBackToPending;

  /// No description provided for @prophecyMarkPending.
  ///
  /// In fr, this message translates to:
  /// **'Remettre en attente'**
  String get prophecyMarkPending;

  /// No description provided for @prophecyNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Parole introuvable.'**
  String get prophecyNotFound;

  /// No description provided for @prophecyReceivedOn.
  ///
  /// In fr, this message translates to:
  /// **'Reçue le {date}'**
  String prophecyReceivedOn(String date);

  /// No description provided for @prophecyGivenByCap.
  ///
  /// In fr, this message translates to:
  /// **'Donnée par {name}'**
  String prophecyGivenByCap(String name);

  /// No description provided for @prophecyIPrayed.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié'**
  String get prophecyIPrayed;

  /// No description provided for @prophecyProclaim.
  ///
  /// In fr, this message translates to:
  /// **'Proclamer'**
  String get prophecyProclaim;

  /// No description provided for @prophecyItIsFulfilled.
  ///
  /// In fr, this message translates to:
  /// **'Elle s\'est accomplie'**
  String get prophecyItIsFulfilled;

  /// No description provided for @prophecyViewMyTestimonyPublic.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon témoignage (parole publiée)'**
  String get prophecyViewMyTestimonyPublic;

  /// No description provided for @prophecyViewMyTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon témoignage'**
  String get prophecyViewMyTestimony;

  /// No description provided for @prophecyNoReminder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rappel de prière'**
  String get prophecyNoReminder;

  /// No description provided for @prophecyNotificationOnPhone.
  ///
  /// In fr, this message translates to:
  /// **'Notification sur ce téléphone'**
  String get prophecyNotificationOnPhone;

  /// No description provided for @prophecyPrayerJournal.
  ///
  /// In fr, this message translates to:
  /// **'Journal de prière'**
  String get prophecyPrayerJournal;

  /// No description provided for @prophecyNoPrayerYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de prière enregistrée.'**
  String get prophecyNoPrayerYet;

  /// No description provided for @prophecyLastPrayed.
  ///
  /// In fr, this message translates to:
  /// **' · dernière fois {when}'**
  String prophecyLastPrayed(String when);

  /// No description provided for @prophecyPrayerRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Prière retirée du journal.'**
  String get prophecyPrayerRemoved;

  /// No description provided for @prophecyRemoveFromJournal.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du journal'**
  String get prophecyRemoveFromJournal;

  /// No description provided for @prophecyPrayedForWord.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié pour cette parole'**
  String get prophecyPrayedForWord;

  /// No description provided for @prophecyNoteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultative)'**
  String get prophecyNoteLabel;

  /// No description provided for @prophecyNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Dieu vous a mis à cœur…'**
  String get prophecyNoteHint;

  /// No description provided for @prophecyPublicFulfilledTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parole prophétique accomplie'**
  String get prophecyPublicFulfilledTitle;

  /// No description provided for @prophecyGivenBy.
  ///
  /// In fr, this message translates to:
  /// **'donnée par {name}'**
  String prophecyGivenBy(String name);

  /// No description provided for @prophecyQuoted.
  ///
  /// In fr, this message translates to:
  /// **'« {text} »'**
  String prophecyQuoted(String text);

  /// No description provided for @prophecyRecordedAsAudio.
  ///
  /// In fr, this message translates to:
  /// **'Parole enregistrée en audio'**
  String get prophecyRecordedAsAudio;

  /// No description provided for @prophecyReadTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Lire le témoignage : {title}'**
  String prophecyReadTestimony(String title);

  /// No description provided for @prophecyMicPermission.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez le micro dans les réglages du téléphone.'**
  String get prophecyMicPermission;

  /// No description provided for @prophecyDateLabel.
  ///
  /// In fr, this message translates to:
  /// **'Date de la parole'**
  String get prophecyDateLabel;

  /// No description provided for @prophecyTimeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Heure de la parole'**
  String get prophecyTimeLabel;

  /// No description provided for @prophecyDueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Échéance (facultative)'**
  String get prophecyDueLabel;

  /// No description provided for @prophecyEmptyContent.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez la parole ou enregistrez-la en audio.'**
  String get prophecyEmptyContent;

  /// No description provided for @prophecyUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Parole mise à jour.'**
  String get prophecyUpdated;

  /// No description provided for @prophecySaved.
  ///
  /// In fr, this message translates to:
  /// **'Parole gardée dans votre carnet.'**
  String get prophecySaved;

  /// No description provided for @prophecyEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la parole'**
  String get prophecyEditTitle;

  /// No description provided for @prophecyNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle parole prophétique'**
  String get prophecyNewTitle;

  /// No description provided for @prophecyKeepWord.
  ///
  /// In fr, this message translates to:
  /// **'Garder cette parole'**
  String get prophecyKeepWord;

  /// No description provided for @prophecySectionWord.
  ///
  /// In fr, this message translates to:
  /// **'La parole'**
  String get prophecySectionWord;

  /// No description provided for @prophecyModeText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get prophecyModeText;

  /// No description provided for @prophecyModeAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get prophecyModeAudio;

  /// No description provided for @prophecyTextHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez la parole telle que vous l\'avez reçue…'**
  String get prophecyTextHint;

  /// No description provided for @prophecySectionContext.
  ///
  /// In fr, this message translates to:
  /// **'Contexte'**
  String get prophecySectionContext;

  /// No description provided for @prophecyTimeOptionalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Heure de la parole (facultatif)'**
  String get prophecyTimeOptionalLabel;

  /// No description provided for @prophecyTimeUnspecified.
  ///
  /// In fr, this message translates to:
  /// **'Non précisée'**
  String get prophecyTimeUnspecified;

  /// No description provided for @prophecyGivenByLabel.
  ///
  /// In fr, this message translates to:
  /// **'Qui l\'a donnée ? (facultatif)'**
  String get prophecyGivenByLabel;

  /// No description provided for @prophecyGivenByHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Pasteur Jean, lors du culte de jeudi'**
  String get prophecyGivenByHint;

  /// No description provided for @prophecyTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre (facultatif)'**
  String get prophecyTitleLabel;

  /// No description provided for @prophecyTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Une porte ouverte'**
  String get prophecyTitleHint;

  /// No description provided for @prophecyDueNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get prophecyDueNone;

  /// No description provided for @prophecyNoReminderShort.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rappel'**
  String get prophecyNoReminderShort;

  /// No description provided for @prophecyReminderSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Une notification pour prier sur cette parole.'**
  String get prophecyReminderSubtitle;

  /// No description provided for @prophecyAudioMobileOnly.
  ///
  /// In fr, this message translates to:
  /// **'L\'enregistrement audio se fait depuis l\'application mobile.'**
  String get prophecyAudioMobileOnly;

  /// No description provided for @prophecyStopRecording.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter l\'enregistrement'**
  String get prophecyStopRecording;

  /// No description provided for @prophecyRecordHint.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez la parole de vive voix, ou faites écouter l\'enregistrement reçu.'**
  String get prophecyRecordHint;

  /// No description provided for @prophecyRecord.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get prophecyRecord;

  /// No description provided for @verseServerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur du serveur ({status}).'**
  String verseServerError(int status);

  /// No description provided for @verseOfflineError.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Réessayez une fois en ligne.'**
  String get verseOfflineError;

  /// No description provided for @verseMoodDeep.
  ///
  /// In fr, this message translates to:
  /// **'Sombre profond'**
  String get verseMoodDeep;

  /// No description provided for @verseMoodLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair et lumineux'**
  String get verseMoodLight;

  /// No description provided for @verseMoodDawn.
  ///
  /// In fr, this message translates to:
  /// **'Aube'**
  String get verseMoodDawn;

  /// No description provided for @verseMoodNight.
  ///
  /// In fr, this message translates to:
  /// **'Nuit'**
  String get verseMoodNight;

  /// No description provided for @verseMoodMinimal.
  ///
  /// In fr, this message translates to:
  /// **'Sobre'**
  String get verseMoodMinimal;

  /// No description provided for @verseMoodWarm.
  ///
  /// In fr, this message translates to:
  /// **'Chaleureux'**
  String get verseMoodWarm;

  /// No description provided for @verseDesignAube.
  ///
  /// In fr, this message translates to:
  /// **'Aube'**
  String get verseDesignAube;

  /// No description provided for @verseDesignNuit.
  ///
  /// In fr, this message translates to:
  /// **'Nuit étoilée'**
  String get verseDesignNuit;

  /// No description provided for @verseDesignOcean.
  ///
  /// In fr, this message translates to:
  /// **'Océan profond'**
  String get verseDesignOcean;

  /// No description provided for @verseDesignLumiere.
  ///
  /// In fr, this message translates to:
  /// **'Lumière douce'**
  String get verseDesignLumiere;

  /// No description provided for @verseDesignBraise.
  ///
  /// In fr, this message translates to:
  /// **'Braise'**
  String get verseDesignBraise;

  /// No description provided for @verseDesignMinimal.
  ///
  /// In fr, this message translates to:
  /// **'Minimal'**
  String get verseDesignMinimal;

  /// No description provided for @verseDesignVitrail.
  ///
  /// In fr, this message translates to:
  /// **'Vitrail'**
  String get verseDesignVitrail;

  /// No description provided for @verseDesignCrepuscule.
  ///
  /// In fr, this message translates to:
  /// **'Crépuscule'**
  String get verseDesignCrepuscule;

  /// No description provided for @verseDesignMatin.
  ///
  /// In fr, this message translates to:
  /// **'Matin clair'**
  String get verseDesignMatin;

  /// No description provided for @verseDesignOr.
  ///
  /// In fr, this message translates to:
  /// **'Or doux'**
  String get verseDesignOr;

  /// No description provided for @verseDesignEncre.
  ///
  /// In fr, this message translates to:
  /// **'Encre'**
  String get verseDesignEncre;

  /// No description provided for @verseDesignArdoise.
  ///
  /// In fr, this message translates to:
  /// **'Ardoise'**
  String get verseDesignArdoise;

  /// No description provided for @verseDesignChangeSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Changer le design du verset. Design actuel : {name}'**
  String verseDesignChangeSemantics(String name);

  /// No description provided for @verseDesignsAndText.
  ///
  /// In fr, this message translates to:
  /// **'Designs et texte'**
  String get verseDesignsAndText;

  /// No description provided for @verseTabBackgrounds.
  ///
  /// In fr, this message translates to:
  /// **'Fonds'**
  String get verseTabBackgrounds;

  /// No description provided for @verseAlwaysMine.
  ///
  /// In fr, this message translates to:
  /// **'Toujours utiliser mon design'**
  String get verseAlwaysMine;

  /// No description provided for @verseAlwaysMineOn.
  ///
  /// In fr, this message translates to:
  /// **'Le même design chaque jour.'**
  String get verseAlwaysMineOn;

  /// No description provided for @verseAlwaysMineOff.
  ///
  /// In fr, this message translates to:
  /// **'Sinon, votre choix vaut jusqu’à demain, puis un nouveau design s’affiche.'**
  String get verseAlwaysMineOff;

  /// No description provided for @verseDesignTileSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Design {name}, {mood}'**
  String verseDesignTileSemantics(String name, String mood);

  /// No description provided for @verseDesignTileSemanticsDaily.
  ///
  /// In fr, this message translates to:
  /// **'Design {name}, {mood}, design du jour'**
  String verseDesignTileSemanticsDaily(String name, String mood);

  /// No description provided for @verseDesignOfTheDayShort.
  ///
  /// In fr, this message translates to:
  /// **'{name} · du jour'**
  String verseDesignOfTheDayShort(String name);

  /// No description provided for @verseFontTitle.
  ///
  /// In fr, this message translates to:
  /// **'Police'**
  String get verseFontTitle;

  /// No description provided for @verseSizeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get verseSizeTitle;

  /// No description provided for @verseAlignTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alignement'**
  String get verseAlignTitle;

  /// No description provided for @verseSizeSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petit'**
  String get verseSizeSmall;

  /// No description provided for @verseSizeMedium.
  ///
  /// In fr, this message translates to:
  /// **'Moyen'**
  String get verseSizeMedium;

  /// No description provided for @verseSizeLarge.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get verseSizeLarge;

  /// No description provided for @verseAlignLeft.
  ///
  /// In fr, this message translates to:
  /// **'Gauche'**
  String get verseAlignLeft;

  /// No description provided for @verseAlignCenter.
  ///
  /// In fr, this message translates to:
  /// **'Centré'**
  String get verseAlignCenter;

  /// No description provided for @verseOfTheDayUpper.
  ///
  /// In fr, this message translates to:
  /// **'VERSET DU JOUR'**
  String get verseOfTheDayUpper;

  /// No description provided for @verseMember.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get verseMember;

  /// No description provided for @verseTodayText.
  ///
  /// In fr, this message translates to:
  /// **'Texte du jour'**
  String get verseTodayText;

  /// No description provided for @verseTtsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La lecture à voix haute n\'est pas disponible sur cet appareil.'**
  String get verseTtsUnavailable;

  /// No description provided for @verseReasonPray.
  ///
  /// In fr, this message translates to:
  /// **'prier avec ce verset'**
  String get verseReasonPray;

  /// No description provided for @verseReasonLike.
  ///
  /// In fr, this message translates to:
  /// **'aimer ce verset'**
  String get verseReasonLike;

  /// No description provided for @verseReasonTestify.
  ///
  /// In fr, this message translates to:
  /// **'témoigner sur ce verset'**
  String get verseReasonTestify;

  /// No description provided for @verseReasonPrayerTopic.
  ///
  /// In fr, this message translates to:
  /// **'confier un sujet de prière'**
  String get verseReasonPrayerTopic;

  /// No description provided for @verseReasonComment.
  ///
  /// In fr, this message translates to:
  /// **'commenter le verset du jour'**
  String get verseReasonComment;

  /// No description provided for @verseBackToVerse.
  ///
  /// In fr, this message translates to:
  /// **'Revenir au verset'**
  String get verseBackToVerse;

  /// No description provided for @verseStopReading.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la lecture'**
  String get verseStopReading;

  /// No description provided for @verseExitReadingMode.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le mode lecture'**
  String get verseExitReadingMode;

  /// No description provided for @verseReadingMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode lecture'**
  String get verseReadingMode;

  /// No description provided for @verseSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour, {reference}'**
  String verseSemantics(String reference);

  /// No description provided for @verseMissingInVersion.
  ///
  /// In fr, this message translates to:
  /// **'Passage absent de la version « {version} » : texte du jour affiché.'**
  String verseMissingInVersion(String version);

  /// No description provided for @verseScrollHintSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Faire défiler : versions, prière, commentaires'**
  String get verseScrollHintSemantics;

  /// No description provided for @verseScrollHint.
  ///
  /// In fr, this message translates to:
  /// **'Faire défiler'**
  String get verseScrollHint;

  /// No description provided for @verseLikeCount.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime · {count}'**
  String verseLikeCount(int count);

  /// No description provided for @versePrayCount.
  ///
  /// In fr, this message translates to:
  /// **'Je prie · {count}'**
  String versePrayCount(int count);

  /// No description provided for @verseVersionsSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche des versions…'**
  String get verseVersionsSearching;

  /// No description provided for @verseVersionsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Versions indisponibles pour le moment.'**
  String get verseVersionsUnavailable;

  /// No description provided for @verseReferenceUnrecognized.
  ///
  /// In fr, this message translates to:
  /// **'Référence non reconnue : seul le texte du jour est proposé.'**
  String get verseReferenceUnrecognized;

  /// No description provided for @verseOfflineDownloadBible.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion : téléchargez une Bible (onglet Bible) pour lire d\'autres versions.'**
  String get verseOfflineDownloadBible;

  /// No description provided for @verseNoOtherVersion.
  ///
  /// In fr, this message translates to:
  /// **'Aucune autre version installée.'**
  String get verseNoOtherVersion;

  /// No description provided for @verseOfflineDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Hors connexion : versions téléchargées sur l\'appareil.'**
  String get verseOfflineDownloaded;

  /// No description provided for @verseBibleVersions.
  ///
  /// In fr, this message translates to:
  /// **'Versions de la Bible'**
  String get verseBibleVersions;

  /// No description provided for @verseVersionMissingTooltip.
  ///
  /// In fr, this message translates to:
  /// **'{name} : passage absent de cette version'**
  String verseVersionMissingTooltip(String name);

  /// No description provided for @verseCompare.
  ///
  /// In fr, this message translates to:
  /// **'Comparer'**
  String get verseCompare;

  /// No description provided for @verseVersionUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Ce passage n\'est pas disponible dans cette version.'**
  String get verseVersionUnavailable;

  /// No description provided for @verseParticipationOffline.
  ///
  /// In fr, this message translates to:
  /// **'Les sujets de prière, commentaires et témoignages seront disponibles une fois en ligne.'**
  String get verseParticipationOffline;

  /// No description provided for @versePrayerIntro.
  ///
  /// In fr, this message translates to:
  /// **'Confiez un sujet de prière inspiré par ce verset ; d\'autres prieront avec vous.'**
  String get versePrayerIntro;

  /// No description provided for @versePrayerCreate.
  ///
  /// In fr, this message translates to:
  /// **'Confier un sujet de prière'**
  String get versePrayerCreate;

  /// No description provided for @versePrayerEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun sujet de prière pour le moment. Soyez le premier !'**
  String get versePrayerEmpty;

  /// No description provided for @versePrayerSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sujet de prière sur le verset du jour'**
  String get versePrayerSheetTitle;

  /// No description provided for @versePrayerHint.
  ///
  /// In fr, this message translates to:
  /// **'Seigneur, à la lumière de ce verset, je te confie…'**
  String get versePrayerHint;

  /// No description provided for @verseAnonymousSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom reste visible de vous et de la modération.'**
  String get verseAnonymousSubtitle;

  /// No description provided for @verseCommentDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le commentaire ?'**
  String get verseCommentDeleteTitle;

  /// No description provided for @verseCommentReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce commentaire'**
  String get verseCommentReportTitle;

  /// No description provided for @verseCommentReported.
  ///
  /// In fr, this message translates to:
  /// **'Merci, le commentaire a été signalé à la modération.'**
  String get verseCommentReported;

  /// No description provided for @verseCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que ce verset vous dit aujourd\'hui…'**
  String get verseCommentHint;

  /// No description provided for @verseCommentHintMention.
  ///
  /// In fr, this message translates to:
  /// **'Ce que ce verset vous dit aujourd\'hui… (@ pour mentionner)'**
  String get verseCommentHintMention;

  /// No description provided for @verseCommentsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire. Partagez ce que ce verset vous inspire.'**
  String get verseCommentsEmpty;

  /// No description provided for @verseCommentHidden.
  ///
  /// In fr, this message translates to:
  /// **'Retiré après signalement'**
  String get verseCommentHidden;

  /// No description provided for @verseTestifyIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ce verset s\'est accompli dans votre vie ? Racontez-le.'**
  String get verseTestifyIntro;

  /// No description provided for @verseTestify.
  ///
  /// In fr, this message translates to:
  /// **'Témoigner sur ce verset'**
  String get verseTestify;

  /// No description provided for @verseTestimoniesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage ne cite encore ce verset.'**
  String get verseTestimoniesEmpty;

  /// No description provided for @errorNotFoundTitle.
  ///
  /// In fr, this message translates to:
  /// **'Page introuvable'**
  String get errorNotFoundTitle;

  /// No description provided for @errorNotFoundBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette page n\'existe pas ou a été déplacée.'**
  String get errorNotFoundBody;

  /// No description provided for @errorBackHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get errorBackHome;

  /// No description provided for @feedEventPast.
  ///
  /// In fr, this message translates to:
  /// **'Événement passé · à revivre'**
  String get feedEventPast;

  /// No description provided for @feedEventOngoing.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get feedEventOngoing;

  /// No description provided for @feedEventUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Événement à venir'**
  String get feedEventUpcoming;

  /// No description provided for @feedPrayerRequest.
  ///
  /// In fr, this message translates to:
  /// **'Requête de prière'**
  String get feedPrayerRequest;

  /// No description provided for @feedPrayerRequestEvent.
  ///
  /// In fr, this message translates to:
  /// **'Requête de prière · {event}'**
  String feedPrayerRequestEvent(String event);

  /// No description provided for @feedPrayerRequestBy.
  ///
  /// In fr, this message translates to:
  /// **'Requête de prière de {name}'**
  String feedPrayerRequestBy(String name);

  /// No description provided for @feedPrayerSession.
  ///
  /// In fr, this message translates to:
  /// **'Session de prière'**
  String get feedPrayerSession;

  /// No description provided for @feedPrayerSessionHost.
  ///
  /// In fr, this message translates to:
  /// **'Session de prière · {host}'**
  String feedPrayerSessionHost(String host);

  /// No description provided for @feedProphecyFulfilled.
  ///
  /// In fr, this message translates to:
  /// **'Parole prophétique accomplie · {author}'**
  String feedProphecyFulfilled(String author);

  /// No description provided for @feedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon fil'**
  String get feedTitle;

  /// No description provided for @feedLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger votre fil.'**
  String get feedLoadError;

  /// No description provided for @feedHeaderFollowing.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Les {count} compte que vous suivez d’abord, puis des témoignages choisis pour vous.} other{Les {count} comptes que vous suivez d’abord, puis des témoignages choisis pour vous.}}'**
  String feedHeaderFollowing(int count);

  /// No description provided for @feedFollowAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Suivez des comptes'**
  String get feedFollowAccounts;

  /// No description provided for @feedNoTestimonyYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de témoignage'**
  String get feedNoTestimonyYet;

  /// No description provided for @feedFollowAccountsBody.
  ///
  /// In fr, this message translates to:
  /// **'Abonnez-vous à des églises, ministères et personnes : leurs témoignages apparaîtront ici. En attendant, voici des témoignages choisis pour vous.'**
  String get feedFollowAccountsBody;

  /// No description provided for @feedFollowingEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Les comptes que vous suivez n\'ont encore rien publié.'**
  String get feedFollowingEmptyBody;

  /// No description provided for @feedDiscoverCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir la communauté'**
  String get feedDiscoverCommunity;

  /// No description provided for @feedSuggestionForYou.
  ///
  /// In fr, this message translates to:
  /// **'Suggestion pour vous'**
  String get feedSuggestionForYou;

  /// No description provided for @liveCameraBroadcastFailed.
  ///
  /// In fr, this message translates to:
  /// **'La caméra n\'a pas pu être diffusée. Réessayez.'**
  String get liveCameraBroadcastFailed;

  /// No description provided for @liveVideoNotConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Le service vidéo n\'est pas configuré.'**
  String get liveVideoNotConfigured;

  /// No description provided for @liveSpeakerRequested.
  ///
  /// In fr, this message translates to:
  /// **'{name} demande à intervenir.'**
  String liveSpeakerRequested(String name);

  /// No description provided for @liveTooManyReactions.
  ///
  /// In fr, this message translates to:
  /// **'Doucement ! Trop de réactions en peu de temps.'**
  String get liveTooManyReactions;

  /// No description provided for @liveNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes pas connecté au direct.'**
  String get liveNotConnected;

  /// No description provided for @liveMicNotOpenedYet.
  ///
  /// In fr, this message translates to:
  /// **'Le service vidéo n\'a pas encore ouvert votre micro. Réessayez.'**
  String get liveMicNotOpenedYet;

  /// No description provided for @liveMicInaccessible.
  ///
  /// In fr, this message translates to:
  /// **'Micro inaccessible. Autorisez-le dans les réglages du téléphone.'**
  String get liveMicInaccessible;

  /// No description provided for @liveStageEndedByHost.
  ///
  /// In fr, this message translates to:
  /// **'Le diffuseur a terminé votre intervention. Merci pour votre témoignage !'**
  String get liveStageEndedByHost;

  /// No description provided for @liveStageRemovedByModerator.
  ///
  /// In fr, this message translates to:
  /// **'Un modérateur vous a retiré de l\'antenne.'**
  String get liveStageRemovedByModerator;

  /// No description provided for @liveStageConnectionLost.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue : vous n\'êtes plus à l\'antenne.'**
  String get liveStageConnectionLost;

  /// No description provided for @liveStageEnded.
  ///
  /// In fr, this message translates to:
  /// **'Votre intervention est terminée. Merci pour votre témoignage !'**
  String get liveStageEnded;

  /// No description provided for @liveVideoUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le service vidéo est momentanément indisponible.'**
  String get liveVideoUnavailable;

  /// No description provided for @liveServerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur du serveur ({status}).'**
  String liveServerError(int status);

  /// No description provided for @liveConnectionImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre accès à Internet.'**
  String get liveConnectionImpossible;

  /// No description provided for @liveReactionPray.
  ///
  /// In fr, this message translates to:
  /// **'Prière'**
  String get liveReactionPray;

  /// No description provided for @liveReactionAmen.
  ///
  /// In fr, this message translates to:
  /// **'Amen'**
  String get liveReactionAmen;

  /// No description provided for @liveReactionWorship.
  ///
  /// In fr, this message translates to:
  /// **'Adorer Dieu'**
  String get liveReactionWorship;

  /// No description provided for @liveReactionFire.
  ///
  /// In fr, this message translates to:
  /// **'Feu'**
  String get liveReactionFire;

  /// No description provided for @liveDefaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Direct'**
  String get liveDefaultTitle;

  /// No description provided for @liveEndReasonHost.
  ///
  /// In fr, this message translates to:
  /// **'Terminé par le diffuseur'**
  String get liveEndReasonHost;

  /// No description provided for @liveEndReasonModerator.
  ///
  /// In fr, this message translates to:
  /// **'Coupé par la modération'**
  String get liveEndReasonModerator;

  /// No description provided for @liveEndReasonConnection.
  ///
  /// In fr, this message translates to:
  /// **'Interrompu (connexion perdue)'**
  String get liveEndReasonConnection;

  /// No description provided for @liveEndReasonAbandoned.
  ///
  /// In fr, this message translates to:
  /// **'Jamais passé à l\'antenne'**
  String get liveEndReasonAbandoned;

  /// No description provided for @liveEndReasonDefault.
  ///
  /// In fr, this message translates to:
  /// **'Merci d\'avoir suivi ce témoignage.'**
  String get liveEndReasonDefault;

  /// No description provided for @liveProtocolEncrypted.
  ///
  /// In fr, this message translates to:
  /// **'{protocol} (chiffré)'**
  String liveProtocolEncrypted(String protocol);

  /// No description provided for @liveCamHikvision.
  ///
  /// In fr, this message translates to:
  /// **'Hikvision (et HiLook)'**
  String get liveCamHikvision;

  /// No description provided for @liveCamHikvisionHint.
  ///
  /// In fr, this message translates to:
  /// **'Canal 1 : 101 (principal), 102 (secondaire). Canal 2 : 201, 202…'**
  String get liveCamHikvisionHint;

  /// No description provided for @liveCamDahua.
  ///
  /// In fr, this message translates to:
  /// **'Dahua (et Imou)'**
  String get liveCamDahua;

  /// No description provided for @liveCamDahuaHint.
  ///
  /// In fr, this message translates to:
  /// **'subtype=0 : flux principal, subtype=1 : flux secondaire.'**
  String get liveCamDahuaHint;

  /// No description provided for @liveCamAmcrestHint.
  ///
  /// In fr, this message translates to:
  /// **'Même format que Dahua.'**
  String get liveCamAmcrestHint;

  /// No description provided for @liveCamReolinkHint.
  ///
  /// In fr, this message translates to:
  /// **'Activez RTSP dans Réglages → Réseau → Avancé → Ports. Modèles 4K / H.265 : /h265Preview_01_main.'**
  String get liveCamReolinkHint;

  /// No description provided for @liveCamAxisHint.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres possibles : ?videocodec=h264&resolution=1280x720.'**
  String get liveCamAxisHint;

  /// No description provided for @liveCamTapoHint.
  ///
  /// In fr, this message translates to:
  /// **'Créez d\'abord un « Compte de la caméra » dans l\'application Tapo (Paramètres avancés) : ce sont cet identifiant et ce mot de passe.'**
  String get liveCamTapoHint;

  /// No description provided for @liveCamFoscamHint.
  ///
  /// In fr, this message translates to:
  /// **'Port RTSP 88 sur la plupart des modèles récents (vérifiez dans Réglages → Réseau → Port).'**
  String get liveCamFoscamHint;

  /// No description provided for @liveCamOnvif.
  ///
  /// In fr, this message translates to:
  /// **'ONVIF générique'**
  String get liveCamOnvif;

  /// No description provided for @liveCamOnvifHint.
  ///
  /// In fr, this message translates to:
  /// **'Le chemin dépend du modèle : lisez-le dans l\'interface de la caméra ou avec ONVIF Device Manager (profil de flux).'**
  String get liveCamOnvifHint;

  /// No description provided for @liveCamOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get liveCamOther;

  /// No description provided for @liveCamOtherHint.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le chemin donné par la documentation de la caméra.'**
  String get liveCamOtherHint;

  /// No description provided for @liveCamHostRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez l\'adresse IP ou le nom d\'hôte de la caméra.'**
  String get liveCamHostRequired;

  /// No description provided for @liveCamHostNoScheme.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez seulement l\'adresse, sans « rtsp:// ».'**
  String get liveCamHostNoScheme;

  /// No description provided for @liveCamHostInvalidChars.
  ///
  /// In fr, this message translates to:
  /// **'Adresse non valide (pas d\'espace, de « / », « @ » ni « ? »).'**
  String get liveCamHostInvalidChars;

  /// No description provided for @liveCamIpv6Invalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse IPv6 non valide.'**
  String get liveCamIpv6Invalid;

  /// No description provided for @liveCamIpInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse IP non valide.'**
  String get liveCamIpInvalid;

  /// No description provided for @liveCamHostnameInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Nom d\'hôte non valide.'**
  String get liveCamHostnameInvalid;

  /// No description provided for @liveCamPortRange.
  ///
  /// In fr, this message translates to:
  /// **'Port entre 1 et 65535.'**
  String get liveCamPortRange;

  /// No description provided for @liveCamPathNoSpace.
  ///
  /// In fr, this message translates to:
  /// **'Le chemin ne doit pas contenir d\'espace.'**
  String get liveCamPathNoSpace;

  /// No description provided for @liveCamPassphraseLength.
  ///
  /// In fr, this message translates to:
  /// **'La phrase secrète SRT compte 10 à 79 caractères.'**
  String get liveCamPassphraseLength;

  /// No description provided for @liveCamUrlTooLong.
  ///
  /// In fr, this message translates to:
  /// **'Adresse trop longue (500 caractères au plus).'**
  String get liveCamUrlTooLong;

  /// No description provided for @livesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Directs'**
  String get livesTitle;

  /// No description provided for @livesGoLive.
  ///
  /// In fr, this message translates to:
  /// **'Lancer un direct'**
  String get livesGoLive;

  /// No description provided for @livesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les directs.'**
  String get livesLoadError;

  /// No description provided for @livesNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Les directs ne sont pas encore disponibles.\nLe service vidéo doit être configuré sur le serveur.'**
  String get livesNotAvailable;

  /// No description provided for @livesEmptyCanGoLive.
  ///
  /// In fr, this message translates to:
  /// **'Aucun direct pour le moment.\nLancez le premier !'**
  String get livesEmptyCanGoLive;

  /// No description provided for @livesEmptyComeBack.
  ///
  /// In fr, this message translates to:
  /// **'Aucun direct pour le moment.\nRevenez bientôt.'**
  String get livesEmptyComeBack;

  /// No description provided for @livesRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get livesRecent;

  /// No description provided for @liveBadgePreparing.
  ///
  /// In fr, this message translates to:
  /// **'EN PRÉPARATION'**
  String get liveBadgePreparing;

  /// No description provided for @liveResume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get liveResume;

  /// No description provided for @liveWatch.
  ///
  /// In fr, this message translates to:
  /// **'Regarder'**
  String get liveWatch;

  /// No description provided for @liveNowCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Un direct en cours} other{{count} directs en cours}}'**
  String liveNowCount(int count);

  /// No description provided for @liveViewersSemantics.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, other{{count} spectateurs : voir qui regarde}}'**
  String liveViewersSemantics(int count);

  /// No description provided for @liveViewersLoadError.
  ///
  /// In fr, this message translates to:
  /// **'La liste n\'a pas pu être chargée.'**
  String get liveViewersLoadError;

  /// No description provided for @liveViewersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qui regarde · {count}'**
  String liveViewersTitle(int count);

  /// No description provided for @liveViewersNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte connecté ne regarde pour le moment.'**
  String get liveViewersNoAccount;

  /// No description provided for @liveViewersNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne ne regarde pour le moment.'**
  String get liveViewersNobody;

  /// No description provided for @liveViewersAnonymous.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{+ 1 visiteur non connecté} other{+ {count} visiteurs non connectés}}'**
  String liveViewersAnonymous(int count);

  /// No description provided for @liveCamUnreadableUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse illisible : le formulaire n\'a pas été rempli.'**
  String get liveCamUnreadableUrl;

  /// No description provided for @liveCamHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get liveCamHide;

  /// No description provided for @liveCamShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get liveCamShow;

  /// No description provided for @liveCamModeForm.
  ///
  /// In fr, this message translates to:
  /// **'Formulaire'**
  String get liveCamModeForm;

  /// No description provided for @liveCamModeFullUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse complète'**
  String get liveCamModeFullUrl;

  /// No description provided for @liveCamPrivateHost.
  ///
  /// In fr, this message translates to:
  /// **'« {host} » est une adresse du réseau local : le service vidéo, sur Internet, ne pourra pas la joindre. Utilisez l\'adresse IP publique de la box ou un nom DDNS, avec une redirection de port vers la caméra, ou choisissez le mode RTMP (OBS, ffmpeg).'**
  String liveCamPrivateHost(String host);

  /// No description provided for @liveCamReachableNotice.
  ///
  /// In fr, this message translates to:
  /// **'La caméra doit être joignable depuis Internet par le service vidéo : IP publique ou DDNS, et redirection du port (ex. 554) vers la caméra sur la box. L\'adresse est conservée chiffrée sur le serveur ; le mot de passe n\'est pas mémorisé sur ce téléphone.'**
  String get liveCamReachableNotice;

  /// No description provided for @liveCamStreamUrlLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du flux *'**
  String get liveCamStreamUrlLabel;

  /// No description provided for @liveCamStreamUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'rtsp://utilisateur:motdepasse@cam.exemple.org:554/stream1'**
  String get liveCamStreamUrlHint;

  /// No description provided for @liveCamStreamUrlHelper.
  ///
  /// In fr, this message translates to:
  /// **'rtsp(s)://, rtmp(s)://, http(s):// ou srt://. Caractères spéciaux du mot de passe encodés (@ → %40).'**
  String get liveCamStreamUrlHelper;

  /// No description provided for @liveCamStreamUrlRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez l\'adresse du flux de la caméra.'**
  String get liveCamStreamUrlRequired;

  /// No description provided for @liveCamStreamUrlInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse non reconnue : elle doit commencer par rtsp://, rtmp://, http(s):// ou srt://.'**
  String get liveCamStreamUrlInvalid;

  /// No description provided for @liveCamModel.
  ///
  /// In fr, this message translates to:
  /// **'Modèle de caméra'**
  String get liveCamModel;

  /// No description provided for @liveCamMainStream.
  ///
  /// In fr, this message translates to:
  /// **'Flux principal'**
  String get liveCamMainStream;

  /// No description provided for @liveCamSubStream.
  ///
  /// In fr, this message translates to:
  /// **'Flux secondaire'**
  String get liveCamSubStream;

  /// No description provided for @liveCamProtocol.
  ///
  /// In fr, this message translates to:
  /// **'Protocole'**
  String get liveCamProtocol;

  /// No description provided for @liveCamHostLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse IP ou nom d\'hôte *'**
  String get liveCamHostLabel;

  /// No description provided for @liveCamHostHint.
  ///
  /// In fr, this message translates to:
  /// **'cam.exemple.org'**
  String get liveCamHostHint;

  /// No description provided for @liveCamPort.
  ///
  /// In fr, this message translates to:
  /// **'Port'**
  String get liveCamPort;

  /// No description provided for @liveCamPathParams.
  ///
  /// In fr, this message translates to:
  /// **'Chemin / paramètres (facultatif)'**
  String get liveCamPathParams;

  /// No description provided for @liveCamPath.
  ///
  /// In fr, this message translates to:
  /// **'Chemin du flux'**
  String get liveCamPath;

  /// No description provided for @liveCamStreamId.
  ///
  /// In fr, this message translates to:
  /// **'Stream ID (facultatif)'**
  String get liveCamStreamId;

  /// No description provided for @liveCamPassphrase.
  ///
  /// In fr, this message translates to:
  /// **'Phrase secrète (facultatif)'**
  String get liveCamPassphrase;

  /// No description provided for @liveCamPassphraseHelper.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement SRT : 10 à 79 caractères.'**
  String get liveCamPassphraseHelper;

  /// No description provided for @liveCamUsername.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant de la caméra'**
  String get liveCamUsername;

  /// No description provided for @liveCamComposedUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse composée'**
  String get liveCamComposedUrl;

  /// No description provided for @liveCheckPending.
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get liveCheckPending;

  /// No description provided for @liveCheckEventOrganizer.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur de l\'événement'**
  String get liveCheckEventOrganizer;

  /// No description provided for @liveCheckEventOrganizerOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seuls l\'organisateur et les administrateurs peuvent diffuser cet événement.'**
  String get liveCheckEventOrganizerOnly;

  /// No description provided for @liveCheckModeratorAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte modérateur ou administrateur'**
  String get liveCheckModeratorAccount;

  /// No description provided for @liveCheckModeratorsOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les modérateurs et administrateurs peuvent diffuser.'**
  String get liveCheckModeratorsOnly;

  /// No description provided for @liveCheckServiceOk.
  ///
  /// In fr, this message translates to:
  /// **'Service vidéo disponible'**
  String get liveCheckServiceOk;

  /// No description provided for @liveCheckServiceMissing.
  ///
  /// In fr, this message translates to:
  /// **'Le service vidéo n\'est pas encore configuré sur le serveur.'**
  String get liveCheckServiceMissing;

  /// No description provided for @liveCheckMobileData.
  ///
  /// In fr, this message translates to:
  /// **'Données mobiles : la vidéo consomme environ 1 Go par heure.'**
  String get liveCheckMobileData;

  /// No description provided for @liveCheckNoInternet.
  ///
  /// In fr, this message translates to:
  /// **'Aucune connexion Internet.'**
  String get liveCheckNoInternet;

  /// No description provided for @liveCheckConnected.
  ///
  /// In fr, this message translates to:
  /// **'Connecté'**
  String get liveCheckConnected;

  /// No description provided for @liveCheckCameraGranted.
  ///
  /// In fr, this message translates to:
  /// **'Caméra autorisée'**
  String get liveCheckCameraGranted;

  /// No description provided for @liveCheckCameraDeniedForever.
  ///
  /// In fr, this message translates to:
  /// **'Caméra refusée : autorisez-la dans les réglages.'**
  String get liveCheckCameraDeniedForever;

  /// No description provided for @liveCheckCameraRestricted.
  ///
  /// In fr, this message translates to:
  /// **'Caméra bloquée sur cet appareil.'**
  String get liveCheckCameraRestricted;

  /// No description provided for @liveCheckCameraDenied.
  ///
  /// In fr, this message translates to:
  /// **'Caméra refusée. Appuyez pour réessayer.'**
  String get liveCheckCameraDenied;

  /// No description provided for @liveCheckMicGranted.
  ///
  /// In fr, this message translates to:
  /// **'Micro autorisé'**
  String get liveCheckMicGranted;

  /// No description provided for @liveCheckMicDeniedForever.
  ///
  /// In fr, this message translates to:
  /// **'Micro refusé : autorisez-le dans les réglages.'**
  String get liveCheckMicDeniedForever;

  /// No description provided for @liveCheckMicRestricted.
  ///
  /// In fr, this message translates to:
  /// **'Micro bloqué sur cet appareil.'**
  String get liveCheckMicRestricted;

  /// No description provided for @liveCheckMicDenied.
  ///
  /// In fr, this message translates to:
  /// **'Micro refusé. Appuyez pour réessayer.'**
  String get liveCheckMicDenied;

  /// No description provided for @liveCheckCameraBusy.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir la caméra (déjà utilisée par une autre application ?).'**
  String get liveCheckCameraBusy;

  /// No description provided for @liveAlreadyRunningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Direct déjà en cours'**
  String get liveAlreadyRunningTitle;

  /// No description provided for @liveAlreadyRunningBody.
  ///
  /// In fr, this message translates to:
  /// **'{message}\n\nVoulez-vous reprendre ce direct ?'**
  String liveAlreadyRunningBody(String message);

  /// No description provided for @liveEventLiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Direct de l\'événement\n'**
  String get liveEventLiveLabel;

  /// No description provided for @liveCameraUsed.
  ///
  /// In fr, this message translates to:
  /// **'Caméra utilisée'**
  String get liveCameraUsed;

  /// No description provided for @liveSourceDevice.
  ///
  /// In fr, this message translates to:
  /// **'Caméra de cet appareil'**
  String get liveSourceDevice;

  /// No description provided for @liveSourceRtmp.
  ///
  /// In fr, this message translates to:
  /// **'Caméra IP ou encodeur (RTMP)'**
  String get liveSourceRtmp;

  /// No description provided for @liveSourceRtmpHint.
  ///
  /// In fr, this message translates to:
  /// **'Conseillé : le studio donne une adresse et une clé à saisir dans la caméra ou le logiciel (OBS…).'**
  String get liveSourceRtmpHint;

  /// No description provided for @liveSourceUrl.
  ///
  /// In fr, this message translates to:
  /// **'Caméra IP (adresse du flux)'**
  String get liveSourceUrl;

  /// No description provided for @liveSourceUrlHint.
  ///
  /// In fr, this message translates to:
  /// **'Renseignez la caméra (RTSP, SRT, HLS…) : le service vidéo lit lui-même son flux, joignable depuis Internet.'**
  String get liveSourceUrlHint;

  /// No description provided for @liveChecks.
  ///
  /// In fr, this message translates to:
  /// **'Vérifications'**
  String get liveChecks;

  /// No description provided for @liveCheckRights.
  ///
  /// In fr, this message translates to:
  /// **'Droits'**
  String get liveCheckRights;

  /// No description provided for @liveCheckService.
  ///
  /// In fr, this message translates to:
  /// **'Service vidéo'**
  String get liveCheckService;

  /// No description provided for @liveCheckNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Réseau'**
  String get liveCheckNetwork;

  /// No description provided for @liveCheckCamera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get liveCheckCamera;

  /// No description provided for @liveCheckMic.
  ///
  /// In fr, this message translates to:
  /// **'Micro'**
  String get liveCheckMic;

  /// No description provided for @liveYourLive.
  ///
  /// In fr, this message translates to:
  /// **'Votre direct'**
  String get liveYourLive;

  /// No description provided for @liveTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre *'**
  String get liveTitleLabel;

  /// No description provided for @liveTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Comment Dieu m\'a relevé'**
  String get liveTitleHint;

  /// No description provided for @liveTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Merci de donner un titre au direct.'**
  String get liveTitleRequired;

  /// No description provided for @liveDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Présentation (facultatif)'**
  String get liveDescriptionLabel;

  /// No description provided for @liveCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie (facultatif)'**
  String get liveCategoryLabel;

  /// No description provided for @liveCategoryNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get liveCategoryNone;

  /// No description provided for @liveAllowComments.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser les commentaires'**
  String get liveAllowComments;

  /// No description provided for @liveAllowCommentsHint.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez masquer un commentaire ou exclure une personne.'**
  String get liveAllowCommentsHint;

  /// No description provided for @liveOpenStudio.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le studio'**
  String get liveOpenStudio;

  /// No description provided for @liveInvisibleUntilOnAir.
  ///
  /// In fr, this message translates to:
  /// **'Le direct reste invisible du public tant que vous n\'êtes pas passé à l\'antenne.'**
  String get liveInvisibleUntilOnAir;

  /// No description provided for @liveRtmpStep1.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez le studio : il affiche l\'adresse du serveur et la clé de diffusion.'**
  String get liveRtmpStep1;

  /// No description provided for @liveRtmpStep2.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez-les dans la caméra, OBS, vMix ou votre encodeur, puis lancez la diffusion.'**
  String get liveRtmpStep2;

  /// No description provided for @liveRtmpStep3.
  ///
  /// In fr, this message translates to:
  /// **'Quand l\'image apparaît dans le studio, appuyez sur « Passer à l\'antenne ».'**
  String get liveRtmpStep3;

  /// No description provided for @liveUrlStep1.
  ///
  /// In fr, this message translates to:
  /// **'Le service vidéo se connecte à l\'adresse indiquée (elle doit être joignable depuis Internet).'**
  String get liveUrlStep1;

  /// No description provided for @liveUrlStep2.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez l\'aperçu dans le studio.'**
  String get liveUrlStep2;

  /// No description provided for @liveUrlStep3.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur « Passer à l\'antenne » : le direct ne démarre jamais tout seul.'**
  String get liveUrlStep3;

  /// No description provided for @liveConnectIpCamera.
  ///
  /// In fr, this message translates to:
  /// **'Brancher une caméra IP'**
  String get liveConnectIpCamera;

  /// No description provided for @liveExternalCameraNote.
  ///
  /// In fr, this message translates to:
  /// **'Caméra et micro de ce téléphone ne sont pas utilisés. Réglages conseillés : 720p, 2 à 4 Mbit/s, image clé toutes les 2 secondes, son AAC.'**
  String get liveExternalCameraNote;

  /// No description provided for @liveCameraPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu de la caméra'**
  String get liveCameraPreview;

  /// No description provided for @liveSwitchCamera.
  ///
  /// In fr, this message translates to:
  /// **'Changer de caméra'**
  String get liveSwitchCamera;

  /// No description provided for @liveYouAreLive.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes en direct !'**
  String get liveYouAreLive;

  /// No description provided for @liveLeaveStudioTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le studio ?'**
  String get liveLeaveStudioTitle;

  /// No description provided for @liveLeaveStudioOnAir.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes en direct. Vous pouvez le terminer, ou quitter et revenir dans les 5 minutes pour le reprendre (sinon il sera clôturé).'**
  String get liveLeaveStudioOnAir;

  /// No description provided for @liveLeaveStudioNotStarted.
  ///
  /// In fr, this message translates to:
  /// **'Le direct n\'a pas commencé. Vous pouvez y revenir depuis la liste des directs.'**
  String get liveLeaveStudioNotStarted;

  /// No description provided for @liveStay.
  ///
  /// In fr, this message translates to:
  /// **'Rester'**
  String get liveStay;

  /// No description provided for @liveLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get liveLeave;

  /// No description provided for @liveEndAction.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get liveEndAction;

  /// No description provided for @liveWaitingCameraFeed.
  ///
  /// In fr, this message translates to:
  /// **'En attente du flux de la caméra…'**
  String get liveWaitingCameraFeed;

  /// No description provided for @liveOpeningCamera.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture de la caméra…'**
  String get liveOpeningCamera;

  /// No description provided for @liveCameraOffViewers.
  ///
  /// In fr, this message translates to:
  /// **'Caméra coupée : les spectateurs ne vous voient plus'**
  String get liveCameraOffViewers;

  /// No description provided for @liveWriteToViewers.
  ///
  /// In fr, this message translates to:
  /// **'Écrire aux spectateurs…'**
  String get liveWriteToViewers;

  /// No description provided for @liveWriteToViewersClosed.
  ///
  /// In fr, this message translates to:
  /// **'Écrire aux spectateurs (commentaires fermés au public)…'**
  String get liveWriteToViewersClosed;

  /// No description provided for @liveConnectingToLive.
  ///
  /// In fr, this message translates to:
  /// **'Connexion au direct…'**
  String get liveConnectingToLive;

  /// No description provided for @liveCameraConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion de la caméra'**
  String get liveCameraConnection;

  /// No description provided for @liveMuteMic.
  ///
  /// In fr, this message translates to:
  /// **'Couper le micro'**
  String get liveMuteMic;

  /// No description provided for @liveRestoreMic.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir le micro'**
  String get liveRestoreMic;

  /// No description provided for @liveCameraOff.
  ///
  /// In fr, this message translates to:
  /// **'Couper la caméra'**
  String get liveCameraOff;

  /// No description provided for @liveRestoreCamera.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir la caméra'**
  String get liveRestoreCamera;

  /// No description provided for @liveConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get liveConnecting;

  /// No description provided for @liveWaitingFeed.
  ///
  /// In fr, this message translates to:
  /// **'En attente du flux'**
  String get liveWaitingFeed;

  /// No description provided for @liveGoOnAir.
  ///
  /// In fr, this message translates to:
  /// **'Passer à l\'antenne'**
  String get liveGoOnAir;

  /// No description provided for @liveAddressCopied.
  ///
  /// In fr, this message translates to:
  /// **'Adresse copiée'**
  String get liveAddressCopied;

  /// No description provided for @liveKeyCopied.
  ///
  /// In fr, this message translates to:
  /// **'Clé copiée'**
  String get liveKeyCopied;

  /// No description provided for @liveNotAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Non disponible'**
  String get liveNotAvailable;

  /// No description provided for @liveIpCamera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra IP'**
  String get liveIpCamera;

  /// No description provided for @liveFeedReceived.
  ///
  /// In fr, this message translates to:
  /// **'Flux reçu'**
  String get liveFeedReceived;

  /// No description provided for @liveRtmpServerUrl.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du serveur (URL RTMP)'**
  String get liveRtmpServerUrl;

  /// No description provided for @liveStreamKey.
  ///
  /// In fr, this message translates to:
  /// **'Clé de diffusion (ne la partagez pas)'**
  String get liveStreamKey;

  /// No description provided for @liveRtmpInstructions.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez ces deux valeurs dans la caméra, OBS ou votre encodeur, puis lancez la diffusion. Le direct ne démarre pas tout seul.'**
  String get liveRtmpInstructions;

  /// No description provided for @liveUrlInstructions.
  ///
  /// In fr, this message translates to:
  /// **'Le service vidéo se connecte lui-même à l\'adresse du flux de la caméra. Si l\'image n\'arrive pas, vérifiez que l\'adresse est joignable depuis Internet.'**
  String get liveUrlInstructions;

  /// No description provided for @liveStreamAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du flux'**
  String get liveStreamAddress;

  /// No description provided for @liveQualityExcellent.
  ///
  /// In fr, this message translates to:
  /// **'Excellent'**
  String get liveQualityExcellent;

  /// No description provided for @liveQualityGood.
  ///
  /// In fr, this message translates to:
  /// **'Bon'**
  String get liveQualityGood;

  /// No description provided for @liveQualityPoor.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get liveQualityPoor;

  /// No description provided for @liveQualityLost.
  ///
  /// In fr, this message translates to:
  /// **'Perdu'**
  String get liveQualityLost;

  /// No description provided for @liveNetworkQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité du réseau : {quality}'**
  String liveNetworkQuality(String quality);

  /// No description provided for @liveLeaveStudio.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le studio'**
  String get liveLeaveStudio;

  /// No description provided for @liveOpeningStudio.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture du studio…'**
  String get liveOpeningStudio;

  /// No description provided for @liveCannotComment.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez plus commenter ce direct'**
  String get liveCannotComment;

  /// No description provided for @liveCommentsDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires désactivés'**
  String get liveCommentsDisabled;

  /// No description provided for @liveChatHint.
  ///
  /// In fr, this message translates to:
  /// **'Chat…'**
  String get liveChatHint;

  /// No description provided for @liveHideComments.
  ///
  /// In fr, this message translates to:
  /// **'Masquer les commentaires'**
  String get liveHideComments;

  /// No description provided for @liveShowComments.
  ///
  /// In fr, this message translates to:
  /// **'Afficher les commentaires'**
  String get liveShowComments;

  /// No description provided for @liveModerationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modération du direct'**
  String get liveModerationTitle;

  /// No description provided for @liveModerationSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous regardez ce direct en tant que modérateur.'**
  String get liveModerationSubtitle;

  /// No description provided for @liveLeaveLive.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le direct'**
  String get liveLeaveLive;

  /// No description provided for @liveContinuesForOthers.
  ///
  /// In fr, this message translates to:
  /// **'Le direct continue pour les autres.'**
  String get liveContinuesForOthers;

  /// No description provided for @liveCutForAll.
  ///
  /// In fr, this message translates to:
  /// **'Couper le direct pour tous'**
  String get liveCutForAll;

  /// No description provided for @liveCutForAllHint.
  ///
  /// In fr, this message translates to:
  /// **'Arrête définitivement la diffusion.'**
  String get liveCutForAllHint;

  /// No description provided for @liveWaitingHostImage.
  ///
  /// In fr, this message translates to:
  /// **'En attente de l\'image du diffuseur…'**
  String get liveWaitingHostImage;

  /// No description provided for @liveStartingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Le direct va bientôt commencer…'**
  String get liveStartingSoon;

  /// No description provided for @liveModeration.
  ///
  /// In fr, this message translates to:
  /// **'Modération'**
  String get liveModeration;

  /// No description provided for @liveFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get liveFullscreen;

  /// No description provided for @liveExitFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le plein écran'**
  String get liveExitFullscreen;

  /// No description provided for @liveChatTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chat en direct'**
  String get liveChatTitle;

  /// No description provided for @liveReact.
  ///
  /// In fr, this message translates to:
  /// **'Réagir'**
  String get liveReact;

  /// No description provided for @liveChatEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour l\'instant.\nSoyez le premier à écrire !'**
  String get liveChatEmpty;

  /// No description provided for @liveConnectionUnstable.
  ///
  /// In fr, this message translates to:
  /// **'Connexion instable… reconnexion en cours'**
  String get liveConnectionUnstable;

  /// No description provided for @liveConnectionLost.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue'**
  String get liveConnectionLost;

  /// No description provided for @liveHostTag.
  ///
  /// In fr, this message translates to:
  /// **'Diffuseur'**
  String get liveHostTag;

  /// No description provided for @livePinMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Message à épingler…'**
  String get livePinMessageHint;

  /// No description provided for @liveDontPinMessage.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas épingler ce message'**
  String get liveDontPinMessage;

  /// No description provided for @livePinMessage.
  ///
  /// In fr, this message translates to:
  /// **'Épingler ce message en haut du direct'**
  String get livePinMessage;

  /// No description provided for @livePinnedByHost.
  ///
  /// In fr, this message translates to:
  /// **'Épinglé · {name} (diffuseur)'**
  String livePinnedByHost(String name);

  /// No description provided for @livePinnedBy.
  ///
  /// In fr, this message translates to:
  /// **'Épinglé · {name}'**
  String livePinnedBy(String name);

  /// No description provided for @liveUnpin.
  ///
  /// In fr, this message translates to:
  /// **'Désépingler'**
  String get liveUnpin;

  /// No description provided for @liveCommentUnpinned.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire désépinglé.'**
  String get liveCommentUnpinned;

  /// No description provided for @liveStatDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get liveStatDuration;

  /// No description provided for @liveStatPeakViewers.
  ///
  /// In fr, this message translates to:
  /// **'Spectateurs au plus fort'**
  String get liveStatPeakViewers;

  /// No description provided for @liveStatComments.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires'**
  String get liveStatComments;

  /// No description provided for @liveStatReactions.
  ///
  /// In fr, this message translates to:
  /// **'Réactions'**
  String get liveStatReactions;

  /// No description provided for @liveBadgeEnded.
  ///
  /// In fr, this message translates to:
  /// **'TERMINÉ'**
  String get liveBadgeEnded;

  /// No description provided for @liveYourLiveEnded.
  ///
  /// In fr, this message translates to:
  /// **'Votre direct est terminé'**
  String get liveYourLiveEnded;

  /// No description provided for @liveEnded.
  ///
  /// In fr, this message translates to:
  /// **'Direct terminé'**
  String get liveEnded;

  /// No description provided for @liveSummaryHost.
  ///
  /// In fr, this message translates to:
  /// **'Bilan de votre direct'**
  String get liveSummaryHost;

  /// No description provided for @liveSummaryNumbers.
  ///
  /// In fr, this message translates to:
  /// **'En chiffres'**
  String get liveSummaryNumbers;

  /// No description provided for @livePinTop.
  ///
  /// In fr, this message translates to:
  /// **'Épingler en haut du direct'**
  String get livePinTop;

  /// No description provided for @livePinReplaces.
  ///
  /// In fr, this message translates to:
  /// **'Remplace le commentaire actuellement épinglé.'**
  String get livePinReplaces;

  /// No description provided for @liveHostPinnedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le diffuseur a épinglé un message'**
  String get liveHostPinnedMessage;

  /// No description provided for @liveHostPinnedOnlyHost.
  ///
  /// In fr, this message translates to:
  /// **'Lui seul peut le retirer ou le remplacer.'**
  String get liveHostPinnedOnlyHost;

  /// No description provided for @liveHideComment.
  ///
  /// In fr, this message translates to:
  /// **'Masquer ce commentaire'**
  String get liveHideComment;

  /// No description provided for @liveBan.
  ///
  /// In fr, this message translates to:
  /// **'Exclure du direct'**
  String get liveBan;

  /// No description provided for @liveBanHint.
  ///
  /// In fr, this message translates to:
  /// **'Ses commentaires sont masqués ; plus de commentaires ni de réactions.'**
  String get liveBanHint;

  /// No description provided for @liveCommentPinned.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire épinglé.'**
  String get liveCommentPinned;

  /// No description provided for @liveCommentHidden.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire masqué.'**
  String get liveCommentHidden;

  /// No description provided for @liveUserBanned.
  ///
  /// In fr, this message translates to:
  /// **'{name} ne peut plus commenter ni réagir.'**
  String liveUserBanned(String name);

  /// No description provided for @liveEndConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Terminer le direct ?'**
  String get liveEndConfirmTitle;

  /// No description provided for @liveCutConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Couper ce direct ?'**
  String get liveCutConfirmTitle;

  /// No description provided for @liveEndConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Les spectateurs verront « Direct terminé ». Cette action est définitive.'**
  String get liveEndConfirmBody;

  /// No description provided for @liveCutConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Le direct sera arrêté immédiatement pour tout le monde.'**
  String get liveCutConfirmBody;

  /// No description provided for @liveCutAction.
  ///
  /// In fr, this message translates to:
  /// **'Couper le direct'**
  String get liveCutAction;

  /// No description provided for @liveSpeaker.
  ///
  /// In fr, this message translates to:
  /// **'Intervenant'**
  String get liveSpeaker;

  /// No description provided for @liveOnAirName.
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne : {name}'**
  String liveOnAirName(String name);

  /// No description provided for @liveOnAirNameMuted.
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne : {name}, micro coupé'**
  String liveOnAirNameMuted(String name);

  /// No description provided for @liveBadgeOnAir.
  ///
  /// In fr, this message translates to:
  /// **'À L\'ANTENNE'**
  String get liveBadgeOnAir;

  /// No description provided for @liveEveryoneHearsYou.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde vous entend'**
  String get liveEveryoneHearsYou;

  /// No description provided for @liveMicMutedNobodyHears.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupé : personne ne vous entend'**
  String get liveMicMutedNobodyHears;

  /// No description provided for @liveEnableMic.
  ///
  /// In fr, this message translates to:
  /// **'Activer le micro'**
  String get liveEnableMic;

  /// No description provided for @liveEnableCamera.
  ///
  /// In fr, this message translates to:
  /// **'Activer la caméra'**
  String get liveEnableCamera;

  /// No description provided for @liveLeaveStage.
  ///
  /// In fr, this message translates to:
  /// **'Quitter l\'antenne'**
  String get liveLeaveStage;

  /// No description provided for @liveSpeakers.
  ///
  /// In fr, this message translates to:
  /// **'Intervenants'**
  String get liveSpeakers;

  /// No description provided for @liveSpeakersCount.
  ///
  /// In fr, this message translates to:
  /// **'Intervenants · {count}'**
  String liveSpeakersCount(int count);

  /// No description provided for @liveRequestToSpeak.
  ///
  /// In fr, this message translates to:
  /// **'Demander à intervenir'**
  String get liveRequestToSpeak;

  /// No description provided for @liveYourTurn.
  ///
  /// In fr, this message translates to:
  /// **'C\'est votre tour !'**
  String get liveYourTurn;

  /// No description provided for @liveInQueue.
  ///
  /// In fr, this message translates to:
  /// **'En file · n°{position}'**
  String liveInQueue(String position);

  /// No description provided for @liveSpeakAction.
  ///
  /// In fr, this message translates to:
  /// **'Intervenir'**
  String get liveSpeakAction;

  /// No description provided for @liveManageSpeakers.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les intervenants'**
  String get liveManageSpeakers;

  /// No description provided for @liveRequestToSpeakLive.
  ///
  /// In fr, this message translates to:
  /// **'Demander à intervenir en direct'**
  String get liveRequestToSpeakLive;

  /// No description provided for @liveEndSpeakerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Terminer l\'intervention ?'**
  String get liveEndSpeakerTitle;

  /// No description provided for @liveEndSpeakerBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} quittera l\'antenne : son micro et sa caméra seront coupés pour tous.'**
  String liveEndSpeakerBody(String name);

  /// No description provided for @liveSpeakerEnded.
  ///
  /// In fr, this message translates to:
  /// **'Intervention terminée.'**
  String get liveSpeakerEnded;

  /// No description provided for @liveRequests.
  ///
  /// In fr, this message translates to:
  /// **'Demandes'**
  String get liveRequests;

  /// No description provided for @liveRequestsOpened.
  ///
  /// In fr, this message translates to:
  /// **'Demandes ouvertes.'**
  String get liveRequestsOpened;

  /// No description provided for @liveRequestsClosedQueueKept.
  ///
  /// In fr, this message translates to:
  /// **'Demandes fermées. La file est conservée.'**
  String get liveRequestsClosedQueueKept;

  /// No description provided for @liveOnAirCamera.
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne · caméra'**
  String get liveOnAirCamera;

  /// No description provided for @liveOnAirMicOnly.
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne · micro seulement'**
  String get liveOnAirMicOnly;

  /// No description provided for @liveInvitedWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Invité · en attente de sa réponse'**
  String get liveInvitedWaiting;

  /// No description provided for @liveInvitationCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Invitation annulée.'**
  String get liveInvitationCancelled;

  /// No description provided for @liveNobodyWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'attend pour le moment.'**
  String get liveNobodyWaiting;

  /// No description provided for @liveRemoveFromQueue.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la file'**
  String get liveRemoveFromQueue;

  /// No description provided for @liveRemovedFromQueue.
  ///
  /// In fr, this message translates to:
  /// **'Demande retirée de la file.'**
  String get liveRemovedFromQueue;

  /// No description provided for @liveInvitationSent.
  ///
  /// In fr, this message translates to:
  /// **'Invitation envoyée : {name} a {seconds} s pour accepter.'**
  String liveInvitationSent(String name, int seconds);

  /// No description provided for @liveInvite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get liveInvite;

  /// No description provided for @liveOnePersonAtATime.
  ///
  /// In fr, this message translates to:
  /// **'Une personne à la fois. L\'invitation expire après {seconds} s sans réponse.'**
  String liveOnePersonAtATime(int seconds);

  /// No description provided for @liveRequestSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée : le diffuseur vous invitera à votre tour.'**
  String get liveRequestSent;

  /// No description provided for @liveLoginRequired.
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get liveLoginRequired;

  /// No description provided for @liveLoginRequiredBody.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour demander à intervenir et partager votre témoignage en direct.'**
  String get liveLoginRequiredBody;

  /// No description provided for @liveSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get liveSignIn;

  /// No description provided for @liveYouAreOnAir.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à l\'antenne'**
  String get liveYouAreOnAir;

  /// No description provided for @liveYouAreOnAirBody.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde vous entend. Utilisez la barre en bas de l\'écran pour couper votre micro ou quitter l\'antenne.'**
  String get liveYouAreOnAirBody;

  /// No description provided for @liveHostInvitesYou.
  ///
  /// In fr, this message translates to:
  /// **'Le diffuseur vous invite à l\'antenne.'**
  String get liveHostInvitesYou;

  /// No description provided for @liveAnswerInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Répondre à l\'invitation'**
  String get liveAnswerInvitation;

  /// No description provided for @liveInvitationDeclined.
  ///
  /// In fr, this message translates to:
  /// **'Invitation refusée.'**
  String get liveInvitationDeclined;

  /// No description provided for @liveDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get liveDecline;

  /// No description provided for @liveRequestWithdrawn.
  ///
  /// In fr, this message translates to:
  /// **'Demande retirée.'**
  String get liveRequestWithdrawn;

  /// No description provided for @liveCancelMyRequest.
  ///
  /// In fr, this message translates to:
  /// **'Annuler ma demande'**
  String get liveCancelMyRequest;

  /// No description provided for @liveRequestsClosed.
  ///
  /// In fr, this message translates to:
  /// **'Demandes fermées'**
  String get liveRequestsClosed;

  /// No description provided for @liveRequestsClosedBody.
  ///
  /// In fr, this message translates to:
  /// **'Les demandes d\'intervention sont fermées pour le moment.'**
  String get liveRequestsClosedBody;

  /// No description provided for @liveTopicLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sujet de votre témoignage (facultatif)'**
  String get liveTopicLabel;

  /// No description provided for @liveTopicHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : guérison, emploi, famille…'**
  String get liveTopicHint;

  /// No description provided for @liveTopicHelper.
  ///
  /// In fr, this message translates to:
  /// **'Seuls le diffuseur et les modérateurs le lisent.'**
  String get liveTopicHelper;

  /// No description provided for @liveTestifyLive.
  ///
  /// In fr, this message translates to:
  /// **'Témoigner en direct'**
  String get liveTestifyLive;

  /// No description provided for @liveQueueNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'attend : vous serez le prochain.'**
  String get liveQueueNobody;

  /// No description provided for @liveQueueWaiting.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 personne en attente} other{{count} personnes en attente}}'**
  String liveQueueWaiting(int count);

  /// No description provided for @liveOnAirPrefix.
  ///
  /// In fr, this message translates to:
  /// **'À l\'antenne : '**
  String get liveOnAirPrefix;

  /// No description provided for @liveStepRequest.
  ///
  /// In fr, this message translates to:
  /// **'Vous demandez'**
  String get liveStepRequest;

  /// No description provided for @liveStepRequestBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom rejoint la file.'**
  String get liveStepRequestBody;

  /// No description provided for @liveStepInvited.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes invité'**
  String get liveStepInvited;

  /// No description provided for @liveStepInvitedBody.
  ///
  /// In fr, this message translates to:
  /// **'Une fenêtre s\'ouvre à votre tour.'**
  String get liveStepInvitedBody;

  /// No description provided for @liveStepSpeak.
  ///
  /// In fr, this message translates to:
  /// **'Vous parlez'**
  String get liveStepSpeak;

  /// No description provided for @liveStepSpeakBody.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupable à tout moment.'**
  String get liveStepSpeakBody;

  /// No description provided for @liveQueueNumber.
  ///
  /// In fr, this message translates to:
  /// **'n°{position}'**
  String liveQueueNumber(int position);

  /// No description provided for @liveYouAreNext.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes le prochain'**
  String get liveYouAreNext;

  /// No description provided for @liveRequestRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Demande enregistrée'**
  String get liveRequestRecorded;

  /// No description provided for @liveKeepLiveOpen.
  ///
  /// In fr, this message translates to:
  /// **'Gardez le direct ouvert : une fenêtre s\'ouvrira à votre tour.'**
  String get liveKeepLiveOpen;

  /// No description provided for @liveInvitationExpired.
  ///
  /// In fr, this message translates to:
  /// **'L\'invitation n\'est plus valable. Vous pouvez refaire une demande.'**
  String get liveInvitationExpired;

  /// No description provided for @liveJoinedMuted.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à l\'antenne, micro coupé. Activez-le quand vous êtes prêt.'**
  String get liveJoinedMuted;

  /// No description provided for @liveJoined.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à l\'antenne. Parlez librement : tout le monde vous entend.'**
  String get liveJoined;

  /// No description provided for @liveInvitationBody.
  ///
  /// In fr, this message translates to:
  /// **'Le diffuseur vous invite à l\'antenne.\nVotre voix sera entendue par tous les spectateurs.'**
  String get liveInvitationBody;

  /// No description provided for @liveEnableMyCamera.
  ///
  /// In fr, this message translates to:
  /// **'Activer ma caméra'**
  String get liveEnableMyCamera;

  /// No description provided for @liveEnableMyCameraHint.
  ///
  /// In fr, this message translates to:
  /// **'Sinon, les spectateurs voient votre nom.'**
  String get liveEnableMyCameraHint;

  /// No description provided for @liveJoinMuted.
  ///
  /// In fr, this message translates to:
  /// **'Arriver micro coupé'**
  String get liveJoinMuted;

  /// No description provided for @liveJoinMutedHint.
  ///
  /// In fr, this message translates to:
  /// **'Endroit bruyant ? Activez le micro au moment de parler.'**
  String get liveJoinMutedHint;

  /// No description provided for @liveInvitationFooter.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez couper le micro ou quitter l\'antenne à tout moment. Le diffuseur peut aussi terminer votre intervention.'**
  String get liveInvitationFooter;

  /// No description provided for @liveJoin.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get liveJoin;

  /// No description provided for @liveJoinFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de rejoindre le direct.'**
  String get liveJoinFailed;

  /// No description provided for @livesViewerCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 spectateur} =1{1 spectateur} other{{count} spectateurs}}'**
  String livesViewerCount(int count);

  /// No description provided for @livesCommentCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 commentaire} =1{1 commentaire} other{{count} commentaires}}'**
  String livesCommentCount(int count);

  /// No description provided for @liveSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get liveSeeAll;

  /// No description provided for @prayerVisibilityPublic.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde'**
  String get prayerVisibilityPublic;

  /// No description provided for @prayerVisibilityFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Mes abonnés'**
  String get prayerVisibilityFollowers;

  /// No description provided for @prayerVisibilityPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Moi seul'**
  String get prayerVisibilityPrivate;

  /// No description provided for @prayerReportInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get prayerReportInappropriate;

  /// No description provided for @prayerReportHate.
  ///
  /// In fr, this message translates to:
  /// **'Propos haineux'**
  String get prayerReportHate;

  /// No description provided for @prayerReportSpam.
  ///
  /// In fr, this message translates to:
  /// **'Publicité ou spam'**
  String get prayerReportSpam;

  /// No description provided for @prayerReportOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre raison'**
  String get prayerReportOther;

  /// No description provided for @prayerDefaultUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get prayerDefaultUser;

  /// No description provided for @prayerDefaultEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get prayerDefaultEvent;

  /// No description provided for @prayerPhaseUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get prayerPhaseUpcoming;

  /// No description provided for @prayerPhaseLive.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get prayerPhaseLive;

  /// No description provided for @prayerPhaseEnded.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get prayerPhaseEnded;

  /// No description provided for @prayerPhaseCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get prayerPhaseCancelled;

  /// No description provided for @prayerSessionDefaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Session de prière'**
  String get prayerSessionDefaultTitle;

  /// No description provided for @prayerErrorServer.
  ///
  /// In fr, this message translates to:
  /// **'Erreur du serveur ({status}).'**
  String prayerErrorServer(int status);

  /// No description provided for @prayerErrorConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre accès à Internet.'**
  String get prayerErrorConnection;

  /// No description provided for @prayerErrorRoomNotOpened.
  ///
  /// In fr, this message translates to:
  /// **'La salle n\'a pas pu être ouverte.'**
  String get prayerErrorRoomNotOpened;

  /// No description provided for @prayerAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Exaucée'**
  String get prayerAnswered;

  /// No description provided for @prayerReasonPray.
  ///
  /// In fr, this message translates to:
  /// **'prier pour cette requête'**
  String get prayerReasonPray;

  /// No description provided for @prayerRequestLabel.
  ///
  /// In fr, this message translates to:
  /// **'Requête de prière'**
  String get prayerRequestLabel;

  /// No description provided for @prayerAnonymousLower.
  ///
  /// In fr, this message translates to:
  /// **'anonyme'**
  String get prayerAnonymousLower;

  /// No description provided for @prayerPrayCount.
  ///
  /// In fr, this message translates to:
  /// **'Je prie · {count}'**
  String prayerPrayCount(int count);

  /// No description provided for @prayerHiddenByModeration.
  ///
  /// In fr, this message translates to:
  /// **'Retirée par la modération.'**
  String get prayerHiddenByModeration;

  /// No description provided for @prayerRegistered.
  ///
  /// In fr, this message translates to:
  /// **'Inscrit'**
  String get prayerRegistered;

  /// No description provided for @prayerFollowersPill.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés'**
  String get prayerFollowersPill;

  /// No description provided for @prayerSessionWhen.
  ///
  /// In fr, this message translates to:
  /// **'{date} · {minutes} min'**
  String prayerSessionWhen(String date, int minutes);

  /// No description provided for @prayerHostedBy.
  ///
  /// In fr, this message translates to:
  /// **'Animée par {name}'**
  String prayerHostedBy(String name);

  /// No description provided for @prayerRegisteredCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 inscrit} =1{1 inscrit} other{{count} inscrits}}'**
  String prayerRegisteredCount(int count);

  /// No description provided for @prayerSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Prière'**
  String get prayerSectionTitle;

  /// No description provided for @prayerRequestCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 requête} =1{1 requête} other{{count} requêtes}}'**
  String prayerRequestCount(int count);

  /// No description provided for @prayerReasonEntrust.
  ///
  /// In fr, this message translates to:
  /// **'confier une requête de prière'**
  String get prayerReasonEntrust;

  /// No description provided for @prayerEntrustRequest.
  ///
  /// In fr, this message translates to:
  /// **'Confier une requête'**
  String get prayerEntrustRequest;

  /// No description provided for @prayerScheduleSession.
  ///
  /// In fr, this message translates to:
  /// **'Programmer une session'**
  String get prayerScheduleSession;

  /// No description provided for @prayerUpcomingSessions.
  ///
  /// In fr, this message translates to:
  /// **'Sessions de prière à venir'**
  String get prayerUpcomingSessions;

  /// No description provided for @prayerSeeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout voir'**
  String get prayerSeeAll;

  /// No description provided for @prayerTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get prayerTabAll;

  /// No description provided for @prayerTabMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes requêtes'**
  String get prayerTabMine;

  /// No description provided for @prayerFilterAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Exaucées'**
  String get prayerFilterAnswered;

  /// No description provided for @prayerEmptyMine.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore confié de requête.\nLa communauté priera avec vous — vous pouvez rester anonyme.'**
  String get prayerEmptyMine;

  /// No description provided for @prayerEmptyAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Aucune requête exaucée pour le moment.'**
  String get prayerEmptyAnswered;

  /// No description provided for @prayerEmptyAll.
  ///
  /// In fr, this message translates to:
  /// **'Aucune requête de prière pour le moment.\nSoyez le premier à confier un besoin.'**
  String get prayerEmptyAll;

  /// No description provided for @prayerLoadRequestsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les requêtes.'**
  String get prayerLoadRequestsError;

  /// No description provided for @prayerVerseJames.
  ///
  /// In fr, this message translates to:
  /// **'« Priez les uns pour les autres, afin que vous soyez guéris. La prière agissante du juste a une grande efficacité. »'**
  String get prayerVerseJames;

  /// No description provided for @prayerVerseJamesRef.
  ///
  /// In fr, this message translates to:
  /// **'Jacques 5:16'**
  String get prayerVerseJamesRef;

  /// No description provided for @prayerSessionMustBeFuture.
  ///
  /// In fr, this message translates to:
  /// **'La session doit être programmée dans le futur.'**
  String get prayerSessionMustBeFuture;

  /// No description provided for @prayerSessionUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Session mise à jour.'**
  String get prayerSessionUpdated;

  /// No description provided for @prayerSessionScheduled.
  ///
  /// In fr, this message translates to:
  /// **'Session de prière programmée.'**
  String get prayerSessionScheduled;

  /// No description provided for @prayerEditSession.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la session'**
  String get prayerEditSession;

  /// No description provided for @prayerSessionNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Session introuvable.'**
  String get prayerSessionNotFound;

  /// No description provided for @prayerSessionFormIntro.
  ///
  /// In fr, this message translates to:
  /// **'À l\'heure prévue, vous ouvrez la salle (caméra ou micro) : les inscrits rejoignent, commentent et peuvent prendre la parole à tour de rôle.'**
  String get prayerSessionFormIntro;

  /// No description provided for @prayerSessionLinkedToEvent.
  ///
  /// In fr, this message translates to:
  /// **'Session rattachée à l\'événement.'**
  String get prayerSessionLinkedToEvent;

  /// No description provided for @prayerSessionTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre *'**
  String get prayerSessionTitleLabel;

  /// No description provided for @prayerSessionTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Veillée de prière pour les familles'**
  String get prayerSessionTitleHint;

  /// No description provided for @prayerSessionTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Donnez un titre à la session.'**
  String get prayerSessionTitleRequired;

  /// No description provided for @prayerSessionDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Présentation'**
  String get prayerSessionDescriptionLabel;

  /// No description provided for @prayerSessionTopics.
  ///
  /// In fr, this message translates to:
  /// **'Sujets de prière'**
  String get prayerSessionTopics;

  /// No description provided for @prayerTopicsMax.
  ///
  /// In fr, this message translates to:
  /// **'10 sujets au plus'**
  String get prayerTopicsMax;

  /// No description provided for @prayerAddTopicHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un sujet'**
  String get prayerAddTopicHint;

  /// No description provided for @prayerAddTopicTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le sujet'**
  String get prayerAddTopicTooltip;

  /// No description provided for @prayerWhen.
  ///
  /// In fr, this message translates to:
  /// **'Quand ?'**
  String get prayerWhen;

  /// No description provided for @prayerDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get prayerDuration;

  /// No description provided for @prayerDurationMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String prayerDurationMinutes(int minutes);

  /// No description provided for @prayerDurationHours.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h'**
  String prayerDurationHours(int hours);

  /// No description provided for @prayerDurationHoursMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes}'**
  String prayerDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @prayerReminderInfo.
  ///
  /// In fr, this message translates to:
  /// **'Les inscrits reçoivent un rappel 15 minutes avant.'**
  String get prayerReminderInfo;

  /// No description provided for @prayerWhoCanSee.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut la voir ?'**
  String get prayerWhoCanSee;

  /// No description provided for @prayerScheduleTheSession.
  ///
  /// In fr, this message translates to:
  /// **'Programmer la session'**
  String get prayerScheduleTheSession;

  /// No description provided for @prayerSessionsTabUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get prayerSessionsTabUpcoming;

  /// No description provided for @prayerSessionsTabJoined.
  ///
  /// In fr, this message translates to:
  /// **'Mes inscriptions'**
  String get prayerSessionsTabJoined;

  /// No description provided for @prayerSessionsTabHosting.
  ///
  /// In fr, this message translates to:
  /// **'Que j\'anime'**
  String get prayerSessionsTabHosting;

  /// No description provided for @prayerSessionsTabPast.
  ///
  /// In fr, this message translates to:
  /// **'Passées'**
  String get prayerSessionsTabPast;

  /// No description provided for @prayerReasonSchedule.
  ///
  /// In fr, this message translates to:
  /// **'programmer une session de prière'**
  String get prayerReasonSchedule;

  /// No description provided for @prayerSchedule.
  ///
  /// In fr, this message translates to:
  /// **'Programmer'**
  String get prayerSchedule;

  /// No description provided for @prayerSessionsEmptyJoined.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes inscrit à aucune session.\nTouchez « Je serai là » sur une session à venir.'**
  String get prayerSessionsEmptyJoined;

  /// No description provided for @prayerSessionsEmptyHosting.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'animez aucune session.\nProgrammez un temps de prière : les inscrits seront prévenus.'**
  String get prayerSessionsEmptyHosting;

  /// No description provided for @prayerSessionsEmptyPast.
  ///
  /// In fr, this message translates to:
  /// **'Aucune session passée.'**
  String get prayerSessionsEmptyPast;

  /// No description provided for @prayerSessionsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune session de prière programmée pour le moment.'**
  String get prayerSessionsEmpty;

  /// No description provided for @prayerLoadSessionsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les sessions.'**
  String get prayerLoadSessionsError;

  /// No description provided for @prayerHintPublic.
  ///
  /// In fr, this message translates to:
  /// **'Visible de tous, même sans compte.'**
  String get prayerHintPublic;

  /// No description provided for @prayerHintFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Visible des personnes qui vous suivent.'**
  String get prayerHintFollowers;

  /// No description provided for @prayerHintPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Visible de vous seul (carnet de prière personnel).'**
  String get prayerHintPrivate;

  /// No description provided for @prayerRequestPublished.
  ///
  /// In fr, this message translates to:
  /// **'Votre requête est publiée. Que Dieu vous réponde !'**
  String get prayerRequestPublished;

  /// No description provided for @prayerRequestLinkedToEvent.
  ///
  /// In fr, this message translates to:
  /// **'Rattachée à l\'événement : elle apparaîtra sur sa page.'**
  String get prayerRequestLinkedToEvent;

  /// No description provided for @prayerYourRequest.
  ///
  /// In fr, this message translates to:
  /// **'Votre requête'**
  String get prayerYourRequest;

  /// No description provided for @prayerRequestEmptyError.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez votre requête de prière.'**
  String get prayerRequestEmptyError;

  /// No description provided for @prayerRequestTooShort.
  ///
  /// In fr, this message translates to:
  /// **'Votre requête est trop courte (10 caractères au moins).'**
  String get prayerRequestTooShort;

  /// No description provided for @prayerRequestHint.
  ///
  /// In fr, this message translates to:
  /// **'Pour quoi souhaitez-vous que l\'on prie ? (@ pour mentionner)'**
  String get prayerRequestHint;

  /// No description provided for @prayerRequestHelperPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Évitez les informations trop personnelles. Requête privée : personne n\'est prévenu des mentions.'**
  String get prayerRequestHelperPrivate;

  /// No description provided for @prayerRequestHelper.
  ///
  /// In fr, this message translates to:
  /// **'Évitez les informations trop personnelles (adresse, téléphone…). Les personnes mentionnées qui peuvent voir la requête sont prévenues.'**
  String get prayerRequestHelper;

  /// No description provided for @prayerPostAnonymously.
  ///
  /// In fr, this message translates to:
  /// **'Publier anonymement'**
  String get prayerPostAnonymously;

  /// No description provided for @prayerPostAnonymouslyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Votre nom est masqué pour les autres. Il reste visible de vous et de l\'équipe de modération.'**
  String get prayerPostAnonymouslyDesc;

  /// No description provided for @prayerPublishMyRequest.
  ///
  /// In fr, this message translates to:
  /// **'Publier ma requête'**
  String get prayerPublishMyRequest;

  /// No description provided for @prayerAnsweredDialogTitle.
  ///
  /// In fr, this message translates to:
  /// **'Elle est exaucée !'**
  String get prayerAnsweredDialogTitle;

  /// No description provided for @prayerAnsweredNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Dieu a fait (facultatif)'**
  String get prayerAnsweredNoteHint;

  /// No description provided for @prayerAnsweredSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Gloire à Dieu ! Pensez à témoigner de cet exaucement.'**
  String get prayerAnsweredSuccess;

  /// No description provided for @prayerDeleteRequestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la requête ?'**
  String get prayerDeleteRequestTitle;

  /// No description provided for @prayerDeleteRequestBody.
  ///
  /// In fr, this message translates to:
  /// **'La requête et ses messages d\'encouragement seront supprimés.'**
  String get prayerDeleteRequestBody;

  /// No description provided for @prayerRequestDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Requête supprimée.'**
  String get prayerRequestDeleted;

  /// No description provided for @prayerReasonReport.
  ///
  /// In fr, this message translates to:
  /// **'signaler un contenu'**
  String get prayerReasonReport;

  /// No description provided for @prayerReportSaved.
  ///
  /// In fr, this message translates to:
  /// **'Signalement enregistré. Merci pour votre vigilance.'**
  String get prayerReportSaved;

  /// No description provided for @prayerReasonEncourage.
  ///
  /// In fr, this message translates to:
  /// **'encourager cette personne'**
  String get prayerReasonEncourage;

  /// No description provided for @prayerEncouragementThanks.
  ///
  /// In fr, this message translates to:
  /// **'Merci pour votre encouragement !'**
  String get prayerEncouragementThanks;

  /// No description provided for @prayerRequestReopened.
  ///
  /// In fr, this message translates to:
  /// **'Requête remise en attente.'**
  String get prayerRequestReopened;

  /// No description provided for @prayerEncouragementsCount.
  ///
  /// In fr, this message translates to:
  /// **'Encouragements ({count})'**
  String prayerEncouragementsCount(int count);

  /// No description provided for @prayerLeaveEncouragement.
  ///
  /// In fr, this message translates to:
  /// **'Laisser un encouragement'**
  String get prayerLeaveEncouragement;

  /// No description provided for @prayerLoadRequestError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la requête.'**
  String get prayerLoadRequestError;

  /// No description provided for @prayerHiddenNotice.
  ///
  /// In fr, this message translates to:
  /// **'{reason} Elle n\'est plus visible des autres.'**
  String prayerHiddenNotice(String reason);

  /// No description provided for @prayerAnsweredGlory.
  ///
  /// In fr, this message translates to:
  /// **'Exaucée — gloire à Dieu !'**
  String get prayerAnsweredGlory;

  /// No description provided for @prayerReadTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Lire le témoignage'**
  String get prayerReadTestimony;

  /// No description provided for @prayerPeoplePraying.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Soyez le premier à prier} =1{1 personne prie} other{{count} personnes prient}}'**
  String prayerPeoplePraying(int count);

  /// No description provided for @prayerShareTitle.
  ///
  /// In fr, this message translates to:
  /// **'Requête de prière de {name}'**
  String prayerShareTitle(String name);

  /// No description provided for @prayerTestifyAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Témoignez de cet exaucement'**
  String get prayerTestifyAnswer;

  /// No description provided for @prayerGodAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Dieu a répondu ?'**
  String get prayerGodAnswered;

  /// No description provided for @prayerTestifyAnswerDesc.
  ///
  /// In fr, this message translates to:
  /// **'Racontez ce que Dieu a fait : votre témoignage fortifiera ceux qui prient encore.'**
  String get prayerTestifyAnswerDesc;

  /// No description provided for @prayerMarkAnsweredDesc.
  ///
  /// In fr, this message translates to:
  /// **'Marquez la requête exaucée : ceux qui ont prié avec vous le verront.'**
  String get prayerMarkAnsweredDesc;

  /// No description provided for @prayerItIsAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Elle est exaucée'**
  String get prayerItIsAnswered;

  /// No description provided for @prayerTestify.
  ///
  /// In fr, this message translates to:
  /// **'Témoigner'**
  String get prayerTestify;

  /// No description provided for @prayerSetPending.
  ///
  /// In fr, this message translates to:
  /// **'Remettre en attente'**
  String get prayerSetPending;

  /// No description provided for @prayerNoMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour le moment. Un verset, une parole d\'encouragement peuvent fortifier.'**
  String get prayerNoMessages;

  /// No description provided for @prayerDeleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le message'**
  String get prayerDeleteMessage;

  /// No description provided for @prayerMessagesUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Messages indisponibles.'**
  String get prayerMessagesUnavailable;

  /// No description provided for @prayerMessageHintMention.
  ///
  /// In fr, this message translates to:
  /// **'Je prie avec vous… (@ pour mentionner)'**
  String get prayerMessageHintMention;

  /// No description provided for @prayerMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Message d\'encouragement'**
  String get prayerMessageLabel;

  /// No description provided for @prayerVerseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Verset (facultatif)'**
  String get prayerVerseLabel;

  /// No description provided for @prayerVerseHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Philippiens 4:6-7'**
  String get prayerVerseHint;

  /// No description provided for @prayerReportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler la requête'**
  String get prayerReportTitle;

  /// No description provided for @prayerReportInfo.
  ///
  /// In fr, this message translates to:
  /// **'Au 3e signalement, la requête est retirée en attendant la modération.'**
  String get prayerReportInfo;

  /// No description provided for @prayerReportDetailsHint.
  ///
  /// In fr, this message translates to:
  /// **'Précisions (facultatif)'**
  String get prayerReportDetailsHint;

  /// No description provided for @prayerReportSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get prayerReportSend;

  /// No description provided for @prayerReasonRegister.
  ///
  /// In fr, this message translates to:
  /// **'vous inscrire à la session'**
  String get prayerReasonRegister;

  /// No description provided for @prayerRegistrationRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Inscription retirée.'**
  String get prayerRegistrationRemoved;

  /// No description provided for @prayerRegistrationSaved.
  ///
  /// In fr, this message translates to:
  /// **'Inscription enregistrée : vous serez prévenu à l\'ouverture de la salle.'**
  String get prayerRegistrationSaved;

  /// No description provided for @prayerCancelSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la session ?'**
  String get prayerCancelSessionTitle;

  /// No description provided for @prayerCancelSessionBody.
  ///
  /// In fr, this message translates to:
  /// **'Elle restera visible comme « Annulée » ; la salle sera fermée.'**
  String get prayerCancelSessionBody;

  /// No description provided for @prayerCancelSession.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la session'**
  String get prayerCancelSession;

  /// No description provided for @prayerSessionCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Session annulée.'**
  String get prayerSessionCancelled;

  /// No description provided for @prayerDeleteSessionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la session ?'**
  String get prayerDeleteSessionTitle;

  /// No description provided for @prayerDeleteSessionBody.
  ///
  /// In fr, this message translates to:
  /// **'La session sera supprimée et sa salle fermée si elle est ouverte.'**
  String get prayerDeleteSessionBody;

  /// No description provided for @prayerSessionDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Session supprimée.'**
  String get prayerSessionDeleted;

  /// No description provided for @prayerLoadSessionError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la session.'**
  String get prayerLoadSessionError;

  /// No description provided for @prayerFollowersOnly.
  ///
  /// In fr, this message translates to:
  /// **'· Réservée aux abonnés'**
  String get prayerFollowersOnly;

  /// No description provided for @prayerSessionWasCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Cette session a été annulée.'**
  String get prayerSessionWasCancelled;

  /// No description provided for @prayerReturnToRoom.
  ///
  /// In fr, this message translates to:
  /// **'Retourner dans la salle'**
  String get prayerReturnToRoom;

  /// No description provided for @prayerOpenRoom.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir la salle'**
  String get prayerOpenRoom;

  /// No description provided for @prayerOpenRoomInfo.
  ///
  /// In fr, this message translates to:
  /// **'Vous arrivez dans le studio : passez à l\'antenne pour commencer. Les inscrits sont prévenus.'**
  String get prayerOpenRoomInfo;

  /// No description provided for @prayerCanOpenRoomFrom.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez ouvrir la salle à partir du {date}.'**
  String prayerCanOpenRoomFrom(String date);

  /// No description provided for @prayerSessionEnded.
  ///
  /// In fr, this message translates to:
  /// **'Cette session est terminée.'**
  String get prayerSessionEnded;

  /// No description provided for @prayerJoinRoom.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre la salle'**
  String get prayerJoinRoom;

  /// No description provided for @prayerJoinRoomInfo.
  ///
  /// In fr, this message translates to:
  /// **'Commentez et demandez à prendre la parole depuis la salle.'**
  String get prayerJoinRoomInfo;

  /// No description provided for @prayerRoomWillOpenNotified.
  ///
  /// In fr, this message translates to:
  /// **'La salle s\'ouvrira à l\'heure prévue : vous serez prévenu.'**
  String get prayerRoomWillOpenNotified;

  /// No description provided for @prayerRoomWillOpen.
  ///
  /// In fr, this message translates to:
  /// **'La salle s\'ouvrira à l\'heure prévue.'**
  String get prayerRoomWillOpen;

  /// No description provided for @prayerIWillBeThere.
  ///
  /// In fr, this message translates to:
  /// **'Je serai là'**
  String get prayerIWillBeThere;

  /// No description provided for @prayerTapAgainToUnregister.
  ///
  /// In fr, this message translates to:
  /// **'Toucher à nouveau pour retirer l\'inscription.'**
  String get prayerTapAgainToUnregister;

  /// No description provided for @prayerRoomTitle.
  ///
  /// In fr, this message translates to:
  /// **'La salle de prière'**
  String get prayerRoomTitle;

  /// No description provided for @testimonyDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce témoignage ?'**
  String get testimonyDeleteTitle;

  /// No description provided for @testimonyDeleteMineBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Le témoignage sera définitivement supprimé.'**
  String get testimonyDeleteMineBody;

  /// No description provided for @testimonyDeleteOtherBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce témoignage de {name} sera définitivement supprimé, avec ses commentaires et ses réactions.'**
  String testimonyDeleteOtherBody(String name);

  /// No description provided for @testimonyDeleteError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer. Réessayez.'**
  String get testimonyDeleteError;

  /// No description provided for @testimonyDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage supprimé.'**
  String get testimonyDeleted;

  /// No description provided for @shortsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun Short disponible'**
  String get shortsEmptyTitle;

  /// No description provided for @shortsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Publiez une vidéo courte pour commencer.'**
  String get shortsEmptyBody;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonFalseTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Faux témoignage'**
  String get reportReasonFalseTestimony;

  /// No description provided for @reportReasonHate.
  ///
  /// In fr, this message translates to:
  /// **'Discours haineux'**
  String get reportReasonHate;

  /// No description provided for @reportReasonSpam.
  ///
  /// In fr, this message translates to:
  /// **'Spam ou publicité'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre raison'**
  String get reportReasonOther;

  /// No description provided for @reportGuestReason.
  ///
  /// In fr, this message translates to:
  /// **'signaler un contenu'**
  String get reportGuestReason;

  /// No description provided for @reportSent.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé. Merci pour votre contribution.'**
  String get reportSent;

  /// No description provided for @reportError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Veuillez réessayer.'**
  String get reportError;

  /// No description provided for @reportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signaler ce témoignage'**
  String get reportTitle;

  /// No description provided for @reportIntro.
  ///
  /// In fr, this message translates to:
  /// **'Votre signalement est anonyme et sera examiné par notre équipe de modération.'**
  String get reportIntro;

  /// No description provided for @reportReasonTitle.
  ///
  /// In fr, this message translates to:
  /// **'Raison du signalement'**
  String get reportReasonTitle;

  /// No description provided for @reportReasonSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez la raison qui correspond le mieux'**
  String get reportReasonSubtitle;

  /// No description provided for @reportDetailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détails supplémentaires (optionnel)'**
  String get reportDetailsTitle;

  /// No description provided for @reportDetailsHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème avec plus de précision…'**
  String get reportDetailsHint;

  /// No description provided for @reportSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get reportSubmit;

  /// No description provided for @testimonyTtsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La lecture vocale n\'est pas disponible sur cet appareil (aucune voix installée pour cette langue).'**
  String get testimonyTtsUnavailable;

  /// No description provided for @testimonyTtsReading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture en cours'**
  String get testimonyTtsReading;

  /// No description provided for @testimonyTtsPaused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get testimonyTtsPaused;

  /// No description provided for @testimonyTtsReadAloud.
  ///
  /// In fr, this message translates to:
  /// **'Lecture vocale du texte'**
  String get testimonyTtsReadAloud;

  /// No description provided for @testimonyTtsPause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get testimonyTtsPause;

  /// No description provided for @testimonyTtsListen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get testimonyTtsListen;

  /// No description provided for @testimonyTtsListenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Écouter ce témoignage'**
  String get testimonyTtsListenTitle;

  /// No description provided for @testimonyTtsStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get testimonyTtsStop;

  /// No description provided for @testimonyTtsOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options de lecture'**
  String get testimonyTtsOptions;

  /// No description provided for @testimonyTtsAutoRead.
  ///
  /// In fr, this message translates to:
  /// **'Lecture automatique'**
  String get testimonyTtsAutoRead;

  /// No description provided for @testimonyAgoJustNow.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get testimonyAgoJustNow;

  /// No description provided for @testimonyAgoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} min'**
  String testimonyAgoMinutes(int count);

  /// No description provided for @testimonyAgoHours.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{il y a 1 heure} other{il y a {count} heures}}'**
  String testimonyAgoHours(int count);

  /// No description provided for @testimonyAgoDays.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{il y a 1 jour} other{il y a {count} jours}}'**
  String testimonyAgoDays(int count);

  /// No description provided for @testimonyAgoMonths.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} mois'**
  String testimonyAgoMonths(int count);

  /// No description provided for @testimonyAgoYears.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{il y a 1 an} other{il y a {count} ans}}'**
  String testimonyAgoYears(int count);

  /// No description provided for @testimonyViews.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{{formatted} vue} =1{{formatted} vue} other{{formatted} vues}}'**
  String testimonyViews(int count, String formatted);

  /// No description provided for @testimonyLikeSemantic.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get testimonyLikeSemantic;

  /// No description provided for @testimonyPraySemantic.
  ///
  /// In fr, this message translates to:
  /// **'Je prie'**
  String get testimonyPraySemantic;

  /// No description provided for @testimonyShareSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get testimonyShareSemantic;

  /// No description provided for @testimonyCommentsSemantic.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires'**
  String get testimonyCommentsSemantic;

  /// No description provided for @testimonyWordOfGod.
  ///
  /// In fr, this message translates to:
  /// **'Parole de Dieu'**
  String get testimonyWordOfGod;

  /// No description provided for @testimonyOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get testimonyOffline;

  /// No description provided for @commentsTitleCount.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires ({count})'**
  String commentsTitleCount(int count);

  /// No description provided for @commentsReplies.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 réponse} other{{count} réponses}}'**
  String commentsReplies(int count);

  /// No description provided for @commentsDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce commentaire ?'**
  String get commentsDeleteTitle;

  /// No description provided for @commentsDeleteIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get commentsDeleteIrreversible;

  /// No description provided for @commentsJustNow.
  ///
  /// In fr, this message translates to:
  /// **'À l\'instant'**
  String get commentsJustNow;

  /// No description provided for @commentsEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun commentaire'**
  String get commentsEmptyTitle;

  /// No description provided for @commentsEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à réagir !'**
  String get commentsEmptyBody;

  /// No description provided for @commentsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les commentaires'**
  String get commentsLoadError;

  /// No description provided for @commentsAgoHoursShort.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count}h'**
  String commentsAgoHoursShort(int count);

  /// No description provided for @commentsAgoDaysShort.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count}j'**
  String commentsAgoDaysShort(int count);

  /// No description provided for @commentsDeletePermanent.
  ///
  /// In fr, this message translates to:
  /// **'Le commentaire sera définitivement supprimé.'**
  String get commentsDeletePermanent;

  /// No description provided for @testimonyDeleteTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le témoignage'**
  String get testimonyDeleteTooltip;

  /// No description provided for @playerQualityAdjusted.
  ///
  /// In fr, this message translates to:
  /// **'Qualité ajustée : {label} ({network})'**
  String playerQualityAdjusted(String label, String network);

  /// No description provided for @playerNetworkMobile.
  ///
  /// In fr, this message translates to:
  /// **'données mobiles'**
  String get playerNetworkMobile;

  /// No description provided for @playerNetworkWifi.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi'**
  String get playerNetworkWifi;

  /// No description provided for @playerQualityOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Originale'**
  String get playerQualityOriginal;

  /// No description provided for @playerQualityLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger cette qualité.'**
  String get playerQualityLoadError;

  /// No description provided for @playerMobileDataHint.
  ///
  /// In fr, this message translates to:
  /// **'Données mobiles · {label}'**
  String playerMobileDataHint(String label);

  /// No description provided for @playerQualityAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get playerQualityAuto;

  /// No description provided for @playerQualityAutoWith.
  ///
  /// In fr, this message translates to:
  /// **'Auto · {label}'**
  String playerQualityAutoWith(String label);

  /// No description provided for @playerQualitiesPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Les autres qualités sont en préparation : réessayez dans quelques minutes.'**
  String get playerQualitiesPreparing;

  /// No description provided for @playerSingleQualityVideo.
  ///
  /// In fr, this message translates to:
  /// **'Une seule qualité est disponible pour cette vidéo.'**
  String get playerSingleQualityVideo;

  /// No description provided for @playerSingleQualityAudio.
  ///
  /// In fr, this message translates to:
  /// **'Une seule qualité est disponible pour cet audio.'**
  String get playerSingleQualityAudio;

  /// No description provided for @playerVideoQualitySettingsHint.
  ///
  /// In fr, this message translates to:
  /// **'Qualité par défaut modifiable dans Paramètres › Qualité vidéo.'**
  String get playerVideoQualitySettingsHint;

  /// No description provided for @playerVideoQualityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qualité de la vidéo'**
  String get playerVideoQualityTitle;

  /// No description provided for @playerQualityThisPlaybackOnly.
  ///
  /// In fr, this message translates to:
  /// **'Ce choix vaut pour cette lecture uniquement.\n{settingsHint}'**
  String playerQualityThisPlaybackOnly(String settingsHint);

  /// No description provided for @playerRemoveFromFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get playerRemoveFromFavorites;

  /// No description provided for @playerAutoplay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture auto'**
  String get playerAutoplay;

  /// No description provided for @playerQualitySwitching.
  ///
  /// In fr, this message translates to:
  /// **'Changement de qualité…'**
  String get playerQualitySwitching;

  /// No description provided for @playerUpNextIn.
  ///
  /// In fr, this message translates to:
  /// **'Suivant dans {seconds} s'**
  String playerUpNextIn(int seconds);

  /// No description provided for @playerCommentsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{{formatted} commentaire} =1{{formatted} commentaire} other{{formatted} commentaires}}'**
  String playerCommentsCount(int count, String formatted);

  /// No description provided for @playerRelatedVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos similaires'**
  String get playerRelatedVideos;

  /// No description provided for @commentsAddHintDots.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire...'**
  String get commentsAddHintDots;

  /// No description provided for @shortsMobileDataTapToPlay.
  ///
  /// In fr, this message translates to:
  /// **'Données mobiles · touchez pour lire'**
  String get shortsMobileDataTapToPlay;

  /// No description provided for @shortsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardé'**
  String get shortsSaved;

  /// No description provided for @shortsSharedFromApp.
  ///
  /// In fr, this message translates to:
  /// **'Partagé depuis l\'application My Testimony ✝️'**
  String get shortsSharedFromApp;

  /// No description provided for @shortsMe.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get shortsMe;

  /// No description provided for @shortsAgoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count}min'**
  String shortsAgoMinutes(int count);

  /// No description provided for @accountsOwnerOnlyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Revenez sur votre compte pour cette action.'**
  String get accountsOwnerOnlyMessage;

  /// No description provided for @accountsSwitchFailed.
  ///
  /// In fr, this message translates to:
  /// **'Bascule impossible. Réessayez.'**
  String get accountsSwitchFailed;

  /// No description provided for @accountsBackToOwn.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes revenu sur votre compte.'**
  String get accountsBackToOwn;

  /// No description provided for @accountsActingAs.
  ///
  /// In fr, this message translates to:
  /// **'Vous agissez au nom de {name}'**
  String accountsActingAs(String name);

  /// No description provided for @accountsMyAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Mes comptes'**
  String get accountsMyAccounts;

  /// No description provided for @accountsSwitcherIntro.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez le compte au nom duquel vous agissez : publications, commentaires, réactions et abonnements seront faits en son nom.'**
  String get accountsSwitcherIntro;

  /// No description provided for @accountsNoOtherManaged.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez aucun autre compte pour le moment.'**
  String get accountsNoOtherManaged;

  /// No description provided for @accountsLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible.'**
  String get accountsLoadFailed;

  /// No description provided for @accountsManagersTitle.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs du compte'**
  String get accountsManagersTitle;

  /// No description provided for @accountsOrganization.
  ///
  /// In fr, this message translates to:
  /// **'Organisation'**
  String get accountsOrganization;

  /// No description provided for @accountsActive.
  ///
  /// In fr, this message translates to:
  /// **'Compte actif'**
  String get accountsActive;

  /// No description provided for @accountsActingAsPrefix.
  ///
  /// In fr, this message translates to:
  /// **'Vous agissez au nom de '**
  String get accountsActingAsPrefix;

  /// No description provided for @accountsReturnToMine.
  ///
  /// In fr, this message translates to:
  /// **'Revenir à mon compte'**
  String get accountsReturnToMine;

  /// No description provided for @accountsActingAsOwnerOnly.
  ///
  /// In fr, this message translates to:
  /// **'Vous agissez au nom de {name}. {message}'**
  String accountsActingAsOwnerOnly(String name, String message);

  /// No description provided for @accountsReturn.
  ///
  /// In fr, this message translates to:
  /// **'Revenir'**
  String get accountsReturn;

  /// No description provided for @accountsAddManager.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un administrateur'**
  String get accountsAddManager;

  /// No description provided for @accountsManagerAdded.
  ///
  /// In fr, this message translates to:
  /// **'{name} peut maintenant agir en votre nom.'**
  String accountsManagerAdded(String name);

  /// No description provided for @accountsRemoveManagerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer cet administrateur ?'**
  String get accountsRemoveManagerTitle;

  /// No description provided for @accountsRemoveManagerBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} ne pourra plus agir au nom de votre compte.'**
  String accountsRemoveManagerBody(String name);

  /// No description provided for @accountsManagerRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Administrateur retiré.'**
  String get accountsManagerRemoved;

  /// No description provided for @accountsLeaveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus administrer ce compte ?'**
  String get accountsLeaveTitle;

  /// No description provided for @accountsLeaveBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pourrez plus agir au nom de {name}. Seul son titulaire pourra vous nommer à nouveau.'**
  String accountsLeaveBody(String name);

  /// No description provided for @accountsLeaveAction.
  ///
  /// In fr, this message translates to:
  /// **'Me retirer'**
  String get accountsLeaveAction;

  /// No description provided for @accountsLeft.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez plus {name}.'**
  String accountsLeft(String name);

  /// No description provided for @accountsManagersExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Désignez jusqu\'à deux personnes de confiance : avec leur propre compte, elles agissent en votre nom (témoignages, événements, prière, commentaires, réactions, abonnements). Elles ne peuvent pas changer vos identifiants, supprimer le compte, nommer d\'autres administrateurs, ni voir votre carnet privé. Vous pouvez les retirer à tout moment.'**
  String get accountsManagersExplanation;

  /// No description provided for @accountsManagersCount.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs ({count}/{max})'**
  String accountsManagersCount(int count, int max);

  /// No description provided for @accountsNoManagers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun administrateur pour le moment.'**
  String get accountsNoManagers;

  /// No description provided for @accountsManagerSince.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le {date}'**
  String accountsManagerSince(String date);

  /// No description provided for @accountsManagersFull.
  ///
  /// In fr, this message translates to:
  /// **'Deux administrateurs au plus'**
  String get accountsManagersFull;

  /// No description provided for @accountsManagersSection.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs'**
  String get accountsManagersSection;

  /// No description provided for @accountsActivityLog.
  ///
  /// In fr, this message translates to:
  /// **'Journal des actions'**
  String get accountsActivityLog;

  /// No description provided for @accountsNoActivity.
  ///
  /// In fr, this message translates to:
  /// **'Aucune action faite en votre nom pour le moment.'**
  String get accountsNoActivity;

  /// No description provided for @accountsManagedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comptes que j\'administre'**
  String get accountsManagedTitle;

  /// No description provided for @accountsNoneManaged.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez aucun compte.'**
  String get accountsNoneManaged;

  /// No description provided for @accountsActOnBehalf.
  ///
  /// In fr, this message translates to:
  /// **'Agir en son nom'**
  String get accountsActOnBehalf;

  /// No description provided for @accountsDateNumeric.
  ///
  /// In fr, this message translates to:
  /// **'{day}/{month}/{year}'**
  String accountsDateNumeric(String day, String month, String year);

  /// No description provided for @accountsDateTimeAt.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {hour}h{minute}'**
  String accountsDateTimeAt(String date, String hour, String minute);

  /// No description provided for @accountsConnectionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre réseau.'**
  String get accountsConnectionFailed;

  /// No description provided for @accountsUnexpectedResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue du serveur.'**
  String get accountsUnexpectedResponse;

  /// No description provided for @accountsFallbackName.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get accountsFallbackName;

  /// No description provided for @accountsFallbackActor.
  ///
  /// In fr, this message translates to:
  /// **'Un administrateur'**
  String get accountsFallbackActor;

  /// No description provided for @accountsNoLongerManaged.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez plus ce compte.'**
  String get accountsNoLongerManaged;

  /// No description provided for @profileRolePastor.
  ///
  /// In fr, this message translates to:
  /// **'Pasteur'**
  String get profileRolePastor;

  /// No description provided for @profileRoleEvangelist.
  ///
  /// In fr, this message translates to:
  /// **'Évangéliste'**
  String get profileRoleEvangelist;

  /// No description provided for @profileRoleSinger.
  ///
  /// In fr, this message translates to:
  /// **'Chantre'**
  String get profileRoleSinger;

  /// No description provided for @profileRoleMinistryLeader.
  ///
  /// In fr, this message translates to:
  /// **'Responsable de ministère'**
  String get profileRoleMinistryLeader;

  /// No description provided for @profileRolePublicFigure.
  ///
  /// In fr, this message translates to:
  /// **'Personnalité publique'**
  String get profileRolePublicFigure;

  /// No description provided for @profileRoleOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get profileRoleOther;

  /// No description provided for @profileVerifDocType.
  ///
  /// In fr, this message translates to:
  /// **'Pièce justificative : photo (JPG, PNG, WebP) ou PDF.'**
  String get profileVerifDocType;

  /// No description provided for @profileVerifDocTooBig.
  ///
  /// In fr, this message translates to:
  /// **'Chaque pièce justificative doit faire {mb} Mo au plus.'**
  String profileVerifDocTooBig(int mb);

  /// No description provided for @profileVerifFullNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre nom complet.'**
  String get profileVerifFullNameRequired;

  /// No description provided for @profileVerifRoleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre fonction.'**
  String get profileVerifRoleRequired;

  /// No description provided for @profileVerifRoleOtherRequired.
  ///
  /// In fr, this message translates to:
  /// **'Précisez votre fonction.'**
  String get profileVerifRoleOtherRequired;

  /// No description provided for @profileVerifChurchRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez votre église ou votre ministère.'**
  String get profileVerifChurchRequired;

  /// No description provided for @profileVerifLinkInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse web attendue (https://…).'**
  String get profileVerifLinkInvalid;

  /// No description provided for @profileVerifDocRequired.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez au moins une pièce justificative.'**
  String get profileVerifDocRequired;

  /// No description provided for @profileVerifDocMax.
  ///
  /// In fr, this message translates to:
  /// **'{count} pièces justificatives au plus.'**
  String profileVerifDocMax(int count);

  /// No description provided for @profileFallbackUser.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get profileFallbackUser;

  /// No description provided for @profileMemberSinceMonthYear.
  ///
  /// In fr, this message translates to:
  /// **'Membre depuis {month, select, 1{Janvier} 2{Février} 3{Mars} 4{Avril} 5{Mai} 6{Juin} 7{Juillet} 8{Août} 9{Septembre} 10{Octobre} 11{Novembre} 12{Décembre} other{{month}}} {year}'**
  String profileMemberSinceMonthYear(String month, String year);

  /// No description provided for @settingsCommentEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde'**
  String get settingsCommentEveryone;

  /// No description provided for @settingsCommentFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Mes abonnés'**
  String get settingsCommentFollowers;

  /// No description provided for @settingsCommentNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get settingsCommentNobody;

  /// No description provided for @profileStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get profileStatusPending;

  /// No description provided for @profileStatusPublished.
  ///
  /// In fr, this message translates to:
  /// **'Publié'**
  String get profileStatusPublished;

  /// No description provided for @profileStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get profileStatusRejected;

  /// No description provided for @profileErrorStatus.
  ///
  /// In fr, this message translates to:
  /// **'Erreur ({status}).'**
  String profileErrorStatus(int status);

  /// No description provided for @settingsVideoQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité vidéo'**
  String get settingsVideoQuality;

  /// No description provided for @settingsCurrentConnectionMobile.
  ///
  /// In fr, this message translates to:
  /// **'Connexion actuelle : données mobiles'**
  String get settingsCurrentConnectionMobile;

  /// No description provided for @settingsCurrentConnectionWifi.
  ///
  /// In fr, this message translates to:
  /// **'Connexion actuelle : Wi-Fi'**
  String get settingsCurrentConnectionWifi;

  /// No description provided for @settingsOnMobileData.
  ///
  /// In fr, this message translates to:
  /// **'Sur données mobiles'**
  String get settingsOnMobileData;

  /// No description provided for @settingsMobileDataFooter.
  ///
  /// In fr, this message translates to:
  /// **'Sur données mobiles, les vidéos ne démarrent jamais seules : la miniature s’affiche avec un bouton de lecture.'**
  String get settingsMobileDataFooter;

  /// No description provided for @settingsOnWifi.
  ///
  /// In fr, this message translates to:
  /// **'En Wi-Fi'**
  String get settingsOnWifi;

  /// No description provided for @settingsWifiFooter.
  ///
  /// In fr, this message translates to:
  /// **'Auto adapte la qualité à votre connexion pendant la lecture.'**
  String get settingsWifiFooter;

  /// No description provided for @settingsQualityDuringPlayback.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez changer de qualité pendant une lecture avec le bouton « Qualité » du lecteur ; ce choix ne vaut que pour la lecture en cours.'**
  String get settingsQualityDuringPlayback;

  /// No description provided for @profileSavedTab.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardés'**
  String get profileSavedTab;

  /// No description provided for @profileOfflineTab.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get profileOfflineTab;

  /// No description provided for @profileNoSaved.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage sauvegardé'**
  String get profileNoSaved;

  /// No description provided for @profileNoSavedHint.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur le signet dans un témoignage\npour le retrouver ici.'**
  String get profileNoSavedHint;

  /// No description provided for @profileNoOffline.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage disponible hors ligne'**
  String get profileNoOffline;

  /// No description provided for @profileNoOfflineHint.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez sur l’icône de téléchargement d’un témoignage\npour le lire sans connexion.'**
  String get profileNoOfflineHint;

  /// No description provided for @profileDownloadsMobileOnly.
  ///
  /// In fr, this message translates to:
  /// **'Les téléchargements sont disponibles sur l’application mobile.'**
  String get profileDownloadsMobileOnly;

  /// No description provided for @profileManageDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Gérer dans Mes téléchargements'**
  String get profileManageDownloads;

  /// No description provided for @profileDeleteConfirmWord.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get profileDeleteConfirmWord;

  /// No description provided for @profileDeleteEnterPassword.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre mot de passe.'**
  String get profileDeleteEnterPassword;

  /// No description provided for @profileDeleteWrongPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe incorrect.'**
  String get profileDeleteWrongPassword;

  /// No description provided for @profileServerUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Réessayez.'**
  String get profileServerUnreachable;

  /// No description provided for @profileDeleteIrreversible.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible'**
  String get profileDeleteIrreversible;

  /// No description provided for @profileDeleteWarnTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos témoignages seront supprimés.'**
  String get profileDeleteWarnTestimonies;

  /// No description provided for @profileDeleteWarnAccount.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte ne pourra pas être récupéré.'**
  String get profileDeleteWarnAccount;

  /// No description provided for @profileDeleteWarnSaved.
  ///
  /// In fr, this message translates to:
  /// **'Vos sauvegardes et interactions seront perdues.'**
  String get profileDeleteWarnSaved;

  /// No description provided for @profileDeleteTypePrefix.
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer, saisissez '**
  String get profileDeleteTypePrefix;

  /// No description provided for @profileDeleteTypeSuffix.
  ///
  /// In fr, this message translates to:
  /// **' ci-dessous :'**
  String get profileDeleteTypeSuffix;

  /// No description provided for @profileDeletePasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Votre mot de passe actuel'**
  String get profileDeletePasswordHint;

  /// No description provided for @profileDeleteForever.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get profileDeleteForever;

  /// No description provided for @profilePwdEnterCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre mot de passe actuel.'**
  String get profilePwdEnterCurrent;

  /// No description provided for @profilePwdMinLengthError.
  ///
  /// In fr, this message translates to:
  /// **'{count} caractères au moins.'**
  String profilePwdMinLengthError(int count);

  /// No description provided for @profilePwdMustDiffer.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un mot de passe différent de l\'actuel.'**
  String get profilePwdMustDiffer;

  /// No description provided for @profilePwdMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les deux mots de passe ne correspondent pas.'**
  String get profilePwdMismatch;

  /// No description provided for @profilePwdCurrentWrong.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel incorrect.'**
  String get profilePwdCurrentWrong;

  /// No description provided for @profilePwdChanged.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe modifié. Vos autres appareils devront se reconnecter.'**
  String get profilePwdChanged;

  /// No description provided for @profileSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité'**
  String get profileSecurity;

  /// No description provided for @profileChangePassword.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get profileChangePassword;

  /// No description provided for @profilePwdOtherDevices.
  ///
  /// In fr, this message translates to:
  /// **'Les autres appareils connectés à votre compte devront se reconnecter avec le nouveau mot de passe.'**
  String get profilePwdOtherDevices;

  /// No description provided for @profilePwdCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel'**
  String get profilePwdCurrent;

  /// No description provided for @profilePwdNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get profilePwdNew;

  /// No description provided for @profilePwdMinLengthHelper.
  ///
  /// In fr, this message translates to:
  /// **'{count} caractères au moins'**
  String profilePwdMinLengthHelper(int count);

  /// No description provided for @profilePwdConfirmNew.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nouveau mot de passe'**
  String get profilePwdConfirmNew;

  /// No description provided for @profileNoPassword.
  ///
  /// In fr, this message translates to:
  /// **'Aucun mot de passe'**
  String get profileNoPassword;

  /// No description provided for @profileNoPasswordBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte se connecte par numéro de téléphone, Google ou Facebook : il n\'a pas de mot de passe à changer.'**
  String get profileNoPasswordBody;

  /// No description provided for @profileAboutSiteOpenFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir le site web'**
  String get profileAboutSiteOpenFailed;

  /// No description provided for @profileAboutVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {version}'**
  String profileAboutVersion(String version);

  /// No description provided for @profileAboutMission.
  ///
  /// In fr, this message translates to:
  /// **'Notre mission'**
  String get profileAboutMission;

  /// No description provided for @profileAboutMissionBody.
  ///
  /// In fr, this message translates to:
  /// **'My Testimony rassemble les récits de vies transformées pour la gloire de Dieu. Partagez ce que Dieu a fait pour vous en vidéo, en audio, en texte ou en image, et soyez édifiés par les témoignages de la communauté — même hors connexion.'**
  String get profileAboutMissionBody;

  /// No description provided for @profileAboutVerse.
  ///
  /// In fr, this message translates to:
  /// **'« Ils l\'ont vaincu à cause du sang de l\'Agneau et à cause de la parole de leur témoignage. » — Apocalypse 12:11'**
  String get profileAboutVerse;

  /// No description provided for @profileAboutWebsite.
  ///
  /// In fr, this message translates to:
  /// **'Site web'**
  String get profileAboutWebsite;

  /// No description provided for @profileAboutLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences open source'**
  String get profileAboutLicenses;

  /// No description provided for @profileAboutDesignedBy.
  ///
  /// In fr, this message translates to:
  /// **'Conçu par {name}'**
  String profileAboutDesignedBy(String name);

  /// No description provided for @profileAboutCopyright.
  ///
  /// In fr, this message translates to:
  /// **'© {year} My Testimony. Tous droits réservés.'**
  String profileAboutCopyright(String year);

  /// No description provided for @profileFaqPublishQ.
  ///
  /// In fr, this message translates to:
  /// **'Comment publier un témoignage ?'**
  String get profileFaqPublishQ;

  /// No description provided for @profileFaqPublishA.
  ///
  /// In fr, this message translates to:
  /// **'Touchez le bouton « + Publier » au centre de la barre du bas, puis choisissez vidéo, audio, texte ou image. Ajoutez un titre, une description et une catégorie, puis touchez « Publier ».'**
  String get profileFaqPublishA;

  /// No description provided for @profileFaqPendingQ.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi mon témoignage est-il « en attente » ?'**
  String get profileFaqPendingQ;

  /// No description provided for @profileFaqPendingA.
  ///
  /// In fr, this message translates to:
  /// **'Chaque témoignage est relu par notre équipe de modération avant sa publication. Vous recevez une notification dès qu\'il est approuvé ou si une correction est demandée.'**
  String get profileFaqPendingA;

  /// No description provided for @profileFaqOfflineQ.
  ///
  /// In fr, this message translates to:
  /// **'Comment regarder hors connexion ?'**
  String get profileFaqOfflineQ;

  /// No description provided for @profileFaqOfflineA.
  ///
  /// In fr, this message translates to:
  /// **'Sur un témoignage, touchez « Télécharger ». Retrouvez-le ensuite dans l\'onglet « Téléchargements ». Activez « Mode hors ligne » dans les paramètres pour ne lire que les témoignages téléchargés.'**
  String get profileFaqOfflineA;

  /// No description provided for @profileFaqAccountQ.
  ///
  /// In fr, this message translates to:
  /// **'Comment modifier ou supprimer mon compte ?'**
  String get profileFaqAccountQ;

  /// No description provided for @profileFaqAccountA.
  ///
  /// In fr, this message translates to:
  /// **'Profil › Modifier le profil pour vos informations. Paramètres › Compte et sécurité pour supprimer définitivement votre compte.'**
  String get profileFaqAccountA;

  /// No description provided for @profileFaqPrivacyQ.
  ///
  /// In fr, this message translates to:
  /// **'Mes données sont-elles protégées ?'**
  String get profileFaqPrivacyQ;

  /// No description provided for @profileFaqPrivacyA.
  ///
  /// In fr, this message translates to:
  /// **'Vos informations personnelles ne sont jamais vendues. Votre carnet privé n\'est visible que par vous, et vous choisissez qui peut commenter vos témoignages dans les paramètres.'**
  String get profileFaqPrivacyA;

  /// No description provided for @profileFaqTtsQ.
  ///
  /// In fr, this message translates to:
  /// **'Comment fonctionne la lecture vocale ?'**
  String get profileFaqTtsQ;

  /// No description provided for @profileFaqTtsA.
  ///
  /// In fr, this message translates to:
  /// **'Les témoignages écrits sont lus à voix haute automatiquement à l\'ouverture. Utilisez les commandes de lecture pour mettre en pause, reprendre ou arrêter la voix.'**
  String get profileFaqTtsA;

  /// No description provided for @profileHelpHowCanWeHelp.
  ///
  /// In fr, this message translates to:
  /// **'Comment pouvons-nous vous aider ?'**
  String get profileHelpHowCanWeHelp;

  /// No description provided for @profileHelpQuickAnswers.
  ///
  /// In fr, this message translates to:
  /// **'Réponses rapides aux questions fréquentes.'**
  String get profileHelpQuickAnswers;

  /// No description provided for @profileHelpFaq.
  ///
  /// In fr, this message translates to:
  /// **'Questions fréquentes'**
  String get profileHelpFaq;

  /// No description provided for @profileHelpContact.
  ///
  /// In fr, this message translates to:
  /// **'Nous contacter'**
  String get profileHelpContact;

  /// No description provided for @profileHelpReportProblem.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get profileHelpReportProblem;

  /// No description provided for @profileHelpReportProblemHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez ce qui ne fonctionne pas'**
  String get profileHelpReportProblemHint;

  /// No description provided for @profileHelpReportSubject.
  ///
  /// In fr, this message translates to:
  /// **'My Testimony — signalement d\'un problème'**
  String get profileHelpReportSubject;

  /// No description provided for @profileHelpReportBody.
  ///
  /// In fr, this message translates to:
  /// **'{text}\n\n— Plateforme : {platform} · Version {version}'**
  String profileHelpReportBody(String text, String platform, String version);

  /// No description provided for @profileHelpReportShareInfo.
  ///
  /// In fr, this message translates to:
  /// **'Votre message sera partagé via l\'application de votre choix (e-mail, WhatsApp…).'**
  String get profileHelpReportShareInfo;

  /// No description provided for @profileHelpReportInputHint.
  ///
  /// In fr, this message translates to:
  /// **'Que s\'est-il passé ? Sur quel écran ?'**
  String get profileHelpReportInputHint;

  /// No description provided for @settingsManagersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Deux personnes au plus agissent en votre nom'**
  String get settingsManagersSubtitle;

  /// No description provided for @settingsSwitchAccount.
  ///
  /// In fr, this message translates to:
  /// **'Changer de compte'**
  String get settingsSwitchAccount;

  /// No description provided for @settingsSwitchAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Agir au nom d\'un compte que vous administrez'**
  String get settingsSwitchAccountSubtitle;

  /// No description provided for @settingsLocation.
  ///
  /// In fr, this message translates to:
  /// **'Localisation'**
  String get settingsLocation;

  /// No description provided for @settingsLocationSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages et événements proches de vous'**
  String get settingsLocationSubtitle;

  /// No description provided for @settingsVideoQualitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Données mobiles : {mobile} · Wi-Fi : {wifi}'**
  String settingsVideoQualitySubtitle(String mobile, String wifi);

  /// No description provided for @settingsAudioQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité audio par défaut'**
  String get settingsAudioQuality;

  /// No description provided for @settingsDataSaver.
  ///
  /// In fr, this message translates to:
  /// **'Économiseur de données'**
  String get settingsDataSaver;

  /// No description provided for @settingsDataSaverSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Audio en qualité réduite sur données mobiles'**
  String get settingsDataSaverSubtitle;

  /// No description provided for @settingsAutoplay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture automatique'**
  String get settingsAutoplay;

  /// No description provided for @settingsAutoplaySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Enchaîner le témoignage suivant'**
  String get settingsAutoplaySubtitle;

  /// No description provided for @settingsRepeat.
  ///
  /// In fr, this message translates to:
  /// **'Répétition'**
  String get settingsRepeat;

  /// No description provided for @settingsFeedLayout.
  ///
  /// In fr, this message translates to:
  /// **'Affichage du fil'**
  String get settingsFeedLayout;

  /// No description provided for @settingsPreferences.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get settingsPreferences;

  /// No description provided for @settingsInviteSubject.
  ///
  /// In fr, this message translates to:
  /// **'Découvre l\'application My Testimony'**
  String get settingsInviteSubject;

  /// No description provided for @settingsInviteText.
  ///
  /// In fr, this message translates to:
  /// **'Je t\'invite à rejoindre l\'application My Testimony — un espace pour partager et vivre les miracles de Dieu 🙏\n\nTélécharge-la ici : {url}'**
  String settingsInviteText(String url);

  /// No description provided for @settingsSecurityPassword.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité et mot de passe'**
  String get settingsSecurityPassword;

  /// No description provided for @settingsNotifApprovalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Validation'**
  String get settingsNotifApprovalTitle;

  /// No description provided for @settingsActingNoticeSuffix.
  ///
  /// In fr, this message translates to:
  /// **'. La sécurité, les notifications, la localisation et « Qui peut commenter » restent ceux de votre compte : revenez sur votre compte pour les modifier.'**
  String get settingsActingNoticeSuffix;

  /// No description provided for @profileTitlePastor.
  ///
  /// In fr, this message translates to:
  /// **'Pasteur'**
  String get profileTitlePastor;

  /// No description provided for @profileTitleEvangelist.
  ///
  /// In fr, this message translates to:
  /// **'Évangéliste'**
  String get profileTitleEvangelist;

  /// No description provided for @profileTitleElder.
  ///
  /// In fr, this message translates to:
  /// **'Ancien'**
  String get profileTitleElder;

  /// No description provided for @profileTitleDeacon.
  ///
  /// In fr, this message translates to:
  /// **'Diacre'**
  String get profileTitleDeacon;

  /// No description provided for @profileTitleMissionary.
  ///
  /// In fr, this message translates to:
  /// **'Missionnaire'**
  String get profileTitleMissionary;

  /// No description provided for @profileTitleTheologyStudent.
  ///
  /// In fr, this message translates to:
  /// **'Étudiant en théologie'**
  String get profileTitleTheologyStudent;

  /// No description provided for @profileTitleBeliever.
  ///
  /// In fr, this message translates to:
  /// **'Fidèle'**
  String get profileTitleBeliever;

  /// No description provided for @profileTitleYouthCoordinator.
  ///
  /// In fr, this message translates to:
  /// **'Coordinateur de jeunesse'**
  String get profileTitleYouthCoordinator;

  /// No description provided for @profileTitleCellLeader.
  ///
  /// In fr, this message translates to:
  /// **'Responsable de cellule'**
  String get profileTitleCellLeader;

  /// No description provided for @profileOrgNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir le nom de l\'organisation'**
  String get profileOrgNameRequired;

  /// No description provided for @profileOrgTypeRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez choisir le type d\'organisation'**
  String get profileOrgTypeRequired;

  /// No description provided for @profileOrgCityRequired.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir la ville'**
  String get profileOrgCityRequired;

  /// No description provided for @profileOrgWebsiteInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du site web invalide'**
  String get profileOrgWebsiteInvalid;

  /// No description provided for @profileOrgSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les informations de l\'organisation n\'ont pas pu être enregistrées sur le serveur. Vérifiez votre connexion et réessayez.'**
  String get profileOrgSaveFailed;

  /// No description provided for @profileErrorDetails.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {details}'**
  String profileErrorDetails(String details);

  /// No description provided for @profileOrgLogoTap.
  ///
  /// In fr, this message translates to:
  /// **'Logo · touchez pour modifier'**
  String get profileOrgLogoTap;

  /// No description provided for @profileOrgNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'organisation *'**
  String get profileOrgNameLabel;

  /// No description provided for @profileOrgNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Église de la Grâce'**
  String get profileOrgNameHint;

  /// No description provided for @profileOrgTypeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type *'**
  String get profileOrgTypeLabel;

  /// No description provided for @profileOrgCityLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ville *'**
  String get profileOrgCityLabel;

  /// No description provided for @profileOrgWebsiteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Site web (optionnel)'**
  String get profileOrgWebsiteLabel;

  /// No description provided for @profileOrgWebsiteHint.
  ///
  /// In fr, this message translates to:
  /// **'www.exemple.org'**
  String get profileOrgWebsiteHint;

  /// No description provided for @profileFirstNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Marie'**
  String get profileFirstNameHint;

  /// No description provided for @profileLastNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Dupont'**
  String get profileLastNameHint;

  /// No description provided for @profileCustomTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Responsable worship, Coordinatrice femmes…'**
  String get profileCustomTitleHint;

  /// No description provided for @profileOptionalNote.
  ///
  /// In fr, this message translates to:
  /// **'(facultatif)'**
  String get profileOptionalNote;

  /// No description provided for @profileEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// No description provided for @profileEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'marie@exemple.com'**
  String get profileEmailHint;

  /// No description provided for @profileCoverEditPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la photo de couverture'**
  String get profileCoverEditPhoto;

  /// No description provided for @profileCoverAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo de couverture'**
  String get profileCoverAdd;

  /// No description provided for @profileCoverEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la couverture'**
  String get profileCoverEdit;

  /// No description provided for @profilePhoneVerifiedSms.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié par SMS'**
  String get profilePhoneVerifiedSms;

  /// No description provided for @profilePhoneLocked.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro sert à vous connecter : il ne se modifie pas ici.'**
  String get profilePhoneLocked;

  /// No description provided for @profileEditAvatar.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la photo de profil'**
  String get profileEditAvatar;

  /// No description provided for @profileCoverPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de couverture'**
  String get profileCoverPhoto;

  /// No description provided for @profileMySpace.
  ///
  /// In fr, this message translates to:
  /// **'Mon espace'**
  String get profileMySpace;

  /// No description provided for @profileAccountApproved.
  ///
  /// In fr, this message translates to:
  /// **'Compte approuvé'**
  String get profileAccountApproved;

  /// No description provided for @profileGetVerified.
  ///
  /// In fr, this message translates to:
  /// **'Faire vérifier mon compte'**
  String get profileGetVerified;

  /// No description provided for @profileBadgeNextToName.
  ///
  /// In fr, this message translates to:
  /// **'Le badge apparaît à côté de votre nom'**
  String get profileBadgeNextToName;

  /// No description provided for @profileVerifUnderReview.
  ///
  /// In fr, this message translates to:
  /// **'Demande en cours d’examen'**
  String get profileVerifUnderReview;

  /// No description provided for @profileVerifRejectedSeeReason.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée : voir le motif'**
  String get profileVerifRejectedSeeReason;

  /// No description provided for @profileGetVerifiedHint.
  ///
  /// In fr, this message translates to:
  /// **'Pasteur, chantre, personnalité publique…'**
  String get profileGetVerifiedHint;

  /// No description provided for @profileSavedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos témoignages mis de côté'**
  String get profileSavedSubtitle;

  /// No description provided for @profileJournal.
  ///
  /// In fr, this message translates to:
  /// **'Mon carnet privé'**
  String get profileJournal;

  /// No description provided for @profileJournalSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Dieu a fait pour moi, gardé pour moi seul'**
  String get profileJournalSubtitle;

  /// No description provided for @profilePrayerRequests.
  ///
  /// In fr, this message translates to:
  /// **'Requêtes de prière'**
  String get profilePrayerRequests;

  /// No description provided for @profilePrayerRequestsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre et intercéder pour les autres'**
  String get profilePrayerRequestsSubtitle;

  /// No description provided for @profilePrayerSessions.
  ///
  /// In fr, this message translates to:
  /// **'Sessions de prière'**
  String get profilePrayerSessions;

  /// No description provided for @profilePrayerSessionsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre ou créer une session collective'**
  String get profilePrayerSessionsSubtitle;

  /// No description provided for @profileFollowingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les comptes que vous suivez'**
  String get profileFollowingSubtitle;

  /// No description provided for @profileMyFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Mes abonnés'**
  String get profileMyFollowers;

  /// No description provided for @profileFollowersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les comptes qui vous suivent'**
  String get profileFollowersSubtitle;

  /// No description provided for @profileCommunitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Églises, ministères et membres à suivre'**
  String get profileCommunitySubtitle;

  /// No description provided for @profileManagement.
  ///
  /// In fr, this message translates to:
  /// **'Gestion'**
  String get profileManagement;

  /// No description provided for @profileModerationSpace.
  ///
  /// In fr, this message translates to:
  /// **'Espace modération'**
  String get profileModerationSpace;

  /// No description provided for @profileModerationSpaceSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les témoignages en attente'**
  String get profileModerationSpaceSubtitle;

  /// No description provided for @profileAdministration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get profileAdministration;

  /// No description provided for @profileAdministrationSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les utilisateurs et le contenu'**
  String get profileAdministrationSubtitle;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations personnelles'**
  String get profilePersonalInfo;

  /// No description provided for @profileCompleteHint.
  ///
  /// In fr, this message translates to:
  /// **'Complétez votre profil pour que la communauté vous connaisse.'**
  String get profileCompleteHint;

  /// No description provided for @profileComplete.
  ///
  /// In fr, this message translates to:
  /// **'Compléter mon profil'**
  String get profileComplete;

  /// No description provided for @profileRecentTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Mes témoignages récents'**
  String get profileRecentTestimonies;

  /// No description provided for @profileVerifPending.
  ///
  /// In fr, this message translates to:
  /// **'Vérification en cours'**
  String get profileVerifPending;

  /// No description provided for @profileVerifRejected.
  ///
  /// In fr, this message translates to:
  /// **'Vérification refusée'**
  String get profileVerifRejected;

  /// No description provided for @profileNoTestimoniesYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore publié de témoignage.'**
  String get profileNoTestimoniesYet;

  /// No description provided for @profileShareTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Partager un témoignage'**
  String get profileShareTestimony;

  /// No description provided for @profileOrganizationApproved.
  ///
  /// In fr, this message translates to:
  /// **'Organisation approuvée'**
  String get profileOrganizationApproved;

  /// No description provided for @profileApprovedSince.
  ///
  /// In fr, this message translates to:
  /// **'{label} · depuis le {date}'**
  String profileApprovedSince(String label, String date);

  /// No description provided for @profileTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous ({count})'**
  String profileTabAll(int count);

  /// No description provided for @profileTabPublished.
  ///
  /// In fr, this message translates to:
  /// **'Publiés ({count})'**
  String profileTabPublished(int count);

  /// No description provided for @profileTabRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusés ({count})'**
  String profileTabRejected(int count);

  /// No description provided for @profileNewTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get profileNewTestimony;

  /// No description provided for @profilePendingNotice.
  ///
  /// In fr, this message translates to:
  /// **'En cours de validation par notre équipe. Vous recevrez une notification dès que ce sera traité.'**
  String get profilePendingNotice;

  /// No description provided for @profileEditResubmit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier et renvoyer'**
  String get profileEditResubmit;

  /// No description provided for @profileDeleteTestimonyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce témoignage ?'**
  String get profileDeleteTestimonyTitle;

  /// No description provided for @profileDeleteTestimonyBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. Le témoignage sera définitivement supprimé.'**
  String get profileDeleteTestimonyBody;

  /// No description provided for @profileDeleteTestimonyFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer. Réessaie.'**
  String get profileDeleteTestimonyFailed;

  /// No description provided for @profileDateToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get profileDateToday;

  /// No description provided for @profileDateYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get profileDateYesterday;

  /// No description provided for @profileDateDaysAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} j'**
  String profileDateDaysAgo(int count);

  /// No description provided for @profileDateWeeksAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {count} sem'**
  String profileDateWeeksAgo(int count);

  /// No description provided for @profileVideoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get profileVideoFailed;

  /// No description provided for @profileView.
  ///
  /// In fr, this message translates to:
  /// **'Consulter'**
  String get profileView;

  /// No description provided for @profileEmptyPendingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage en attente'**
  String get profileEmptyPendingTitle;

  /// No description provided for @profileEmptyPendingBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos témoignages soumis apparaîtront ici\npendant leur validation.'**
  String get profileEmptyPendingBody;

  /// No description provided for @profileEmptyPublishedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage publié'**
  String get profileEmptyPublishedTitle;

  /// No description provided for @profileEmptyPublishedBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos témoignages validés\ns\'afficheront ici.'**
  String get profileEmptyPublishedBody;

  /// No description provided for @profileEmptyRejectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage refusé'**
  String get profileEmptyRejectedTitle;

  /// No description provided for @profileEmptyRejectedBody.
  ///
  /// In fr, this message translates to:
  /// **'Bonne nouvelle ! Aucun de vos\ntémoignages n\'a été refusé.'**
  String get profileEmptyRejectedBody;

  /// No description provided for @profileEmptyAllTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage'**
  String get profileEmptyAllTitle;

  /// No description provided for @profileEmptyAllBody.
  ///
  /// In fr, this message translates to:
  /// **'Partagez ce que Dieu a fait\ndans votre vie.'**
  String get profileEmptyAllBody;

  /// No description provided for @profilePublishTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Publier un témoignage'**
  String get profilePublishTestimony;

  /// No description provided for @profileMyTestimoniesLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos témoignages.'**
  String get profileMyTestimoniesLoadFailed;

  /// No description provided for @profilePublishedEditWarning.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage repassera en modération et ne sera plus visible jusqu\'à sa validation. Continuer ?'**
  String get profilePublishedEditWarning;

  /// No description provided for @profilePublishedEditWarningLabel.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage repassera en modération et ne sera plus visible jusqu\'à sa validation. Continuer ?\n\nIl perdra aussi son label Témoignage approuvé.'**
  String get profilePublishedEditWarningLabel;

  /// No description provided for @profileEditPublishedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier un témoignage publié ?'**
  String get profileEditPublishedTitle;

  /// No description provided for @profileResubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyé en modération'**
  String get profileResubmitted;

  /// No description provided for @profileChangesSaved.
  ///
  /// In fr, this message translates to:
  /// **'Modifications enregistrées'**
  String get profileChangesSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer. Réessayez.'**
  String get profileSaveFailed;

  /// No description provided for @profileBodyTranscription.
  ///
  /// In fr, this message translates to:
  /// **'Transcription'**
  String get profileBodyTranscription;

  /// No description provided for @profileBodyDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get profileBodyDescription;

  /// No description provided for @profileBodyTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage'**
  String get profileBodyTestimony;

  /// No description provided for @profileEditTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le témoignage'**
  String get profileEditTestimony;

  /// No description provided for @profileRejectionReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif du refus : {reason}'**
  String profileRejectionReason(String reason);

  /// No description provided for @profileTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get profileTitleLabel;

  /// No description provided for @profileTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le titre est obligatoire.'**
  String get profileTitleRequired;

  /// No description provided for @profileBodyRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le texte du témoignage est obligatoire.'**
  String get profileBodyRequired;

  /// No description provided for @profileResubmitAction.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer en modération'**
  String get profileResubmitAction;

  /// No description provided for @profileVerifTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du compte'**
  String get profileVerifTitle;

  /// No description provided for @profileVerifOrgTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte organisation'**
  String get profileVerifOrgTitle;

  /// No description provided for @profileVerifOrgBody.
  ///
  /// In fr, this message translates to:
  /// **'Les organisations sont vérifiées à partir des informations de leur profil. Modifiez votre profil pour compléter ou corriger ces informations.'**
  String get profileVerifOrgBody;

  /// No description provided for @profileVerifLoadFailedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible'**
  String get profileVerifLoadFailedTitle;

  /// No description provided for @profileVerifLoadFailedBody.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Réessayez.'**
  String get profileVerifLoadFailedBody;

  /// No description provided for @profileVerifVerifiedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est vérifié'**
  String get profileVerifVerifiedTitle;

  /// No description provided for @profileVerifVerifiedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le badge « Compte vérifié » apparaît à côté de votre nom sur votre profil, vos témoignages et vos commentaires.'**
  String get profileVerifVerifiedBody;

  /// No description provided for @profileVerifPendingBody.
  ///
  /// In fr, this message translates to:
  /// **'Notre équipe vérifie vos informations. Vous serez prévenu dans vos notifications.'**
  String get profileVerifPendingBody;

  /// No description provided for @profileVerifRevokedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification retirée'**
  String get profileVerifRevokedTitle;

  /// No description provided for @profileVerifRefusedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande refusée'**
  String get profileVerifRefusedTitle;

  /// No description provided for @profileVerifReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif : {reason}'**
  String profileVerifReason(String reason);

  /// No description provided for @profileVerifCanRequestAgain.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez envoyer une nouvelle demande.'**
  String get profileVerifCanRequestAgain;

  /// No description provided for @profileVerifRequestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Faire vérifier mon compte'**
  String get profileVerifRequestTitle;

  /// No description provided for @profileVerifRequestBody.
  ///
  /// In fr, this message translates to:
  /// **'Pasteurs, évangélistes, chantres, responsables de ministère, personnalités publiques : le badge aide la communauté à reconnaître votre compte officiel. Il ne donne pas de droits supplémentaires.'**
  String get profileVerifRequestBody;

  /// No description provided for @profileVerifYourRequest.
  ///
  /// In fr, this message translates to:
  /// **'Votre demande'**
  String get profileVerifYourRequest;

  /// No description provided for @profileVerifSummaryFullName.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get profileVerifSummaryFullName;

  /// No description provided for @profileVerifSummaryRole.
  ///
  /// In fr, this message translates to:
  /// **'Fonction'**
  String get profileVerifSummaryRole;

  /// No description provided for @profileVerifSummaryChurch.
  ///
  /// In fr, this message translates to:
  /// **'Église ou ministère'**
  String get profileVerifSummaryChurch;

  /// No description provided for @profileVerifSummaryDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Pièces justificatives'**
  String get profileVerifSummaryDocuments;

  /// No description provided for @profileVerifDocumentsPrivateCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} (privées)'**
  String profileVerifDocumentsPrivateCount(int count);

  /// No description provided for @profileVerifFixFields.
  ///
  /// In fr, this message translates to:
  /// **'Merci de corriger les champs signalés.'**
  String get profileVerifFixFields;

  /// No description provided for @profileVerifSendFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’envoyer la demande. Vérifiez votre connexion et réessayez.'**
  String get profileVerifSendFailed;

  /// No description provided for @profileVerifSent.
  ///
  /// In fr, this message translates to:
  /// **'Demande envoyée. Vous serez prévenu dans vos notifications.'**
  String get profileVerifSent;

  /// No description provided for @profileVerifFullNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet *'**
  String get profileVerifFullNameLabel;

  /// No description provided for @profileVerifFullNameHelper.
  ///
  /// In fr, this message translates to:
  /// **'Tel qu’il figure sur votre pièce d’identité'**
  String get profileVerifFullNameHelper;

  /// No description provided for @profileVerifRoleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fonction *'**
  String get profileVerifRoleLabel;

  /// No description provided for @profileVerifRoleOtherLabel.
  ///
  /// In fr, this message translates to:
  /// **'Précisez votre fonction *'**
  String get profileVerifRoleOtherLabel;

  /// No description provided for @profileVerifChurchLabel.
  ///
  /// In fr, this message translates to:
  /// **'Église ou ministère de rattachement *'**
  String get profileVerifChurchLabel;

  /// No description provided for @profileVerifChurchHint.
  ///
  /// In fr, this message translates to:
  /// **'Église de la Grâce, Cotonou'**
  String get profileVerifChurchHint;

  /// No description provided for @profileVerifLinksLabel.
  ///
  /// In fr, this message translates to:
  /// **'Liens publics (facultatif)'**
  String get profileVerifLinksLabel;

  /// No description provided for @profileVerifLinksHint.
  ///
  /// In fr, this message translates to:
  /// **'Site, page Facebook, chaîne YouTube… qui montrent votre ministère.'**
  String get profileVerifLinksHint;

  /// No description provided for @profileVerifAddLink.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un lien'**
  String get profileVerifAddLink;

  /// No description provided for @profileVerifDocumentsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Pièces justificatives *'**
  String get profileVerifDocumentsLabel;

  /// No description provided for @profileVerifDocumentsHint.
  ///
  /// In fr, this message translates to:
  /// **'Photo de votre pièce d’identité et/ou lettre de votre église : JPG, PNG, WebP ou PDF, {mb} Mo au plus chacune, {max} au plus.'**
  String profileVerifDocumentsHint(int mb, int max);

  /// No description provided for @profileVerifTakePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get profileVerifTakePhoto;

  /// No description provided for @profileVerifPickFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un fichier'**
  String get profileVerifPickFile;

  /// No description provided for @profileVerifDocumentsPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Ces pièces restent privées : seuls les administrateurs chargés de la vérification peuvent les consulter. Elles ne sont jamais publiées.'**
  String get profileVerifDocumentsPrivate;

  /// No description provided for @profileVerifMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Message (facultatif)'**
  String get profileVerifMessageLabel;

  /// No description provided for @profileVerifMessageHint.
  ///
  /// In fr, this message translates to:
  /// **'Toute information utile à notre équipe'**
  String get profileVerifMessageHint;

  /// No description provided for @profileVerifSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get profileVerifSubmit;

  /// No description provided for @profileFileSizeMb.
  ///
  /// In fr, this message translates to:
  /// **'{size} Mo'**
  String profileFileSizeMb(String size);

  /// No description provided for @profileFileSizeKb.
  ///
  /// In fr, this message translates to:
  /// **'{size} Ko'**
  String profileFileSizeKb(int size);

  /// No description provided for @journalOfflineUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'La copie hors ligne n\'a pas pu être mise à jour.'**
  String get journalOfflineUpdateFailed;

  /// No description provided for @journalConnectionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre accès à Internet.'**
  String get journalConnectionFailed;

  /// No description provided for @journalServerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur du serveur ({status}).'**
  String journalServerError(int status);

  /// No description provided for @journalTypeText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get journalTypeText;

  /// No description provided for @journalTypeAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get journalTypeAudio;

  /// No description provided for @journalTypeVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get journalTypeVideo;

  /// No description provided for @journalUntitled.
  ///
  /// In fr, this message translates to:
  /// **'Sans titre'**
  String get journalUntitled;

  /// No description provided for @journalSharedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage partagé : il sera visible après validation par un modérateur.'**
  String get journalSharedSnack;

  /// No description provided for @journalMovedBackSnack.
  ///
  /// In fr, this message translates to:
  /// **'Rangé dans votre carnet privé 🔒'**
  String get journalMovedBackSnack;

  /// No description provided for @journalDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce témoignage ?'**
  String get journalDeleteTitle;

  /// No description provided for @journalDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Il sera définitivement effacé de votre carnet.'**
  String get journalDeleteBody;

  /// No description provided for @journalDeletedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage supprimé.'**
  String get journalDeletedSnack;

  /// No description provided for @journalMyJournal.
  ///
  /// In fr, this message translates to:
  /// **'Mon carnet'**
  String get journalMyJournal;

  /// No description provided for @journalUnshare.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus partager · ranger dans mon carnet'**
  String get journalUnshare;

  /// No description provided for @journalOfflineAvailableOnPhone.
  ///
  /// In fr, this message translates to:
  /// **'Disponible hors ligne sur ce téléphone'**
  String get journalOfflineAvailableOnPhone;

  /// No description provided for @journalStatusPrivate.
  ///
  /// In fr, this message translates to:
  /// **'Privé · visible par vous seul'**
  String get journalStatusPrivate;

  /// No description provided for @journalStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'Partagé · en attente de validation'**
  String get journalStatusPending;

  /// No description provided for @journalStatusShared.
  ///
  /// In fr, this message translates to:
  /// **'Partagé'**
  String get journalStatusShared;

  /// No description provided for @journalAudioError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire l\'enregistrement audio.'**
  String get journalAudioError;

  /// No description provided for @journalVideoError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire la vidéo.'**
  String get journalVideoError;

  /// No description provided for @journalShareSheetBody.
  ///
  /// In fr, this message translates to:
  /// **'Il quittera votre carnet privé et sera relu par un modérateur avant d\'être visible par tous. Vous pourrez toujours le reprendre.'**
  String get journalShareSheetBody;

  /// No description provided for @journalCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get journalCategory;

  /// No description provided for @publishCertifyReal.
  ///
  /// In fr, this message translates to:
  /// **'Je certifie que ce témoignage est réel'**
  String get publishCertifyReal;

  /// No description provided for @journalCertifySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les faits sont authentiques et vécus personnellement.'**
  String get journalCertifySubtitle;

  /// No description provided for @journalNewPrivateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau témoignage privé'**
  String get journalNewPrivateTitle;

  /// No description provided for @journalNewPrivateHint.
  ///
  /// In fr, this message translates to:
  /// **'Gardé pour vous seul. Vous pourrez le partager plus tard.'**
  String get journalNewPrivateHint;

  /// No description provided for @journalNewWrite.
  ///
  /// In fr, this message translates to:
  /// **'Écrire'**
  String get journalNewWrite;

  /// No description provided for @journalNewWriteHint.
  ///
  /// In fr, this message translates to:
  /// **'Un texte, avec mise en forme'**
  String get journalNewWriteHint;

  /// No description provided for @journalNewRecordVoice.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer ma voix'**
  String get journalNewRecordVoice;

  /// No description provided for @journalNewRecordVoiceHint.
  ///
  /// In fr, this message translates to:
  /// **'Un audio'**
  String get journalNewRecordVoiceHint;

  /// No description provided for @journalNewFilm.
  ///
  /// In fr, this message translates to:
  /// **'Filmer'**
  String get journalNewFilm;

  /// No description provided for @journalNewFilmHint.
  ///
  /// In fr, this message translates to:
  /// **'Une vidéo'**
  String get journalNewFilmHint;

  /// No description provided for @journalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon carnet privé'**
  String get journalTitle;

  /// No description provided for @journalNewEntry.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau témoignage'**
  String get journalNewEntry;

  /// No description provided for @journalSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans mon carnet…'**
  String get journalSearchHint;

  /// No description provided for @journalFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get journalFilterAll;

  /// No description provided for @journalNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage ne correspond.'**
  String get journalNoMatch;

  /// No description provided for @journalEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Votre carnet est vide.\nNotez ce que Dieu a fait pour vous, pour ne jamais l\'oublier.'**
  String get journalEmpty;

  /// No description provided for @journalFirstEntry.
  ///
  /// In fr, this message translates to:
  /// **'Mon premier témoignage'**
  String get journalFirstEntry;

  /// No description provided for @journalNoDate.
  ///
  /// In fr, this message translates to:
  /// **'Sans date'**
  String get journalNoDate;

  /// No description provided for @journalOfflineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne : copie enregistrée sur ce téléphone.'**
  String get journalOfflineBanner;

  /// No description provided for @journalOfflineBannerDate.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne : copie du {date}.'**
  String journalOfflineBannerDate(String date);

  /// No description provided for @journalHeaderTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que Dieu a fait pour moi'**
  String get journalHeaderTitle;

  /// No description provided for @journalHeaderCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 témoignage · visible par vous seul} other{{count} témoignages · visibles par vous seul}}'**
  String journalHeaderCount(int count);

  /// No description provided for @journalHeaderEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Visible uniquement par vous · sans modération'**
  String get journalHeaderEmpty;

  /// No description provided for @journalProphecies.
  ///
  /// In fr, this message translates to:
  /// **'Paroles prophétiques'**
  String get journalProphecies;

  /// No description provided for @journalPropheciesHint.
  ///
  /// In fr, this message translates to:
  /// **'Gardez-les, priez, témoignez de leur accomplissement.'**
  String get journalPropheciesHint;

  /// No description provided for @journalOfflineAskTitle.
  ///
  /// In fr, this message translates to:
  /// **'Garder aussi une copie sur ce téléphone ?'**
  String get journalOfflineAskTitle;

  /// No description provided for @journalOfflineAskBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre carnet est toujours sauvegardé en ligne : même si vous perdez ou changez de téléphone, vous le retrouvez en vous connectant.\n\nUne copie sur ce téléphone vous permet en plus de le relire et d\'écouter vos audios et vidéos sans connexion. Elle utilise de l\'espace de stockage.\n\nVous pourrez changer d\'avis à tout moment.'**
  String get journalOfflineAskBody;

  /// No description provided for @journalOfflineAskNo.
  ///
  /// In fr, this message translates to:
  /// **'Non merci'**
  String get journalOfflineAskNo;

  /// No description provided for @journalOfflineAskYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui, garder une copie'**
  String get journalOfflineAskYes;

  /// No description provided for @journalOfflineAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Disponible hors ligne'**
  String get journalOfflineAvailable;

  /// No description provided for @journalOfflineKeep.
  ///
  /// In fr, this message translates to:
  /// **'Garder hors ligne'**
  String get journalOfflineKeep;

  /// No description provided for @journalOfflineRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la copie de ce téléphone ?'**
  String get journalOfflineRemoveTitle;

  /// No description provided for @journalOfflineRemoveBody.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers enregistrés sur ce téléphone seront effacés. Votre carnet reste intact en ligne : rien n\'est supprimé de votre compte.'**
  String get journalOfflineRemoveBody;

  /// No description provided for @journalOfflineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get journalOfflineTitle;

  /// No description provided for @journalOfflineSheetIntro.
  ///
  /// In fr, this message translates to:
  /// **'Votre carnet est toujours sauvegardé en ligne. La copie sur ce téléphone sert à le relire sans connexion.'**
  String get journalOfflineSheetIntro;

  /// No description provided for @journalOfflineEnabledHint.
  ///
  /// In fr, this message translates to:
  /// **'Textes, audios et vidéos gardés sur ce téléphone'**
  String get journalOfflineEnabledHint;

  /// No description provided for @journalOfflineOnlineOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seulement en ligne'**
  String get journalOfflineOnlineOnly;

  /// No description provided for @journalOfflineUpdating.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour de la copie…'**
  String get journalOfflineUpdating;

  /// No description provided for @journalOfflineDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement des audios et vidéos : {done} / {total}'**
  String journalOfflineDownloading(int done, int total);

  /// No description provided for @journalOfflineSpaceUsed.
  ///
  /// In fr, this message translates to:
  /// **'Espace utilisé : {size}'**
  String journalOfflineSpaceUsed(String size);

  /// No description provided for @journalOfflineUpdatedAt.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour le {day}/{month}/{year} à {hour}h{minute}'**
  String journalOfflineUpdatedAt(
    String day,
    String month,
    String year,
    String hour,
    String minute,
  );

  /// No description provided for @journalOfflineMediaFailed.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 fichier audio/vidéo non téléchargé (réessayé à la prochaine mise à jour)} other{{count} fichiers audio/vidéo non téléchargés (réessayé à la prochaine mise à jour)}}'**
  String journalOfflineMediaFailed(int count);

  /// No description provided for @journalOfflineUpdateNow.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour maintenant'**
  String get journalOfflineUpdateNow;

  /// No description provided for @publishFormatText.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage Écrit'**
  String get publishFormatText;

  /// No description provided for @publishFormatAudio.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage Audio'**
  String get publishFormatAudio;

  /// No description provided for @publishFormatVideo.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage Vidéo'**
  String get publishFormatVideo;

  /// No description provided for @publishFormatTextHint.
  ///
  /// In fr, this message translates to:
  /// **'Racontez avec vos mots'**
  String get publishFormatTextHint;

  /// No description provided for @publishFormatAudioHint.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez votre voix'**
  String get publishFormatAudioHint;

  /// No description provided for @publishFormatVideoHint.
  ///
  /// In fr, this message translates to:
  /// **'Filmez votre histoire'**
  String get publishFormatVideoHint;

  /// No description provided for @publishStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get publishStatusDraft;

  /// No description provided for @publishStatusSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Soumis'**
  String get publishStatusSubmitted;

  /// No description provided for @publishStatusInReview.
  ///
  /// In fr, this message translates to:
  /// **'En validation'**
  String get publishStatusInReview;

  /// No description provided for @publishStatusPublished.
  ///
  /// In fr, this message translates to:
  /// **'Publié'**
  String get publishStatusPublished;

  /// No description provided for @publishStatusOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get publishStatusOffline;

  /// No description provided for @publishStatusJournal.
  ///
  /// In fr, this message translates to:
  /// **'Dans mon carnet'**
  String get publishStatusJournal;

  /// No description provided for @publishStatusVideoUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi de la vidéo'**
  String get publishStatusVideoUploading;

  /// No description provided for @publishProofBadFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format non accepté : image (JPG, PNG, WebP) ou PDF uniquement.'**
  String get publishProofBadFormat;

  /// No description provided for @publishProofTooBig.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop lourd : 10 Mo au maximum.'**
  String get publishProofTooBig;

  /// No description provided for @publishDefaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon témoignage'**
  String get publishDefaultTitle;

  /// No description provided for @publishServerTooSlow.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a mis trop de temps à répondre.'**
  String get publishServerTooSlow;

  /// No description provided for @publishCoverUploadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'envoi de l\'image de couverture. Réessaie.'**
  String get publishCoverUploadFailed;

  /// No description provided for @publishAudioUploadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'envoi audio. Réessaie.'**
  String get publishAudioUploadFailed;

  /// No description provided for @publishAnotherVideoUploading.
  ///
  /// In fr, this message translates to:
  /// **'Une autre vidéo est en cours d’envoi. Attendez la fin de son envoi (ou annulez-le) avant d’en publier une nouvelle.'**
  String get publishAnotherVideoUploading;

  /// No description provided for @publishServerErrorRetry.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur ({code}). Réessaie plus tard.'**
  String publishServerErrorRetry(String code);

  /// No description provided for @publishUnknownCode.
  ///
  /// In fr, this message translates to:
  /// **'inconnue'**
  String get publishUnknownCode;

  /// No description provided for @publishListenToMyTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Écoutez mon témoignage…'**
  String get publishListenToMyTestimony;

  /// No description provided for @uploadPhaseCompressing.
  ///
  /// In fr, this message translates to:
  /// **'Compression de la vidéo…'**
  String get uploadPhaseCompressing;

  /// No description provided for @uploadPhasePreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de l’envoi…'**
  String get uploadPhasePreparing;

  /// No description provided for @uploadPhaseUploading.
  ///
  /// In fr, this message translates to:
  /// **'Envoi de la vidéo…'**
  String get uploadPhaseUploading;

  /// No description provided for @uploadPhaseWaitingNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion perdue : l’envoi reprendra automatiquement.'**
  String get uploadPhaseWaitingNetwork;

  /// No description provided for @uploadPhaseFinalizing.
  ///
  /// In fr, this message translates to:
  /// **'Finalisation…'**
  String get uploadPhaseFinalizing;

  /// No description provided for @uploadPhaseDone.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo envoyée'**
  String get uploadPhaseDone;

  /// No description provided for @uploadPhaseFailed.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi a échoué'**
  String get uploadPhaseFailed;

  /// No description provided for @uploadAlreadyRunning.
  ///
  /// In fr, this message translates to:
  /// **'Un envoi de vidéo est déjà en cours.'**
  String get uploadAlreadyRunning;

  /// No description provided for @uploadInterrupted.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi de votre vidéo a été interrompu.'**
  String get uploadInterrupted;

  /// No description provided for @uploadUnexpectedError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur inattendue est survenue.'**
  String get uploadUnexpectedError;

  /// No description provided for @uploadConnectionUnstable.
  ///
  /// In fr, this message translates to:
  /// **'La connexion est trop instable pour envoyer la vidéo. Vérifiez votre réseau puis réessayez : l’envoi reprendra là où il s’était arrêté.'**
  String get uploadConnectionUnstable;

  /// No description provided for @uploadCompressionFailed.
  ///
  /// In fr, this message translates to:
  /// **'La compression de la vidéo a échoué. Réessayez, ou choisissez une autre vidéo.'**
  String get uploadCompressionFailed;

  /// No description provided for @uploadUnexpectedResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue du serveur.'**
  String get uploadUnexpectedResponse;

  /// No description provided for @uploadFileMissing.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier vidéo est introuvable sur l’appareil. Annulez puis publiez-le à nouveau.'**
  String get uploadFileMissing;

  /// No description provided for @uploadAuthorizationRefused.
  ///
  /// In fr, this message translates to:
  /// **'L’autorisation d’envoi a été refusée. Réessayez dans quelques instants.'**
  String get uploadAuthorizationRefused;

  /// No description provided for @uploadServerRefused.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur vidéo a refusé l’envoi (erreur {code}).'**
  String uploadServerRefused(int code);

  /// No description provided for @uploadResendBusy.
  ///
  /// In fr, this message translates to:
  /// **'Une vidéo est déjà en cours d’envoi. Attendez la fin de son envoi (ou annulez-le) avant d’en renvoyer une autre.'**
  String get uploadResendBusy;

  /// No description provided for @uploadResendHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez à nouveau la vidéo de votre témoignage. Le titre, la catégorie et le texte sont conservés.'**
  String get uploadResendHint;

  /// No description provided for @uploadResendGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get uploadResendGallery;

  /// No description provided for @uploadResendFetchFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de récupérer le témoignage. Vérifiez votre connexion.'**
  String get uploadResendFetchFailed;

  /// No description provided for @uploadResendAlreadyUploading.
  ///
  /// In fr, this message translates to:
  /// **'Une vidéo est déjà en cours d’envoi.'**
  String get uploadResendAlreadyUploading;

  /// No description provided for @uploadProcessingMessage.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage est en cours de traitement. Vous serez notifié dès qu\'il sera en ligne.'**
  String get uploadProcessingMessage;

  /// No description provided for @uploadScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Publication de la vidéo'**
  String get uploadScreenTitle;

  /// No description provided for @uploadSeeTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon témoignage'**
  String get uploadSeeTestimony;

  /// No description provided for @uploadSeeMyPublications.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes publications'**
  String get uploadSeeMyPublications;

  /// No description provided for @uploadBackHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l’accueil'**
  String get uploadBackHome;

  /// No description provided for @uploadCanLeave.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez quitter cet écran : l’envoi continue et reprend tout seul après une coupure de réseau.'**
  String get uploadCanLeave;

  /// No description provided for @uploadNothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun envoi de vidéo en cours.'**
  String get uploadNothing;

  /// No description provided for @uploadCancelTitle.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la publication ?'**
  String get uploadCancelTitle;

  /// No description provided for @uploadCancelBody.
  ///
  /// In fr, this message translates to:
  /// **'L’envoi de la vidéo sera arrêté et le témoignage ne sera pas publié.'**
  String get uploadCancelBody;

  /// No description provided for @uploadContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer l’envoi'**
  String get uploadContinue;

  /// No description provided for @uploadCancelPublication.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la publication'**
  String get uploadCancelPublication;

  /// No description provided for @uploadPercent.
  ///
  /// In fr, this message translates to:
  /// **'{percent} %'**
  String uploadPercent(int percent);

  /// No description provided for @uploadProofFailed.
  ///
  /// In fr, this message translates to:
  /// **'La preuve {position} n’a pas pu être envoyée.'**
  String uploadProofFailed(int position);

  /// No description provided for @uploadProofsFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les preuves n’ont pas pu être envoyées.'**
  String get uploadProofsFailed;

  /// No description provided for @uploadGiveUp.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get uploadGiveUp;

  /// No description provided for @uploadStepCompression.
  ///
  /// In fr, this message translates to:
  /// **'Compression'**
  String get uploadStepCompression;

  /// No description provided for @uploadStepUpload.
  ///
  /// In fr, this message translates to:
  /// **'Envoi'**
  String get uploadStepUpload;

  /// No description provided for @uploadStepFinalize.
  ///
  /// In fr, this message translates to:
  /// **'Finalisation'**
  String get uploadStepFinalize;

  /// No description provided for @publishCameraPermissionsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Les permissions caméra et microphone sont requises.\n\nActivez-les dans les réglages de l\'application.'**
  String get publishCameraPermissionsRequired;

  /// No description provided for @publishCameraDetectFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de détecter les caméras : {error}'**
  String publishCameraDetectFailed(String error);

  /// No description provided for @publishNoCamera.
  ///
  /// In fr, this message translates to:
  /// **'Aucune caméra disponible sur cet appareil.'**
  String get publishNoCamera;

  /// No description provided for @publishCameraError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur caméra : {error}'**
  String publishCameraError(String error);

  /// No description provided for @publishVideoRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo enregistrée !'**
  String get publishVideoRecorded;

  /// No description provided for @publishDuration.
  ///
  /// In fr, this message translates to:
  /// **'Durée : {duration}'**
  String publishDuration(String duration);

  /// No description provided for @publishTapToStop.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour arrêter'**
  String get publishTapToStop;

  /// No description provided for @publishTapToRecord.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour enregistrer'**
  String get publishTapToRecord;

  /// No description provided for @publishRetake.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get publishRetake;

  /// No description provided for @publishUse.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser'**
  String get publishUse;

  /// No description provided for @publishCameraInitializing.
  ///
  /// In fr, this message translates to:
  /// **'Initialisation de la caméra…'**
  String get publishCameraInitializing;

  /// No description provided for @publishCategoryHealing.
  ///
  /// In fr, this message translates to:
  /// **'Guérison'**
  String get publishCategoryHealing;

  /// No description provided for @publishCategoryDeliverance.
  ///
  /// In fr, this message translates to:
  /// **'Délivrance'**
  String get publishCategoryDeliverance;

  /// No description provided for @publishCategoryConversion.
  ///
  /// In fr, this message translates to:
  /// **'Conversion'**
  String get publishCategoryConversion;

  /// No description provided for @publishCategoryMarriage.
  ///
  /// In fr, this message translates to:
  /// **'Mariage'**
  String get publishCategoryMarriage;

  /// No description provided for @publishCategoryFamily.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get publishCategoryFamily;

  /// No description provided for @publishCategoryFinances.
  ///
  /// In fr, this message translates to:
  /// **'Finances'**
  String get publishCategoryFinances;

  /// No description provided for @publishCategoryMiracles.
  ///
  /// In fr, this message translates to:
  /// **'Miracles'**
  String get publishCategoryMiracles;

  /// No description provided for @publishCategoryProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get publishCategoryProtection;

  /// No description provided for @publishCategoryMinistry.
  ///
  /// In fr, this message translates to:
  /// **'Ministère'**
  String get publishCategoryMinistry;

  /// No description provided for @publishCategorySalvation.
  ///
  /// In fr, this message translates to:
  /// **'Salut'**
  String get publishCategorySalvation;

  /// No description provided for @publishShortPermissionsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Accès à la caméra et au microphone requis.\nVeuillez autoriser ces permissions dans les paramètres.'**
  String get publishShortPermissionsRequired;

  /// No description provided for @publishShortCameraInitError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'initialisation de la caméra: {error}'**
  String publishShortCameraInitError(String error);

  /// No description provided for @publishShortGenericError.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur s\'est produite.'**
  String get publishShortGenericError;

  /// No description provided for @publishShortRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Court Témoignage enregistré !'**
  String get publishShortRecorded;

  /// No description provided for @publishShortDuration.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Durée: 0 seconde} =1{Durée: 1 seconde} other{Durée: {count} secondes}}'**
  String publishShortDuration(int count);

  /// No description provided for @publishShortTitle.
  ///
  /// In fr, this message translates to:
  /// **'Short Témoignage'**
  String get publishShortTitle;

  /// No description provided for @publishImportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Importer une image / document'**
  String get publishImportTitle;

  /// No description provided for @publishImportHint.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier accompagne un témoignage écrit : une image devient la couverture, un document (PDF ou image) est joint comme preuve.'**
  String get publishImportHint;

  /// No description provided for @publishImportCover.
  ///
  /// In fr, this message translates to:
  /// **'Image de couverture'**
  String get publishImportCover;

  /// No description provided for @publishImportCoverHint.
  ///
  /// In fr, this message translates to:
  /// **'Photo de la galerie'**
  String get publishImportCoverHint;

  /// No description provided for @publishImportProof.
  ///
  /// In fr, this message translates to:
  /// **'Document ou preuve'**
  String get publishImportProof;

  /// No description provided for @publishImportProofHint.
  ///
  /// In fr, this message translates to:
  /// **'PDF, JPG, PNG ou WebP · 10 Mo max.'**
  String get publishImportProofHint;

  /// No description provided for @publishShareTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partager un témoignage'**
  String get publishShareTitle;

  /// No description provided for @publishWhichForm.
  ///
  /// In fr, this message translates to:
  /// **'Quelle forme prend votre témoignage ?'**
  String get publishWhichForm;

  /// No description provided for @publishRecordVideo.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer une vidéo'**
  String get publishRecordVideo;

  /// No description provided for @publishRecordAudio.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer un audio'**
  String get publishRecordAudio;

  /// No description provided for @publishWriteText.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un texte'**
  String get publishWriteText;

  /// No description provided for @publishOtherWays.
  ///
  /// In fr, this message translates to:
  /// **'Autres façons de partager'**
  String get publishOtherWays;

  /// No description provided for @publishShortHint.
  ///
  /// In fr, this message translates to:
  /// **'60 secondes · Impact immédiat'**
  String get publishShortHint;

  /// No description provided for @publishJournalOption.
  ///
  /// In fr, this message translates to:
  /// **'Carnet privé'**
  String get publishJournalOption;

  /// No description provided for @publishJournalOptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Garder un témoignage pour moi, sans le publier'**
  String get publishJournalOptionHint;

  /// No description provided for @publishCreateEvent.
  ///
  /// In fr, this message translates to:
  /// **'Créer un événement'**
  String get publishCreateEvent;

  /// No description provided for @publishCreateEventHint.
  ///
  /// In fr, this message translates to:
  /// **'Croisade, conférence, camp… avec participation et direct'**
  String get publishCreateEventHint;

  /// No description provided for @publishLiveHint.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage en direct, en temps réel'**
  String get publishLiveHint;

  /// No description provided for @publishYouTubeLink.
  ///
  /// In fr, this message translates to:
  /// **'Lien YouTube'**
  String get publishYouTubeLink;

  /// No description provided for @publishYouTubeHint.
  ///
  /// In fr, this message translates to:
  /// **'Publier une vidéo déjà sur YouTube (administrateurs)'**
  String get publishYouTubeHint;

  /// No description provided for @publishStatusLabel.
  ///
  /// In fr, this message translates to:
  /// **'Statut :'**
  String get publishStatusLabel;

  /// No description provided for @publishEventTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage de l\'événement'**
  String get publishEventTestimony;

  /// No description provided for @publishEventDetach.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas rattacher à l\'événement'**
  String get publishEventDetach;

  /// No description provided for @publishProphecyFulfillment.
  ///
  /// In fr, this message translates to:
  /// **'Accomplissement de la parole'**
  String get publishProphecyFulfillment;

  /// No description provided for @publishProphecyDetach.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas rattacher à la parole'**
  String get publishProphecyDetach;

  /// No description provided for @publishProphecyMakePublic.
  ///
  /// In fr, this message translates to:
  /// **'Publier aussi la parole prophétique'**
  String get publishProphecyMakePublic;

  /// No description provided for @publishProphecyMakePublicHint.
  ///
  /// In fr, this message translates to:
  /// **'Elle sera montrée avec votre témoignage, une fois celui-ci publié.'**
  String get publishProphecyMakePublicHint;

  /// No description provided for @publishStepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {step} sur 3 · {name}'**
  String publishStepOf(int step, String name);

  /// No description provided for @publishStepDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get publishStepDetails;

  /// No description provided for @publishStepContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu'**
  String get publishStepContent;

  /// No description provided for @publishStepPublication.
  ///
  /// In fr, this message translates to:
  /// **'Publication'**
  String get publishStepPublication;

  /// No description provided for @publishTitleOptional.
  ///
  /// In fr, this message translates to:
  /// **'Titre (optionnel)'**
  String get publishTitleOptional;

  /// No description provided for @publishTitleHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex : Dieu a changé ma vie'**
  String get publishTitleHint;

  /// No description provided for @publishDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get publishDescription;

  /// No description provided for @publishDescriptionOptional.
  ///
  /// In fr, this message translates to:
  /// **'Description (optionnel)'**
  String get publishDescriptionOptional;

  /// No description provided for @publishTranscriptHint.
  ///
  /// In fr, this message translates to:
  /// **'Sert aussi de transcription pour l\'accessibilité.'**
  String get publishTranscriptHint;

  /// No description provided for @publishBodyHint.
  ///
  /// In fr, this message translates to:
  /// **'Racontez votre témoignage… (@ pour mentionner)'**
  String get publishBodyHint;

  /// No description provided for @publishCategoryOptional.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie (optionnel)'**
  String get publishCategoryOptional;

  /// No description provided for @publishCoverOptional.
  ///
  /// In fr, this message translates to:
  /// **'Image de couverture (optionnel)'**
  String get publishCoverOptional;

  /// No description provided for @publishYourTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage'**
  String get publishYourTestimony;

  /// No description provided for @publishNoDescription.
  ///
  /// In fr, this message translates to:
  /// **'Aucune description.'**
  String get publishNoDescription;

  /// No description provided for @publishVerseOptional.
  ///
  /// In fr, this message translates to:
  /// **'Verset biblique (optionnel)'**
  String get publishVerseOptional;

  /// No description provided for @publishVerseHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Jean 3:16 ou sélectionnez dans la Bible'**
  String get publishVerseHint;

  /// No description provided for @publishMicPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission microphone refusée.'**
  String get publishMicPermissionDenied;

  /// No description provided for @publishImportFromFiles.
  ///
  /// In fr, this message translates to:
  /// **'Importer depuis les fichiers'**
  String get publishImportFromFiles;

  /// No description provided for @publishVideoFile.
  ///
  /// In fr, this message translates to:
  /// **'Fichier vidéo'**
  String get publishVideoFile;

  /// No description provided for @publishYouTubeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Lien YouTube non reconnu (youtube.com/watch?v=…, youtu.be/…, /shorts/…).'**
  String get publishYouTubeInvalid;

  /// No description provided for @publishYouTubeNote.
  ///
  /// In fr, this message translates to:
  /// **'La vidéo reste hébergée sur YouTube et sera lue avec le lecteur YouTube. Sa miniature sert d\'image de couverture.'**
  String get publishYouTubeNote;

  /// No description provided for @publishProofsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Preuves du témoignage (facultatif)'**
  String get publishProofsLabel;

  /// No description provided for @publishProofsHint.
  ///
  /// In fr, this message translates to:
  /// **'Joignez jusqu\'à 2 justificatifs (image ou PDF, 10 Mo au maximum). Par défaut, seuls vous et l\'équipe de modération pouvez les voir ; vous pouvez choisir de les publier.'**
  String get publishProofsHint;

  /// No description provided for @publishProofsPublic.
  ///
  /// In fr, this message translates to:
  /// **'Publier aussi mes preuves pour confirmer le témoignage'**
  String get publishProofsPublic;

  /// No description provided for @publishProofsPublicHint.
  ///
  /// In fr, this message translates to:
  /// **'Une fois le témoignage publié, tout le monde pourra les voir. Masquez d\'abord les informations personnelles. L\'équipe de modération peut retirer cet affichage.'**
  String get publishProofsPublicHint;

  /// No description provided for @publishProofFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Image de la galerie'**
  String get publishProofFromGallery;

  /// No description provided for @publishProofFromFiles.
  ///
  /// In fr, this message translates to:
  /// **'Document PDF ou image (fichiers)'**
  String get publishProofFromFiles;

  /// No description provided for @publishProofAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter la preuve {position}'**
  String publishProofAdd(int position);

  /// No description provided for @publishProofItem.
  ///
  /// In fr, this message translates to:
  /// **'Preuve {position} · {size}'**
  String publishProofItem(int position, String size);

  /// No description provided for @publishProofRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la preuve {position}'**
  String publishProofRemove(int position);

  /// No description provided for @publishProofUploadFailed.
  ///
  /// In fr, this message translates to:
  /// **'La preuve {position} n\'a pas pu être envoyée'**
  String publishProofUploadFailed(int position);

  /// No description provided for @publishSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée. Reconnecte-toi.'**
  String get publishSessionExpired;

  /// No description provided for @publishSavedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne — témoignage enregistré localement. Il sera envoyé à la prochaine connexion.'**
  String get publishSavedOffline;

  /// No description provided for @publishSavedToJournal.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré dans votre carnet privé 🔒'**
  String get publishSavedToJournal;

  /// No description provided for @publishSubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage soumis ! Il sera visible après modération.'**
  String get publishSubmitted;

  /// No description provided for @publishVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité'**
  String get publishVisibility;

  /// No description provided for @publishWhoCanSee.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut voir votre témoignage ?'**
  String get publishWhoCanSee;

  /// No description provided for @publishVisibilityPublic.
  ///
  /// In fr, this message translates to:
  /// **'Public'**
  String get publishVisibilityPublic;

  /// No description provided for @publishVisibilityPublicHint.
  ///
  /// In fr, this message translates to:
  /// **'Visible par tous les utilisateurs'**
  String get publishVisibilityPublicHint;

  /// No description provided for @publishVisibilityFriends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get publishVisibilityFriends;

  /// No description provided for @publishVisibilityFriendsHint.
  ///
  /// In fr, this message translates to:
  /// **'Visible uniquement par vos abonnés'**
  String get publishVisibilityFriendsHint;

  /// No description provided for @publishVisibilityPrivateHint.
  ///
  /// In fr, this message translates to:
  /// **'Gardé pour vous seul, sans modération. Vous pourrez le partager plus tard.'**
  String get publishVisibilityPrivateHint;

  /// No description provided for @publishCertifyBody.
  ///
  /// In fr, this message translates to:
  /// **'Je confirme que les faits relatés dans ce témoignage sont authentiques et vécus personnellement.'**
  String get publishCertifyBody;

  /// No description provided for @publishConsentRequired.
  ///
  /// In fr, this message translates to:
  /// **'La confirmation est requise pour publier.'**
  String get publishConsentRequired;

  /// No description provided for @publishCategoryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Pour publier, choisissez une catégorie (étape 1).'**
  String get publishCategoryRequired;

  /// No description provided for @publishJournalInfo.
  ///
  /// In fr, this message translates to:
  /// **'Ce témoignage sera rangé dans votre carnet privé : vous seul pourrez le voir, il ne sera ni publié ni relu par les modérateurs.\n\nVous pourrez le partager quand vous le souhaitez, depuis votre carnet.'**
  String get publishJournalInfo;

  /// No description provided for @publishChooseCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une catégorie'**
  String get publishChooseCategory;

  /// No description provided for @publishChange.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get publishChange;

  /// No description provided for @publishTapToAddCover.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour ajouter\nune image de couverture'**
  String get publishTapToAddCover;

  /// No description provided for @publishFormatHeading.
  ///
  /// In fr, this message translates to:
  /// **'Titre (# texte)'**
  String get publishFormatHeading;

  /// No description provided for @publishFormatBold.
  ///
  /// In fr, this message translates to:
  /// **'Gras (**texte**)'**
  String get publishFormatBold;

  /// No description provided for @publishFormatItalic.
  ///
  /// In fr, this message translates to:
  /// **'Italique (__texte__)'**
  String get publishFormatItalic;

  /// No description provided for @publishFormatStrike.
  ///
  /// In fr, this message translates to:
  /// **'Barré (~~texte~~)'**
  String get publishFormatStrike;

  /// No description provided for @publishFormatQuote.
  ///
  /// In fr, this message translates to:
  /// **'Citation (> texte)'**
  String get publishFormatQuote;

  /// No description provided for @publishFormatBullets.
  ///
  /// In fr, this message translates to:
  /// **'Liste à puces (- texte)'**
  String get publishFormatBullets;

  /// No description provided for @publishFormatNumbered.
  ///
  /// In fr, this message translates to:
  /// **'Liste numérotée (1. texte)'**
  String get publishFormatNumbered;

  /// No description provided for @publishRecordingDone.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement terminé ✓'**
  String get publishRecordingDone;

  /// No description provided for @publishFilmVideo.
  ///
  /// In fr, this message translates to:
  /// **'Filmer une vidéo'**
  String get publishFilmVideo;

  /// No description provided for @publishPickFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get publishPickFromGallery;

  /// No description provided for @publishTrimVideo.
  ///
  /// In fr, this message translates to:
  /// **'Couper la vidéo'**
  String get publishTrimVideo;

  /// No description provided for @publishThumbnail.
  ///
  /// In fr, this message translates to:
  /// **'Miniature'**
  String get publishThumbnail;

  /// No description provided for @publishThumbnailCustom.
  ///
  /// In fr, this message translates to:
  /// **'Perso.'**
  String get publishThumbnailCustom;

  /// No description provided for @publishOr.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get publishOr;

  /// No description provided for @publishSizeKb.
  ///
  /// In fr, this message translates to:
  /// **'{size} Ko'**
  String publishSizeKb(String size);

  /// No description provided for @publishSizeMb.
  ///
  /// In fr, this message translates to:
  /// **'{size} Mo'**
  String publishSizeMb(String size);

  /// No description provided for @publishSizeGb.
  ///
  /// In fr, this message translates to:
  /// **'{size} Go'**
  String publishSizeGb(String size);

  /// No description provided for @apiActingAsRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez plus ce compte.'**
  String get apiActingAsRevoked;

  /// No description provided for @apiFeatureNotDeployed.
  ///
  /// In fr, this message translates to:
  /// **'Cette fonctionnalité n\'est pas encore disponible sur le serveur. Réessayez après sa mise à jour.'**
  String get apiFeatureNotDeployed;

  /// No description provided for @apiNotDownloadedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Ce témoignage n\'est pas téléchargé (mode hors ligne).'**
  String get apiNotDownloadedOffline;

  /// No description provided for @apiServerError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur ({statusCode}).'**
  String apiServerError(int statusCode);

  /// No description provided for @apiUnexpectedResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue du serveur.'**
  String get apiUnexpectedResponse;

  /// No description provided for @appCategoryCareer.
  ///
  /// In fr, this message translates to:
  /// **'Emploi & Carrière'**
  String get appCategoryCareer;

  /// No description provided for @appCategoryProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get appCategoryProtection;

  /// No description provided for @appCategoryProvision.
  ///
  /// In fr, this message translates to:
  /// **'Provision'**
  String get appCategoryProvision;

  /// No description provided for @appCategoryStudies.
  ///
  /// In fr, this message translates to:
  /// **'Études'**
  String get appCategoryStudies;

  /// No description provided for @appSecurityAndPassword.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité et mot de passe'**
  String get appSecurityAndPassword;

  /// No description provided for @mediaFeedLayoutCards.
  ///
  /// In fr, this message translates to:
  /// **'Grandes cartes'**
  String get mediaFeedLayoutCards;

  /// No description provided for @mediaFeedLayoutCompact.
  ///
  /// In fr, this message translates to:
  /// **'Liste compacte'**
  String get mediaFeedLayoutCompact;

  /// No description provided for @mediaOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get mediaOffline;

  /// No description provided for @mediaOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Originale'**
  String get mediaOriginal;

  /// No description provided for @mediaPlayVideo.
  ///
  /// In fr, this message translates to:
  /// **'Lire la vidéo'**
  String get mediaPlayVideo;

  /// No description provided for @mediaProcessingShort.
  ///
  /// In fr, this message translates to:
  /// **'En traitement'**
  String get mediaProcessingShort;

  /// No description provided for @mediaRepeatAll.
  ///
  /// In fr, this message translates to:
  /// **'Répéter la liste'**
  String get mediaRepeatAll;

  /// No description provided for @mediaRepeatOff.
  ///
  /// In fr, this message translates to:
  /// **'Pas de répétition'**
  String get mediaRepeatOff;

  /// No description provided for @mediaRepeatOne.
  ///
  /// In fr, this message translates to:
  /// **'Répéter ce témoignage'**
  String get mediaRepeatOne;

  /// No description provided for @mediaVideoFailed.
  ///
  /// In fr, this message translates to:
  /// **'La vidéo n’a pas pu être traitée'**
  String get mediaVideoFailed;

  /// No description provided for @mediaVideoProcessing.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo en cours de traitement'**
  String get mediaVideoProcessing;

  /// No description provided for @mediaVideoResend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer la vidéo'**
  String get mediaVideoResend;

  /// No description provided for @qualityAudioHigh.
  ///
  /// In fr, this message translates to:
  /// **'Haute'**
  String get qualityAudioHigh;

  /// No description provided for @qualityAudioHighHint.
  ///
  /// In fr, this message translates to:
  /// **'Meilleur son · plus de données'**
  String get qualityAudioHighHint;

  /// No description provided for @qualityAudioLow.
  ///
  /// In fr, this message translates to:
  /// **'Faible'**
  String get qualityAudioLow;

  /// No description provided for @qualityAudioLowHint.
  ///
  /// In fr, this message translates to:
  /// **'Économique (≈64 kbps)'**
  String get qualityAudioLowHint;

  /// No description provided for @qualityAudioStandard.
  ///
  /// In fr, this message translates to:
  /// **'Standard'**
  String get qualityAudioStandard;

  /// No description provided for @qualityAudioStandardHint.
  ///
  /// In fr, this message translates to:
  /// **'Bon compromis (≈128 kbps)'**
  String get qualityAudioStandardHint;

  /// No description provided for @qualityAudioVeryLow.
  ///
  /// In fr, this message translates to:
  /// **'Très faible'**
  String get qualityAudioVeryLow;

  /// No description provided for @qualityAudioVeryLowHint.
  ///
  /// In fr, this message translates to:
  /// **'Minimum de données (≈32 kbps)'**
  String get qualityAudioVeryLowHint;

  /// No description provided for @qualityAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get qualityAuto;

  /// No description provided for @qualityAutoCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Auto ({current})'**
  String qualityAutoCurrent(String current);

  /// No description provided for @qualityAutoHint.
  ///
  /// In fr, this message translates to:
  /// **'S\'adapte à votre connexion'**
  String get qualityAutoHint;

  /// No description provided for @qualityVideoDataSaver.
  ///
  /// In fr, this message translates to:
  /// **'Économie'**
  String get qualityVideoDataSaver;

  /// No description provided for @qualityVideoDataSaverHint.
  ///
  /// In fr, this message translates to:
  /// **'Minimum de données · ≈ 4,5 Mo par minute'**
  String get qualityVideoDataSaverHint;

  /// No description provided for @qualityVideoFullLabel.
  ///
  /// In fr, this message translates to:
  /// **'{label} ({height}p)'**
  String qualityVideoFullLabel(String label, int height);

  /// No description provided for @qualityVideoHd.
  ///
  /// In fr, this message translates to:
  /// **'HD'**
  String get qualityVideoHd;

  /// No description provided for @qualityVideoHdHint.
  ///
  /// In fr, this message translates to:
  /// **'Haute qualité · plus de données'**
  String get qualityVideoHdHint;

  /// No description provided for @qualityVideoStandard.
  ///
  /// In fr, this message translates to:
  /// **'Standard'**
  String get qualityVideoStandard;

  /// No description provided for @qualityVideoStandardHint.
  ///
  /// In fr, this message translates to:
  /// **'Bon compromis · ≈ 6 Mo par minute'**
  String get qualityVideoStandardHint;

  /// No description provided for @sharedAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get sharedAll;

  /// No description provided for @sharedApprovedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte approuvé'**
  String get sharedApprovedAccount;

  /// No description provided for @sharedApprovedOrganization.
  ///
  /// In fr, this message translates to:
  /// **'Organisation approuvée'**
  String get sharedApprovedOrganization;

  /// No description provided for @sharedApprovedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié par l\'équipe de modération'**
  String get sharedApprovedTooltip;

  /// No description provided for @sharedCategoryConversion.
  ///
  /// In fr, this message translates to:
  /// **'Conversion'**
  String get sharedCategoryConversion;

  /// No description provided for @sharedCategoryDeliverance.
  ///
  /// In fr, this message translates to:
  /// **'Délivrance'**
  String get sharedCategoryDeliverance;

  /// No description provided for @sharedCategoryFamily.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get sharedCategoryFamily;

  /// No description provided for @sharedCategoryFinances.
  ///
  /// In fr, this message translates to:
  /// **'Finances'**
  String get sharedCategoryFinances;

  /// No description provided for @sharedCategoryHealing.
  ///
  /// In fr, this message translates to:
  /// **'Guérison'**
  String get sharedCategoryHealing;

  /// No description provided for @sharedCategoryMarriage.
  ///
  /// In fr, this message translates to:
  /// **'Mariage'**
  String get sharedCategoryMarriage;

  /// No description provided for @sharedCategoryMinistry.
  ///
  /// In fr, this message translates to:
  /// **'Ministère'**
  String get sharedCategoryMinistry;

  /// No description provided for @sharedCategoryMiracles.
  ///
  /// In fr, this message translates to:
  /// **'Miracles'**
  String get sharedCategoryMiracles;

  /// No description provided for @sharedCategoryProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection divine'**
  String get sharedCategoryProtection;

  /// No description provided for @sharedCategorySalvation.
  ///
  /// In fr, this message translates to:
  /// **'Salut'**
  String get sharedCategorySalvation;

  /// No description provided for @sharedCountryNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pays ne correspond à votre recherche.'**
  String get sharedCountryNoMatch;

  /// No description provided for @sharedCountryNoMatchWithDial.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pays ni indicatif ne correspond.'**
  String get sharedCountryNoMatchWithDial;

  /// No description provided for @sharedCountrySearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays'**
  String get sharedCountrySearch;

  /// No description provided for @sharedCountrySearchWithDial.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays ou un indicatif'**
  String get sharedCountrySearchWithDial;

  /// No description provided for @sharedCoverHint.
  ///
  /// In fr, this message translates to:
  /// **'Format large conseillé (1500 × 500 pixels).'**
  String get sharedCoverHint;

  /// No description provided for @sharedCoverPickGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get sharedCoverPickGallery;

  /// No description provided for @sharedCoverRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la couverture'**
  String get sharedCoverRemove;

  /// No description provided for @sharedCoverRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Photo de couverture retirée'**
  String get sharedCoverRemoved;

  /// No description provided for @sharedCoverSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'La photo de couverture n\'a pas pu être enregistrée.'**
  String get sharedCoverSaveFailed;

  /// No description provided for @sharedCoverSaveFailedNetwork.
  ///
  /// In fr, this message translates to:
  /// **'La photo de couverture n\'a pas pu être enregistrée. Vérifiez votre connexion.'**
  String get sharedCoverSaveFailedNetwork;

  /// No description provided for @sharedCoverTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photo de couverture'**
  String get sharedCoverTitle;

  /// No description provided for @sharedCoverUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Photo de couverture mise à jour'**
  String get sharedCoverUpdated;

  /// No description provided for @sharedDrawerAdministration.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get sharedDrawerAdministration;

  /// No description provided for @sharedDrawerBible.
  ///
  /// In fr, this message translates to:
  /// **'Bible'**
  String get sharedDrawerBible;

  /// No description provided for @sharedDrawerBibleSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Lire, rechercher, comparer les versions'**
  String get sharedDrawerBibleSubtitle;

  /// No description provided for @sharedDrawerCommunitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Organisations et personnes à suivre'**
  String get sharedDrawerCommunitySubtitle;

  /// No description provided for @sharedDrawerEventsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Croisades, conférences, camps…'**
  String get sharedDrawerEventsSubtitle;

  /// No description provided for @sharedDrawerFeedSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos abonnements et des témoignages pour vous'**
  String get sharedDrawerFeedSubtitle;

  /// No description provided for @sharedDrawerFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Mes abonnés'**
  String get sharedDrawerFollowers;

  /// No description provided for @sharedDrawerFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Mes abonnements'**
  String get sharedDrawerFollowing;

  /// No description provided for @sharedDrawerGuestSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Pour suivre des comptes et témoigner'**
  String get sharedDrawerGuestSubtitle;

  /// No description provided for @sharedDrawerJournal.
  ///
  /// In fr, this message translates to:
  /// **'Mon carnet privé'**
  String get sharedDrawerJournal;

  /// No description provided for @sharedDrawerLives.
  ///
  /// In fr, this message translates to:
  /// **'Directs'**
  String get sharedDrawerLives;

  /// No description provided for @sharedDrawerManagedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte administré · voir le profil'**
  String get sharedDrawerManagedAccount;

  /// No description provided for @sharedDrawerManagers.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs du compte'**
  String get sharedDrawerManagers;

  /// No description provided for @sharedDrawerManagersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Deux personnes au plus agissent en votre nom'**
  String get sharedDrawerManagersSubtitle;

  /// No description provided for @sharedDrawerModeration.
  ///
  /// In fr, this message translates to:
  /// **'Modération'**
  String get sharedDrawerModeration;

  /// No description provided for @sharedDrawerPrayerRequestsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Confiez un besoin, priez pour les autres'**
  String get sharedDrawerPrayerRequestsSubtitle;

  /// No description provided for @sharedDrawerPrayerSessionsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Priez ensemble, en direct'**
  String get sharedDrawerPrayerSessionsSubtitle;

  /// No description provided for @sharedDrawerProphecies.
  ///
  /// In fr, this message translates to:
  /// **'Paroles prophétiques'**
  String get sharedDrawerProphecies;

  /// No description provided for @sharedDrawerPropheciesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Gardez-les, priez, témoignez de leur accomplissement'**
  String get sharedDrawerPropheciesSubtitle;

  /// No description provided for @sharedDrawerSaved.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardés'**
  String get sharedDrawerSaved;

  /// No description provided for @sharedDrawerSwitchAccount.
  ///
  /// In fr, this message translates to:
  /// **'Changer de compte'**
  String get sharedDrawerSwitchAccount;

  /// No description provided for @sharedDrawerSwitchAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Agir au nom d\'un compte que vous administrez'**
  String get sharedDrawerSwitchAccountSubtitle;

  /// No description provided for @sharedDrawerViewProfile.
  ///
  /// In fr, this message translates to:
  /// **'Voir mon profil'**
  String get sharedDrawerViewProfile;

  /// No description provided for @sharedEmptyNoFavoritesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les témoignages que vous sauvegardez apparaîtront ici.'**
  String get sharedEmptyNoFavoritesSubtitle;

  /// No description provided for @sharedEmptyNoFavoritesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori'**
  String get sharedEmptyNoFavoritesTitle;

  /// No description provided for @sharedEmptyNoInternetSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez votre connexion internet et réessayez.'**
  String get sharedEmptyNoInternetSubtitle;

  /// No description provided for @sharedEmptyNoInternetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion'**
  String get sharedEmptyNoInternetTitle;

  /// No description provided for @sharedEmptyNoNotificationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à jour ! Revenez plus tard.'**
  String get sharedEmptyNoNotificationsSubtitle;

  /// No description provided for @sharedEmptyNoNotificationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pas de notifications'**
  String get sharedEmptyNoNotificationsTitle;

  /// No description provided for @sharedEmptyNoResultsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Essayez d\'autres mots-clés ou changez de catégorie.'**
  String get sharedEmptyNoResultsSubtitle;

  /// No description provided for @sharedEmptyNoTestimoniesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Soyez le premier à partager comment Dieu a agi dans votre vie.'**
  String get sharedEmptyNoTestimoniesSubtitle;

  /// No description provided for @sharedEmptyNoTestimoniesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage'**
  String get sharedEmptyNoTestimoniesTitle;

  /// No description provided for @sharedEmptyNothingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rien à afficher'**
  String get sharedEmptyNothingTitle;

  /// No description provided for @sharedFeatured.
  ///
  /// In fr, this message translates to:
  /// **'À la une'**
  String get sharedFeatured;

  /// No description provided for @sharedFeaturedTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage mis en avant'**
  String get sharedFeaturedTestimony;

  /// No description provided for @sharedGuestCreateAccountFor.
  ///
  /// In fr, this message translates to:
  /// **'Créez un compte pour {reason}'**
  String sharedGuestCreateAccountFor(String reason);

  /// No description provided for @sharedGuestDefaultReason.
  ///
  /// In fr, this message translates to:
  /// **'profiter de toutes les fonctionnalités'**
  String get sharedGuestDefaultReason;

  /// No description provided for @sharedGuestLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get sharedGuestLater;

  /// No description provided for @sharedGuestSheetBody.
  ///
  /// In fr, this message translates to:
  /// **'C\'est gratuit et rapide. Vous pourrez partager, réagir et retrouver vos témoignages sur tous vos appareils.'**
  String get sharedGuestSheetBody;

  /// No description provided for @sharedMediaAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get sharedMediaAudio;

  /// No description provided for @sharedMediaVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get sharedMediaVideo;

  /// No description provided for @sharedMentionFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Abonné'**
  String get sharedMentionFollowing;

  /// No description provided for @sharedMentionNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte trouvé pour « {query} ».'**
  String sharedMentionNoMatch(String query);

  /// No description provided for @sharedMentionSearchError.
  ///
  /// In fr, this message translates to:
  /// **'Recherche indisponible. Réessayez.'**
  String get sharedMentionSearchError;

  /// No description provided for @sharedMentionSearching.
  ///
  /// In fr, this message translates to:
  /// **'Recherche…'**
  String get sharedMentionSearching;

  /// No description provided for @sharedMentionSuggestions.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions de mentions'**
  String get sharedMentionSuggestions;

  /// No description provided for @sharedMentionTypeName.
  ///
  /// In fr, this message translates to:
  /// **'Tapez un nom après « @ ».'**
  String get sharedMentionTypeName;

  /// No description provided for @sharedOrgTypeAssociation.
  ///
  /// In fr, this message translates to:
  /// **'Association'**
  String get sharedOrgTypeAssociation;

  /// No description provided for @sharedOrgTypeChurch.
  ///
  /// In fr, this message translates to:
  /// **'Église'**
  String get sharedOrgTypeChurch;

  /// No description provided for @sharedOrgTypeMedia.
  ///
  /// In fr, this message translates to:
  /// **'Média chrétien'**
  String get sharedOrgTypeMedia;

  /// No description provided for @sharedOrgTypeMinistry.
  ///
  /// In fr, this message translates to:
  /// **'Ministère'**
  String get sharedOrgTypeMinistry;

  /// No description provided for @sharedOrgTypeNgo.
  ///
  /// In fr, this message translates to:
  /// **'ONG'**
  String get sharedOrgTypeNgo;

  /// No description provided for @sharedOrgTypeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get sharedOrgTypeOther;

  /// No description provided for @sharedOrganization.
  ///
  /// In fr, this message translates to:
  /// **'Organisation'**
  String get sharedOrganization;

  /// No description provided for @sharedPhoneDial.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif'**
  String get sharedPhoneDial;

  /// No description provided for @sharedPhoneDialRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez l\'indicatif du pays.'**
  String get sharedPhoneDialRequired;

  /// No description provided for @sharedPhoneDialSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Indicatif du pays'**
  String get sharedPhoneDialSemantics;

  /// No description provided for @sharedPhoneInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Numéro de téléphone invalide.'**
  String get sharedPhoneInvalid;

  /// No description provided for @sharedPhoneLabelRequired.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone *'**
  String get sharedPhoneLabelRequired;

  /// No description provided for @sharedPhoneNumberHint.
  ///
  /// In fr, this message translates to:
  /// **'Numéro'**
  String get sharedPhoneNumberHint;

  /// No description provided for @sharedPhonePrivacyNote.
  ///
  /// In fr, this message translates to:
  /// **'Sert uniquement à vérifier votre compte : il n\'est jamais affiché publiquement.'**
  String get sharedPhonePrivacyNote;

  /// No description provided for @sharedPhoneRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro de téléphone est obligatoire.'**
  String get sharedPhoneRequired;

  /// No description provided for @sharedProofDownloadFailed.
  ///
  /// In fr, this message translates to:
  /// **'La preuve n\'a pas pu être téléchargée.'**
  String get sharedProofDownloadFailed;

  /// No description provided for @sharedProofDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement de la preuve…'**
  String get sharedProofDownloading;

  /// No description provided for @sharedProofLabel.
  ///
  /// In fr, this message translates to:
  /// **'Preuve {position}'**
  String sharedProofLabel(int position);

  /// No description provided for @sharedProofsPublicNote.
  ///
  /// In fr, this message translates to:
  /// **'Documents partagés par l\'auteur pour confirmer ce témoignage.'**
  String get sharedProofsPublicNote;

  /// No description provided for @sharedProofsStaffNote.
  ///
  /// In fr, this message translates to:
  /// **'Visibles de l\'auteur et de l\'équipe de modération ; aussi du public si l\'auteur a accepté leur publication (une fois le témoignage publié).'**
  String get sharedProofsStaffNote;

  /// No description provided for @sharedProofsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Preuves du témoignage'**
  String get sharedProofsTitle;

  /// No description provided for @sharedReasonPublishTestimony.
  ///
  /// In fr, this message translates to:
  /// **'publier votre témoignage'**
  String get sharedReasonPublishTestimony;

  /// No description provided for @sharedReasonShareTestimony.
  ///
  /// In fr, this message translates to:
  /// **'partager votre témoignage'**
  String get sharedReasonShareTestimony;

  /// No description provided for @sharedSearchClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get sharedSearchClear;

  /// No description provided for @sharedSearchClearAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get sharedSearchClearAll;

  /// No description provided for @sharedSearchClearAllSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Effacer toutes les recherches récentes'**
  String get sharedSearchClearAllSemantics;

  /// No description provided for @sharedSearchComplete.
  ///
  /// In fr, this message translates to:
  /// **'Compléter avec « {text} »'**
  String sharedSearchComplete(String text);

  /// No description provided for @sharedSearchDirectAccess.
  ///
  /// In fr, this message translates to:
  /// **'Accès direct'**
  String get sharedSearchDirectAccess;

  /// No description provided for @sharedSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher…'**
  String get sharedSearchHint;

  /// No description provided for @sharedSearchLoadingSuggestions.
  ///
  /// In fr, this message translates to:
  /// **'Recherche de suggestions…'**
  String get sharedSearchLoadingSuggestions;

  /// No description provided for @sharedSearchRecent.
  ///
  /// In fr, this message translates to:
  /// **'Récentes'**
  String get sharedSearchRecent;

  /// No description provided for @sharedSearchRecentSearches.
  ///
  /// In fr, this message translates to:
  /// **'Recherches récentes'**
  String get sharedSearchRecentSearches;

  /// No description provided for @sharedSearchRecentSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Recherche récente : {text}'**
  String sharedSearchRecentSemantics(String text);

  /// No description provided for @sharedSearchRemoveRecent.
  ///
  /// In fr, this message translates to:
  /// **'Retirer « {text} » des recherches récentes'**
  String sharedSearchRemoveRecent(String text);

  /// No description provided for @sharedSearchResultSemantics.
  ///
  /// In fr, this message translates to:
  /// **'{type} : {text}'**
  String sharedSearchResultSemantics(String type, String text);

  /// No description provided for @sharedSearchSuggestionCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 proposition} =1{1 proposition} other{{count} propositions}}'**
  String sharedSearchSuggestionCount(int count);

  /// No description provided for @sharedSearchSuggestionSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Suggestion : {text}'**
  String sharedSearchSuggestionSemantics(String text);

  /// No description provided for @sharedSearchSuggestions.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions'**
  String get sharedSearchSuggestions;

  /// No description provided for @sharedSearchTypeAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get sharedSearchTypeAccount;

  /// No description provided for @sharedSearchTypeBibleBook.
  ///
  /// In fr, this message translates to:
  /// **'Livre de la Bible'**
  String get sharedSearchTypeBibleBook;

  /// No description provided for @sharedSearchTypeCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get sharedSearchTypeCategory;

  /// No description provided for @sharedSearchTypeResult.
  ///
  /// In fr, this message translates to:
  /// **'Résultat'**
  String get sharedSearchTypeResult;

  /// No description provided for @sharedSearchVerifiedSuffix.
  ///
  /// In fr, this message translates to:
  /// **', vérifié'**
  String get sharedSearchVerifiedSuffix;

  /// No description provided for @sharedTestify.
  ///
  /// In fr, this message translates to:
  /// **'Témoigner'**
  String get sharedTestify;

  /// No description provided for @sharedTestifyInvitation.
  ///
  /// In fr, this message translates to:
  /// **'Invitation à témoigner'**
  String get sharedTestifyInvitation;

  /// No description provided for @sharedTestimonyApproved.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage approuvé'**
  String get sharedTestimonyApproved;

  /// No description provided for @sharedTestimonyApprovedSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage approuvé. {tooltip}'**
  String sharedTestimonyApprovedSemantics(String tooltip);

  /// No description provided for @sharedTextCollapse.
  ///
  /// In fr, this message translates to:
  /// **'Réduire ‹'**
  String get sharedTextCollapse;

  /// No description provided for @sharedTextReadEnd.
  ///
  /// In fr, this message translates to:
  /// **'Lire la fin ›'**
  String get sharedTextReadEnd;

  /// No description provided for @sharedTextReadMore.
  ///
  /// In fr, this message translates to:
  /// **'Lire la suite ›'**
  String get sharedTextReadMore;

  /// No description provided for @sharedVerseSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Verset {reference}'**
  String sharedVerseSemantics(String reference);

  /// No description provided for @sharedWhyTestifyCount.
  ///
  /// In fr, this message translates to:
  /// **'{reasons} raisons et {verses} versets de la Bible'**
  String sharedWhyTestifyCount(int reasons, int verses);

  /// No description provided for @sharedWhyTestifyPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Dieu a agi dans votre vie ? Votre histoire peut fortifier quelqu\'un.'**
  String get sharedWhyTestifyPrompt;

  /// No description provided for @sharedWhyTestifyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi témoigner ?'**
  String get sharedWhyTestifyTitle;

  /// No description provided for @notifTypeComment.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire'**
  String get notifTypeComment;

  /// No description provided for @notifTypeLike.
  ///
  /// In fr, this message translates to:
  /// **'Like'**
  String get notifTypeLike;

  /// No description provided for @notifTypePrayer.
  ///
  /// In fr, this message translates to:
  /// **'Prière'**
  String get notifTypePrayer;

  /// No description provided for @notifTypeApproved.
  ///
  /// In fr, this message translates to:
  /// **'Approuvé'**
  String get notifTypeApproved;

  /// No description provided for @notifTypeNewTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau témoignage'**
  String get notifTypeNewTestimony;

  /// No description provided for @notifTypeResubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyé en modération'**
  String get notifTypeResubmitted;

  /// No description provided for @notifTypeApprovalRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Badge retiré'**
  String get notifTypeApprovalRevoked;

  /// No description provided for @notifTypePendingCorrection.
  ///
  /// In fr, this message translates to:
  /// **'Correction requise'**
  String get notifTypePendingCorrection;

  /// No description provided for @notifTypeOrganizationVerified.
  ///
  /// In fr, this message translates to:
  /// **'Organisation vérifiée'**
  String get notifTypeOrganizationVerified;

  /// No description provided for @notifTypeOrganizationRejected.
  ///
  /// In fr, this message translates to:
  /// **'Vérification refusée'**
  String get notifTypeOrganizationRejected;

  /// No description provided for @notifTypeAccountVerified.
  ///
  /// In fr, this message translates to:
  /// **'Compte vérifié'**
  String get notifTypeAccountVerified;

  /// No description provided for @notifTypeAccountVerification.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du compte'**
  String get notifTypeAccountVerification;

  /// No description provided for @notifTypeLive.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get notifTypeLive;

  /// No description provided for @notifTypeEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get notifTypeEvent;

  /// No description provided for @notifTypeFollow.
  ///
  /// In fr, this message translates to:
  /// **'Abonné'**
  String get notifTypeFollow;

  /// No description provided for @notifTypeShare.
  ///
  /// In fr, this message translates to:
  /// **'Partage'**
  String get notifTypeShare;

  /// No description provided for @notifTypeMention.
  ///
  /// In fr, this message translates to:
  /// **'Mention'**
  String get notifTypeMention;

  /// No description provided for @notifTypeRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusé'**
  String get notifTypeRejected;

  /// No description provided for @notifTypeAccountManagers.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs'**
  String get notifTypeAccountManagers;

  /// No description provided for @notifBodyComment.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a commenté votre témoignage « {title} »'**
  String notifBodyComment(String actor, String title);

  /// No description provided for @notifBodyReacted.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a réagi à votre publication'**
  String notifBodyReacted(String actor);

  /// No description provided for @notifBodyLiked.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a aimé votre témoignage « {title} »'**
  String notifBodyLiked(String actor, String title);

  /// No description provided for @notifBodyPrayer.
  ///
  /// In fr, this message translates to:
  /// **'{actor} prie pour vous suite à « {title} »'**
  String notifBodyPrayer(String actor, String title);

  /// No description provided for @notifBodyApproved.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage « {title} » a été approuvé'**
  String notifBodyApproved(String title);

  /// No description provided for @notifBodyNewTestimony.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a partagé un nouveau témoignage « {title} »'**
  String notifBodyNewTestimony(String actor, String title);

  /// No description provided for @notifBodyApprovalRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Le badge « Approuvé » a été retiré de votre compte'**
  String get notifBodyApprovalRevoked;

  /// No description provided for @notifBodyResubmitted.
  ///
  /// In fr, this message translates to:
  /// **'Un témoignage a été modifié et renvoyé en modération'**
  String get notifBodyResubmitted;

  /// No description provided for @notifBodyPendingCorrection.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage « {title} » nécessite des corrections'**
  String notifBodyPendingCorrection(String title);

  /// No description provided for @notifBodyOrganizationVerified.
  ///
  /// In fr, this message translates to:
  /// **'Votre organisation a été vérifiée : le badge est maintenant visible'**
  String get notifBodyOrganizationVerified;

  /// No description provided for @notifBodyOrganizationRejected.
  ///
  /// In fr, this message translates to:
  /// **'La vérification de votre organisation a été refusée'**
  String get notifBodyOrganizationRejected;

  /// No description provided for @notifBodyAccountVerified.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est vérifié : le badge est maintenant visible'**
  String get notifBodyAccountVerified;

  /// No description provided for @notifBodyAccountVerificationRejected.
  ///
  /// In fr, this message translates to:
  /// **'La vérification de votre compte a été refusée'**
  String get notifBodyAccountVerificationRejected;

  /// No description provided for @notifBodyLiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'{actor} est en direct : {title}'**
  String notifBodyLiveTitle(String actor, String title);

  /// No description provided for @notifBodyLive.
  ///
  /// In fr, this message translates to:
  /// **'{actor} est en direct'**
  String notifBodyLive(String actor);

  /// No description provided for @notifBodyFollow.
  ///
  /// In fr, this message translates to:
  /// **'{actor} vous suit maintenant'**
  String notifBodyFollow(String actor);

  /// No description provided for @notifBodyShareTitle.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a partagé votre témoignage « {title} »'**
  String notifBodyShareTitle(String actor, String title);

  /// No description provided for @notifBodyShare.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a partagé votre témoignage'**
  String notifBodyShare(String actor);

  /// No description provided for @notifBodyMention.
  ///
  /// In fr, this message translates to:
  /// **'{actor} vous a mentionné'**
  String notifBodyMention(String actor);

  /// No description provided for @notifBodyRejected.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage « {title} » n\'a pas été publié'**
  String notifBodyRejected(String title);

  /// No description provided for @notifBodyManagerAddedBy.
  ///
  /// In fr, this message translates to:
  /// **'{actor} vous a nommé administrateur de son compte'**
  String notifBodyManagerAddedBy(String actor);

  /// No description provided for @notifBodyManagerAdded.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez été nommé administrateur d\'un compte'**
  String get notifBodyManagerAdded;

  /// No description provided for @notifBodyManagerRemovedBy.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez plus le compte de {actor}'**
  String notifBodyManagerRemovedBy(String actor);

  /// No description provided for @notifBodyManagerRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'administrez plus un compte'**
  String get notifBodyManagerRemoved;

  /// No description provided for @notifTitleComment.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau commentaire'**
  String get notifTitleComment;

  /// No description provided for @notifTitleReaction.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle réaction'**
  String get notifTitleReaction;

  /// No description provided for @notifTitlePopular.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage populaire'**
  String get notifTitlePopular;

  /// No description provided for @notifTitlePrayerSession.
  ///
  /// In fr, this message translates to:
  /// **'Session de prière'**
  String get notifTitlePrayerSession;

  /// No description provided for @notifTitlePrayer.
  ///
  /// In fr, this message translates to:
  /// **'Prière pour vous'**
  String get notifTitlePrayer;

  /// No description provided for @notifTitleApproved.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage approuvé'**
  String get notifTitleApproved;

  /// No description provided for @notifTitleFollow.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel abonné'**
  String get notifTitleFollow;

  /// No description provided for @notifTitlePostShared.
  ///
  /// In fr, this message translates to:
  /// **'Publication partagée'**
  String get notifTitlePostShared;

  /// No description provided for @notifTitleTestimonyShared.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage partagé'**
  String get notifTitleTestimonyShared;

  /// No description provided for @notifTitleMention.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez été mentionné'**
  String get notifTitleMention;

  /// No description provided for @notifTitleRejected.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage non publié'**
  String get notifTitleRejected;

  /// No description provided for @notifTitleManagerAdded.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compte à administrer'**
  String get notifTitleManagerAdded;

  /// No description provided for @notifTitleManagerRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Administration retirée'**
  String get notifTitleManagerRemoved;

  /// No description provided for @communityTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get communityTabAll;

  /// No description provided for @communityTabOrganizations.
  ///
  /// In fr, this message translates to:
  /// **'Organisations'**
  String get communityTabOrganizations;

  /// No description provided for @communityTabPeople.
  ///
  /// In fr, this message translates to:
  /// **'Personnes'**
  String get communityTabPeople;

  /// No description provided for @communityTabSuggestions.
  ///
  /// In fr, this message translates to:
  /// **'Suggestions'**
  String get communityTabSuggestions;

  /// No description provided for @communityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Communauté'**
  String get communityTitle;

  /// No description provided for @communityFollowSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour suivre ce compte.'**
  String get communityFollowSignIn;

  /// No description provided for @communityFollowSelf.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas vous suivre vous-même.'**
  String get communityFollowSelf;

  /// No description provided for @communityFollowFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible. Vérifiez votre connexion.'**
  String get communityFollowFailed;

  /// No description provided for @communitySuggestionsError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les suggestions. Vérifiez votre connexion.'**
  String get communitySuggestionsError;

  /// No description provided for @communitySuggestionsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune suggestion pour le moment. Parcourez l\'onglet « Tous » pour découvrir la communauté.'**
  String get communitySuggestionsEmpty;

  /// No description provided for @communitySearchPeople.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une personne'**
  String get communitySearchPeople;

  /// No description provided for @communitySearchOrganizations.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une organisation, une ville…'**
  String get communitySearchOrganizations;

  /// No description provided for @communitySearchAll.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un compte, une ville…'**
  String get communitySearchAll;

  /// No description provided for @communityEmptyPeople.
  ///
  /// In fr, this message translates to:
  /// **'Les personnes inscrites apparaîtront ici.'**
  String get communityEmptyPeople;

  /// No description provided for @communityEmptyOrganizations.
  ///
  /// In fr, this message translates to:
  /// **'Les églises, ministères et associations inscrits apparaîtront ici.'**
  String get communityEmptyOrganizations;

  /// No description provided for @communityEmptyAll.
  ///
  /// In fr, this message translates to:
  /// **'Les personnes et organisations inscrites apparaîtront ici.'**
  String get communityEmptyAll;

  /// No description provided for @communityDiscover.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir la Communauté'**
  String get communityDiscover;

  /// No description provided for @communityFollowsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés et abonnements'**
  String get communityFollowsTitle;

  /// No description provided for @communityFollowersTab.
  ///
  /// In fr, this message translates to:
  /// **'Abonnés'**
  String get communityFollowersTab;

  /// No description provided for @communityFollowingTab.
  ///
  /// In fr, this message translates to:
  /// **'Abonnements'**
  String get communityFollowingTab;

  /// No description provided for @communitySearchFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans mes abonnés'**
  String get communitySearchFollowers;

  /// No description provided for @communityFollowBack.
  ///
  /// In fr, this message translates to:
  /// **'Suivre en retour'**
  String get communityFollowBack;

  /// No description provided for @communityFollowersEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Personne ne vous suit encore.\nPubliez des témoignages et participez à la Communauté : ceux qui vous suivront apparaîtront ici.'**
  String get communityFollowersEmpty;

  /// No description provided for @communityFollowersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 compte vous suit} =1{1 compte vous suit} other{{count} comptes vous suivent}}'**
  String communityFollowersCount(int count);

  /// No description provided for @communitySearchFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans mes abonnements'**
  String get communitySearchFollowing;

  /// No description provided for @communityFollowingEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne suivez encore personne.\nSuivez des églises, des ministères et des personnes pour être prévenu de leurs témoignages et de leurs directs.'**
  String get communityFollowingEmpty;

  /// No description provided for @communityFollowingCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Vous suivez 0 compte} =1{Vous suivez 1 compte} other{Vous suivez {count} comptes}}'**
  String communityFollowingCount(int count);

  /// No description provided for @communityProfileLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Ce profil n\'a pas pu être chargé.'**
  String get communityProfileLoadError;

  /// No description provided for @communityProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get communityProfile;

  /// No description provided for @communityTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages'**
  String get communityTestimonies;

  /// No description provided for @communityNoTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage publié pour le moment.'**
  String get communityNoTestimonies;

  /// No description provided for @communityFollow.
  ///
  /// In fr, this message translates to:
  /// **'Suivre'**
  String get communityFollow;

  /// No description provided for @communityFollowing.
  ///
  /// In fr, this message translates to:
  /// **'Abonné'**
  String get communityFollowing;

  /// No description provided for @communityAccountCounts.
  ///
  /// In fr, this message translates to:
  /// **'{followers, plural, =0{0 abonné} =1{1 abonné} other{{followers} abonnés}} · {testimonies, plural, =0{0 témoignage} =1{1 témoignage} other{{testimonies} témoignages}}'**
  String communityAccountCounts(int followers, int testimonies);

  /// No description provided for @communityFollowSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Suivre{name}'**
  String communityFollowSemantics(Object name);

  /// No description provided for @communityUnfollowSemantics.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus suivre{name}'**
  String communityUnfollowSemantics(Object name);

  /// No description provided for @communityListNotDeployed.
  ///
  /// In fr, this message translates to:
  /// **'Cette liste n\'est pas encore disponible sur le serveur. Réessayez plus tard.'**
  String get communityListNotDeployed;

  /// No description provided for @communityListSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour voir cette liste.'**
  String get communityListSignIn;

  /// No description provided for @communityListTooMany.
  ///
  /// In fr, this message translates to:
  /// **'Trop de demandes. Patientez un instant puis réessayez.'**
  String get communityListTooMany;

  /// No description provided for @communityListError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la liste. Vérifiez votre connexion.'**
  String get communityListError;

  /// No description provided for @communityNoMatch.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte ne correspond à votre recherche.'**
  String get communityNoMatch;

  /// No description provided for @communitySuggestedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comptes à suivre'**
  String get communitySuggestedTitle;

  /// No description provided for @communityVerifiedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte vérifié'**
  String get communityVerifiedAccount;

  /// No description provided for @communityStatTestimony.
  ///
  /// In fr, this message translates to:
  /// **'témoignage'**
  String get communityStatTestimony;

  /// No description provided for @communityStatTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'témoignages'**
  String get communityStatTestimonies;

  /// No description provided for @communityStatFollower.
  ///
  /// In fr, this message translates to:
  /// **'abonné'**
  String get communityStatFollower;

  /// No description provided for @communityStatFollowers.
  ///
  /// In fr, this message translates to:
  /// **'abonnés'**
  String get communityStatFollowers;

  /// No description provided for @communityStatFollowingOne.
  ///
  /// In fr, this message translates to:
  /// **'abonnement'**
  String get communityStatFollowingOne;

  /// No description provided for @communityStatFollowingMany.
  ///
  /// In fr, this message translates to:
  /// **'abonnements'**
  String get communityStatFollowingMany;

  /// No description provided for @repostKindEventThis.
  ///
  /// In fr, this message translates to:
  /// **'cet événement'**
  String get repostKindEventThis;

  /// No description provided for @repostKindEventThe.
  ///
  /// In fr, this message translates to:
  /// **'L’événement'**
  String get repostKindEventThe;

  /// No description provided for @repostKindPrayerRequestThis.
  ///
  /// In fr, this message translates to:
  /// **'cette requête de prière'**
  String get repostKindPrayerRequestThis;

  /// No description provided for @repostKindPrayerRequestThe.
  ///
  /// In fr, this message translates to:
  /// **'La requête de prière'**
  String get repostKindPrayerRequestThe;

  /// No description provided for @repostKindPrayerSessionThis.
  ///
  /// In fr, this message translates to:
  /// **'cette session de prière'**
  String get repostKindPrayerSessionThis;

  /// No description provided for @repostKindPrayerSessionThe.
  ///
  /// In fr, this message translates to:
  /// **'La session de prière'**
  String get repostKindPrayerSessionThe;

  /// No description provided for @repostSharedWithFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Partagé avec vos abonnés.'**
  String get repostSharedWithFollowers;

  /// No description provided for @repostCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Partage annulé.'**
  String get repostCancelled;

  /// No description provided for @repostServerUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne prend pas encore en charge cette action. Réessayez plus tard.'**
  String get repostServerUnsupported;

  /// No description provided for @repostReactionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer votre réaction. Réessayez.'**
  String get repostReactionFailed;

  /// No description provided for @repostReasonReactShare.
  ///
  /// In fr, this message translates to:
  /// **'réagir et partager'**
  String get repostReasonReactShare;

  /// No description provided for @repostShareThis.
  ///
  /// In fr, this message translates to:
  /// **'Partager {what}'**
  String repostShareThis(String what);

  /// No description provided for @repostOnTestiApp.
  ///
  /// In fr, this message translates to:
  /// **'Sur My Testimony'**
  String get repostOnTestiApp;

  /// No description provided for @repostCannotShare.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de partager {what} sur My Testimony : la publication est la vôtre, ou elle n’est pas publique.'**
  String repostCannotShare(String what);

  /// No description provided for @repostLinkCopied.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get repostLinkCopied;

  /// No description provided for @repostOtherApps.
  ///
  /// In fr, this message translates to:
  /// **'Autres applis'**
  String get repostOtherApps;

  /// No description provided for @repostReasonShare.
  ///
  /// In fr, this message translates to:
  /// **'partager avec vos abonnés'**
  String get repostReasonShare;

  /// No description provided for @repostFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le partage a échoué. Réessayez.'**
  String get repostFailed;

  /// No description provided for @repostShareOnTestiApp.
  ///
  /// In fr, this message translates to:
  /// **'Partager sur My Testimony'**
  String get repostShareOnTestiApp;

  /// No description provided for @repostContentExplain.
  ///
  /// In fr, this message translates to:
  /// **'{what} apparaîtra dans le fil de vos abonnés, avec son auteur, pour toucher plus de monde. L’auteur sera prévenu.'**
  String repostContentExplain(String what);

  /// No description provided for @repostCommentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Votre commentaire (facultatif)'**
  String get repostCommentLabel;

  /// No description provided for @repostCommentHintContent.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi vous le partagez…'**
  String get repostCommentHintContent;

  /// No description provided for @repostShareWithFollowers.
  ///
  /// In fr, this message translates to:
  /// **'Partager avec mes abonnés'**
  String get repostShareWithFollowers;

  /// No description provided for @repostUpdate.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à jour mon partage'**
  String get repostUpdate;

  /// No description provided for @repostUndo.
  ///
  /// In fr, this message translates to:
  /// **'Annuler mon partage'**
  String get repostUndo;

  /// No description provided for @repostSomeone.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu’un'**
  String get repostSomeone;

  /// No description provided for @repostTestimonyShared.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage partagé avec vos abonnés.'**
  String get repostTestimonyShared;

  /// No description provided for @repostJustNow.
  ///
  /// In fr, this message translates to:
  /// **'à l’instant'**
  String get repostJustNow;

  /// No description provided for @repostOnDate.
  ///
  /// In fr, this message translates to:
  /// **'le {date}'**
  String repostOnDate(String date);

  /// No description provided for @repostHasShared.
  ///
  /// In fr, this message translates to:
  /// **' a partagé'**
  String get repostHasShared;

  /// No description provided for @repostReasonShareTestimony.
  ///
  /// In fr, this message translates to:
  /// **'partager ce témoignage avec vos abonnés'**
  String get repostReasonShareTestimony;

  /// No description provided for @repostTestimonyExplain.
  ///
  /// In fr, this message translates to:
  /// **'Le témoignage de {author} apparaîtra dans le fil de vos abonnés, avec son auteur. Il sera prévenu.'**
  String repostTestimonyExplain(String author);

  /// No description provided for @repostCommentHintTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi ce témoignage vous a touché…'**
  String get repostCommentHintTestimony;

  /// No description provided for @repostSharesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partages'**
  String get repostSharesTitle;

  /// No description provided for @repostNotPublishedYet.
  ///
  /// In fr, this message translates to:
  /// **'Ce témoignage n’est pas encore publié.'**
  String get repostNotPublishedYet;

  /// No description provided for @repostOwnTestimony.
  ///
  /// In fr, this message translates to:
  /// **'C’est votre témoignage : il est déjà visible par vos abonnés.'**
  String get repostOwnTestimony;

  /// No description provided for @moderationReasonInappropriate.
  ///
  /// In fr, this message translates to:
  /// **'Contenu inapproprié'**
  String get moderationReasonInappropriate;

  /// No description provided for @moderationReasonFalseTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Faux témoignage'**
  String get moderationReasonFalseTestimony;

  /// No description provided for @moderationReasonHateSpeech.
  ///
  /// In fr, this message translates to:
  /// **'Discours haineux'**
  String get moderationReasonHateSpeech;

  /// No description provided for @moderationReasonSpam.
  ///
  /// In fr, this message translates to:
  /// **'Spam'**
  String get moderationReasonSpam;

  /// No description provided for @moderationReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get moderationReasonOther;

  /// No description provided for @moderationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String moderationError(String error);

  /// No description provided for @moderationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modération'**
  String get moderationTitle;

  /// No description provided for @moderationAdvancedFilters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres avancés'**
  String get moderationAdvancedFilters;

  /// No description provided for @moderationApprovedItem.
  ///
  /// In fr, this message translates to:
  /// **'Approuvé : {title}'**
  String moderationApprovedItem(String title);

  /// No description provided for @moderationRejectedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage rejeté'**
  String get moderationRejectedSnack;

  /// No description provided for @moderationEditRequestedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Demande de modification envoyée'**
  String get moderationEditRequestedSnack;

  /// No description provided for @moderationStatApprovedToday.
  ///
  /// In fr, this message translates to:
  /// **'Approuvés\naujourd\'hui'**
  String get moderationStatApprovedToday;

  /// No description provided for @moderationStatRejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejetés'**
  String get moderationStatRejected;

  /// No description provided for @moderationStatTotalMonth.
  ///
  /// In fr, this message translates to:
  /// **'Total ce mois'**
  String get moderationStatTotalMonth;

  /// No description provided for @moderationTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get moderationTabAll;

  /// No description provided for @moderationEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage à modérer'**
  String get moderationEmptyTitle;

  /// No description provided for @moderationEmptyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Tout est à jour !'**
  String get moderationEmptyDesc;

  /// No description provided for @moderationPreviewAction.
  ///
  /// In fr, this message translates to:
  /// **'Prévisualiser'**
  String get moderationPreviewAction;

  /// No description provided for @moderationApproveShort.
  ///
  /// In fr, this message translates to:
  /// **'Approuver'**
  String get moderationApproveShort;

  /// No description provided for @moderationEditShort.
  ///
  /// In fr, this message translates to:
  /// **'Modif.'**
  String get moderationEditShort;

  /// No description provided for @moderationRejectShort.
  ///
  /// In fr, this message translates to:
  /// **'Rejeter'**
  String get moderationRejectShort;

  /// No description provided for @moderationRejectReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif du rejet'**
  String get moderationRejectReasonLabel;

  /// No description provided for @moderationSelectReason.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner un motif'**
  String get moderationSelectReason;

  /// No description provided for @moderationNoteForModerator.
  ///
  /// In fr, this message translates to:
  /// **'Note optionnelle pour le modérateur'**
  String get moderationNoteForModerator;

  /// No description provided for @moderationInstructionsForAuthor.
  ///
  /// In fr, this message translates to:
  /// **'Instructions pour l\'auteur'**
  String get moderationInstructionsForAuthor;

  /// No description provided for @moderationNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note interne (optionnel)…'**
  String get moderationNoteHint;

  /// No description provided for @moderationInstructionsHint.
  ///
  /// In fr, this message translates to:
  /// **'Expliquer les modifications attendues…'**
  String get moderationInstructionsHint;

  /// No description provided for @moderationSendRequest.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get moderationSendRequest;

  /// No description provided for @moderationConfirmReject.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le rejet'**
  String get moderationConfirmReject;

  /// No description provided for @downloadsTypeVideo.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get downloadsTypeVideo;

  /// No description provided for @downloadsTypeAudio.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get downloadsTypeAudio;

  /// No description provided for @downloadsTypeText.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get downloadsTypeText;

  /// No description provided for @downloadsYouTubeUnsupported.
  ///
  /// In fr, this message translates to:
  /// **'Les vidéos YouTube ne peuvent pas être téléchargées.'**
  String get downloadsYouTubeUnsupported;

  /// No description provided for @downloadsStorageFull.
  ///
  /// In fr, this message translates to:
  /// **'Espace de téléchargement plein. Supprimez des téléchargements.'**
  String get downloadsStorageFull;

  /// No description provided for @downloadsFailedNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement impossible. Vérifiez votre connexion.'**
  String get downloadsFailedNetwork;

  /// No description provided for @downloadsFailedGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement impossible.'**
  String get downloadsFailedGeneric;

  /// No description provided for @downloadsNoFile.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier à télécharger.'**
  String get downloadsNoFile;

  /// No description provided for @downloadsFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get downloadsFilterAll;

  /// No description provided for @downloadsFilterVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get downloadsFilterVideos;

  /// No description provided for @downloadsFilterAudios.
  ///
  /// In fr, this message translates to:
  /// **'Audios'**
  String get downloadsFilterAudios;

  /// No description provided for @downloadsFilterTexts.
  ///
  /// In fr, this message translates to:
  /// **'Textes'**
  String get downloadsFilterTexts;

  /// No description provided for @downloadsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes téléchargements'**
  String get downloadsTitle;

  /// No description provided for @downloadsOfflineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes hors ligne. Vos téléchargements restent disponibles.'**
  String get downloadsOfflineBanner;

  /// No description provided for @downloadsStorageUsed.
  ///
  /// In fr, this message translates to:
  /// **'Stockage utilisé {percent} %'**
  String downloadsStorageUsed(int percent);

  /// No description provided for @downloadsManageStorage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer le stockage'**
  String get downloadsManageStorage;

  /// No description provided for @downloadsCountUsed.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{0 téléchargement} =1{1 téléchargement} other{{count} téléchargements}} · {size} utilisés'**
  String downloadsCountUsed(int count, String size);

  /// No description provided for @downloadsTheVideos.
  ///
  /// In fr, this message translates to:
  /// **'les vidéos'**
  String get downloadsTheVideos;

  /// No description provided for @downloadsTheAudios.
  ///
  /// In fr, this message translates to:
  /// **'les audios'**
  String get downloadsTheAudios;

  /// No description provided for @downloadsTheTexts.
  ///
  /// In fr, this message translates to:
  /// **'les textes'**
  String get downloadsTheTexts;

  /// No description provided for @downloadsDeleteTypeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {label} ?'**
  String downloadsDeleteTypeTitle(String label);

  /// No description provided for @downloadsDeleteTypeBody.
  ///
  /// In fr, this message translates to:
  /// **'Tous {label} téléchargés seront supprimés de l’appareil.'**
  String downloadsDeleteTypeBody(String label);

  /// No description provided for @downloadsDeleteAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer'**
  String get downloadsDeleteAll;

  /// No description provided for @downloadsDeleteAllTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tout supprimer ?'**
  String get downloadsDeleteAllTitle;

  /// No description provided for @downloadsDeleteAllBody.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos téléchargements seront supprimés. Ils ne seront plus disponibles hors ligne.'**
  String get downloadsDeleteAllBody;

  /// No description provided for @downloadsDeleteTypeTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer les {name}'**
  String downloadsDeleteTypeTooltip(String name);

  /// No description provided for @downloadsEmptyFiltered.
  ///
  /// In fr, this message translates to:
  /// **'Aucun téléchargement de ce type'**
  String get downloadsEmptyFiltered;

  /// No description provided for @downloadsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun téléchargement'**
  String get downloadsEmpty;

  /// No description provided for @downloadsEmptyDesc.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez des témoignages pour les lire, les écouter ou les regarder sans connexion.'**
  String get downloadsEmptyDesc;

  /// No description provided for @downloadsExplore.
  ///
  /// In fr, this message translates to:
  /// **'Explorer les témoignages'**
  String get downloadsExplore;

  /// No description provided for @downloadsWebTitle.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargements disponibles sur l’application mobile'**
  String get downloadsWebTitle;

  /// No description provided for @downloadsWebDesc.
  ///
  /// In fr, this message translates to:
  /// **'Le navigateur ne permet pas d’enregistrer les témoignages pour une lecture hors ligne.'**
  String get downloadsWebDesc;

  /// No description provided for @downloadsOfflineReading.
  ///
  /// In fr, this message translates to:
  /// **'Lecture hors ligne'**
  String get downloadsOfflineReading;

  /// No description provided for @downloadsOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get downloadsOffline;

  /// No description provided for @downloadsDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get downloadsDownload;

  /// No description provided for @downloadsDownloadTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger pour lire hors ligne'**
  String get downloadsDownloadTooltip;

  /// No description provided for @downloadsQueued.
  ///
  /// In fr, this message translates to:
  /// **'En attente…'**
  String get downloadsQueued;

  /// No description provided for @downloadsCancelDownload.
  ///
  /// In fr, this message translates to:
  /// **'Annuler le téléchargement'**
  String get downloadsCancelDownload;

  /// No description provided for @downloadsDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé'**
  String get downloadsDownloaded;

  /// No description provided for @downloadsDownloadedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargé · disponible hors ligne'**
  String get downloadsDownloadedTooltip;

  /// No description provided for @downloadsFailedRetry.
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement · réessayer'**
  String get downloadsFailedRetry;

  /// No description provided for @downloadsStarted.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement lancé…'**
  String get downloadsStarted;

  /// No description provided for @downloadsAvailableOffline.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » est disponible hors ligne'**
  String downloadsAvailableOffline(String title);

  /// No description provided for @downloadsFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement'**
  String get downloadsFailed;

  /// No description provided for @downloadsCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement annulé'**
  String get downloadsCancelled;

  /// No description provided for @downloadsReadOffline.
  ///
  /// In fr, this message translates to:
  /// **'Lire hors ligne'**
  String get downloadsReadOffline;

  /// No description provided for @downloadsDeleteDownload.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement'**
  String get downloadsDeleteDownload;

  /// No description provided for @downloadsDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement supprimé'**
  String get downloadsDeleted;

  /// No description provided for @downloadsDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le téléchargement ?'**
  String get downloadsDeleteConfirmTitle;

  /// No description provided for @downloadsDeleteConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'« {title} » ne sera plus disponible hors ligne.'**
  String downloadsDeleteConfirmBody(String title);

  /// No description provided for @downloadsMoreOptions.
  ///
  /// In fr, this message translates to:
  /// **'Plus d’options'**
  String get downloadsMoreOptions;

  /// No description provided for @downloadsPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get downloadsPlay;

  /// No description provided for @downloadsInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement…'**
  String get downloadsInProgress;

  /// No description provided for @downloadsProgress.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement · {percent} %'**
  String downloadsProgress(int percent);

  /// No description provided for @downloadsPercent.
  ///
  /// In fr, this message translates to:
  /// **'{percent} %'**
  String downloadsPercent(int percent);

  /// No description provided for @bibleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bible'**
  String get bibleTitle;

  /// No description provided for @bibleUnexpectedResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse inattendue (type: {type})'**
  String bibleUnexpectedResponse(String type);

  /// No description provided for @bibleErrorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Endpoint introuvable (404). Vérifiez la configuration du serveur.'**
  String get bibleErrorNotFound;

  /// No description provided for @bibleErrorUnauthorized.
  ///
  /// In fr, this message translates to:
  /// **'Non autorisé (401). Reconnectez-vous et réessayez.'**
  String get bibleErrorUnauthorized;

  /// No description provided for @bibleErrorServer.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur {status} : {message}'**
  String bibleErrorServer(int status, String message);

  /// No description provided for @bibleErrorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau : {message}'**
  String bibleErrorNetwork(String message);

  /// No description provided for @bibleErrorFormat.
  ///
  /// In fr, this message translates to:
  /// **'Format de réponse invalide : {message}'**
  String bibleErrorFormat(String message);

  /// No description provided for @bibleError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {error}'**
  String bibleError(String error);

  /// No description provided for @bibleNoContent.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contenu téléchargé.'**
  String get bibleNoContent;

  /// No description provided for @bibleBookSublabel.
  ///
  /// In fr, this message translates to:
  /// **'Bible · {count} chapitres'**
  String bibleBookSublabel(int count);

  /// No description provided for @bibleGoToBook.
  ///
  /// In fr, this message translates to:
  /// **'Aller à un livre'**
  String get bibleGoToBook;

  /// No description provided for @bibleBookHint.
  ///
  /// In fr, this message translates to:
  /// **'Livre (ex. Jean 3)'**
  String get bibleBookHint;

  /// No description provided for @bibleStopReading.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter la lecture'**
  String get bibleStopReading;

  /// No description provided for @bibleReadChapter.
  ///
  /// In fr, this message translates to:
  /// **'Lire le chapitre'**
  String get bibleReadChapter;

  /// No description provided for @bibleChooseBook.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un livre'**
  String get bibleChooseBook;

  /// No description provided for @bibleChaptersShort.
  ///
  /// In fr, this message translates to:
  /// **'{count} ch.'**
  String bibleChaptersShort(int count);

  /// No description provided for @bibleChapterEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Ce chapitre ne contient aucun verset.'**
  String get bibleChapterEmpty;

  /// No description provided for @bibleSelectedVerses.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 verset} other{{count} versets}}'**
  String bibleSelectedVerses(int count);

  /// No description provided for @bibleInsert.
  ///
  /// In fr, this message translates to:
  /// **'Insérer'**
  String get bibleInsert;

  /// No description provided for @bibleHighlight.
  ///
  /// In fr, this message translates to:
  /// **'Surligner'**
  String get bibleHighlight;

  /// No description provided for @bibleShareVerse.
  ///
  /// In fr, this message translates to:
  /// **'Partager ce verset'**
  String get bibleShareVerse;

  /// No description provided for @bibleCompareTranslations.
  ///
  /// In fr, this message translates to:
  /// **'Comparer les traductions'**
  String get bibleCompareTranslations;

  /// No description provided for @bibleInsertInTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Insérer dans un témoignage'**
  String get bibleInsertInTestimony;

  /// No description provided for @bibleCompareEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargez d\'autres traductions pour les comparer.'**
  String get bibleCompareEmpty;

  /// No description provided for @bibleLanguageAmharic.
  ///
  /// In fr, this message translates to:
  /// **'Amharique'**
  String get bibleLanguageAmharic;

  /// No description provided for @bibleChooseTranslation.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une traduction'**
  String get bibleChooseTranslation;

  /// No description provided for @bibleDownloadedTranslations.
  ///
  /// In fr, this message translates to:
  /// **'Traductions téléchargées'**
  String get bibleDownloadedTranslations;

  /// No description provided for @bibleNoTranslation.
  ///
  /// In fr, this message translates to:
  /// **'Aucune traduction disponible.\nTéléchargez-en depuis l\'onglet Bible.'**
  String get bibleNoTranslation;

  /// No description provided for @bibleVerseCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} versets'**
  String bibleVerseCount(String count);

  /// No description provided for @bibleConnecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get bibleConnecting;

  /// No description provided for @bibleRead.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get bibleRead;

  /// No description provided for @bibleDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get bibleDownload;

  /// No description provided for @bibleDeleteVersionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la version ?'**
  String get bibleDeleteVersionTitle;

  /// No description provided for @bibleDeleteVersionBody.
  ///
  /// In fr, this message translates to:
  /// **'La version \"{name}\" sera supprimée de votre appareil. Vous pourrez la re-télécharger à tout moment.'**
  String bibleDeleteVersionBody(String name);

  /// No description provided for @bibleNoVersion.
  ///
  /// In fr, this message translates to:
  /// **'Aucune version disponible'**
  String get bibleNoVersion;

  /// No description provided for @bibleNoVersionDesc.
  ///
  /// In fr, this message translates to:
  /// **'Les versions de la Bible seront disponibles dès que le serveur les proposera.'**
  String get bibleNoVersionDesc;

  /// No description provided for @bibleLoadVersionsFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les versions'**
  String get bibleLoadVersionsFailed;

  /// No description provided for @eventsFormYoutubeLive.
  ///
  /// In fr, this message translates to:
  /// **'Direct sur YouTube'**
  String get eventsFormYoutubeLive;

  /// No description provided for @eventsFormYoutubeLiveHelp.
  ///
  /// In fr, this message translates to:
  /// **'Collez le lien YouTube de votre direct : il s\'affichera sur la page de l\'événement.'**
  String get eventsFormYoutubeLiveHelp;

  /// No description provided for @eventsFormYoutubeLiveLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien YouTube du direct'**
  String get eventsFormYoutubeLiveLabel;

  /// No description provided for @eventsFormYoutubeLiveInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Lien YouTube non reconnu (youtube.com/watch?v=…, youtu.be/…, youtube.com/live/…)'**
  String get eventsFormYoutubeLiveInvalid;

  /// No description provided for @eventsAddYoutubeLive.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter le direct YouTube'**
  String get eventsAddYoutubeLive;

  /// No description provided for @eventsYoutubeLiveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Direct sur YouTube'**
  String get eventsYoutubeLiveTitle;

  /// No description provided for @eventsYoutubeLiveUpcoming.
  ///
  /// In fr, this message translates to:
  /// **'Le direct sera diffusé ici le jour de l\'événement.'**
  String get eventsYoutubeLiveUpcoming;

  /// No description provided for @eventsYoutubeLiveOngoing.
  ///
  /// In fr, this message translates to:
  /// **'Suivez l\'événement en direct.'**
  String get eventsYoutubeLiveOngoing;

  /// No description provided for @eventsYoutubeLivePast.
  ///
  /// In fr, this message translates to:
  /// **'Revoir la diffusion de l\'événement.'**
  String get eventsYoutubeLivePast;

  /// No description provided for @eventsOpenOnYoutube.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir sur YouTube'**
  String get eventsOpenOnYoutube;

  /// No description provided for @commonOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get commonOptions;

  /// No description provided for @verseTabPrayerTopics.
  ///
  /// In fr, this message translates to:
  /// **'Sujets de prière'**
  String get verseTabPrayerTopics;

  /// No description provided for @verseTabComments.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires'**
  String get verseTabComments;

  /// No description provided for @verseTabTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages'**
  String get verseTabTestimonies;

  /// No description provided for @audioPlayerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage audio'**
  String get audioPlayerTitle;

  /// No description provided for @audioPlayerQualityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qualité audio'**
  String get audioPlayerQualityTitle;

  /// No description provided for @audioPlayerQualitySettingsHint.
  ///
  /// In fr, this message translates to:
  /// **'Qualité par défaut modifiable dans Paramètres › Lecture et données.'**
  String get audioPlayerQualitySettingsHint;

  /// No description provided for @audioPlayerPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lecture'**
  String get audioPlayerPlay;

  /// No description provided for @audioPlayerRepeat.
  ///
  /// In fr, this message translates to:
  /// **'Répéter'**
  String get audioPlayerRepeat;

  /// No description provided for @audioPlayerRepeatOne.
  ///
  /// In fr, this message translates to:
  /// **'Répéter 1'**
  String get audioPlayerRepeatOne;

  /// No description provided for @audioPlayerRepeatAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout répéter'**
  String get audioPlayerRepeatAll;

  /// No description provided for @audioPlayerAutoplayOn.
  ///
  /// In fr, this message translates to:
  /// **'Lecture automatique activée'**
  String get audioPlayerAutoplayOn;

  /// No description provided for @audioPlayerAutoplayOff.
  ///
  /// In fr, this message translates to:
  /// **'Lecture automatique désactivée'**
  String get audioPlayerAutoplayOff;

  /// No description provided for @audioPlayerQuality.
  ///
  /// In fr, this message translates to:
  /// **'Qualité'**
  String get audioPlayerQuality;

  /// No description provided for @audioPlayerSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get audioPlayerSpeed;

  /// No description provided for @audioPlayerTranscript.
  ///
  /// In fr, this message translates to:
  /// **'Transcription'**
  String get audioPlayerTranscript;

  /// No description provided for @verseShareText.
  ///
  /// In fr, this message translates to:
  /// **'« {text} »\n— {reference}'**
  String verseShareText(String text, String reference);

  /// No description provided for @modTypeBadgeText.
  ///
  /// In fr, this message translates to:
  /// **'TEXTE'**
  String get modTypeBadgeText;

  /// No description provided for @modTypeBadgeAudio.
  ///
  /// In fr, this message translates to:
  /// **'AUDIO'**
  String get modTypeBadgeAudio;

  /// No description provided for @modTypeBadgeVideo.
  ///
  /// In fr, this message translates to:
  /// **'VIDEO'**
  String get modTypeBadgeVideo;

  /// No description provided for @conversionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Conversion'**
  String get conversionLabel;

  /// No description provided for @conversionTestimonyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage de conversion'**
  String get conversionTestimonyTitle;

  /// No description provided for @conversionSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages de conversion'**
  String get conversionSectionTitle;

  /// No description provided for @conversionSectionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Comment ils ont rencontré Jésus'**
  String get conversionSectionSubtitle;

  /// No description provided for @conversionSectionIntro.
  ///
  /// In fr, this message translates to:
  /// **'Le témoignage fondamental de chaque croyant : le jour où il a rencontré Jésus.'**
  String get conversionSectionIntro;

  /// No description provided for @conversionEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun témoignage de conversion publié pour le moment.'**
  String get conversionEmpty;

  /// No description provided for @conversionLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les témoignages de conversion.'**
  String get conversionLoadError;

  /// No description provided for @conversionLoginToTell.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter pour raconter ma conversion'**
  String get conversionLoginToTell;

  /// No description provided for @conversionInviteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Racontez comment vous avez rencontré Jésus'**
  String get conversionInviteTitle;

  /// No description provided for @conversionInviteBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage de conversion sera mis en avant sur votre profil.'**
  String get conversionInviteBody;

  /// No description provided for @conversionDefaultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comment j\'ai rencontré Jésus'**
  String get conversionDefaultTitle;

  /// No description provided for @conversionYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get conversionYear;

  /// No description provided for @conversionPlace.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get conversionPlace;

  /// No description provided for @conversionVerse.
  ///
  /// In fr, this message translates to:
  /// **'Verset'**
  String get conversionVerse;

  /// No description provided for @conversionDetailLabel.
  ///
  /// In fr, this message translates to:
  /// **'{label} : '**
  String conversionDetailLabel(String label);

  /// No description provided for @conversionYearHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 2012'**
  String get conversionYearHint;

  /// No description provided for @conversionPlaceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ville, église, camp…'**
  String get conversionPlaceHint;

  /// No description provided for @conversionVerseHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Jean 3:16'**
  String get conversionVerseHint;

  /// No description provided for @conversionYearInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Année entre {min} et {max}'**
  String conversionYearInvalid(int min, int max);

  /// No description provided for @conversionMyConversion.
  ///
  /// In fr, this message translates to:
  /// **'Ma conversion'**
  String get conversionMyConversion;

  /// No description provided for @conversionFieldsHint.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif : l\'année, le lieu et le verset qui ont marqué votre conversion.'**
  String get conversionFieldsHint;

  /// No description provided for @conversionStatusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente de validation'**
  String get conversionStatusPending;

  /// No description provided for @conversionStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Refusé par la modération'**
  String get conversionStatusRejected;

  /// No description provided for @conversionStatusDraft.
  ///
  /// In fr, this message translates to:
  /// **'Brouillon'**
  String get conversionStatusDraft;

  /// No description provided for @conversionMineTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon témoignage de conversion'**
  String get conversionMineTitle;

  /// No description provided for @conversionMineHint.
  ///
  /// In fr, this message translates to:
  /// **'Le relire ou le modifier'**
  String get conversionMineHint;

  /// No description provided for @conversionPublishHint.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la forme de votre témoignage ; l\'année, le lieu et le verset sont demandés à l\'étape suivante.'**
  String get conversionPublishHint;

  /// No description provided for @conversionPublishCancel.
  ///
  /// In fr, this message translates to:
  /// **'Publier un témoignage ordinaire'**
  String get conversionPublishCancel;

  /// No description provided for @conversionEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon témoignage de conversion'**
  String get conversionEditTitle;

  /// No description provided for @conversionEditReviewNotice.
  ///
  /// In fr, this message translates to:
  /// **'Après modification, votre témoignage repasse en modération avant d\'être publié de nouveau.'**
  String get conversionEditReviewNotice;

  /// No description provided for @conversionTitleLabel.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get conversionTitleLabel;

  /// No description provided for @conversionTitleRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un titre (3 caractères au moins)'**
  String get conversionTitleRequired;

  /// No description provided for @conversionBodyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Votre témoignage'**
  String get conversionBodyLabel;

  /// No description provided for @conversionBodyRequired.
  ///
  /// In fr, this message translates to:
  /// **'Racontez votre conversion'**
  String get conversionBodyRequired;

  /// No description provided for @conversionSavedForReview.
  ///
  /// In fr, this message translates to:
  /// **'Modifications enregistrées : votre témoignage repasse en modération.'**
  String get conversionSavedForReview;

  /// No description provided for @conversionNoneYet.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas encore de témoignage de conversion.'**
  String get conversionNoneYet;

  /// No description provided for @conversionRecordButton.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer mon témoignage de conversion'**
  String get conversionRecordButton;

  /// No description provided for @conversionServerUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Les témoignages de conversion seront disponibles après la mise à jour du serveur.'**
  String get conversionServerUnavailable;

  /// No description provided for @pastEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Revivre les événements'**
  String get pastEventsTitle;

  /// No description provided for @pastEventsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les témoignages de ceux qui y étaient'**
  String get pastEventsSubtitle;

  /// No description provided for @pastEventsScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événements passés'**
  String get pastEventsScreenTitle;

  /// No description provided for @pastEventsIntro.
  ///
  /// In fr, this message translates to:
  /// **'Croisades, conférences, camps… Revivez ce que Dieu a fait à travers les témoignages des participants.'**
  String get pastEventsIntro;

  /// No description provided for @pastEventsSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un événement, une ville…'**
  String get pastEventsSearchHint;

  /// No description provided for @pastEventsAllTypes.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get pastEventsAllTypes;

  /// No description provided for @pastEventsRelive.
  ///
  /// In fr, this message translates to:
  /// **'Revivre les témoignages'**
  String get pastEventsRelive;

  /// No description provided for @pastEventsOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'événement'**
  String get pastEventsOpen;

  /// No description provided for @pastEventsTestimonyCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun témoignage} =1{1 témoignage} other{{count} témoignages}}'**
  String pastEventsTestimonyCount(int count);

  /// No description provided for @prayerFocusTitle.
  ///
  /// In fr, this message translates to:
  /// **'Temps de prière'**
  String get prayerFocusTitle;

  /// No description provided for @prayerFocusFor.
  ///
  /// In fr, this message translates to:
  /// **'Avec {name}, présentez ce besoin à Dieu'**
  String prayerFocusFor(String name);

  /// No description provided for @prayerFocusSubject.
  ///
  /// In fr, this message translates to:
  /// **'Sujet de prière'**
  String get prayerFocusSubject;

  /// No description provided for @prayerFocusWait.
  ///
  /// In fr, this message translates to:
  /// **'Prenez ces 5 minutes pour prier. Vous pourrez ensuite confirmer votre prière.'**
  String get prayerFocusWait;

  /// No description provided for @prayerFocusConfirm.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié pour cette requête'**
  String get prayerFocusConfirm;

  /// No description provided for @prayerFocusValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider ma prière'**
  String get prayerFocusValidate;

  /// No description provided for @prayerFocusLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter sans valider'**
  String get prayerFocusLeave;

  /// No description provided for @prayerFocusDone.
  ///
  /// In fr, this message translates to:
  /// **'Temps de prière terminé'**
  String get prayerFocusDone;

  /// No description provided for @prayerFocusRemaining.
  ///
  /// In fr, this message translates to:
  /// **'Temps restant : {time}'**
  String prayerFocusRemaining(String time);

  /// No description provided for @prayerFocusVerseRef.
  ///
  /// In fr, this message translates to:
  /// **'Jacques 5:16'**
  String get prayerFocusVerseRef;

  /// No description provided for @immersiveLayoutClassic.
  ///
  /// In fr, this message translates to:
  /// **'Classique'**
  String get immersiveLayoutClassic;

  /// No description provided for @immersiveLayoutImmersive.
  ///
  /// In fr, this message translates to:
  /// **'Immersif'**
  String get immersiveLayoutImmersive;

  /// No description provided for @immersiveSwitchToImmersive.
  ///
  /// In fr, this message translates to:
  /// **'Affichage immersif'**
  String get immersiveSwitchToImmersive;

  /// No description provided for @immersiveSwitchToClassic.
  ///
  /// In fr, this message translates to:
  /// **'Affichage classique'**
  String get immersiveSwitchToClassic;

  /// No description provided for @immersiveBy.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage de {name}'**
  String immersiveBy(String name);

  /// No description provided for @immersiveTextHint.
  ///
  /// In fr, this message translates to:
  /// **'Écouter · touchez un paragraphe pour le lire'**
  String get immersiveTextHint;

  /// No description provided for @immersiveNoTranscript.
  ///
  /// In fr, this message translates to:
  /// **'Ce témoignage audio n\'a pas encore de transcription. Écoutez-le et laissez-vous toucher.'**
  String get immersiveNoTranscript;

  /// No description provided for @immersiveApproxSync.
  ///
  /// In fr, this message translates to:
  /// **'Texte synchronisé approximativement sur l\'audio'**
  String get immersiveApproxSync;

  /// No description provided for @immersiveSettingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Affichage immersif des témoignages'**
  String get immersiveSettingTitle;

  /// No description provided for @immersiveSettingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran, texte qui défile pendant la lecture : propice à la prière'**
  String get immersiveSettingSubtitle;

  /// No description provided for @prayerFocusTestimonyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage'**
  String get prayerFocusTestimonyLabel;

  /// No description provided for @prayerFocusTestimonyConfirm.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié pour ce témoignage'**
  String get prayerFocusTestimonyConfirm;

  /// No description provided for @bibleOtherVersions.
  ///
  /// In fr, this message translates to:
  /// **'Autres versions'**
  String get bibleOtherVersions;

  /// No description provided for @bibleDownloadingVersion.
  ///
  /// In fr, this message translates to:
  /// **'Préparation de la {name} sur votre téléphone…\nUne seule fois : elle sera ensuite lisible hors ligne.'**
  String bibleDownloadingVersion(String name);

  /// No description provided for @commentLike.
  ///
  /// In fr, this message translates to:
  /// **'Aimer ce commentaire'**
  String get commentLike;

  /// No description provided for @commentUnlike.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'aime plus ce commentaire'**
  String get commentUnlike;

  /// No description provided for @commentLikeReason.
  ///
  /// In fr, this message translates to:
  /// **'aimer un commentaire'**
  String get commentLikeReason;

  /// No description provided for @commentLikeFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer votre « J\'aime ». Réessayez.'**
  String get commentLikeFailed;

  /// No description provided for @adminSettingsPublishing.
  ///
  /// In fr, this message translates to:
  /// **'Publication'**
  String get adminSettingsPublishing;

  /// No description provided for @adminSettingsTypeText.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages écrits'**
  String get adminSettingsTypeText;

  /// No description provided for @adminSettingsTypeAudio.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages audio'**
  String get adminSettingsTypeAudio;

  /// No description provided for @adminSettingsTypeVideo.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages vidéo'**
  String get adminSettingsTypeVideo;

  /// No description provided for @adminSettingsTypeYoutube.
  ///
  /// In fr, this message translates to:
  /// **'Liens YouTube'**
  String get adminSettingsTypeYoutube;

  /// No description provided for @adminSettingsTypeSub.
  ///
  /// In fr, this message translates to:
  /// **'Accepté sur toute la plateforme (un profil peut avoir une exception)'**
  String get adminSettingsTypeSub;

  /// No description provided for @adminSettingsTypeYoutubeSub.
  ///
  /// In fr, this message translates to:
  /// **'Administrateurs, et profils autorisés un par un'**
  String get adminSettingsTypeYoutubeSub;

  /// No description provided for @adminSettingsSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le réglage n\'a pas pu être enregistré. Réessayez.'**
  String get adminSettingsSaveFailed;

  /// No description provided for @adminUserPublishingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Types de témoignages'**
  String get adminUserPublishingTitle;

  /// No description provided for @adminUserPublishingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ce que {name} peut publier'**
  String adminUserPublishingSubtitle(String name);

  /// No description provided for @adminUserPublishingAllowed.
  ///
  /// In fr, this message translates to:
  /// **'Autorisé'**
  String get adminUserPublishingAllowed;

  /// No description provided for @adminUserPublishingBlocked.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get adminUserPublishingBlocked;

  /// No description provided for @adminUserPublishingDefaultOn.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut (oui)'**
  String get adminUserPublishingDefaultOn;

  /// No description provided for @adminUserPublishingDefaultOff.
  ///
  /// In fr, this message translates to:
  /// **'Par défaut (non)'**
  String get adminUserPublishingDefaultOff;

  /// No description provided for @adminUserPublishingAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get adminUserPublishingAllow;

  /// No description provided for @adminUserPublishingDeny.
  ///
  /// In fr, this message translates to:
  /// **'Interdire'**
  String get adminUserPublishingDeny;

  /// No description provided for @publishNoTypeAllowed.
  ///
  /// In fr, this message translates to:
  /// **'La publication de témoignages n\'est pas ouverte pour votre compte pour le moment.'**
  String get publishNoTypeAllowed;

  /// No description provided for @authPhoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneSignInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par téléphone'**
  String get authPhoneSignInTitle;

  /// No description provided for @authPhoneUseSmsCode.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir plutôt un code par SMS'**
  String get authPhoneUseSmsCode;

  /// No description provided for @authSignUpWithGoogle.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte avec Google'**
  String get authSignUpWithGoogle;

  /// No description provided for @authOrFillForm.
  ///
  /// In fr, this message translates to:
  /// **'ou remplissez le formulaire'**
  String get authOrFillForm;

  /// No description provided for @prayerFocusVerseSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Méditez ce verset et priez avec lui'**
  String get prayerFocusVerseSubtitle;

  /// No description provided for @prayerFocusVerseLabel.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour'**
  String get prayerFocusVerseLabel;

  /// No description provided for @prayerFocusVerseConfirm.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié avec ce verset'**
  String get prayerFocusVerseConfirm;

  /// No description provided for @prayerFocusContentSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Présentez ce sujet à Dieu'**
  String get prayerFocusContentSubtitle;

  /// No description provided for @prayerFocusContentConfirm.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié pour ce sujet'**
  String get prayerFocusContentConfirm;

  /// No description provided for @prayerFocusKindEvent.
  ///
  /// In fr, this message translates to:
  /// **'Événement'**
  String get prayerFocusKindEvent;

  /// No description provided for @prayerFocusKindSession.
  ///
  /// In fr, this message translates to:
  /// **'Session de prière'**
  String get prayerFocusKindSession;

  /// No description provided for @prayerFocusProphecySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Priez sur cette parole reçue'**
  String get prayerFocusProphecySubtitle;

  /// No description provided for @prayerFocusProphecyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Parole prophétique'**
  String get prayerFocusProphecyLabel;

  /// No description provided for @prayerFocusProphecyConfirm.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai prié sur cette parole'**
  String get prayerFocusProphecyConfirm;

  /// No description provided for @pushConsentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir les notifications ?'**
  String get pushConsentTitle;

  /// No description provided for @pushConsentBody.
  ///
  /// In fr, this message translates to:
  /// **'My Testimony vous prévient quand il se passe quelque chose pour vous.'**
  String get pushConsentBody;

  /// No description provided for @pushConsentComments.
  ///
  /// In fr, this message translates to:
  /// **'Commentaires, mentions et « J\'aime »'**
  String get pushConsentComments;

  /// No description provided for @pushConsentPrayers.
  ///
  /// In fr, this message translates to:
  /// **'Prières pour vos requêtes et vos témoignages'**
  String get pushConsentPrayers;

  /// No description provided for @pushConsentEvents.
  ///
  /// In fr, this message translates to:
  /// **'Directs, événements et sessions de prière'**
  String get pushConsentEvents;

  /// No description provided for @pushConsentAccount.
  ///
  /// In fr, this message translates to:
  /// **'Validation de vos témoignages et de votre compte'**
  String get pushConsentAccount;

  /// No description provided for @pushConsentChoose.
  ///
  /// In fr, this message translates to:
  /// **'Vous choisissez ensuite quoi recevoir dans Paramètres › Notifications.'**
  String get pushConsentChoose;

  /// No description provided for @pushConsentAccept.
  ///
  /// In fr, this message translates to:
  /// **'Activer les notifications'**
  String get pushConsentAccept;

  /// No description provided for @pushConsentLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get pushConsentLater;

  /// No description provided for @eventsNoYoutubeLive.
  ///
  /// In fr, this message translates to:
  /// **'Aucun direct YouTube pour cet événement.'**
  String get eventsNoYoutubeLive;

  /// No description provided for @eventsLiveFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get eventsLiveFullscreen;

  /// No description provided for @eventsLiveExitFullscreen.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le plein écran'**
  String get eventsLiveExitFullscreen;

  /// No description provided for @eventsLiveChat.
  ///
  /// In fr, this message translates to:
  /// **'Discussion en direct'**
  String get eventsLiveChat;

  /// No description provided for @eventsWatchLive.
  ///
  /// In fr, this message translates to:
  /// **'Regarder le direct'**
  String get eventsWatchLive;

  /// No description provided for @liveTestify.
  ///
  /// In fr, this message translates to:
  /// **'Témoigner sur ce direct'**
  String get liveTestify;

  /// No description provided for @liveTestifyReason.
  ///
  /// In fr, this message translates to:
  /// **'témoigner sur ce direct'**
  String get liveTestifyReason;

  /// No description provided for @liveReplayChat.
  ///
  /// In fr, this message translates to:
  /// **'Revoir la discussion'**
  String get liveReplayChat;

  /// No description provided for @liveReplayEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message n\'a été laissé pendant ce direct.'**
  String get liveReplayEmpty;

  /// No description provided for @liveTestimoniesTitle.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 témoignage sur ce direct} other{{count} témoignages sur ce direct}}'**
  String liveTestimoniesTitle(int count);

  /// No description provided for @publishLiveTestimony.
  ///
  /// In fr, this message translates to:
  /// **'Témoignage sur le direct'**
  String get publishLiveTestimony;

  /// No description provided for @settingsNotifFollowedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comptes suivis'**
  String get settingsNotifFollowedTitle;

  /// No description provided for @settingsNotifFollowed.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux témoignages et directs des comptes que vous suivez'**
  String get settingsNotifFollowed;

  /// No description provided for @settingsNotifFollowsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveaux abonnés'**
  String get settingsNotifFollowsTitle;

  /// No description provided for @settingsNotifFollows.
  ///
  /// In fr, this message translates to:
  /// **'Quand quelqu\'un s\'abonne à vous'**
  String get settingsNotifFollows;

  /// No description provided for @settingsNotifEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événements et prière'**
  String get settingsNotifEventsTitle;

  /// No description provided for @settingsNotifEvents.
  ///
  /// In fr, this message translates to:
  /// **'Événements reportés ou annulés, sessions de prière qui commencent'**
  String get settingsNotifEvents;

  /// No description provided for @settingsNotifAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get settingsNotifAccountTitle;

  /// No description provided for @settingsNotifAccount.
  ///
  /// In fr, this message translates to:
  /// **'Vérification, badge, administrateurs du compte'**
  String get settingsNotifAccount;

  /// No description provided for @settingsNotifModerationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modération'**
  String get settingsNotifModerationTitle;

  /// No description provided for @settingsNotifModeration.
  ///
  /// In fr, this message translates to:
  /// **'Témoignages renvoyés en relecture, vidéos bloquées'**
  String get settingsNotifModeration;

  /// No description provided for @publishYouTubeCreditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Crédit de la vidéo'**
  String get publishYouTubeCreditTitle;

  /// No description provided for @publishYouTubeCreditHint.
  ///
  /// In fr, this message translates to:
  /// **'Citez l\'auteur de la vidéo d\'origine et sa chaîne YouTube.'**
  String get publishYouTubeCreditHint;

  /// No description provided for @publishYouTubeCreditAuthor.
  ///
  /// In fr, this message translates to:
  /// **'Auteur de la vidéo'**
  String get publishYouTubeCreditAuthor;

  /// No description provided for @publishYouTubeCreditAuthorHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. Pasteur Jean Mukendi'**
  String get publishYouTubeCreditAuthorHint;

  /// No description provided for @publishYouTubeCreditChannel.
  ///
  /// In fr, this message translates to:
  /// **'Chaîne YouTube'**
  String get publishYouTubeCreditChannel;

  /// No description provided for @publishYouTubeCreditChannelHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la chaîne'**
  String get publishYouTubeCreditChannelHint;

  /// No description provided for @publishYouTubeCreditUrl.
  ///
  /// In fr, this message translates to:
  /// **'Lien de la chaîne ou de la vidéo d\'origine'**
  String get publishYouTubeCreditUrl;

  /// No description provided for @publishYouTubeCreditUrlInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Lien non valide (https://…)'**
  String get publishYouTubeCreditUrlInvalid;

  /// No description provided for @youtubeCreditBy.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo de {name}'**
  String youtubeCreditBy(String name);

  /// No description provided for @youtubeCreditChannel.
  ///
  /// In fr, this message translates to:
  /// **'Chaîne {name}'**
  String youtubeCreditChannel(String name);

  /// No description provided for @youtubeCreditSource.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo d\'origine sur YouTube'**
  String get youtubeCreditSource;

  /// No description provided for @youtubeCreditOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir la chaîne'**
  String get youtubeCreditOpen;

  /// No description provided for @liveChatHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer la discussion'**
  String get liveChatHide;

  /// No description provided for @liveChatShow.
  ///
  /// In fr, this message translates to:
  /// **'Afficher la discussion'**
  String get liveChatShow;

  /// No description provided for @liveChatWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans la discussion en direct ! Protégez votre vie privée et restez bienveillant.'**
  String get liveChatWelcome;

  /// No description provided for @liveChatLearnMore.
  ///
  /// In fr, this message translates to:
  /// **'En savoir plus'**
  String get liveChatLearnMore;

  /// No description provided for @liveChatRulesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Règles de la discussion'**
  String get liveChatRulesTitle;

  /// No description provided for @liveChatRules.
  ///
  /// In fr, this message translates to:
  /// **'• Parlez avec respect et bienveillance.\n• Ne partagez pas d\'informations personnelles (téléphone, adresse…).\n• Pas de publicité, de spam ni de propos blessants.\n• Les modérateurs peuvent retirer un message ou exclure un participant.'**
  String get liveChatRules;

  /// No description provided for @liveChatLoginRequired.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour écrire dans la discussion.'**
  String get liveChatLoginRequired;

  /// No description provided for @verseOfTheDayMenu.
  ///
  /// In fr, this message translates to:
  /// **'Verset du jour'**
  String get verseOfTheDayMenu;

  /// No description provided for @verseOfTheDayMenuSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Méditer, prier et réagir'**
  String get verseOfTheDayMenuSubtitle;

  /// No description provided for @verseHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Versets précédents'**
  String get verseHistoryTitle;

  /// No description provided for @verseHistoryMenuSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique des versets du jour'**
  String get verseHistoryMenuSubtitle;

  /// No description provided for @verseHistoryIntro.
  ///
  /// In fr, this message translates to:
  /// **'Retrouvez les versets des jours passés, avec les « J\'aime », les prières, les commentaires et les témoignages de la communauté.'**
  String get verseHistoryIntro;

  /// No description provided for @verseHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun verset pour le moment.'**
  String get verseHistoryEmpty;

  /// No description provided for @verseHistoryLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l\'historique des versets.'**
  String get verseHistoryLoadError;

  /// No description provided for @verseHistoryToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get verseHistoryToday;

  /// No description provided for @verseHistoryLikes.
  ///
  /// In fr, this message translates to:
  /// **'j\'aime'**
  String get verseHistoryLikes;

  /// No description provided for @verseHistoryPrayers.
  ///
  /// In fr, this message translates to:
  /// **'prières'**
  String get verseHistoryPrayers;

  /// No description provided for @verseHistoryComments.
  ///
  /// In fr, this message translates to:
  /// **'commentaires'**
  String get verseHistoryComments;

  /// No description provided for @verseHistoryTestimonies.
  ///
  /// In fr, this message translates to:
  /// **'témoignages'**
  String get verseHistoryTestimonies;

  /// No description provided for @verseHistoryOpen.
  ///
  /// In fr, this message translates to:
  /// **'Versets précédents'**
  String get verseHistoryOpen;

  /// No description provided for @verseHistoryOfDay.
  ///
  /// In fr, this message translates to:
  /// **'Verset du {date}'**
  String verseHistoryOfDay(String date);

  /// No description provided for @adminEventTypes.
  ///
  /// In fr, this message translates to:
  /// **'Types d\'événements'**
  String get adminEventTypes;

  /// No description provided for @adminEventTypesSub.
  ///
  /// In fr, this message translates to:
  /// **'Croisades, conférences, camps… : ajouter, modifier, réordonner'**
  String get adminEventTypesSub;

  /// No description provided for @adminEventTypesIntro.
  ///
  /// In fr, this message translates to:
  /// **'Les catégories proposées aux organisateurs. Faites glisser pour changer l\'ordre ; un type désactivé n\'est plus proposé mais reste sur les événements existants.'**
  String get adminEventTypesIntro;

  /// No description provided for @adminEventTypeAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un type'**
  String get adminEventTypeAdd;

  /// No description provided for @adminEventTypeEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le type'**
  String get adminEventTypeEdit;

  /// No description provided for @adminEventTypeNameFr.
  ///
  /// In fr, this message translates to:
  /// **'Nom (français)'**
  String get adminEventTypeNameFr;

  /// No description provided for @adminEventTypeNameEn.
  ///
  /// In fr, this message translates to:
  /// **'Nom (anglais, facultatif)'**
  String get adminEventTypeNameEn;

  /// No description provided for @adminEventTypeIcon.
  ///
  /// In fr, this message translates to:
  /// **'Icône'**
  String get adminEventTypeIcon;

  /// No description provided for @adminEventTypeInactive.
  ///
  /// In fr, this message translates to:
  /// **'désactivé'**
  String get adminEventTypeInactive;

  /// No description provided for @adminEventTypeCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun événement} =1{1 événement} other{{count} événements}}'**
  String adminEventTypeCount(int count);

  /// No description provided for @adminEventTypeDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le type « {name} » ?'**
  String adminEventTypeDeleteTitle(String name);

  /// No description provided for @adminEventTypeReplaceTitle.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » est utilisé par {count, plural, =1{1 événement} other{{count} événements}}. Quel type les reprend ?'**
  String adminEventTypeReplaceTitle(String name, int count);

  /// No description provided for @liveSourceYoutube.
  ///
  /// In fr, this message translates to:
  /// **'Lien d\'un direct YouTube'**
  String get liveSourceYoutube;

  /// No description provided for @liveSourceYoutubeHint.
  ///
  /// In fr, this message translates to:
  /// **'Diffusez sur YouTube, sans LiveKit ; la discussion reste dans l\'application'**
  String get liveSourceYoutubeHint;

  /// No description provided for @liveYoutubeUrlLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lien du direct YouTube'**
  String get liveYoutubeUrlLabel;

  /// No description provided for @liveYoutubeUrlInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Lien YouTube invalide.'**
  String get liveYoutubeUrlInvalid;

  /// No description provided for @liveYoutubeHelpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Diffuser avec YouTube'**
  String get liveYoutubeHelpTitle;

  /// No description provided for @liveYoutubeStep1.
  ///
  /// In fr, this message translates to:
  /// **'Lancez votre direct sur YouTube (application YouTube, YouTube Studio ou OBS).'**
  String get liveYoutubeStep1;

  /// No description provided for @liveYoutubeStep2.
  ///
  /// In fr, this message translates to:
  /// **'Copiez son lien et collez-le ci-dessus.'**
  String get liveYoutubeStep2;

  /// No description provided for @liveYoutubeStep3.
  ///
  /// In fr, this message translates to:
  /// **'Le direct s\'ouvre aussitôt dans l\'application ; terminez-le ici quand la diffusion YouTube est finie.'**
  String get liveYoutubeStep3;

  /// No description provided for @liveCheckYoutubeOk.
  ///
  /// In fr, this message translates to:
  /// **'Diffusion par YouTube'**
  String get liveCheckYoutubeOk;

  /// No description provided for @adminCategoryNameFr.
  ///
  /// In fr, this message translates to:
  /// **'Nom (français)'**
  String get adminCategoryNameFr;

  /// No description provided for @adminCategoryNameEn.
  ///
  /// In fr, this message translates to:
  /// **'Nom anglais (facultatif)'**
  String get adminCategoryNameEn;

  /// No description provided for @adminCategoryNameEnHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. : Healing'**
  String get adminCategoryNameEnHint;

  /// No description provided for @adminNewCategoryEnHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom anglais (facultatif)…'**
  String get adminNewCategoryEnHint;

  /// No description provided for @adminCategoryNoEnglish.
  ///
  /// In fr, this message translates to:
  /// **'Pas de nom anglais'**
  String get adminCategoryNoEnglish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
