// Paroles prophétiques du carnet privé (API Laravel ProphecyResource).
// Doc serveur : docs/fonctionnalites/paroles-prophetiques.md

DateTime? _day(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

DateTime? _instant(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

String? _str(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Heure « HH:MM » (l'API peut renvoyer « HH:MM:SS ») ; null si absente ou invalide.
String? parseClockTime(Object? v) {
  final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)').firstMatch(v?.toString().trim() ?? '');
  return m == null ? null : '${m.group(1)}:${m.group(2)}';
}

/// Heure actuelle « HH:MM ».
String clockNow() {
  final n = DateTime.now();
  return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
}

/// Date seule au format de l'API (AAAA-MM-JJ).
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

enum ReminderFrequency {
  daily('daily', 'Chaque jour'),
  weekly('weekly', 'Chaque semaine');

  const ReminderFrequency(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ReminderFrequency? parse(Object? raw) => switch (raw) {
        'daily' => ReminderFrequency.daily,
        'weekly' => ReminderFrequency.weekly,
        _ => null,
      };
}

/// Rappel de prière, programmé sur le téléphone (heure locale).
class ProphecyReminder {
  const ProphecyReminder({required this.frequency, required this.hour, required this.minute, this.weekday});

  static ProphecyReminder? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final f = ReminderFrequency.parse(raw['frequency']);
    final t = '${raw['time'] ?? ''}'.split(':');
    if (f == null || t.length != 2) return null;
    return ProphecyReminder(
      frequency: f,
      hour: int.tryParse(t[0]) ?? 7,
      minute: int.tryParse(t[1]) ?? 0,
      weekday: raw['weekday'] == null ? null : _int(raw['weekday']),
    );
  }

  final ReminderFrequency frequency;
  final int hour;
  final int minute;

  /// 1 = lundi … 7 = dimanche (hebdomadaire).
  final int? weekday;

  String get time => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static const weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

  String get label => frequency == ReminderFrequency.daily
      ? 'Chaque jour à $time'
      : 'Chaque ${weekdays[((weekday ?? 1) - 1).clamp(0, 6)]} à $time';
}

class ProphecyPrayer {
  const ProphecyPrayer({required this.id, required this.prayedAt, this.note});

  factory ProphecyPrayer.fromJson(Map<String, dynamic> m) => ProphecyPrayer(
        id: _int(m['id']),
        note: _str(m['note']),
        prayedAt: _instant(m['prayedAt']) ?? DateTime.now(),
      );

  final int id;
  final String? note;
  final DateTime prayedAt;
}

class Prophecy {
  const Prophecy({
    required this.id,
    required this.receivedOn,
    this.receivedTime,
    this.title,
    this.bodyText,
    this.audioUrl,
    this.audioDuration = 0,
    this.givenBy,
    this.dueOn,
    this.fulfilled = false,
    this.fulfilledOn,
    this.testimonyId,
    this.isPublic = false,
    this.reminder,
    this.prayerCount = 0,
    this.lastPrayedAt,
  });

  factory Prophecy.fromJson(Map<String, dynamic> m) => Prophecy(
        id: '${m['id']}',
        title: _str(m['title']),
        receivedOn: _day(m['receivedOn']) ?? DateTime.now(),
        receivedTime: parseClockTime(m['receivedTime']),
        bodyText: _str(m['bodyText']),
        audioUrl: _str(m['audioUrl']),
        audioDuration: _int(m['audioDuration']),
        givenBy: _str(m['givenBy']),
        dueOn: _day(m['dueOn']),
        fulfilled: m['status'] == 'fulfilled',
        fulfilledOn: _day(m['fulfilledOn']),
        testimonyId: _str(m['testimonyId']),
        isPublic: m['isPublic'] == true,
        reminder: ProphecyReminder.fromJson(m['reminder']),
        prayerCount: _int(m['prayerCount']),
        lastPrayedAt: _instant(m['lastPrayedAt']),
      );

  final String id;
  final String? title;
  final DateTime receivedOn;

  /// Heure à laquelle la parole a été reçue (« HH:MM »), si elle a été notée.
  final String? receivedTime;
  final String? bodyText;
  final String? audioUrl;
  final int audioDuration;
  final String? givenBy;
  final DateTime? dueOn;
  final bool fulfilled;
  final DateTime? fulfilledOn;
  final String? testimonyId;
  final bool isPublic;
  final ProphecyReminder? reminder;
  final int prayerCount;
  final DateTime? lastPrayedAt;

  bool get hasAudio => audioUrl != null;

  /// Titre affiché : le titre, sinon le début du texte, sinon « Parole du … ».
  String displayTitle(String Function(DateTime) day) {
    if (title != null) return title!;
    final t = bodyText?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t != null && t.isNotEmpty) return t.length > 60 ? '${t.substring(0, 60)}…' : t;
    return 'Parole du ${day(receivedOn)}';
  }

  /// Échéance dépassée et pas encore accomplie.
  bool get isOverdue {
    final d = dueOn;
    if (d == null || fulfilled) return false;
    final today = DateTime.now();
    return d.isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// Données du formulaire.
class ProphecyDraft {
  ProphecyDraft({
    DateTime? receivedOn,
    String? receivedTime,
    this.title = '',
    this.bodyText = '',
    this.givenBy = '',
    this.dueOn,
    this.audioUrl,
    this.audioDuration = 0,
    this.localAudioPath,
    this.reminder,
  })  : receivedOn = receivedOn ?? DateTime.now(),
        // Nouvelle parole : l'heure actuelle par défaut.
        receivedTime = receivedTime ?? (receivedOn == null ? clockNow() : null);

  factory ProphecyDraft.fromProphecy(Prophecy p) => ProphecyDraft(
        receivedOn: p.receivedOn,
        receivedTime: p.receivedTime,
        title: p.title ?? '',
        bodyText: p.bodyText ?? '',
        givenBy: p.givenBy ?? '',
        dueOn: p.dueOn,
        audioUrl: p.audioUrl,
        audioDuration: p.audioDuration,
        reminder: p.reminder,
      );

  DateTime receivedOn;

  /// Heure de réception « HH:MM » (facultative).
  String? receivedTime;
  String title;
  String bodyText;
  String givenBy;
  DateTime? dueOn;
  String? audioUrl;
  int audioDuration;

  /// Enregistrement pas encore envoyé (envoyé à l'enregistrement de la parole).
  String? localAudioPath;
  ProphecyReminder? reminder;

  String? _clean(String s) => s.trim().isEmpty ? null : s.trim();

  Map<String, dynamic> toJson() => {
        'received_on': apiDate(receivedOn),
        'received_time': receivedTime,
        'title': _clean(title),
        'body_text': _clean(bodyText),
        'given_by': _clean(givenBy),
        'due_on': dueOn == null ? null : apiDate(dueOn!),
        'audio_url': audioUrl,
        'audio_duration': audioDuration,
        'reminder_frequency': reminder?.frequency.apiValue,
        'reminder_time': reminder?.time,
        'reminder_weekday': reminder?.frequency == ReminderFrequency.weekly ? reminder?.weekday : null,
      };
}
