import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/pending_ops_dao.dart';
import '../../../core/providers/categories_provider.dart';
import '../../../core/local_db/daos/testimony_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
import '../../../services/api_service.dart';
import '../models/publish_models.dart';

// =============================================================================
// Publish flow state — drives the multi-step stepper
// =============================================================================

class PublishNotifier extends Notifier<PublishDraft> {
  @override
  PublishDraft build() => PublishDraft();

  // ── Format selector ─────────────────────────────────────────────────────────

  void selectFormat(TestimonyFormat format) {
    state = PublishDraft(format: format);
  }

  // ── Step 1: Details ─────────────────────────────────────────────────────────

  void updateTitle(String value) =>
      state = state.copyWith(
          title: value.length > 80 ? value.substring(0, 80) : value);

  void updateCategory(CategoryModel cat) => state = state.copyWith(
        category: cat.slug,
        categoryId: cat.id > 0 ? cat.id : null,
      );

  void updateCoverImage(String path) =>
      state = state.copyWith(coverImagePath: path);

  // ── Step 2: Content ─────────────────────────────────────────────────────────

  void updateBodyText(String value) => state = state.copyWith(bodyText: value);

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

  // ── Step 3: Publication ─────────────────────────────────────────────────────

  void setVisibility(TestimonyVisibility v) =>
      state = state.copyWith(visibility: v);

  void toggleConsent() =>
      state = state.copyWith(consentGiven: !state.consentGiven);

  void saveDraft() => state = state.copyWith(status: PublishStatus.draft);

  Future<void> publish() async {
    state = state.copyWith(status: PublishStatus.submitted, uploadError: null);

    final format = state.format ?? TestimonyFormat.text;

    // ── Upload média si chemin local présent et pas encore envoyé ─────────────
    if (format == TestimonyFormat.audio &&
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
        final url = result.data['url'] as String?;
        debugPrint('═══ UPLOAD audio ✓ url=$url');
        state = state.copyWith(audioRemoteUrl: url, isUploadingMedia: false);
      } catch (e) {
        debugPrint('═══ UPLOAD audio ✗ $e');
        state = state.copyWith(
          isUploadingMedia: false,
          status: PublishStatus.draft,
          uploadError: "Échec de l'envoi audio. Réessaie.",
        );
        return;
      }
    }

    if (format == TestimonyFormat.video &&
        (state.videoPath ?? '').isNotEmpty &&
        state.videoRemoteUrl == null) {
      state = state.copyWith(isUploadingMedia: true);
      try {
        final api    = ref.read(apiServiceProvider);
        final result = await api.upload<Map<String, dynamic>>(
          AppConstants.uploadMedia,
          filePath: state.videoPath!,
          fieldName: 'file',
          extraFields: {'type': 'video'},
        );
        final url = result.data['url'] as String?;
        debugPrint('═══ UPLOAD video ✓ url=$url');
        state = state.copyWith(videoRemoteUrl: url, isUploadingMedia: false);
      } catch (e) {
        debugPrint('═══ UPLOAD video ✗ $e');
        state = state.copyWith(
          isUploadingMedia: false,
          status: PublishStatus.draft,
          uploadError: "Échec de l'envoi vidéo. Réessaie.",
        );
        return;
      }
    }

    final user     = ref.read(currentUserProvider);
    final userId   = user?.id ?? 'anon';
    final userName = user?.displayName ?? 'Vous';
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
        bodyText  = null;
        mediaUrl  = state.videoRemoteUrl;
        durationSec = state.videoDurationSeconds > 0
            ? state.videoDurationSeconds
            : (state.videoTrimEnd != Duration.zero
                ? (state.videoTrimEnd - state.videoTrimStart).inSeconds
                : 0);
    }

    // ── POST vers l'API ───────────────────────────────────────────────────
    String id = 'local_${DateTime.now().millisecondsSinceEpoch}';

    final postBody = <String, dynamic>{
      'title'       : state.title,
      'type'        : typeStr,
      'category'    : catSlug,
      'category_id' : catId,
      'body_text'   : bodyText,
      'media_url'   : mediaUrl,
      'cover_url'   : state.coverImagePath,
      'duration'    : durationSec,
      'bible_verse' : state.bibleVerse.isNotEmpty ? state.bibleVerse : null,
      'visibility'  : state.visibility == TestimonyVisibility.private
          ? 'private'
          : 'public',
    };

    debugPrint('═══ PUBLISH → POST ${AppConstants.baseUrl}${AppConstants.testimonies}');
    debugPrint('═══ category slug=$catSlug id=$catId (state.categoryId=${state.categoryId}, catMatch=${catMatch?.id})');
    debugPrint('═══ BODY: $postBody');

    try {
      final api    = ref.read(apiServiceProvider);
      final result = await api.post<Map<String, dynamic>>(
        AppConstants.testimonies,
        data: postBody,
      );
      debugPrint('═══ PUBLISH ✓ id=${result.data['id']}');
      id = result.data['id'] as String? ?? id;
    } on DioException catch (e) {
      debugPrint('═══ PUBLISH DioException type=${e.type} status=${e.response?.statusCode} body=${e.response?.data}');
      final isOffline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;

      if (isOffline) {
        // Hors ligne → file d'attente locale, sync au prochain retour en ligne
        try {
          final dao = PendingOpsDao(DatabaseService());
          await dao.enqueue(
            type:     PendingOpType.publishDraft,
            method:   'POST',
            endpoint: AppConstants.testimonies,
            body:     postBody,
          );
        } catch (_) {}
      } else {
        // Erreur serveur (4xx/5xx) — informer l'utilisateur
        final serverMsg = (e.response?.data as Map?)?['message'] as String?;
        final msg = serverMsg ??
            'Erreur serveur (${e.response?.statusCode ?? 'inconnue'}). Réessaie plus tard.';
        state = state.copyWith(status: PublishStatus.draft, errorMessage: msg);
        return;
      }
    } catch (e) {
      debugPrint('═══ PUBLISH catch-all: $e');
      final raw = e.toString();
      final msg = raw.contains('): ')
          ? raw.substring(raw.indexOf('): ') + 3)
          : raw;
      state = state.copyWith(status: PublishStatus.draft, errorMessage: msg);
      return;
    }

    // ── Construire l'objet Testimony pour le feed en mémoire ──────────────
    final Testimony testimony;
    final Map<String, dynamic> dbRow;

    switch (format) {
      case TestimonyFormat.text:
        final body = bodyText ?? '';
        testimony = TextTestimony(
          id: id, author: author, title: state.title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          preview: body.substring(0, math.min(220, body.length)),
          coverImageUrl: state.coverImagePath,
        );
        dbRow = _buildRow(
          id: id, userId: userId, authorName: userName,
          title: state.title, type: 'text', category: category,
          bodyText: body, mediaUrl: null, coverUrl: state.coverImagePath,
          durationSec: 0, bibleVerse: state.bibleVerse, now: now,
        );

      case TestimonyFormat.audio:
        final transcript = bodyText ?? '';
        testimony = AudioTestimony(
          id: id, author: author, title: state.title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          durationSeconds: durationSec,
          transcriptPreview: transcript.isNotEmpty
              ? transcript.substring(0, math.min(180, transcript.length))
              : 'Écoutez mon témoignage…',
          mediaPath: mediaUrl,
          coverImageUrl: state.coverImagePath,
        );
        dbRow = _buildRow(
          id: id, userId: userId, authorName: userName,
          title: state.title, type: 'audio', category: category,
          bodyText: transcript, mediaUrl: mediaUrl,
          coverUrl: state.coverImagePath, durationSec: durationSec,
          bibleVerse: state.bibleVerse, now: now,
        );

      case TestimonyFormat.video:
        testimony = VideoTestimony(
          id: id, author: author, title: state.title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          durationSeconds: durationSec,
          thumbnailUrl: state.coverImagePath ?? '',
          mediaPath: mediaUrl,
        );
        dbRow = _buildRow(
          id: id, userId: userId, authorName: userName,
          title: state.title, type: 'video', category: category,
          bodyText: null, mediaUrl: mediaUrl, coverUrl: state.coverImagePath,
          durationSec: durationSec, bibleVerse: null, now: now,
        );
    }

    // ── Sauvegarder en SQLite (cache local) ───────────────────────────────
    try {
      final dao = TestimonyDao(DatabaseService());
      await dao.upsert(dbRow);
    } catch (_) {}

    ref.read(feedNotifierProvider.notifier).addTestimony(testimony);
    // Soumis à la modération (status API: pending) → inReview dans l'app
    state = state.copyWith(status: PublishStatus.inReview);
  }

  static Map<String, dynamic> _buildRow({
    required String id,
    required String userId,
    required String authorName,
    required String title,
    required String type,
    required TestimonyCategory category,
    required String? bodyText,
    required String? mediaUrl,
    required String? coverUrl,
    required int durationSec,
    required String? bibleVerse,
    required DateTime now,
  }) {
    final iso = now.toIso8601String();
    return {
      'id':           id,
      'user_id':      userId,
      'author_name':  authorName,
      'title':        title,
      'type':         type,
      'category':     category.name,
      'body_text':   bodyText,
      'media_url':   mediaUrl,
      'cover_url':   coverUrl,
      'duration_sec': durationSec,
      if (bibleVerse != null && bibleVerse.isNotEmpty)
        'bible_verse': bibleVerse,
      'visibility':   'public',
      'status':       'published',
      'views':        0,
      'like_count':   0,
      'prayer_count': 0,
      'comment_count': 0,
      'is_featured':  0,
      'user_liked':   0,
      'user_prayed':  0,
      'user_saved':   0,
      'created_at':   iso,
      'updated_at':   iso,
    };
  }

  void reset() => state = PublishDraft();
}

// Mappe les libellés français → enum TestimonyCategory
TestimonyCategory _categoryFromString(String? s) => switch (s) {
      'Délivrance' => TestimonyCategory.delivrance,
      'Conversion' => TestimonyCategory.conversion,
      'Mariage' => TestimonyCategory.mariage,
      'Famille' => TestimonyCategory.famille,
      'Finances' => TestimonyCategory.finances,
      'Miracles' => TestimonyCategory.miracles,
      'Protection divine' => TestimonyCategory.protection,
      'Ministère' => TestimonyCategory.ministere,
      'Salut' => TestimonyCategory.salut,
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
