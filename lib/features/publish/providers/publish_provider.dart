import 'dart:async' show Timer, unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/network/network_failure.dart';
import '../../../core/providers/categories_provider.dart';
import '../../../core/media/youtube.dart';
import '../../offline/outbox_controller.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider, realUserProvider;
import '../../../features/bible/providers/bible_providers.dart'
    show bibleVerseRefProvider, bibleVerseToInsertProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/api_service.dart';
import '../../journal/data/journal_repository.dart' show journalRefreshProvider;
import '../drafts/publish_drafts.dart';
import '../models/publish_models.dart';
import '../upload/video_upload_controller.dart' show videoUploadProvider;
import '../../../shared/models/mention.dart' show MentionRef;
import '../../prophecies/providers/prophecies_providers.dart' show propheciesListProvider;
import '../../conversion/providers/conversion_providers.dart'
    show myConversionProvider, latestConversionsProvider;
import '../../../l10n/app_localizations.dart';

// Converts a relative server URL (e.g. "/storage/videos/x.mp4") to absolute.
String? _absoluteUrl(String? raw) => absoluteMediaUrl(raw);

/// Message d'échec d'upload : raison renvoyée par Laravel si disponible
/// (ex. « The file failed to upload. » quand PHP refuse la taille du fichier).
String _uploadErrorMessage(Object e, String fallback) {
  if (e is LaravelApiException) {
    final detail = e.displayMessage;
    return detail.isNotEmpty ? '$fallback\n$detail' : fallback;
  }
  if (e is DioException && e.type == DioExceptionType.receiveTimeout) {
    return '$fallback\n${L10n.current.publishServerTooSlow}';
  }
  return fallback;
}

// =============================================================================
// Événement de rattachement (témoignage officiel publié par un gestionnaire)
// Backend : docs/fonctionnalites/evenements.md
// =============================================================================

/// Événement auquel le prochain témoignage publié sera rattaché (`event_id`),
/// choisi depuis la page de l'événement. null : témoignage ordinaire.
class PublishEventNotifier extends Notifier<({String id, String title})?> {
  @override
  ({String id, String title})? build() => null;

  void attach(String id, String title) => state = (id: id, title: title);
  void clear() => state = null;
}

final publishEventProvider =
    NotifierProvider<PublishEventNotifier, ({String id, String title})?>(
        PublishEventNotifier.new);

/// Direct terminé dont le prochain témoignage parle (`live_id`, docs serveur
/// fonctionnalites/lives.md) : n'importe quel compte peut témoigner après la fin.
final publishLiveProvider =
    NotifierProvider<PublishEventNotifier, ({String id, String title})?>(
        PublishEventNotifier.new);

/// Parole prophétique dont le prochain témoignage raconte l'accomplissement
/// (`prophecy_id`) ; [makePublic] : la parole est montrée avec le témoignage.
/// Doc serveur : docs/fonctionnalites/paroles-prophetiques.md
typedef PublishProphecy = ({String id, String title, bool makePublic});

class PublishProphecyNotifier extends Notifier<PublishProphecy?> {
  @override
  PublishProphecy? build() => null;

  void attach(String id, String title) => state = (id: id, title: title, makePublic: true);
  void setPublic(bool value) {
    final s = state;
    if (s != null) state = (id: s.id, title: s.title, makePublic: value);
  }

  void clear() => state = null;
}

final publishProphecyProvider =
    NotifierProvider<PublishProphecyNotifier, PublishProphecy?>(PublishProphecyNotifier.new);

// =============================================================================
// Témoignage de conversion (kind = conversion), un seul par compte personnel.
// Backend : docs/fonctionnalites/temoignage-de-conversion.md
// =============================================================================

/// Champs propres du témoignage de conversion, tous facultatifs.
class ConversionFields {
  const ConversionFields({this.year, this.place = '', this.verse = ''});

  final int? year;
  final String place;
  final String verse;

  ConversionFields copyWith({int? Function()? year, String? place, String? verse}) => ConversionFields(
        year: year != null ? year() : this.year,
        place: place ?? this.place,
        verse: verse ?? this.verse,
      );

  /// Champs envoyés avec POST /testimonies (ou /videos/upload-init).
  Map<String, dynamic> toJson() => {
        'kind': 'conversion',
        'conversion_year': year,
        'conversion_place': place.trim().isEmpty ? null : place.trim(),
        'conversion_verse': verse.trim().isEmpty ? null : verse.trim(),
      };
}

/// Le prochain témoignage publié est mon témoignage de conversion ; null : témoignage standard.
class PublishConversionNotifier extends Notifier<ConversionFields?> {
  @override
  ConversionFields? build() => null;

  void start() => state = const ConversionFields();
  void update(ConversionFields fields) => state = fields;
  void clear() => state = null;
}

final publishConversionProvider =
    NotifierProvider<PublishConversionNotifier, ConversionFields?>(PublishConversionNotifier.new);

// =============================================================================
// Publish flow state — drives the multi-step stepper
// =============================================================================

class PublishNotifier extends Notifier<PublishDraft> {
  // ── Brouillon gardé sur le téléphone (lib/features/publish/drafts/) ────────
  //
  // Enregistré 2 s après chaque modification et quand le formulaire est quitté :
  // un retour par mégarde ou la fermeture de l'application ne perd rien.
  // Supprimé une fois le témoignage publié (ou gardé dans la file d'envoi).

  Timer? _autosave;
  String? _lastSaved;

  /// « Supprimer le brouillon » : plus rien n'est enregistré pour ce formulaire.
  bool _discarded = false;

  static const _sentStatuses = {
    PublishStatus.inReview,
    PublishStatus.published,
    PublishStatus.pendingSync,
    PublishStatus.savedToJournal,
    PublishStatus.videoUploading,
  };

  /// Dernier état et personne connectée, pour l'enregistrement à la fermeture
  /// (le Ref n'est plus utilisable dans onDispose).
  PublishDraft? _latest;
  String? _uid;

  @override
  PublishDraft build() {
    final store = ref.read(publishDraftsStoreProvider);
    final container = ref.container;
    listenSelf((prev, next) {
      _latest = next;
      _uid = ref.read(realUserProvider)?.id;
      // Publié : le brouillon n'a plus lieu d'être.
      if (_sentStatuses.contains(next.status)) {
        _autosave?.cancel();
        final id = next.draftId ?? prev?.draftId;
        if (id != null) unawaited(_deleteStored(id));
        return;
      }
      _autosave?.cancel();
      _autosave = Timer(const Duration(seconds: 2), () => unawaited(saveDraftNow()));
    });
    ref.onDispose(() {
      // Quitté avant les 2 s : enregistré quand même (l'état est figé ici).
      if (_autosave?.isActive ?? false) {
        _autosave!.cancel();
        final uid = _uid;
        final draft = _latest;
        if (uid != null && draft != null && _shouldSave(draft)) {
          unawaited(store.save(uid, draft).then((_) => container.invalidate(publishDraftsProvider)).catchError((_) {}));
        }
      }
    });
    return PublishDraft();
  }

  bool _shouldSave(PublishDraft d) =>
      !_discarded && d.hasContent && !_sentStatuses.contains(d.status) && d.status != PublishStatus.submitted;

  /// Enregistre le brouillon tout de suite (rien à faire s'il est vide ou inchangé).
  Future<void> saveDraftNow() async {
    _autosave?.cancel();
    final uid = ref.read(realUserProvider)?.id;
    final draft = state;
    if (uid == null || !_shouldSave(draft)) return;
    final json = jsonEncode(draft.toDraftJson());
    if (json == _lastSaved && draft.draftId != null) return;
    try {
      final saved = await ref.read(publishDraftsStoreProvider).save(uid, draft);
      if (!ref.mounted) return;
      _lastSaved = jsonEncode(saved.toDraftJson());
      // Identifiant et chemins des copies, sans relancer d'enregistrement.
      if (state.draftId != saved.draftId ||
          state.coverImagePath != saved.coverImagePath ||
          state.audioPath != saved.audioPath ||
          state.videoPath != saved.videoPath ||
          state.proofs.length != saved.proofs.length ||
          state.proofs.entries.any((e) => saved.proofs[e.key]?.path != e.value.path)) {
        state = state.copyWith(
          draftId: saved.draftId,
          coverImagePath: saved.coverImagePath,
          audioPath: saved.audioPath,
          videoPath: saved.videoPath,
          proofs: saved.proofs,
        );
        _autosave?.cancel();
      }
      ref.invalidate(publishDraftsProvider);
    } catch (e) {
      debugPrint('Brouillon ✗ enregistrement : $e');
    }
  }

  /// Reprend un brouillon enregistré.
  void loadDraft(PublishDraft draft) {
    _discarded = false;
    _lastSaved = jsonEncode(draft.toDraftJson());
    state = draft.copyWith(status: PublishStatus.draft, errorMessage: null, uploadError: null);
    _autosave?.cancel();
  }

  /// « Supprimer le brouillon » : formulaire vidé, brouillon effacé du téléphone.
  Future<void> discardDraft() async {
    _discarded = true;
    _autosave?.cancel();
    final id = state.draftId;
    state = PublishDraft();
    _autosave?.cancel();
    if (id != null) await _deleteStored(id);
  }

  Future<void> _deleteStored(String id) async {
    try {
      await ref.read(publishDraftsStoreProvider).delete(id);
      if (ref.mounted) ref.invalidate(publishDraftsProvider);
    } catch (e) {
      debugPrint('Brouillon ✗ suppression : $e');
    }
  }

  // ── Format selector ─────────────────────────────────────────────────────────

  /// [journal] : nouvelle entrée du carnet privé (visibilité privée d'office).
  void selectFormat(TestimonyFormat format, {bool journal = false}) {
    // Témoignage de conversion : catégorie « Conversion » proposée d'office.
    final conversion = !journal && ref.read(publishConversionProvider) != null;
    final conversionCat = conversion
        ? ref.read(categoriesListProvider).where((c) => c.slug == 'conversion').firstOrNull
        : null;
    _discarded = false;
    _lastSaved = null;
    state = PublishDraft(
      format: format,
      visibility:
          journal ? TestimonyVisibility.private : TestimonyVisibility.public,
      category: conversion ? 'conversion' : null, // i18n-ignore
      categoryId: conversionCat != null && conversionCat.id.isNotEmpty ? conversionCat.id : null,
      // Verset choisi (Bible, verset du jour) : repris quel que soit le type de témoignage.
      bibleVerse: journal ? '' : ref.read(bibleVerseToInsertProvider) ?? '',
    );
  }

  // ── Step 1: Details ─────────────────────────────────────────────────────────

  void updateTitle(String value) =>
      state = state.copyWith(
          title: value.length > 80 ? value.substring(0, 80) : value);

  void updateCategory(CategoryModel cat) => state = state.copyWith(
        category: cat.slug,
        categoryId: cat.id.isNotEmpty ? cat.id : null,
      );

  void updateCoverImage(String path) =>
      state = state.copyWith(coverImagePath: path);

  // ── Step 2: Content ─────────────────────────────────────────────────────────

  void updateBodyText(String value) => state = state.copyWith(bodyText: value);

  /// Mentions « @ » choisies dans la description / transcription (envoyées en `mention_ids`).
  void updateMentions(List<MentionRef> mentions) =>
      state = state.copyWith(mentions: List.unmodifiable(mentions));

  void updateBibleVerse(String value) =>
      state = state.copyWith(bibleVerse: value);

  void updateAudioPath(String path) => state = state.copyWith(audioPath: path);

  void updateAudioDuration(int seconds) =>
      state = state.copyWith(audioDurationSeconds: seconds);

  void clearAudio() => state = state.copyWith(
        audioPath: '',
        audioDurationSeconds: 0,
        audioRemoteUrl: null,
        isUploadingMedia: false,
        uploadError: null,
      );

  void updateAudioTranscript(String text) =>
      state = state.copyWith(audioTranscript: text);

  void updateVideoPath(String path) => state = state.copyWith(videoPath: path);

  void updateVideoDuration(int seconds) =>
      state = state.copyWith(videoDurationSeconds: seconds);

  void updateVideoTrim(Duration start, Duration end) =>
      state = state.copyWith(videoTrimStart: start, videoTrimEnd: end);

  void updateThumbnailIndex(int index) =>
      state = state.copyWith(videoThumbnailIndex: index);

  // Vidéo YouTube (administrateurs) : le lien remplace le fichier vidéo.
  void setUseYouTube(bool value) => state = state.copyWith(useYouTube: value);

  void updateYouTubeUrl(String value) =>
      state = state.copyWith(youtubeUrl: value.trim());

  /// Crédit de la vidéo d'origine (auteur, chaîne YouTube, lien).
  void updateYouTubeCredit({String? author, String? channel, String? url}) => state = state.copyWith(
        youtubeCreditAuthor: author,
        youtubeCreditChannel: channel,
        youtubeCreditUrl: url,
      );

  // ── Preuves (2 emplacements) ────────────────────────────────────────────────

  void setProof(int position, ProofAttachment file) =>
      state = state.copyWith(proofs: {...state.proofs, position: file});

  void removeProof(int position) => state = state.copyWith(
      proofs: {...state.proofs}..remove(position));

  /// Publier aussi les preuves (docs serveur fonctionnalites/preuves.md).
  void setProofsPublic(bool value) => state = state.copyWith(proofsPublic: value);

  // ── Référencement (docs serveur fonctionnalites/referencement.md) ───────────

  /// Publier aussi sur le site (et dans Google).
  void setPublicationWeb(bool value) => state = state.copyWith(publicationWeb: value);

  /// « Témoignage anonyme » sur le site.
  void setAnonymous(bool value) => state = state.copyWith(isAnonymous: value);

  void updateResume(String value) => state = state.copyWith(resume: value);

  void updateTranscription(String value) => state = state.copyWith(transcription: value);

  /// Liste existante (null : aucune). Efface le titre d'une nouvelle liste.
  void setPlaylist(String? id) =>
      state = state.copyWith(playlistId: id, playlistTitle: id == null ? null : '', playlistError: null);

  /// Titre d'une nouvelle liste (prioritaire sur la liste choisie, comme côté serveur).
  void setPlaylistTitle(String value) => state = state.copyWith(playlistTitle: value, playlistError: null);

  // ── Step 3: Publication ─────────────────────────────────────────────────────

  void setVisibility(TestimonyVisibility v) =>
      state = state.copyWith(visibility: v);

  void toggleConsent() =>
      state = state.copyWith(consentGiven: !state.consentGiven);

  void saveDraft() => unawaited(saveDraftNow());

  Future<void> publish() async {
    state = state.copyWith(status: PublishStatus.submitted, uploadError: null);

    final format = state.format ?? TestimonyFormat.text;

    // Serveur injoignable : le témoignage et ses fichiers sont gardés sur le
    // téléphone (file d'envoi), puis envoyés au retour du réseau.
    var offline = false;

    // ── Upload image de couverture si chemin local présent et pas encore envoyé ─
    if ((state.coverImagePath ?? '').isNotEmpty &&
        state.coverImageRemoteUrl == null) {
      state = state.copyWith(isUploadingMedia: true);
      try {
        final api    = ref.read(apiServiceProvider);
        final result = await api.upload<Map<String, dynamic>>(
          AppConstants.uploadMedia,
          filePath: state.coverImagePath!,
          fieldName: 'file',
          extraFields: {'type': 'image'},
        );
        final url = _absoluteUrl(result.data['url'] as String?);
        debugPrint('═══ UPLOAD cover ✓ url=$url');
        state = state.copyWith(coverImageRemoteUrl: url, isUploadingMedia: false);
      } catch (e) {
        debugPrint('═══ UPLOAD cover ✗ $e');
        state = state.copyWith(isUploadingMedia: false);
        // Hors connexion : la couverture partira avec le témoignage (file d'envoi).
        if (isNetworkFailure(e) && !kIsWeb) {
          offline = true;
        } else {
          state = state.copyWith(
            status: PublishStatus.draft,
            uploadError: _uploadErrorMessage(e, L10n.current.publishCoverUploadFailed),
          );
          return;
        }
      }
    }

    // ── Upload média si chemin local présent et pas encore envoyé ─────────────
    if (!offline &&
        format == TestimonyFormat.audio &&
        (state.audioPath ?? '').isNotEmpty &&
        state.audioRemoteUrl == null) {
      state = state.copyWith(isUploadingMedia: true);
      try {
        final api    = ref.read(apiServiceProvider);
        final result = await api.upload<Map<String, dynamic>>(
          AppConstants.uploadMedia,
          filePath: state.audioPath!,
          fieldName: 'file',
          extraFields: {'type': 'audio'},
        );
        final url = _absoluteUrl(result.data['url'] as String?);
        debugPrint('═══ UPLOAD audio ✓ url=$url');
        state = state.copyWith(audioRemoteUrl: url, isUploadingMedia: false);
      } catch (e) {
        debugPrint('═══ UPLOAD audio ✗ $e');
        state = state.copyWith(isUploadingMedia: false);
        if (isNetworkFailure(e) && !kIsWeb) {
          offline = true;
        } else {
          state = state.copyWith(
            status: PublishStatus.draft,
            uploadError: _uploadErrorMessage(e, L10n.current.publishAudioUploadFailed),
          );
          return;
        }
      }
    }

    // Lien YouTube (administrateurs) : aucun fichier vidéo à envoyer.
    final youtubeId = format == TestimonyFormat.video && state.useYouTube
        ? extractYouTubeId(state.youtubeUrl)
        : null;

    // Fichier vidéo : envoyé à Bunny Stream après la construction du corps
    // (POST /videos/upload-init, voir plus bas), pas par /media/upload.
    final bunnyVideo = format == TestimonyFormat.video &&
        youtubeId == null &&
        (state.videoPath ?? '').isNotEmpty;

    // Titre facultatif dans le formulaire : repli sur la description.
    final title    = state.effectiveTitle;

    final user     = ref.read(currentUserProvider);
    final userId   = user?.id ?? 'anon';
    final userName = user?.displayName ?? L10n.current.commonYou;
    final author   = TestimonyAuthor(uid: userId, displayName: userName);
    final now      = DateTime.now();

    // Résoudre category depuis le provider serveur si categoryId absent
    final cats       = ref.read(categoriesListProvider);
    final catSlug    = state.category ?? '';
    final catMatch   = cats.where((c) => c.slug == catSlug).firstOrNull;
    final catId      = state.categoryId ?? catMatch?.id;
    final category   = _categoryFromString(state.category);

    // ── Calculer durée et corps selon le format ───────────────────────────
    final String typeStr;
    final String? bodyText;
    final String? mediaUrl;
    final int durationSec;

    switch (format) {
      case TestimonyFormat.text:
        typeStr    = 'text';
        bodyText   = state.bodyText;
        mediaUrl   = null;
        durationSec = 0;
      case TestimonyFormat.audio:
        typeStr     = 'audio';
        bodyText    = state.audioTranscript.isNotEmpty ? state.audioTranscript : null;
        mediaUrl    = state.audioRemoteUrl;
        durationSec = state.audioDurationSeconds;
      case TestimonyFormat.video:
        typeStr   = 'video';
        // Description facultative saisie à l'étape 1.
        bodyText  = state.bodyText.trim().isNotEmpty ? state.bodyText : null;
        mediaUrl  = youtubeId != null ? null : state.videoRemoteUrl;
        durationSec = youtubeId != null
            ? 0
            : state.videoDurationSeconds > 0
            ? state.videoDurationSeconds
            : (state.videoTrimEnd != Duration.zero
                ? (state.videoTrimEnd - state.videoTrimStart).inSeconds
                : 0);
    }

    // ── POST vers l'API ───────────────────────────────────────────────────
    String id = newLocalId();
    var savedOffline = false;
    var created = false;

    final postBody = <String, dynamic>{
      'title'       : title,
      'type'        : typeStr,
      // Facultative dans le carnet privé (le serveur met « autre »).
      'category'    : catSlug.isEmpty ? null : catSlug,
      'category_id' : catId,
      'body_text'   : bodyText,
      // Mentions « @Nom » choisies : reconnues par le serveur, prévenues à la publication.
      if (state.mentionIdsIn(bodyText) case final ids when ids.isNotEmpty)
        'mention_ids': ids,
      'media_url'   : mediaUrl,
      'cover_url'   : state.coverImageRemoteUrl,
      'duration'    : durationSec,
      'bible_verse' : state.bibleVerse.isNotEmpty ? state.bibleVerse : null,
      // Référence structurée (« Jean 3:16-18 ») choisie dans la Bible ou le verset
      // du jour : enregistrée dans bible_ref (verseReference) et utilisée par le
      // serveur pour lier le témoignage au verset, audio et vidéo compris.
      if (ref.read(bibleVerseRefProvider) case final vRef?)
        'verse_ref': vRef.displayRef,
      // Administrateurs seulement (403 sinon) : le serveur force le type vidéo,
      // aucun fichier et la miniature YouTube en couverture.
      if (youtubeId != null) 'youtube_url': state.youtubeUrl,
      // Crédit de la vidéo d'origine (docs serveur videos-youtube.md).
      if (youtubeId != null) ...{
        'youtube_credit_author': state.youtubeCreditAuthor.trim().isEmpty ? null : state.youtubeCreditAuthor.trim(),
        'youtube_credit_channel': state.youtubeCreditChannel.trim().isEmpty ? null : state.youtubeCreditChannel.trim(),
        'youtube_credit_url': state.youtubeCreditUrl.trim().isEmpty ? null : state.youtubeCreditUrl.trim(),
      },
      // Preuves montrées au public (une fois le témoignage publié) si l'auteur l'accepte.
      if (state.proofs.isNotEmpty) 'proofs_public': state.proofsPublic,
      // Témoignage officiel d'un événement (gestionnaires ; jamais pour le carnet privé).
      if (ref.read(publishEventProvider) case final ev?
          when state.visibility != TestimonyVisibility.private)
        'event_id': ev.id,
      // Témoignage sur un direct terminé.
      if (ref.read(publishLiveProvider) case final live?
          when state.visibility != TestimonyVisibility.private)
        'live_id': live.id,
      // Accomplissement d'une parole prophétique (et parole rendue publique ou non).
      if (ref.read(publishProphecyProvider) case final p?) ...{
        'prophecy_id': p.id,
        'prophecy_public': p.makePublic && state.visibility != TestimonyVisibility.private,
      },
      // Témoignage de conversion : sorte et champs propres (année, lieu, verset).
      if (ref.read(publishConversionProvider) case final c?) ...c.toJson(),
      // Site et Google (docs serveur fonctionnalites/referencement.md) : accord,
      // anonymat sur le site ; audio et vidéo : résumé et transcription
      // (pour un audio, la transcription est la description saisie).
      ...webPublicationFields(state, format),
      // Liste de témoignages (facultatif ; jamais pour le carnet privé).
      ...playlistPublishFields(state),
      'visibility'  : switch (state.visibility) {
        TestimonyVisibility.private => 'private',
        TestimonyVisibility.friends => 'followers', // valeur attendue par l'API
        TestimonyVisibility.public  => 'public',
      },
    };

    // ── Vidéo Bunny Stream : upload-init crée le témoignage (mêmes champs que
    // POST /testimonies, sans media_url) ; compression, envoi TUS reprenable et
    // upload-complete se poursuivent dans videoUploadProvider, même si l'on
    // quitte l'écran. La vidéo n'apparaît qu'une fois prête (push video_ready).
    if (bunnyVideo) {
      final body = {...postBody}..remove('media_url');
      final positions = state.proofs.keys.toList()..sort();
      // Une autre vidéo part déjà : celle-ci attend son tour dans la file d'envoi.
      final outbox = ref.read(outboxProvider.notifier);
      final videoDraft = OutboxDraft(
        kind: OutboxKind.videoTestimony,
        label: title,
        video: {
          'sourcePath': state.videoPath!,
          'title': title,
          'body': body,
          'proofs': [
            for (final p in positions) {'position': p, 'path': state.proofs[p]!.path},
          ],
        },
      );
      if (ref.read(videoUploadProvider.notifier).hasPendingJob && outbox.canQueue(videoDraft)) {
        await outbox.enqueue(videoDraft);
        _attachmentsPublished();
        state = state.copyWith(status: PublishStatus.pendingSync);
        return;
      }
      try {
        await ref.read(videoUploadProvider.notifier).start(
              sourcePath: state.videoPath!,
              title: title,
              body: body,
              proofs: [
                for (final p in positions)
                  (position: p, path: state.proofs[p]!.path),
              ],
            );
      } on StateError {
        state = state.copyWith(
          status: PublishStatus.draft,
          errorMessage: L10n.current.publishAnotherVideoUploading,
        );
        return;
      }
      _attachmentsPublished();
      state = state.copyWith(status: PublishStatus.videoUploading);
      return;
    }

    debugPrint('═══ PUBLISH → POST ${AppConstants.baseUrl}${AppConstants.testimonies}');
    debugPrint('═══ category slug=$catSlug id=$catId (state.categoryId=${state.categoryId}, catMatch=${catMatch?.id})');
    debugPrint('═══ BODY: $postBody');

    // Hors ligne : le témoignage, sa couverture, son audio et ses preuves sont
    // gardés sur le téléphone ; l'identifiant provisoire [id] est remplacé par
    // celui du serveur à l'envoi.
    Future<bool> queue() async {
      final positions = state.proofs.keys.toList()..sort();
      final draft = OutboxDraft(
        kind: OutboxKind.testimony,
        label: title,
        localId: id,
        request: OutboxRequest('POST', AppConstants.testimonies, body: postBody),
        before: [
          if ((state.coverImagePath ?? '').isNotEmpty && state.coverImageRemoteUrl == null)
            OutboxFile(path: AppConstants.uploadMedia, file: state.coverImagePath!, fields: const {'type': 'image'}, into: 'cover_url'),
          if (format == TestimonyFormat.audio && (state.audioPath ?? '').isNotEmpty && state.audioRemoteUrl == null)
            OutboxFile(path: AppConstants.uploadMedia, file: state.audioPath!, fields: const {'type': 'audio'}, into: 'media_url'),
        ],
        after: [
          for (final p in positions)
            OutboxFile(path: AppConstants.testimonyProofs('{id}'), file: state.proofs[p]!.path, fields: {'position': p}),
        ],
      );
      final outbox = ref.read(outboxProvider.notifier);
      if (!outbox.canQueue(draft)) return false;
      try {
        return await outbox.enqueue(draft) != null;
      } catch (e) {
        debugPrint('═══ PUBLISH file d\'envoi ✗ $e');
        return false;
      }
    }

    try {
      if (offline) {
        if (!await queue()) {
          state = state.copyWith(status: PublishStatus.draft, errorMessage: L10n.current.commonErrorNetwork);
          return;
        }
        savedOffline = true;
        _attachmentsPublished();
      } else {
        final api    = ref.read(apiServiceProvider);
        final result = await api.post<Map<String, dynamic>>(
          AppConstants.testimonies,
          data: postBody,
        );
        debugPrint('═══ PUBLISH ✓ id=${result.data['id']}');
        id = result.data['id']?.toString() ?? id;
        created = true;
        _attachmentsPublished();
      }
    } on DioException catch (e) {
      debugPrint('═══ PUBLISH DioException type=${e.type} status=${e.response?.statusCode} body=${e.response?.data}');
      if (isNetworkFailure(e)) {
        // Hors ligne → file d'envoi, envoi automatique au retour du réseau.
        if (!await queue()) {
          state = state.copyWith(status: PublishStatus.draft, errorMessage: L10n.current.commonErrorNetwork);
          return;
        }
        savedOffline = true;
        _attachmentsPublished();
      } else {
        // Erreur serveur (4xx/5xx) — informer l'utilisateur
        final serverMsg = (e.response?.data as Map?)?['message'] as String?;
        // Liste d'un autre compte (422 errors.playlist_id) : message sous le champ.
        final playlistError = playlistErrorFrom(e.response?.data);
        if (playlistError != null) {
          state = state.copyWith(status: PublishStatus.draft, errorMessage: playlistError, playlistError: playlistError);
          return;
        }
        final msg = serverMsg ??
            L10n.current.publishServerErrorRetry(
                '${e.response?.statusCode ?? L10n.current.publishUnknownCode}');
        state = state.copyWith(status: PublishStatus.draft, errorMessage: msg);
        return;
      }
    } on LaravelApiException catch (e) {
      // 422 errors.playlist_id (liste d'un autre compte) : message sous le champ.
      final playlistError = playlistErrorFrom({'errors': e.errors});
      state = state.copyWith(
        status: PublishStatus.draft,
        errorMessage: playlistError ?? e.message,
        playlistError: playlistError,
      );
      return;
    } catch (e) {
      debugPrint('═══ PUBLISH catch-all: $e');
      final raw = e.toString();
      final msg = raw.contains('): ')
          ? raw.substring(raw.indexOf('): ') + 3)
          : raw;
      state = state.copyWith(status: PublishStatus.draft, errorMessage: msg);
      return;
    }

    // ── Preuves : envoyées après la création du témoignage ────────────────
    // Hors ligne, elles partent avec le témoignage depuis la file d'envoi.
    // Un échec n'annule pas la publication (message affiché par l'écran).
    final failedProofs = <int>[];
    if (created && !savedOffline) {
      final api = ref.read(apiServiceProvider);
      final positions = state.proofs.keys.toList()..sort();
      for (final position in positions) {
        try {
          await api.upload<Map<String, dynamic>>(
            AppConstants.testimonyProofs(id),
            filePath: state.proofs[position]!.path,
            fieldName: 'file',
            extraFields: {'position': position},
          );
        } catch (e) {
          debugPrint('═══ UPLOAD preuve $position ✗ $e');
          failedProofs.add(position);
        }
      }
    }
    state = state.copyWith(failedProofPositions: failedProofs);

    // ── Construire l'objet Testimony pour le feed en mémoire ──────────────
    final Testimony testimony;

    switch (format) {
      case TestimonyFormat.text:
        final body = bodyText ?? '';
        final coverUrl = state.coverImageRemoteUrl;
        testimony = TextTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          preview: body,
          coverImageUrl: coverUrl,
        );

      case TestimonyFormat.audio:
        final transcript = bodyText ?? '';
        final coverUrl = state.coverImageRemoteUrl;
        testimony = AudioTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          durationSeconds: durationSec,
          transcriptPreview: transcript.isNotEmpty
              ? transcript.substring(0, math.min(180, transcript.length))
              : L10n.current.publishListenToMyTestimony,
          mediaPath: mediaUrl,
          coverImageUrl: coverUrl,
        );

      case TestimonyFormat.video:
        final coverUrl = state.coverImageRemoteUrl;
        testimony = VideoTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          durationSeconds: durationSec,
          thumbnailUrl: youtubeId != null
              ? youTubeThumbnailUrl(youtubeId)
              : coverUrl ?? '',
          // Prefer remote URL; fall back to local file if upload URL was not returned.
          mediaPath: youtubeId != null ? null : mediaUrl ?? state.videoPath,
          youtubeId: youtubeId,
        );
    }

    // Carnet privé : ne jamais l'ajouter au fil.
    if (state.visibility == TestimonyVisibility.private) {
      ref.read(journalRefreshProvider.notifier).bump();
      state = state.copyWith(
        status: savedOffline
            ? PublishStatus.pendingSync
            : PublishStatus.savedToJournal,
      );
      return;
    }

    ref.read(feedNotifierProvider.notifier).addTestimony(testimony);
    state = state.copyWith(
      status: savedOffline ? PublishStatus.pendingSync : PublishStatus.inReview,
    );
  }

  /// Rattachements (événement, direct, verset, parole, conversion) consommés :
  /// ils ne doivent pas suivre le témoignage suivant.
  void _attachmentsPublished() {
    ref.read(publishEventProvider.notifier).clear();
    ref.read(publishLiveProvider.notifier).clear();
    ref.read(bibleVerseRefProvider.notifier).clear();
    ref.read(bibleVerseToInsertProvider.notifier).clear();
    _conversionPublished();
    if (ref.read(publishProphecyProvider) != null) {
      ref.read(publishProphecyProvider.notifier).clear();
      ref.invalidate(propheciesListProvider);
    }
  }

  /// Témoignage de conversion envoyé : mode quitté, profil et section rechargés.
  void _conversionPublished() {
    if (ref.read(publishConversionProvider) == null) return;
    ref.read(publishConversionProvider.notifier).clear();
    ref.invalidate(myConversionProvider);
    ref.invalidate(latestConversionsProvider);
  }

  void reset() => state = PublishDraft();
}

/// Champs de la liste de témoignages envoyés avec POST /testimonies (et
/// upload-init) : `playlist_title` (nouvelle liste, prioritaire) ou
/// `playlist_id` ; rien pour le carnet privé. Docs serveur listes-de-temoignages.md
Map<String, dynamic> playlistPublishFields(PublishDraft d) {
  if (d.visibility == TestimonyVisibility.private) return const {};
  final title = d.playlistTitle.trim();
  if (title.isNotEmpty) return {'playlist_title': title};
  final id = d.playlistId;
  return id == null || id.isEmpty ? const {} : {'playlist_id': id};
}

/// Premier message de `errors.playlist_id` (ou `playlist_title`) d'une réponse 422.
String? playlistErrorFrom(Object? body) {
  final errors = body is Map ? body['errors'] : null;
  if (errors is! Map) return null;
  for (final key in const ['playlist_id', 'playlist_title']) {
    final v = errors[key];
    if (v is List && v.isNotEmpty) return '${v.first}';
    if (v is String && v.isNotEmpty) return v;
  }
  return null;
}

// Mappe les libellés français → enum TestimonyCategory
/// Champs de publication sur le web envoyés avec le témoignage (création et
/// upload-init) : `publicationWeb`, `isAnonymous`, `resume`, `transcription`.
Map<String, dynamic> webPublicationFields(PublishDraft d, TestimonyFormat format) {
  // Carnet privé et abonnés : jamais sur le site.
  final public = d.visibility == TestimonyVisibility.public;
  String? text(String v) => v.trim().isEmpty ? null : v.trim();
  final transcription = switch (format) {
    TestimonyFormat.text => null,
    TestimonyFormat.audio => text(d.audioTranscript),
    TestimonyFormat.video => text(d.transcription),
  };
  return {
    'publicationWeb': public && d.publicationWeb,
    'isAnonymous': public && d.publicationWeb && d.isAnonymous,
    if (format != TestimonyFormat.text && text(d.resume) != null) 'resume': text(d.resume),
    'transcription': ?transcription,
  };
}

TestimonyCategory _categoryFromString(String? s) => switch (s) {
      'Délivrance' => TestimonyCategory.delivrance, // i18n-ignore
      'Conversion' => TestimonyCategory.conversion, // i18n-ignore
      'Mariage' => TestimonyCategory.mariage, // i18n-ignore
      'Famille' => TestimonyCategory.famille, // i18n-ignore
      'Finances' => TestimonyCategory.finances, // i18n-ignore
      'Miracles' => TestimonyCategory.miracles, // i18n-ignore
      'Protection divine' => TestimonyCategory.protection, // i18n-ignore
      'Ministère' => TestimonyCategory.ministere, // i18n-ignore
      'Salut' => TestimonyCategory.salut, // i18n-ignore
      _ => TestimonyCategory.guerison,
    };

final publishProvider =
    NotifierProvider.autoDispose<PublishNotifier, PublishDraft>(
  PublishNotifier.new,
);

// ── Stepper step ─────────────────────────────────────────────────────────────

class PublishStepNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void goTo(int step) {
    assert(step >= 1 && step <= 3);
    state = step;
  }

  void next() {
    if (state < 3) state++;
  }

  void previous() {
    if (state > 1) state--;
  }
}

final publishStepProvider =
    NotifierProvider.autoDispose<PublishStepNotifier, int>(
  PublishStepNotifier.new,
);

// ── Audio recording state ────────────────────────────────────────────────────

enum AudioRecordingStatus { idle, recording, paused, finished }

class AudioRecordingNotifier extends Notifier<AudioRecordingStatus> {
  @override
  AudioRecordingStatus build() => AudioRecordingStatus.idle;

  void startRecording() => state = AudioRecordingStatus.recording;
  void stopRecording() => state = AudioRecordingStatus.finished;
  void pauseRecording() => state = AudioRecordingStatus.paused;
  void resumeRecording() => state = AudioRecordingStatus.recording;
  void reset() => state = AudioRecordingStatus.idle;
}

final audioRecordingProvider =
    NotifierProvider.autoDispose<AudioRecordingNotifier, AudioRecordingStatus>(
  AudioRecordingNotifier.new,
);
