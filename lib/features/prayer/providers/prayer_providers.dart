import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../services/api_service.dart';
import '../models/prayer_models.dart';

// ── Prayer Requests notifier ──────────────────────────────────────────────────

class PrayerRequestsNotifier
    extends AsyncNotifier<List<PrayerRequest>> {
  @override
  Future<List<PrayerRequest>> build() => _fetch();

  Future<List<PrayerRequest>> _fetch() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response =
          await api.get<dynamic>(AppConstants.prayerRequests);
      final raw = response.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : []);
      return list
          .map((e) => PrayerRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  // Optimistic: prepend locally then sync
  Future<void> addRequest(PrayerRequest req) async {
    final prev = state.asData?.value ?? [];
    state = AsyncData([req, ...prev]);
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(
        AppConstants.prayerRequests,
        data: {
          'body': req.body,
          'visibility': req.visibility.name,
        },
      );
    } catch (_) {
      await refresh();
    }
  }

  void togglePray(String requestId, String userId) {
    final prev = state.asData?.value;
    if (prev == null) return;
    state = AsyncData(prev.map((r) {
      if (r.id != requestId) return r;
      final hasPrayed = r.userHasPrayed;
      return r.copyWith(
        userHasPrayed: !hasPrayed,
        prayerCount: hasPrayed ? r.prayerCount - 1 : r.prayerCount + 1,
      );
    }).toList());
    ref.read(apiServiceProvider).post<void>(
      AppConstants.prayerRequestPray(requestId),
    );
  }

  void incrementMessages(String requestId) {
    final prev = state.asData?.value;
    if (prev == null) return;
    state = AsyncData(prev.map((r) {
      if (r.id != requestId) return r;
      return r.copyWith(messageCount: r.messageCount + 1);
    }).toList());
  }
}

final prayerRequestsProvider =
    AsyncNotifierProvider<PrayerRequestsNotifier, List<PrayerRequest>>(
  PrayerRequestsNotifier.new,
);

// ── Inspiration messages (all, keyed by requestId) ───────────────────────────

class InspirationMessagesNotifier
    extends Notifier<Map<String, List<InspirationMessage>>> {
  @override
  Map<String, List<InspirationMessage>> build() => {};

  List<InspirationMessage> forRequest(String requestId) =>
      state[requestId] ?? [];

  void addMessage(InspirationMessage msg) {
    final current = List<InspirationMessage>.from(state[msg.requestId] ?? []);
    current.add(msg);
    state = {...state, msg.requestId: current};
  }
}

final inspirationMessagesProvider = NotifierProvider<
    InspirationMessagesNotifier, Map<String, List<InspirationMessage>>>(
  InspirationMessagesNotifier.new,
);

// ── Group Prayer Sessions notifier ────────────────────────────────────────────

class GroupSessionsNotifier
    extends AsyncNotifier<List<GroupPrayerSession>> {
  @override
  Future<List<GroupPrayerSession>> build() => _fetch();

  Future<List<GroupPrayerSession>> _fetch() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response =
          await api.get<dynamic>(AppConstants.prayerSessions);
      final raw = response.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : []);
      return list
          .map((e) => GroupPrayerSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> addSession(GroupPrayerSession session) async {
    final prev = state.asData?.value ?? [];
    state = AsyncData([session, ...prev]);
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(
        AppConstants.prayerSessions,
        data: {
          'title': session.title,
          'description': session.description,
          'scheduled_at': session.scheduledAt.toIso8601String(),
          'visibility': session.visibility.name,
        },
      );
    } catch (_) {
      await refresh();
    }
  }

  void updateStatus(String sessionId, PrayerSessionStatus status) {
    final prev = state.asData?.value;
    if (prev == null) return;
    state = AsyncData(prev.map((s) {
      if (s.id != sessionId) return s;
      return s.copyWith(status: status);
    }).toList());
  }
}

final groupSessionsProvider =
    AsyncNotifierProvider<GroupSessionsNotifier, List<GroupPrayerSession>>(
  GroupSessionsNotifier.new,
);
