// Composition d'un fil : témoignages, messages « Témoigner » (encouragements) et
// éléments insérés (événements, requêtes de prière…). Même règle sur le site :
// resources/views/videos/partials/cards.blade.php du serveur.

import 'encouragements.dart' show encouragementEvery;

/// Un emplacement du fil.
sealed class FeedSlot {
  const FeedSlot();
}

/// Le témoignage n° [index] de la liste.
final class TestimonySlot extends FeedSlot {
  const TestimonySlot(this.index);
  final int index;

  @override
  bool operator ==(Object other) => other is TestimonySlot && other.index == index;
  @override
  int get hashCode => index.hashCode;
  @override
  String toString() => 'T$index';
}

/// Le message d'encouragement n° [number] (0, 1, 2…).
final class EncouragementSlot extends FeedSlot {
  const EncouragementSlot(this.number);
  final int number;

  @override
  bool operator ==(Object other) => other is EncouragementSlot && other.number == number;
  @override
  int get hashCode => number.hashCode + 7919;
  @override
  String toString() => 'E$number';
}

/// L'élément inséré n° [index] (événement, requête de prière…).
final class InsertSlot extends FeedSlot {
  const InsertSlot(this.index);
  final int index;

  @override
  bool operator ==(Object other) => other is InsertSlot && other.index == index;
  @override
  int get hashCode => index.hashCode + 104729;
  @override
  String toString() => 'I$index';
}

/// Premier élément inséré après ce nombre de témoignages, puis tous les [feedInsertEvery].
const feedInsertFirst = 3;
const feedInsertEvery = 6;

/// Emplacements d'un fil de [testimonies] témoignages avec [inserts] éléments insérés :
/// un message d'encouragement tous les [encouragementEvery] témoignages (si [encourage]),
/// un élément inséré après le 3e témoignage puis tous les 6. Avec moins de 3 témoignages,
/// les éléments insérés suivent la liste (un fil vide en montre donc quand même).
/// Les éléments en trop attendent les pages suivantes.
List<FeedSlot> mixFeed(int testimonies, {int inserts = 0, bool encourage = true}) {
  final slots = <FeedSlot>[];
  var nextInsert = 0;
  for (var i = 0; i < testimonies; i++) {
    slots.add(TestimonySlot(i));
    final shown = i + 1;
    if (nextInsert < inserts && shown >= feedInsertFirst && (shown - feedInsertFirst) % feedInsertEvery == 0) {
      slots.add(InsertSlot(nextInsert++));
    }
    if (encourage && shown >= encouragementEvery && shown % encouragementEvery == 0) {
      slots.add(EncouragementSlot(shown ~/ encouragementEvery - 1));
    }
  }
  if (testimonies < feedInsertFirst) {
    while (nextInsert < inserts) {
      slots.add(InsertSlot(nextInsert++));
    }
  }
  return slots;
}

/// Alterne plusieurs listes : a0, b0, a1, b1, … (les plus longues continuent seules).
List<T> interleave<T>(List<List<T>> lists) {
  final out = <T>[];
  final longest = lists.fold(0, (n, l) => l.length > n ? l.length : n);
  for (var i = 0; i < longest; i++) {
    for (final l in lists) {
      if (i < l.length) out.add(l[i]);
    }
  }
  return out;
}

/// Éléments insérés de « Mon fil » : ceux des comptes suivis d'abord, puis ceux des autres
/// comptes ; dans chaque groupe, les sources alternent ([interleave]). Même ordre sur le site
/// (App\Services\FeedInserts::mixed).
List<T> mixInserts<T>(List<List<T>> following, List<List<T>> others) =>
    [...interleave(following), ...interleave(others)];
