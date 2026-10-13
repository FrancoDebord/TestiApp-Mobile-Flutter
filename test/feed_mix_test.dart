import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/shared/content/feed_mix.dart';

void main() {
  String mix(int t, {int inserts = 0, bool encourage = true}) =>
      mixFeed(t, inserts: inserts, encourage: encourage).join(' ');

  test('sans insertion : un encouragement tous les 8 témoignages', () {
    expect(mix(3), 'T0 T1 T2');
    expect(mix(9), 'T0 T1 T2 T3 T4 T5 T6 T7 E0 T8');
    expect(mix(16).split(' ').where((s) => s.startsWith('E')), ['E0', 'E1']);
  });

  test('insertions après le 3e témoignage puis tous les 6', () {
    expect(mix(10, inserts: 5, encourage: false), 'T0 T1 T2 I0 T3 T4 T5 T6 T7 T8 I1 T9');
    // Insertions et encouragements ne se touchent pas.
    expect(mix(16, inserts: 5), 'T0 T1 T2 I0 T3 T4 T5 T6 T7 E0 T8 I1 T9 T10 T11 T12 T13 T14 I2 T15 E1');
  });

  test('les insertions en trop attendent la suite du fil', () {
    expect(mix(4, inserts: 3, encourage: false), 'T0 T1 T2 I0 T3');
  });

  test('fil court ou vide : les insertions suivent la liste', () {
    expect(mix(0, inserts: 2), 'I0 I1');
    expect(mix(2, inserts: 2), 'T0 T1 I0 I1');
  });

  test('chaque témoignage apparaît une fois, dans l’ordre', () {
    final slots = mixFeed(57, inserts: 20);
    final t = slots.whereType<TestimonySlot>().map((s) => s.index).toList();
    expect(t, List.generate(57, (i) => i));
    final ins = slots.whereType<InsertSlot>().map((s) => s.index).toList();
    expect(ins, List.generate(ins.length, (i) => i));
  });

  test('interleave alterne les sources', () {
    expect(interleave([
      ['e1', 'e2', 'e3'],
      ['p1'],
    ]), ['e1', 'p1', 'e2', 'e3']);
    expect(interleave<String>([]), isEmpty);
  });

  test('mixInserts : comptes suivis d’abord, sources en alternance', () {
    expect(
      mixInserts([
        ['eS'],
        ['sS1', 'sS2'],
        <String>[],
        ['pS'],
      ], [
        ['eA'],
        <String>[],
        ['rA'],
        ['pA'],
      ]),
      ['eS', 'sS1', 'pS', 'sS2', 'eA', 'rA', 'pA'],
    );
  });
}
