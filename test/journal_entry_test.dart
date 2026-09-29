import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/features/journal/models/journal_entry.dart';
import 'package:testi_app/features/journal/screens/journal_screen.dart';

// Format TestimonyResource du backend.
Map<String, dynamic> _json(Map<String, dynamic> extra) => {
      'id': '01a0d43f-0000-0000-0000-00000000000a',
      'title': 'Guérison de maman',
      'type': 'text',
      'category': 'autre',
      'bodyText': '**Merci Seigneur** pour ta fidélité.',
      'mediaUrl': null,
      'coverUrl': null,
      'duration': 0,
      'visibility': 'private',
      'status': 'draft',
      'createdAt': '2026-09-26T08:30:00+00:00',
      ...extra,
    };

void main() {
  test('lit une entrée du carnet', () {
    final e = JournalEntry.fromJson(_json({}));
    expect(e.title, 'Guérison de maman');
    expect(e.type, JournalEntryType.text);
    expect(e.isPrivate, isTrue);
    expect(e.isPendingReview, isFalse);
    expect(e.body, contains('Merci Seigneur'));
    expect(e.createdAt, isNotNull);
  });

  test('entrée partagée : en attente de validation', () {
    final e = JournalEntry.fromJson(_json({'visibility': 'public', 'status': 'pending'}));
    expect(e.isPrivate, isFalse);
    expect(e.isPendingReview, isTrue);
  });

  test('média : URL absolue conservée, titre vide remplacé', () {
    final e = JournalEntry.fromJson(_json({
      'type': 'audio',
      'title': '  ',
      'mediaUrl': 'https://testi.airid-africa.com/storage/media/audios/a.m4a',
      'duration': 95,
    }));
    expect(e.type, JournalEntryType.audio);
    expect(e.title, 'Sans titre');
    expect(e.mediaUrl, 'https://testi.airid-africa.com/storage/media/audios/a.m4a');
    expect(e.durationSeconds, 95);
  });

  test('libellés de date en français', () {
    final d = DateTime(2026, 9, 26);
    expect(journalMonthLabel(d), 'Septembre 2026');
    expect(journalDayLabel(d), '26 septembre 2026');
  });
}
