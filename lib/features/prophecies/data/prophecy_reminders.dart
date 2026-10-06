import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../services/fcm_service.dart' show localNotificationsPlugin;
import '../models/prophecy.dart';

/// Rappels de prière des paroles prophétiques : notifications locales répétées
/// (chaque jour ou chaque semaine à l'heure choisie), programmées sur ce téléphone.
/// Le réglage est enregistré sur le serveur ; chaque appareil le reprogramme à
/// l'ouverture des paroles ([sync]) et dès qu'une parole change ailleurs (site,
/// autre téléphone) grâce au message silencieux du serveur ([handlePush]).
/// Aucun rappel pour une parole accomplie.
abstract final class ProphecyReminders {
  static const _channelId = 'prophecy_reminders';
  static const _channelName = 'Rappels de prière';
  static bool _tzReady = false;
  static bool _pluginReady = false;

  /// Type du message silencieux du serveur (Laravel SyncProphecyReminderJob).
  static const pushType = 'prophecy_sync';

  /// Parole reconstruite depuis un message silencieux, avec juste ce qu'il faut
  /// pour le rappel ; null si elle a été supprimée (rappel à annuler).
  static Prophecy? fromPush(Map<String, dynamic> data) {
    final id = data['prophecy_id']?.toString() ?? '';
    if (id.isEmpty || data['deleted']?.toString() == 'true') return null;
    final title = data['display_title']?.toString().trim() ?? '';
    return Prophecy(
      id: id,
      receivedOn: DateTime.now(),
      title: title.isEmpty ? null : title,
      fulfilled: data['status'] == 'fulfilled',
      reminder: ProphecyReminder.fromJson({
        'frequency': data['reminder_frequency'],
        'time': data['reminder_time'],
        'weekday': data['reminder_weekday'],
      }),
    );
  }

  /// Traite un message silencieux du serveur : reprogramme ou annule le rappel
  /// de la parole. Renvoie false si le message n'est pas de ce type.
  /// [background] : appel depuis le gestionnaire FCM en arrière-plan (isolat
  /// séparé, où le module de notifications n'est pas encore initialisé).
  static Future<bool> handlePush(Map<String, dynamic> data, {bool background = false}) async {
    if (data['type'] != pushType) return false;
    final id = data['prophecy_id']?.toString() ?? '';
    if (id.isEmpty) return true;
    if (background) await _initPlugin();
    final p = fromPush(data);
    if (p == null) {
      await cancel(id);
    } else {
      await apply(p);
    }
    return true;
  }

  static Future<void> _initPlugin() async {
    if (_pluginReady || !_supported) return;
    try {
      await localNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _pluginReady = true;
    } catch (e) {
      debugPrint('[Prophecy] notifications non initialisées : $e');
    }
  }

  /// Identifiant de notification stable pour une parole.
  static int notificationId(String prophecyId) => 700000 + (prophecyId.hashCode & 0x3FFFF);

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Prochaine échéance (heure locale) d'un rappel, à partir de [now].
  static DateTime nextOccurrence(ProphecyReminder r, DateTime now) {
    var at = DateTime(now.year, now.month, now.day, r.hour, r.minute);
    if (r.frequency == ReminderFrequency.weekly) {
      final wd = r.weekday ?? 1;
      at = at.add(Duration(days: (wd - at.weekday + 7) % 7));
      if (!at.isAfter(now)) at = at.add(const Duration(days: 7));
    } else if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  /// Programme (ou annule) les rappels de toutes les paroles.
  static Future<void> sync(List<Prophecy> prophecies) async {
    for (final p in prophecies) {
      await apply(p);
    }
  }

  /// Programme le rappel de [p], ou l'annule (pas de rappel, ou parole accomplie).
  static Future<void> apply(Prophecy p) async {
    if (!_supported) return;
    final id = notificationId(p.id);
    try {
      await localNotificationsPlugin.cancel(id);
      final r = p.reminder;
      if (r == null || p.fulfilled) return;
      if (!_tzReady) {
        tzdata.initializeTimeZones();
        _tzReady = true;
      }
      // Heure du téléphone convertie en UTC : la répétition garde la même heure locale
      // (hors changement d'heure d'été).
      final next = nextOccurrence(r, DateTime.now()).toUtc();
      await localNotificationsPlugin.zonedSchedule(
        id,
        'Temps de prière',
        'Priez pour la parole : « ${p.displayTitle((d) => '${d.day}/${d.month}/${d.year}')} »',
        tz.TZDateTime.from(next, tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Rappels pour prier sur vos paroles prophétiques.',
            importance: Importance.defaultImportance,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: r.frequency == ReminderFrequency.daily
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime,
        payload: jsonEncode({'type': 'prophecy_reminder', 'prophecy_id': p.id}),
      );
    } catch (e) {
      debugPrint('[Prophecy] rappel non programmé : $e');
    }
  }

  static Future<void> cancel(String prophecyId) async {
    if (!_supported) return;
    try {
      await localNotificationsPlugin.cancel(notificationId(prophecyId));
    } catch (_) {}
  }
}
