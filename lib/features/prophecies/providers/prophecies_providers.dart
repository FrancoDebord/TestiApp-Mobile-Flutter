import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prophecies_repository.dart';
import '../data/prophecy_reminders.dart';
import '../models/prophecy.dart';

/// Toutes les paroles de la personne (en attente d'abord). Les rappels de prière
/// sont reprogrammés sur ce téléphone à chaque chargement.
final propheciesListProvider = FutureProvider.autoDispose<List<Prophecy>>((ref) async {
  final list = await ref.watch(propheciesRepositoryProvider).list();
  await ProphecyReminders.sync(list);
  return list;
});

/// Une parole (détail).
final prophecyProvider = FutureProvider.autoDispose.family<Prophecy, String>(
  (ref, id) => ref.watch(propheciesRepositoryProvider).show(id),
);

/// Journal de prière d'une parole.
final prophecyPrayersProvider = FutureProvider.autoDispose.family<List<ProphecyPrayer>, String>(
  (ref, id) => ref.watch(propheciesRepositoryProvider).prayers(id),
);
