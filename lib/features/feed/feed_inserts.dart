import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../services/api_service.dart';
import '../../shared/content/feed_mix.dart';
import '../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../events/models/event_models.dart';
import '../prayer/models/prayer_models.dart';
import '../prophecies/models/public_prophecy.dart';

// Éléments insérés dans « Mon fil » : GET /feed/inserts — événements à venir, en cours et passés, sessions de
// prière programmées, requêtes de prière et paroles prophétiques publiques, ceux des comptes
// suivis d'abord. Doc serveur : fonctionnalites/recommandations.md

/// Un groupe (comptes suivis ou autres comptes), une liste par source.
class FeedInsertGroup {
  const FeedInsertGroup({
    this.events = const [],
    this.prayerSessions = const [],
    this.prayerRequests = const [],
    this.prophecies = const [],
    this.pastEvents = const [],
  });

  /// À venir et en cours.
  final List<ChristianEvent> events;

  /// Terminés récemment : revivre l'événement (témoignages, commentaires).
  final List<ChristianEvent> pastEvents;
  final List<PrayerSession> prayerSessions;
  final List<PrayerRequest> prayerRequests;
  final List<PublicProphecy> prophecies;

  /// Sources dans l'ordre d'alternance (même ordre que le site).
  List<List<Object>> get sources => [events, prayerSessions, prayerRequests, prophecies, pastEvents];

  static List<T> _list<T>(Object? raw, T? Function(Map<String, dynamic>) parse) => [
        if (raw is List)
          for (final e in raw)
            if (e is Map)
              if (_safe(() => parse(Map<String, dynamic>.from(e))) case final T v) v,
      ];

  static T? _safe<T>(T? Function() f) {
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

  factory FeedInsertGroup.fromJson(Object? raw) {
    final m = raw is Map ? raw : const {};
    return FeedInsertGroup(
      events: _list(m['events'], ChristianEvent.fromJson),
      prayerSessions: _list(m['prayerSessions'], PrayerSession.fromJson),
      prayerRequests: _list(m['prayerRequests'], PrayerRequest.fromJson),
      prophecies: _list(m['prophecies'], PublicProphecy.tryParse),
      pastEvents: _list(m['pastEvents'], ChristianEvent.fromJson),
    );
  }
}

class FeedInserts {
  const FeedInserts({this.following = const FeedInsertGroup(), this.others = const FeedInsertGroup()});

  final FeedInsertGroup following;
  final FeedInsertGroup others;

  /// Ordre d'insertion : comptes suivis d'abord, sources en alternance ([mixInserts]).
  List<Object> get mixed => mixInserts<Object>(following.sources, others.sources);

  factory FeedInserts.fromJson(Object? raw) {
    final m = raw is Map ? raw : const {};
    return FeedInserts(
      following: FeedInsertGroup.fromJson(m['following']),
      others: FeedInsertGroup.fromJson(m['others']),
    );
  }
}

/// Éléments insérés de « Mon fil » (vide pour un invité ou en cas d'erreur réseau).
final feedInsertsProvider = FutureProvider.autoDispose<FeedInserts>((ref) async {
  if (ref.watch(currentUserProvider) == null) return const FeedInserts();
  try {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.personalFeedInserts);
    return FeedInserts.fromJson(res.data);
  } catch (_) {
    return const FeedInserts();
  }
});
