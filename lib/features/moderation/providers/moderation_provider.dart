import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/moderation_models.dart';

// ============================================================================
// Helpers : JSON API → modèles de modération
// ============================================================================

ModerationItem? _itemFromJson(dynamic raw) {
  try {
    final m      = raw as Map<String, dynamic>;
    final author = m['author'] as Map<String, dynamic>? ?? {};

    return ModerationItem(
      id:             m['id']             as String,
      title:          m['title']          as String? ?? '',
      category:       m['category']       as String? ?? '',
      type:           _parseType(m['type'] as String? ?? 'text'),
      status:         _parseStatus(m['status'] as String? ?? 'pending'),
      submittedAt:    DateTime.tryParse(m['submittedAt'] as String? ?? '') ?? DateTime.now(),
      contentPreview: m['contentPreview'] as String?,
      rejectionReason: _parseRejectionReason(m['rejectionReason'] as String?),
      moderatorNote:  m['moderatorNote']  as String?,
      author: ModerationAuthor(
        uid:         author['uid']         as String? ?? '',
        displayName: author['displayName'] as String? ?? 'Anonyme',
        country:     author['country']     as String? ?? '',
        avatarUrl:   author['avatarUrl']   as String?,
      ),
    );
  } catch (_) {
    return null;
  }
}

TestimonyType _parseType(String v) => switch (v) {
      'audio' => TestimonyType.audio,
      'video' => TestimonyType.video,
      _       => TestimonyType.text,
    };

ModerationStatus _parseStatus(String v) => switch (v) {
      'in_review' => ModerationStatus.inReview,
      'approved'  => ModerationStatus.approved,
      'rejected'  => ModerationStatus.rejected,
      _           => ModerationStatus.pending,
    };

RejectionReason? _parseRejectionReason(String? v) => switch (v) {
      'inappropriate_content' => RejectionReason.inappropriateContent,
      'false_testimony'       => RejectionReason.falseTestimony,
      'hate_speech'           => RejectionReason.hateSpeech,
      'spam'                  => RejectionReason.spam,
      'other'                 => RejectionReason.other,
      _                       => null,
    };

ModerationStats _statsFromJson(Map<String, dynamic> m) => ModerationStats(
      pending:        (m['pending']        as int?) ?? 0,
      approvedToday:  (m['approvedToday']  as int?) ?? 0,
      rejectedToday:  (m['rejectedToday']  as int?) ?? 0,
      totalThisMonth: (m['totalThisMonth'] as int?) ?? 0,
    );

// ============================================================================
// Notifier principal — charge et met à jour les items de modération
// ============================================================================

class ModerationNotifier extends AsyncNotifier<List<ModerationItem>> {
  @override
  Future<List<ModerationItem>> build() => _fetchPending();

  Future<List<ModerationItem>> _fetchPending() async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.get<List<dynamic>>(AppConstants.moderationPending);
    return response.data
        .map(_itemFromJson)
        .whereType<ModerationItem>()
        .toList();
  }

  Future<void> approve(String id) async {
    final api = ref.read(apiServiceProvider);
    await api.post<void>(AppConstants.moderationApprove(id));
    state = AsyncValue.data(
      state.value?.where((i) => i.id != id).toList() ?? [],
    );
  }

  Future<void> reject(String id, RejectionReason reason, String note) async {
    final api = ref.read(apiServiceProvider);
    await api.post<void>(
      AppConstants.moderationReject(id),
      data: {
        'rejection_reason': _rejectionReasonToApi(reason),
        if (note.isNotEmpty) 'moderator_note': note,
      },
    );
    state = AsyncValue.data(
      state.value?.where((i) => i.id != id).toList() ?? [],
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchPending);
  }

  static String _rejectionReasonToApi(RejectionReason r) => switch (r) {
        RejectionReason.inappropriateContent => 'inappropriate_content',
        RejectionReason.falseTestimony       => 'false_testimony',
        RejectionReason.hateSpeech           => 'hate_speech',
        RejectionReason.spam                 => 'spam',
        RejectionReason.other                => 'other',
      };
}

final moderationNotifierProvider =
    AsyncNotifierProvider<ModerationNotifier, List<ModerationItem>>(
  ModerationNotifier.new,
);

// ============================================================================
// Filter state notifier
// ============================================================================

enum ModerationFilterTab { pending, inReview, all }

class ModerationFilterNotifier extends Notifier<ModerationFilterTab> {
  @override
  ModerationFilterTab build() => ModerationFilterTab.pending;
  void setTab(ModerationFilterTab tab) => state = tab;
}

final moderationFilterProvider =
    NotifierProvider<ModerationFilterNotifier, ModerationFilterTab>(
  ModerationFilterNotifier.new,
);

// ============================================================================
// Items filtrés (dérivé du notifier async)
// ============================================================================

final moderationItemsProvider = Provider<List<ModerationItem>>((ref) {
  final filter = ref.watch(moderationFilterProvider);
  final items  = ref.watch(moderationNotifierProvider).value ?? const [];

  return switch (filter) {
    ModerationFilterTab.pending  => items.where((i) => i.status == ModerationStatus.pending).toList(),
    ModerationFilterTab.inReview => items.where((i) => i.status == ModerationStatus.inReview).toList(),
    ModerationFilterTab.all      => items,
  };
});

// ============================================================================
// Stats provider
// ============================================================================

final moderationStatsProvider =
    FutureProvider<ModerationStats>((ref) async {
  final api      = ref.read(apiServiceProvider);
  final response = await api.get<Map<String, dynamic>>(AppConstants.moderationStats);
  return _statsFromJson(response.data);
});

// ============================================================================
// Item par ID (lecture locale dans la liste déjà chargée)
// ============================================================================

final moderationItemByIdProvider =
    Provider.family<ModerationItem?, String>((ref, id) {
  final all = ref.watch(moderationNotifierProvider).value ?? const [];
  return all.where((i) => i.id == id).firstOrNull;
});
