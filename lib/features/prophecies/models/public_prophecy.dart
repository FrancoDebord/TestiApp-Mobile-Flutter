// Parole prophétique rendue publique avec son témoignage d'accomplissement
// (insérée dans « Mon fil » : GET /feed/inserts → prophecies). Doc serveur :
// fonctionnalites/paroles-prophetiques.md et recommandations.md

import 'prophecy.dart' show parseClockTime;
import '../../../l10n/app_localizations.dart';

class PublicProphecy {
  const PublicProphecy({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.testimonyId,
    required this.testimonyTitle,
    this.authorAvatarUrl,
    this.title,
    this.bodyText,
    this.audioUrl,
    this.givenBy,
    this.receivedOn,
    this.receivedTime,
    this.fulfilledOn,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String testimonyId;
  final String testimonyTitle;
  final String? title;
  final String? bodyText;
  final String? audioUrl;
  final String? givenBy;
  final DateTime? receivedOn;

  /// Heure de réception « HH:MM », si l'auteur l'a notée.
  final String? receivedTime;
  final DateTime? fulfilledOn;

  static String? _s(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
  static DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

  /// Null si le témoignage d'accomplissement manque.
  static PublicProphecy? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final user = m['user'] is Map ? Map<String, dynamic>.from(m['user'] as Map) : const <String, dynamic>{};
    final t = m['testimony'] is Map ? Map<String, dynamic>.from(m['testimony'] as Map) : null;
    final id = _s(m['id']);
    final testimonyId = _s(t?['id']);
    if (id == null || testimonyId == null) return null;
    return PublicProphecy(
      id: id,
      authorId: user['id']?.toString() ?? '',
      authorName: _s(user['displayName'] ?? user['display_name']) ?? L10n.current.commonAnonymous,
      authorAvatarUrl: _s(user['avatarUrl'] ?? user['avatar_url']),
      testimonyId: testimonyId,
      testimonyTitle: _s(t?['title']) ?? L10n.current.modTestimony,
      title: _s(m['title']),
      bodyText: _s(m['bodyText']),
      audioUrl: _s(m['audioUrl']),
      givenBy: _s(m['givenBy']),
      receivedOn: _d(m['receivedOn']),
      receivedTime: parseClockTime(m['receivedTime']),
      fulfilledOn: _d(m['fulfilledOn']),
    );
  }
}
