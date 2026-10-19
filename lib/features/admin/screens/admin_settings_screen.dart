import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart' show AppSettings;
import '../providers/admin_provider.dart';
import '../providers/admin_settings_schema.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../../../l10n/app_localizations.dart';

// =============================================================================
// AdminSettingsScreen — App-wide feature toggles
//
// Widget tree:
//   ListView
//     _MaintenanceBanner  (visible when maintenanceMode is true)
//     _SettingsSection("Accès")
//       _ToggleTile × 3
//     _SettingsSection("Modération")
//       _ToggleTile × 2
//     _SettingsSection("Notifications")
//       _ToggleTile × 1
//     _DangerZone
// =============================================================================

class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Réglages décrits par le serveur : exactement ceux de la page du site.
    final schema = ref.watch(adminSettingsSchemaProvider);
    return switch (schema) {
      AsyncValue(:final value?) when value.isNotEmpty => _SchemaSettings(groups: value),
      AsyncValue(:final error?) => _SchemaError(
          message: error is LaravelApiException ? error.displayMessage : context.l10n.adminSettingsSaveFailed,
          onRetry: () => ref.invalidate(adminSettingsSchemaProvider),
        ),
      AsyncValue(isLoading: true) => const Center(child: CircularProgressIndicator()),
      // Serveur plus ancien (pas de description) : réglages fixes de l'application.
      _ => const _StaticSettings(),
    };
  }
}

/// Réglages construits depuis GET /admin/settings/schema.
class _SchemaSettings extends ConsumerWidget {
  const _SchemaSettings({required this.groups});
  final List<AdminSettingsGroup> groups;

  static IconData _groupIcon(String key) => switch (key) {
        'general' => Icons.tune_rounded,
        'access' || 'auth' => Icons.lock_outline_rounded,
        'moderation' => Icons.shield_outlined,
        'notifications' => Icons.notifications_outlined,
        'publishing' => Icons.post_add_rounded,
        'media' || 'videos' => Icons.video_library_outlined,
        'features' => Icons.extension_outlined,
        _ => Icons.settings_outlined,
      };

  Future<void> _set(BuildContext context, WidgetRef ref, String key, Object? value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final err = await ref.read(adminSettingsSchemaProvider.notifier).set(key, value);
    if (err != null) {
      messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, AdminSetting s) async {
    final ctrl = TextEditingController(text: s.value?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: s.type == 'integer' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(helperText: s.description, helperMaxLines: 3),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(ctx.l10n.commonSave)),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !context.mounted) return;
    if (s.type == 'integer') {
      final n = int.tryParse(result.trim());
      if (n == null) return;
      await _set(context, ref, s.key, n);
    } else {
      await _set(context, ref, s.key, result.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenance = groups.expand((g) => g.settings).where((s) => s.key == 'maintenance_mode').firstOrNull;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminSettingsSchemaProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (maintenance != null && maintenance.boolValue) ...[
            _MaintenanceBanner(onDisable: () => _set(context, ref, 'maintenance_mode', false)),
            const SizedBox(height: 16),
          ],
          for (final g in groups) ...[
            _SettingsSection(
              title: g.label,
              icon: _groupIcon(g.key),
              tiles: [
                for (final s in g.settings)
                  if (s.isBoolean)
                    _ToggleTile(
                      icon: Icons.toggle_on_outlined,
                      label: s.label,
                      sublabel: s.description ?? '',
                      value: s.boolValue,
                      onChanged: (v) => _set(context, ref, s.key, v),
                    )
                  else
                    ListTile(
                      title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        [if (s.description != null) s.description!, s.value?.toString() ?? '—'].join('\n'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      trailing: s.type == 'json' ? null : const Icon(Icons.edit_outlined, size: 18),
                      onTap: s.type == 'json' ? null : () => _edit(context, ref, s),
                    ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SchemaError extends StatelessWidget {
  const _SchemaError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
            ],
          ),
        ),
      );
}

/// Réglages fixes (serveur sans GET /admin/settings/schema).
class _StaticSettings extends ConsumerWidget {
  const _StaticSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final notifier = ref.read(appSettingsProvider.notifier);

    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ── Maintenance warning banner ────────────────────────────────────
        if (settings.maintenanceMode) ...[
          _MaintenanceBanner(onDisable: () => _toggle(context, notifier, 'maintenanceMode')),
          const SizedBox(height: 16),
        ],

        // ── Access section ────────────────────────────────────────────────
        _SettingsSection(
          title: l10n.adminSettingsAccess,
          icon: Icons.lock_outline_rounded,
          tiles: [
            _ToggleTile(
              icon: Icons.person_add_outlined,
              label: l10n.adminSettingsNewSignups,
              sublabel: l10n.adminSettingsNewSignupsSub,
              value: settings.allowNewRegistrations,
              onChanged: (_) => _toggle(context, notifier, 'allowNewRegistrations'),
            ),
            _ToggleTile(
              icon: Icons.visibility_outlined,
              label: l10n.adminSettingsGuestAccess,
              sublabel: l10n.adminSettingsGuestAccessSub,
              value: settings.allowGuestView,
              onChanged: (_) => _toggle(context, notifier, 'allowGuestView'),
            ),
            _ToggleTile(
              icon: Icons.mark_email_read_outlined,
              label: l10n.adminSettingsEmailVerification,
              sublabel: l10n.adminSettingsEmailVerificationSub,
              value: settings.requireEmailVerification,
              onChanged: (_) => _toggle(context, notifier, 'requireEmailVerification'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Moderation section ────────────────────────────────────────────
        _SettingsSection(
          title: l10n.adminSettingsModeration,
          icon: Icons.shield_outlined,
          tiles: [
            _ToggleTile(
              icon: Icons.auto_awesome_outlined,
              label: l10n.adminSettingsAutoModeration,
              sublabel: l10n.adminSettingsAutoModerationSub,
              value: settings.autoModerationEnabled,
              onChanged: (_) => _toggle(context, notifier, 'autoModerationEnabled'),
              isExperimental: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Publication : types de témoignages acceptés ───────────────────
        _SettingsSection(
          title: l10n.adminSettingsPublishing,
          icon: Icons.post_add_rounded,
          tiles: [
            _ToggleTile(
              icon: Icons.article_outlined,
              label: l10n.adminSettingsTypeText,
              sublabel: l10n.adminSettingsTypeSub,
              value: settings.textTestimoniesEnabled,
              onChanged: (_) => _toggle(context, notifier, 'textTestimoniesEnabled'),
            ),
            _ToggleTile(
              icon: Icons.mic_none_rounded,
              label: l10n.adminSettingsTypeAudio,
              sublabel: l10n.adminSettingsTypeSub,
              value: settings.audioTestimoniesEnabled,
              onChanged: (_) => _toggle(context, notifier, 'audioTestimoniesEnabled'),
            ),
            _ToggleTile(
              icon: Icons.videocam_outlined,
              label: l10n.adminSettingsTypeVideo,
              sublabel: l10n.adminSettingsTypeSub,
              value: settings.videoTestimoniesEnabled,
              onChanged: (_) => _toggle(context, notifier, 'videoTestimoniesEnabled'),
            ),
            _ToggleTile(
              icon: Icons.smart_display_outlined,
              label: l10n.adminSettingsTypeYoutube,
              sublabel: l10n.adminSettingsTypeYoutubeSub,
              value: settings.youtubeTestimoniesEnabled,
              onChanged: (_) => _toggle(context, notifier, 'youtubeTestimoniesEnabled'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Notifications section ─────────────────────────────────────────
        _SettingsSection(
          title: l10n.adminSettingsNotifications,
          icon: Icons.notifications_outlined,
          tiles: [
            _ToggleTile(
              icon: Icons.send_outlined,
              label: l10n.adminSettingsPush,
              sublabel: l10n.adminSettingsPushSub,
              value: settings.pushNotificationsEnabled,
              onChanged: (_) => _toggle(context, notifier, 'pushNotificationsEnabled'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Danger zone ───────────────────────────────────────────────────
        _DangerZone(
          maintenanceMode: settings.maintenanceMode,
          onToggleMaintenance: () => _toggle(context, notifier, 'maintenanceMode'),
        ),
      ],
    );
  }
}

/// Enregistre l'interrupteur ; message si le serveur refuse.
Future<void> _toggle(BuildContext context, AppSettingsNotifier notifier, String key) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final err = await notifier.toggle(key);
  if (err != null) {
    messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(err)));
  }
}

// ─── Maintenance banner ───────────────────────────────────────────────────────

class _MaintenanceBanner extends StatelessWidget {
  const _MaintenanceBanner({required this.onDisable});
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF79009).withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction_rounded,
              color: Color(0xFFF79009), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.adminMaintenanceActive,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFFC48A06),
                  ),
                ),
                Text(
                  context.l10n.adminMaintenanceActiveBody,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    color: Color(0xFFC48A06),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDisable,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC48A06),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: Text(context.l10n.adminDisable,
                style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Settings section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.tiles,
  });

  final String title;
  final IconData icon;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF184797)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF263238),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          ...tiles,
        ],
      ),
    );
  }
}

// ─── Toggle tile ──────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.isExperimental = false,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isExperimental;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC))),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFF184797).withAlpha(15)
                : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16,
              color: value
                  ? const Color(0xFF184797)
                  : const Color(0xFF98A2B3)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Color(0xFF263238),
                ),
              ),
            ),
            if (isExperimental) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  context.l10n.adminBeta,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF79009),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          sublabel,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            color: Color(0xFF667085),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF184797),
          activeTrackColor: const Color(0xFF184797).withAlpha(80),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ─── Danger zone ──────────────────────────────────────────────────────────────

class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.maintenanceMode,
    required this.onToggleMaintenance,
  });

  final bool maintenanceMode;
  final VoidCallback onToggleMaintenance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD92D20).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFD92D20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.adminDangerZone,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: maintenanceMode
                    ? const Color(0xFFFFFAEB)
                    : const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.construction_rounded,
                size: 16,
                color: maintenanceMode
                    ? const Color(0xFFF79009)
                    : const Color(0xFFD92D20),
              ),
            ),
            title: Text(
              context.l10n.adminMaintenanceMode,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF263238),
              ),
            ),
            subtitle: Text(
              maintenanceMode
                  ? context.l10n.adminMaintenanceOnSub
                  : context.l10n.adminMaintenanceOffSub,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                color: Color(0xFF667085),
              ),
            ),
            trailing: ElevatedButton(
              onPressed: onToggleMaintenance,
              style: ElevatedButton.styleFrom(
                backgroundColor: maintenanceMode
                    ? const Color(0xFF12B76A)
                    : const Color(0xFFD92D20),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                textStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(maintenanceMode
                  ? context.l10n.adminDisable
                  : context.l10n.adminEnable),
            ),
          ),
        ],
      ),
    );
  }
}
