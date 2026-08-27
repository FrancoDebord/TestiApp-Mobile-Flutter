import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/moderation_models.dart';

// =============================================================================
// JSON helpers
// =============================================================================

ModerationItem? _fromJson(dynamic raw) {
  try {
    final m    = raw as Map<String, dynamic>;
    final user = m['user'] as Map<String, dynamic>? ?? {};
    return ModerationItem(
      id: m['id'] as String,
      author: ModerationAuthor(
        uid:         user['id']           as String? ?? '',
        displayName: user['display_name'] as String? ?? '',
        country:     user['country']      as String? ?? '',
        avatarUrl:   user['avatar_url']   as String?,
      ),
      title:          m['title']    as String? ?? '',
      category:       _categoryLabel(m['category']),
      type:           _parseType(m['type']   as String? ?? 'text'),
      status:         _parseStatus(m['status'] as String? ?? 'pending'),
      submittedAt:    DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      contentPreview: m['body_text'] as String?,
    );
  } catch (_) {
    return null;
  }
}

String _categoryLabel(dynamic raw) {
  if (raw is String) return raw;
  if (raw is Map) return raw['name'] as String? ?? '';
  return '';
}

TestimonyType _parseType(String v) => switch (v) {
      'audio' => TestimonyType.audio,
      'video' => TestimonyType.video,
      _       => TestimonyType.text,
    };

ModerationStatus _parseStatus(String v) => switch (v) {
      'approved'  => ModerationStatus.approved,
      'rejected'  => ModerationStatus.rejected,
      'in_review' => ModerationStatus.inReview,
      _           => ModerationStatus.pending,
    };

String _reasonToString(RejectionReason r) => switch (r) {
      RejectionReason.inappropriateContent => 'inappropriate_content',
      RejectionReason.falseTestimony       => 'false_testimony',
      RejectionReason.hateSpeech           => 'hate_speech',
      RejectionReason.spam                 => 'spam',
      RejectionReason.other                => 'other',
    };

// =============================================================================
// Filter tab state
// =============================================================================

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

// =============================================================================
// Main state notifier — AsyncNotifier backed by real API
// =============================================================================

class ModerationNotifier extends AsyncNotifier<List<ModerationItem>> {
  @override
  Future<List<ModerationItem>> build() => _fetchPending();

  Future<List<ModerationItem>> _fetchPending() async {
    final api      = ref.read(apiServiceProvider);
    final response = await api.get<List<dynamic>>(AppConstants.moderationPending);
    return response.data
        .map(_fromJson)
        .whereType<ModerationItem>()
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchPending);
  }

  Future<void> approve(String id) async {
    // Optimistic update
    final current = state.value ?? [];
    state = AsyncValue.data([
      for (final item in current)
        if (item.id == id)
          item.copyWith(status: ModerationStatus.approved)
        else
          item,
    ]);
    try {
      await ref
          .read(apiServiceProvider)
          .post<void>(AppConstants.moderationApprove(id));
    } catch (_) {
      state = await AsyncValue.guard(_fetchPending);
    }
  }

  Future<void> reject(
    String id, {
    RejectionReason? reason,
    String? note,
  }) async {
    // Optimistic update
    final current = state.value ?? [];
    state = AsyncValue.data([
      for (final item in current)
        if (item.id == id)
          item.copyWith(
            status: ModerationStatus.rejected,
            rejectionReason: reason,
            moderatorNote: note,
          )
        else
          item,
    ]);
    try {
      await ref.read(apiServiceProvider).post<void>(
        AppConstants.moderationReject(id),
        data: {
          if (reason != null) 'reason': _reasonToString(reason),
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
    } catch (_) {
      state = await AsyncValue.guard(_fetchPending);
    }
  }
}

final moderationNotifierProvider =
    AsyncNotifierProvider<ModerationNotifier, List<ModerationItem>>(
  ModerationNotifier.new,
);

// =============================================================================
// Filtered list (for the moderation screen list)
// =============================================================================

final moderationItemsProvider = Provider<List<ModerationItem>>((ref) {
  final filter = ref.watch(moderationFilterProvider);
  final items  = ref.watch(moderationNotifierProvider).value ?? const [];
  return switch (filter) {
    ModerationFilterTab.pending  =>
        items.where((i) => i.status == ModerationStatus.pending).toList(),
    ModerationFilterTab.inReview =>
        items.where((i) => i.status == ModerationStatus.inReview).toList(),
    ModerationFilterTab.all      => items,
  };
});

// =============================================================================
// Reactive stats (auto-updates when state changes)
// =============================================================================

final moderationStatsProvider = Provider<ModerationStats>((ref) {
  final items = ref.watch(moderationNotifierProvider).value ?? const [];
  return ModerationStats(
    pending:        items.where((i) => i.status == ModerationStatus.pending).length,
    approvedToday:  items.where((i) => i.status == ModerationStatus.approved).length,
    rejectedToday:  items.where((i) => i.status == ModerationStatus.rejected).length,
    totalThisMonth: items.length,
  );
});

// =============================================================================
// Single item (for detail screen — reactive to state changes)
// =============================================================================

final moderationItemByIdProvider =
    Provider.family<ModerationItem?, String>((ref, id) {
  return (ref.watch(moderationNotifierProvider).value ?? const [])
      .where((i) => i.id == id)
      .firstOrNull;
});
