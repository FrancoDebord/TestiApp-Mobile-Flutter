// Témoignages de conversion : le mien, celui d'un compte, la section paginée.
// Backend : docs/fonctionnalites/temoignage-de-conversion.md

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../home/models/testimony_model.dart';
import '../data/conversion_repository.dart';

/// Mon témoignage de conversion (tous statuts) ; null pour un visiteur.
final myConversionProvider = FutureProvider.autoDispose<MyConversion?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(conversionRepositoryProvider).mine(isOrganization: user.isOrganization);
});

/// Témoignage de conversion publié d'un compte (null s'il n'en a pas).
final userConversionProvider =
    FutureProvider.autoDispose.family<Testimony?, String>((ref, userId) async {
  return ref.watch(conversionRepositoryProvider).ofUser(userId);
});

/// Derniers témoignages de conversion publiés (bloc de l'accueil, 3 au plus).
final latestConversionsProvider = FutureProvider.autoDispose<List<Testimony>>((ref) async {
  final page = await ref.watch(conversionRepositoryProvider).list(limit: 3);
  return page.items.take(3).toList();
});

/// Section « Témoignages de conversion » (pagination).
class ConversionListState {
  const ConversionListState({this.items = const [], this.hasMore = false, this.loadingMore = false});

  final List<Testimony> items;
  final bool hasMore;
  final bool loadingMore;

  ConversionListState copyWith({List<Testimony>? items, bool? hasMore, bool? loadingMore}) =>
      ConversionListState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class ConversionListNotifier extends AsyncNotifier<ConversionListState> {
  int _page = 1;

  ConversionRepository get _repo => ref.read(conversionRepositoryProvider);

  @override
  Future<ConversionListState> build() async {
    _page = 1;
    final p = await _repo.list();
    return ConversionListState(items: p.items, hasMore: p.hasMore);
  }

  Future<void> refreshAll() async {
    _page = 1;
    final p = await _repo.list();
    state = AsyncData(ConversionListState(items: p.items, hasMore: p.hasMore));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final p = await _repo.list(page: _page + 1);
      _page = p.page;
      final seen = {for (final t in current.items) t.id};
      state = AsyncData(ConversionListState(
        items: [...current.items, ...p.items.where((t) => !seen.contains(t.id))],
        hasMore: p.hasMore,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

final conversionListProvider =
    AsyncNotifierProvider.autoDispose<ConversionListNotifier, ConversionListState>(
        ConversionListNotifier.new);
