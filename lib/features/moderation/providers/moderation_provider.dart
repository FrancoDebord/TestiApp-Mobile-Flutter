import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moderation_models.dart';

// =============================================================================
// Stub data — replace with Dio repository calls
// =============================================================================

final _stubItems = <ModerationItem>[
  ModerationItem(
    id: 'm1',
    author: const ModerationAuthor(
      uid: 'u1',
      displayName: 'Marie Dubois',
      country: 'Côte d\'Ivoire',
      avatarUrl: null,
    ),
    title: 'Comment Dieu m\'a guéri d\'une maladie incurable après des années de prières',
    category: 'Guérison',
    type: TestimonyType.text,
    status: ModerationStatus.pending,
    submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
    contentPreview:
        'Il y a trois ans, les médecins m\'ont annoncé que je souffrais d\'une maladie rare et incurable. J\'ai pleuré, j\'ai douté, mais j\'ai continué à prier...',
  ),
  ModerationItem(
    id: 'm2',
    author: const ModerationAuthor(
      uid: 'u2',
      displayName: 'Jean-Paul Koffi',
      country: 'Cameroun',
      avatarUrl: null,
    ),
    title: 'Délivrance de la dépendance à l\'alcool grâce à la prière',
    category: 'Délivrance',
    type: TestimonyType.audio,
    status: ModerationStatus.pending,
    submittedAt: DateTime.now().subtract(const Duration(hours: 5)),
    contentPreview:
        'Pendant dix ans j\'étais esclave de l\'alcool. Ma famille avait perdu espoir. Un soir lors d\'une réunion de prière...',
  ),
  ModerationItem(
    id: 'm3',
    author: const ModerationAuthor(
      uid: 'u3',
      displayName: 'Esther Nkomo',
      country: 'Congo',
      avatarUrl: null,
    ),
    title: 'Mon mariage restauré après deux ans de séparation',
    category: 'Mariage',
    type: TestimonyType.video,
    status: ModerationStatus.inReview,
    submittedAt: DateTime.now().subtract(const Duration(hours: 8)),
    contentPreview:
        'Mon mari et moi étions séparés depuis deux ans. Les avocats avaient déjà préparé les papiers du divorce...',
  ),
  ModerationItem(
    id: 'm4',
    author: const ModerationAuthor(
      uid: 'u4',
      displayName: 'Samuel Ouédraogo',
      country: 'Burkina Faso',
      avatarUrl: null,
    ),
    title: 'Dieu a pourvu à tous mes besoins financiers en un seul jour',
    category: 'Finances',
    type: TestimonyType.text,
    status: ModerationStatus.pending,
    submittedAt: DateTime.now().subtract(const Duration(hours: 12)),
    contentPreview:
        'J\'avais des dettes énormes et je ne savais pas comment nourrir mes enfants. J\'ai jeûné trois jours et prié...',
  ),
  ModerationItem(
    id: 'm5',
    author: const ModerationAuthor(
      uid: 'u5',
      displayName: 'Grace Mensah',
      country: 'Ghana',
      avatarUrl: null,
    ),
    title: 'Protection divine lors d\'un accident de voiture mortel',
    category: 'Protection divine',
    type: TestimonyType.text,
    status: ModerationStatus.inReview,
    submittedAt: DateTime.now().subtract(const Duration(days: 1)),
    contentPreview:
        'C\'était un vendredi soir. Je rentrais du travail quand soudain un camion a percuté ma voiture de plein fouet...',
  ),
];

// =============================================================================
// Filter state notifier
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
// Items provider (filtered)
// =============================================================================

final moderationItemsProvider = Provider<List<ModerationItem>>((ref) {
  final filter = ref.watch(moderationFilterProvider);
  switch (filter) {
    case ModerationFilterTab.pending:
      return _stubItems
          .where((i) => i.status == ModerationStatus.pending)
          .toList();
    case ModerationFilterTab.inReview:
      return _stubItems
          .where((i) => i.status == ModerationStatus.inReview)
          .toList();
    case ModerationFilterTab.all:
      return _stubItems;
  }
});

// =============================================================================
// Stats provider
// =============================================================================

final moderationStatsProvider = Provider<ModerationStats>((ref) {
  return const ModerationStats(
    pending: 24,
    approvedToday: 12,
    rejectedToday: 3,
    totalThisMonth: 89,
  );
});

// =============================================================================
// Single item provider
// =============================================================================

final moderationItemByIdProvider =
    Provider.family<ModerationItem?, String>((ref, id) {
  return _stubItems.where((i) => i.id == id).firstOrNull;
});
