// Types (catégories) d'événements gérés par les administrateurs.
// Backend : docs/fonctionnalites/types-evenements.md
//   GET    /event-types[?all=1]                → [{ id, slug, name, nameFr, nameEn, icon, position, isActive, eventsCount }]
//   POST   /admin/event-types                  { name_fr, name_en?, icon?, is_active? }
//   PUT    /admin/event-types/{id}             { name_fr?, name_en?, icon?, is_active?, position? }
//   DELETE /admin/event-types/{id}?replace_with=slug   (409 si des événements l'utilisent)
//   PUT    /admin/event-types/reorder          { ids: [...] }

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../models/event_models.dart';

/// Refus du serveur ; [eventsCount] > 0 (409) : des événements utilisent encore ce type.
class EventTypeFailure implements Exception {
  const EventTypeFailure(this.message, {this.eventsCount = 0});
  final String message;
  final int eventsCount;

  @override
  String toString() => message;
}

List<EventType> _parseList(Object? data) => [
      for (final m in (data is List ? data : const []))
        if (m is Map) EventType.fromJson(Map<String, dynamic>.from(m)),
    ];

/// Types proposés partout dans l'application (formulaire, filtres, badges).
/// Hors ligne / serveur plus ancien : les types d'origine.
final eventTypesProvider = FutureProvider<List<EventType>>((ref) async {
  try {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.eventTypes);
    final list = _parseList(res.data);
    EventType.register(list);
    return EventType.values;
  } catch (_) {
    return EventType.values;
  }
});

class AdminEventTypesNotifier extends AsyncNotifier<List<EventType>> {
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  Future<List<EventType>> build() async {
    final res = await _api.get<dynamic>(AppConstants.eventTypes, query: {'all': 1});
    return _parseList(res.data)..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      final r = await call();
      ref.invalidate(eventTypesProvider);
      return r;
    } on LaravelApiException catch (e) {
      // 409 : des événements utilisent encore ce type (choisir un remplaçant).
      throw EventTypeFailure(e.message, eventsCount: e.statusCode == 409 ? 1 : 0);
    } catch (e) {
      if (e is EventTypeFailure) rethrow;
      throw EventTypeFailure(L10n.current.adminSettingsSaveFailed);
    }
  }

  Future<void> create({required String nameFr, String? nameEn, required String icon}) => _guard(() async {
        await _api.post<dynamic>(AppConstants.adminEventTypes, data: {
          'name_fr': nameFr.trim(),
          if ((nameEn ?? '').trim().isNotEmpty) 'name_en': nameEn!.trim(),
          'icon': icon,
        });
        ref.invalidateSelf();
      });

  Future<void> edit(EventType t, {String? nameFr, String? nameEn, String? icon, bool? isActive}) => _guard(() async {
        await _api.put<dynamic>(AppConstants.adminEventType(t.id!), data: {
          'name_fr': ?nameFr?.trim(),
          if (nameEn != null) 'name_en': nameEn.trim().isEmpty ? null : nameEn.trim(),
          'icon': ?icon,
          'is_active': ?isActive,
        });
        ref.invalidateSelf();
      });

  /// Supprime le type ; [replaceWith] : type qui reprend ses événements.
  Future<void> delete(EventType t, {String? replaceWith}) => _guard(() async {
        await _api.delete<dynamic>(AppConstants.adminEventType(t.id!),
            query: {'replace_with': ?replaceWith});
        ref.invalidateSelf();
      });

  Future<void> reorder(List<EventType> ordered) async {
    state = AsyncData(ordered);
    await _guard(() async {
      await _api.put<dynamic>(AppConstants.adminEventTypesReorder,
          data: {'ids': [for (final t in ordered) t.id]});
    });
  }
}

final adminEventTypesProvider =
    AsyncNotifierProvider.autoDispose<AdminEventTypesNotifier, List<EventType>>(AdminEventTypesNotifier.new);
