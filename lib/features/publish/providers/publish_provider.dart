import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/daos/testimony_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../features/home/models/testimony_model.dart';
import '../../../features/home/providers/home_providers.dart';
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

  void updateCategory(String category) =>
      state = state.copyWith(category: category);

  void updateCoverImage(String path) =>
      state = state.copyWith(coverImagePath: path);

  // ── Step 2: Content ─────────────────────────────────────────────────────────

  void updateBodyText(String value) => state = state.copyWith(bodyText: value);

  void updateBibleVerse(String value) =>
      state = state.copyWith(bibleVerse: value);

  void updateAudioPath(String path) => state = state.copyWith(audioPath: path);

  void updateAudioDuration(int seconds) =>
      state = state.copyWith(audioDurationSeconds: seconds);

  void updateAudioTranscript(String text) =>
      state = state.copyWith(audioTranscript: text);

  void updateVideoPath(String path) => state = state.copyWith(videoPath: path);

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
    state = state.copyWith(status: PublishStatus.submitted);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final user     = ref.read(currentUserProvider);
    final userId   = user?.id ?? 'anon';
    final userName = user?.displayName ?? 'Vous';
    final author   = TestimonyAuthor(uid: userId, displayName: userName);
    final id       = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final category = _categoryFromString(state.category);
    final now      = DateTime.now();

    // ── Créer l'objet Testimony (pour le feed en mémoire) ─────────────────
    final Testimony testimony;
    final Map<String, dynamic> dbRow;

    switch (state.format ?? TestimonyFormat.text) {
      case TestimonyFormat.text:
        final body = state.bodyText;
        testimony = TextTestimony(
          id: id, author: author, title: state.title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          preview: body.substring(0, math.min(220, body.length)),
        );
        dbRow = _buildRow(
          id: id, userId: userId, authorName: userName,
          title: state.title, type: 'text', category: category,
          bodyText: body, mediaUrl: null,
          coverUrl: state.coverImagePath,
          durationSec: 0, bibleVerse: state.bibleVerse,
          now: now,
        );

      case TestimonyFormat.audio:
        final transcript = state.audioTranscript;
        testimony = AudioTestimony(
          id: id, author: author, title: state.title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          durationSeconds: state.audioDurationSeconds,
          transcriptPreview: transcript.isNotEmpty
              ? transcript.substring(0, math.min(180, transcript.length))
              : 'Écoutez mon témoignage…',
          mediaPath: state.audioPath,
        );
        dbRow = _buildRow(
          id: id, userId: userId, authorName: userName,
          title: state.title, type: 'audio', category: category,
          bodyText: transcript, mediaUrl: state.audioPath,
          coverUrl: state.coverImagePath,
          durationSec: state.audioDurationSeconds,
          bibleVerse: state.bibleVerse, now: now,
        );

      case TestimonyFormat.video:
        testimony = VideoTestimony(
          id: id, author: author, title: state.title,
          category: category, createdAt: now, stats: TestimonyStats.zero,
          durationSeconds: 0, thumbnailUrl: state.coverImagePath ?? '',
          mediaPath: state.videoPath,
        );
        dbRow = _buildRow(
          id: id, userId: userId, authorName: userName,
          title: state.title, type: 'video', category: category,
          bodyText: null, mediaUrl: state.videoPath,
          coverUrl: state.coverImagePath,
          durationSec: 0, bibleVerse: null, now: now,
        );
    }

    // ── Sauvegarder en SQLite ─────────────────────────────────────────────
    try {
      final dao = TestimonyDao(DatabaseService());
      await dao.upsert(dbRow);
    } catch (e) {
      // Échec SQLite non bloquant : le feed en mémoire reste fonctionnel
    }

    ref.read(feedNotifierProvider.notifier).addTestimony(testimony);
    state = state.copyWith(status: PublishStatus.published);
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
      if (bodyText  != null) 'body_text':   bodyText,
      if (mediaUrl  != null) 'media_url':   mediaUrl,
      if (coverUrl  != null) 'cover_url':   coverUrl,
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
