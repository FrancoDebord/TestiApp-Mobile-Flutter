// Paramètres globaux décrits par le serveur (mêmes groupes, libellés et ordre que
// la page d'administration du site) : l'application affiche exactement les
// réglages du site. Backend : docs/fonctionnalites/parametres-globaux.md
//   GET /admin/settings/schema → { groups: [ { key, label, settings: [
//       { key, label, description, type: boolean|integer|string|json, value } ] } ] }
//   PUT /admin/settings { clé: valeur }

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';

class AdminSetting {
  const AdminSetting({
    required this.key,
    required this.label,
    required this.type,
    required this.value,
    this.description,
  });

  factory AdminSetting.fromJson(Map<String, dynamic> m) => AdminSetting(
        key: '${m['key']}',
        label: '${m['label'] ?? m['key']}',
        description: (m['description'] as String?)?.trim().isEmpty ?? true ? null : m['description'] as String,
        type: '${m['type'] ?? 'string'}',
        value: m['value'],
      );

  final String key;
  final String label;
  final String? description;

  /// boolean | integer | string | json
  final String type;
  final Object? value;

  bool get isBoolean => type == 'boolean';
  bool get boolValue => switch (value) {
        final bool b => b,
        final num n => n != 0,
        final String s => s == '1' || s.toLowerCase() == 'true',
        _ => false,
      };

  AdminSetting withValue(Object? v) =>
      AdminSetting(key: key, label: label, description: description, type: type, value: v);
}

class AdminSettingsGroup {
  const AdminSettingsGroup({required this.key, required this.label, required this.settings});

  factory AdminSettingsGroup.fromJson(Map<String, dynamic> m) => AdminSettingsGroup(
        key: '${m['key']}',
        label: '${m['label'] ?? m['key']}',
        settings: [
          for (final s in (m['settings'] is List ? m['settings'] as List : const []))
            if (s is Map) AdminSetting.fromJson(Map<String, dynamic>.from(s)),
        ],
      );

  final String key;
  final String label;
  final List<AdminSetting> settings;
}

class AdminSettingsSchemaNotifier extends AsyncNotifier<List<AdminSettingsGroup>?> {
  /// null : serveur sans description (ancienne version) — l'écran garde ses réglages fixes.
  @override
  Future<List<AdminSettingsGroup>?> build() async {
    try {
      final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.adminSettingsSchema);
      final data = res.data;
      final groups = data is Map ? data['groups'] : null;
      if (groups is! List) return null;
      return [
        for (final g in groups)
          if (g is Map) AdminSettingsGroup.fromJson(Map<String, dynamic>.from(g)),
      ];
    } on LaravelApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  AdminSetting? find(String key) {
    for (final g in state.value ?? const <AdminSettingsGroup>[]) {
      for (final s in g.settings) {
        if (s.key == key) return s;
      }
    }
    return null;
  }

  /// Enregistre une valeur (PUT /admin/settings { clé: valeur }) ; en cas d'échec,
  /// l'ancienne valeur revient et le message est renvoyé.
  Future<String?> set(String key, Object? value) async {
    final before = state.value;
    if (before == null) return null;
    state = AsyncValue.data(_replace(before, key, value));
    try {
      await ref.read(apiServiceProvider).put<dynamic>(AppConstants.adminSettings, data: {key: value});
      return null;
    } on LaravelApiException catch (e) {
      state = AsyncValue.data(before);
      return e.displayMessage;
    } catch (_) {
      state = AsyncValue.data(before);
      return L10n.current.adminSettingsSaveFailed;
    }
  }

  static List<AdminSettingsGroup> _replace(List<AdminSettingsGroup> groups, String key, Object? value) => [
        for (final g in groups)
          AdminSettingsGroup(
            key: g.key,
            label: g.label,
            settings: [for (final s in g.settings) s.key == key ? s.withValue(value) : s],
          ),
      ];
}

final adminSettingsSchemaProvider =
    AsyncNotifierProvider.autoDispose<AdminSettingsSchemaNotifier, List<AdminSettingsGroup>?>(
        AdminSettingsSchemaNotifier.new);
