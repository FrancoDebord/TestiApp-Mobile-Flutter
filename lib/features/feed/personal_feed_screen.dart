import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/api_service.dart';
import '../../shared/content/encouragements.dart';
import '../../shared/content/feed_mix.dart';
import '../../shared/widgets/encouragement_card.dart';
import '../live/data/live_repository.dart' show livesIndexProvider;
import '../community/widgets/suggested_accounts_strip.dart';
import '../live/widgets/live_now_strip.dart';
import '../repost/repost.dart';
import '../repost/repost_widgets.dart';
import '../location/location_providers.dart' show locationChangeProvider, nearbyLabelsProvider;
import '../location/nearby_widgets.dart' show NearbyCardLabel, NearbyFeedBanner;
import '../location/user_location.dart' show FeedPlace, parseNearbyLabels;
import 'feed_insert_card.dart';
import 'feed_inserts.dart';
import '../home/models/testimony_model.dart';
import '../home/providers/home_providers.dart' show testimonyFromApiJson;
import '../home/widgets/testimony_feed_item.dart';

// Mon fil, comme l'accueil mais personnalisé : tous les témoignages publiés, les comptes
// suivis d'abord (leurs témoignages et partages « X a partagé »), puis le classement
// « Pour vous » (« Suggestion pour vous » sur les comptes non suivis). GET /feed ;
// éléments insérés : GET /feed/inserts. Doc serveur : fonctionnalites/recommandations.md

class PersonalFeedEntry {
  const PersonalFeedEntry(this.testimony, {required this.suggested, this.repost});
  final Testimony testimony;

  /// Témoignage d'un compte non suivi, proposé selon ses centres d'intérêt.
  final bool suggested;

  /// Partage d'un compte suivi (l'auteur d'origine reste [testimony].author).
  final RepostInfo? repost;
}

class PersonalFeedState {
  const PersonalFeedState({
    this.items = const [],
    this.page = 1,
    this.hasMore = false,
    this.followingCount = 0,
    this.loadingMore = false,
    this.place,
  });

  final List<PersonalFeedEntry> items;
  final int page;
  final bool hasMore;
  final int followingCount;
  final bool loadingMore;

  /// Zone utilisée pour le classement (meta.place) : « Près de chez vous · Cotonou ».
  final FeedPlace? place;

  PersonalFeedState copyWith({List<PersonalFeedEntry>? items, int? page, bool? hasMore, bool? loadingMore}) =>
      PersonalFeedState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        followingCount: followingCount,
        loadingMore: loadingMore ?? this.loadingMore,
        place: place,
      );
}

class PersonalFeedNotifier extends AsyncNotifier<PersonalFeedState> {
  @override
  Future<PersonalFeedState> build() {
    // Zone modifiée (réglage de localisation) : le fil est reclassé.
    ref.watch(locationChangeProvider);
    return _fetch(1);
  }

  Future<PersonalFeedState> _fetch(int page) async {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.personalFeed, query: {'page': page});
    final list = res.data is List ? res.data as List : const [];
    final items = <PersonalFeedEntry>[
      for (final raw in list)
        if (testimonyFromApiJson(raw) case final t?)
          PersonalFeedEntry(
            t,
            suggested: raw is Map && raw['feedReason'] == 'suggested',
            repost: RepostInfo.fromFeedItem(raw),
          ),
    ];
    final meta = res.meta is Map ? Map<String, dynamic>.from(res.meta as Map) : const <String, dynamic>{};
    int n(Object? v) => v is num ? v.toInt() : 0;
    ref.read(nearbyLabelsProvider.notifier).merge(parseNearbyLabels(meta));
    return PersonalFeedState(
      items: items,
      page: n(meta['currentPage']) == 0 ? page : n(meta['currentPage']),
      hasMore: n(meta['currentPage']) < n(meta['lastPage']),
      followingCount: n(meta['followingCount']),
      place: FeedPlace.fromMeta(meta),
    );
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final next = await _fetch(s.page + 1);
      // Sans doublon : un témoignage déjà affiché (liste recalculée entre deux pages) est ignoré.
      final seen = {for (final e in s.items) e.testimony.id};
      state = AsyncData(s.copyWith(
        items: [...s.items, ...next.items.where((e) => seen.add(e.testimony.id))],
        page: next.page,
        hasMore: next.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(s.copyWith(loadingMore: false));
    }
  }
}

final personalFeedProvider =
    AsyncNotifierProvider.autoDispose<PersonalFeedNotifier, PersonalFeedState>(PersonalFeedNotifier.new);

/// Position des comptes suggérés dans Mon fil : après les premiers éléments, ou en tête
/// si l'on ne suit encore personne.
const personalFeedSuggestionsAfter = 6;

class PersonalFeedScreen extends ConsumerWidget {
  const PersonalFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personalFeedProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon fil'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref
            ..invalidate(livesIndexProvider)
            ..invalidate(feedInsertsProvider);
          return ref.refresh(personalFeedProvider.future);
        },
        child: switch (async) {
          AsyncValue(:final value?) => _list(context, ref, value),
          AsyncValue(:final error?) => ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  error is LaravelApiException ? error.message : 'Impossible de charger votre fil.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => ref.invalidate(personalFeedProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, PersonalFeedState s) {
    // Insérés entre les témoignages : comptes suivis d'abord, sources en alternance
    // (événements, sessions de prière, requêtes de prière, paroles prophétiques).
    final inserts = ref.watch(feedInsertsProvider).value?.mixed ?? const <Object>[];
    final slots = mixFeed(s.items.length, inserts: inserts.length);
    final suggestionsAt = s.followingCount == 0
        ? 0
        : (slots.length < personalFeedSuggestionsAfter ? slots.length : personalFeedSuggestionsAfter);
    // 0 : en-tête · 1 : directs en cours · puis les emplacements du fil, les comptes suggérés
    // à [suggestionsAt], et l'indicateur de chargement en dernier.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) ref.read(personalFeedProvider.notifier).loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        itemCount: slots.length + 4,
        separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 0 : 14),
        itemBuilder: (context, i) {
          // Directs en cours (masqué s'il n'y en a pas) : pleine largeur, sans marge latérale.
          if (i == 1) return const LiveNowStrip();
          if (i == 0) {
            return _padded(Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(followingCount: s.followingCount, empty: s.items.isEmpty),
                // « Près de chez vous · Cotonou » et invitation à activer la position.
                NearbyFeedBanner(place: s.place, padding: const EdgeInsets.only(top: 10)),
              ],
            ));
          }
          final p = i - 2;
          if (p == suggestionsAt) return const _SuggestedAccounts();
          final position = p > suggestionsAt ? p - 1 : p;
          if (position >= slots.length) {
            return s.loadingMore
                ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
                : const SizedBox.shrink();
          }
          return _padded(_slot(slots[position], s, inserts));
        },
      ),
    );
  }

  static Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen), child: child);

  Widget _slot(FeedSlot slot, PersonalFeedState s, List<Object> inserts) {
    switch (slot) {
      case EncouragementSlot(:final number):
        return EncouragementCard(message: encouragementOfTheDay(3 + number));
      case InsertSlot(index: final n):
        return FeedInsertCard(item: inserts[n]);
      case TestimonySlot(:final index):
        final e = s.items[index];
        if (e.repost case final r?) {
          // « X a partagé » : la carte garde l'auteur d'origine. Le partage précis de Mon fil
          // remplace celui choisi par défaut.
          return Column(
            key: ValueKey('r-${e.testimony.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepostHeader(repost: r),
              const SizedBox(height: 8),
              NearbyCardLabel(testimonyId: e.testimony.id),
              TestimonyFeedItem(testimony: e.testimony, showRepost: false),
            ],
          );
        }
        if (!e.suggested) {
          return Column(
            key: ValueKey(e.testimony.id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NearbyCardLabel(testimonyId: e.testimony.id),
              TestimonyFeedItem(testimony: e.testimony),
            ],
          );
        }
        return Column(
          key: ValueKey('s-${e.testimony.id}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SuggestionLabel(),
            const SizedBox(height: 6),
            NearbyCardLabel(testimonyId: e.testimony.id),
            TestimonyFeedItem(testimony: e.testimony),
          ],
        );
    }
  }
}

/// Comptes à suivre (GET /users/suggestions ; masqué si vide).
class _SuggestedAccounts extends StatelessWidget {
  const _SuggestedAccounts();

  @override
  Widget build(BuildContext context) => const SuggestedAccountsStrip();
}

class _Header extends StatelessWidget {
  const _Header({required this.followingCount, required this.empty});

  final int followingCount;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    if (followingCount > 0 && !empty) {
      return Text(
        'Les $followingCount compte${followingCount > 1 ? 's' : ''} que vous suivez d’abord, '
        'puis des témoignages choisis pour vous.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            followingCount == 0 ? 'Suivez des comptes' : 'Pas encore de témoignage',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            followingCount == 0
                ? 'Abonnez-vous à des églises, ministères et personnes : leurs témoignages '
                    'apparaîtront ici. En attendant, voici des témoignages choisis pour vous.'
                : 'Les comptes que vous suivez n\'ont encore rien publié.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.push('/community'),
            icon: const Icon(Icons.groups_rounded),
            label: const Text('Découvrir la communauté'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionLabel extends StatelessWidget {
  const _SuggestionLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.secondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Suggestion pour vous',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.secondaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
