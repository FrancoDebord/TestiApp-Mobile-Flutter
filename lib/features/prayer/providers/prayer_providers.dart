import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prayer_models.dart';

// ── Seed data ─────────────────────────────────────────────────────────────────

final _seedRequests = <PrayerRequest>[
  PrayerRequest(
    id: 'pr1',
    authorId: 'u1',
    authorName: 'Marie Dupont',
    body: 'Priez pour ma mère qui est hospitalisée depuis 3 jours. '
        'Les médecins cherchent encore le diagnostic. Que Dieu intervienne !',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    prayerCount: 47,
    messageCount: 12,
  ),
  PrayerRequest(
    id: 'pr2',
    authorId: 'u2',
    authorName: 'Jean-Pierre Koffi',
    body: 'Besoin de prière pour trouver un emploi stable. '
        'Cela fait 6 mois que je cherche. Je crois que Dieu a un plan.',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    prayerCount: 31,
    messageCount: 8,
  ),
  PrayerRequest(
    id: 'pr3',
    authorId: 'u3',
    authorName: 'Esther Ngoula',
    body: 'Priez pour la réconciliation dans ma famille. '
        'Il y a beaucoup de conflits depuis l\'héritage. Dieu peut guérir tout ça.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    prayerCount: 89,
    messageCount: 23,
  ),
  PrayerRequest(
    id: 'pr4',
    authorId: 'u4',
    authorName: 'Samuel Tchemou',
    body: 'Je demande la prière pour mon fils qui s\'est éloigné de la foi. '
        'Que le Saint-Esprit le touche.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    prayerCount: 124,
    messageCount: 34,
  ),
];

final _seedSessions = <GroupPrayerSession>[
  GroupPrayerSession(
    id: 'gs1',
    hostId: 'u5',
    hostName: 'Pasteur Emmanuel',
    title: 'Prière du mercredi soir',
    description: 'Rejoignez-nous pour une heure de prière collective.',
    scheduledAt: DateTime.now().add(const Duration(hours: 3)),
    visibility: PrayerVisibility.public,
    participantCount: 28,
  ),
  GroupPrayerSession(
    id: 'gs2',
    hostId: 'u6',
    hostName: 'Sœur Céleste',
    title: 'Intercession pour les malades',
    description: 'Session dédiée à la prière pour la guérison.',
    scheduledAt: DateTime.now().subtract(const Duration(minutes: 10)),
    visibility: PrayerVisibility.public,
    status: PrayerSessionStatus.live,
    participantCount: 15,
  ),
];

// ── Prayer Requests notifier ──────────────────────────────────────────────────

class PrayerRequestsNotifier extends Notifier<List<PrayerRequest>> {
  @override
  List<PrayerRequest> build() => List.from(_seedRequests);

  void addRequest(PrayerRequest req) {
    state = [req, ...state];
  }

  void togglePray(String requestId, String userId) {
    state = state.map((r) {
      if (r.id != requestId) return r;
      final hasPrayed = r.userHasPrayed;
      return r.copyWith(
        userHasPrayed: !hasPrayed,
        prayerCount: hasPrayed ? r.prayerCount - 1 : r.prayerCount + 1,
      );
    }).toList();
  }

  void incrementMessages(String requestId) {
    state = state.map((r) {
      if (r.id != requestId) return r;
      return r.copyWith(messageCount: r.messageCount + 1);
    }).toList();
  }
}

final prayerRequestsProvider =
    NotifierProvider<PrayerRequestsNotifier, List<PrayerRequest>>(
  PrayerRequestsNotifier.new,
);

// ── Inspiration messages (all, keyed by requestId) ───────────────────────────

class InspirationMessagesNotifier
    extends Notifier<Map<String, List<InspirationMessage>>> {
  @override
  Map<String, List<InspirationMessage>> build() => {
        'pr1': [
          InspirationMessage(
            id: 'im1',
            requestId: 'pr1',
            authorId: 'u7',
            authorName: 'Frère Caleb',
            body: 'Je prie avec toi. "Car je suis l\'Éternel, ton médecin." '
                'Dieu guérit et Il entend ta prière.',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            bibleVerse: 'Exode 15:26',
          ),
        ],
      };

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

class GroupSessionsNotifier extends Notifier<List<GroupPrayerSession>> {
  @override
  List<GroupPrayerSession> build() => List.from(_seedSessions);

  void addSession(GroupPrayerSession session) {
    state = [session, ...state];
  }

  void updateStatus(String sessionId, PrayerSessionStatus status) {
    state = state.map((s) {
      if (s.id != sessionId) return s;
      return s.copyWith(status: status);
    }).toList();
  }
}

final groupSessionsProvider =
    NotifierProvider<GroupSessionsNotifier, List<GroupPrayerSession>>(
  GroupSessionsNotifier.new,
);
