// Lien de partage du verset du jour (docs serveur verset-du-jour.md, « Lien de partage »).

import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/app_constants.dart';
import 'package:testi_app/features/daily_verse/screens/daily_verse_screen.dart';
import 'package:testi_app/features/home/models/testimony_model.dart';

void main() {
  test('shareUrl du serveur lu et partagé tel quel', () {
    final v = DailyVerse.fromJson({
      'id': 12,
      'text': 'Car Dieu a tant aimé le monde',
      'reference': 'Jean 3:16',
      'shareUrl': 'https://temoignage.as-krea.com/verset-du-jour/2026-10-27',
    });
    expect(v.shareUrl, 'https://temoignage.as-krea.com/verset-du-jour/2026-10-27');
    expect(v.copyWith(isLiked: true).shareUrl, v.shareUrl);
    expect(dailyVerseShareLink(v), v.shareUrl);
  });

  test('sans shareUrl (cache ancien, hors ligne) : page datée du site', () {
    const v = DailyVerse(text: 't', reference: 'r');
    expect(dailyVerseShareLink(v, date: DateTime(2026, 10, 3)),
        '${AppConstants.webBaseUrl}/verset-du-jour/2026-10-03');
    // Jour du verset à Porto-Novo (UTC+1) : 23 h 30 UTC le 27 → le 28.
    expect(dailyVerseShareLink(null, now: DateTime.utc(2026, 10, 27, 23, 30)),
        '${AppConstants.webBaseUrl}/verset-du-jour/2026-10-28');
  });
}
