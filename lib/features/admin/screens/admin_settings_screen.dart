import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart' show AppSettings;
import '../providers/admin_provider.dart';

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
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final notifier = ref.read(appSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ── Maintenance warning banner ────────────────────────────────────
        if (settings.maintenanceMode) ...[
          _MaintenanceBanner(onDisable: () => notifier.toggle('maintenanceMode')),
          const SizedBox(height: 16),
        ],

        // ── Access section ────────────────────────────────────────────────
        _SettingsSection(
          title: 'Accès',
          icon: Icons.lock_outline_rounded,
          tiles: [
            _ToggleTile(
              icon: Icons.person_add_outlined,
              label: 'Nouvelles inscriptions',
              sublabel: 'Autoriser les nouveaux comptes',
              value: settings.allowNewRegistrations,
              onChanged: (_) => notifier.toggle('allowNewRegistrations'),
            ),
            _ToggleTile(
              icon: Icons.visibility_outlined,
              label: 'Accès visiteur',
              sublabel: 'Consulter sans compte',
              value: settings.allowGuestView,
              onChanged: (_) => notifier.toggle('allowGuestView'),
            ),
            _ToggleTile(
              icon: Icons.mark_email_read_outlined,
              label: 'Vérification e-mail',
              sublabel: 'Obligatoire à l\'inscription',
              value: settings.requireEmailVerification,
              onChanged: (_) => notifier.toggle('requireEmailVerification'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Moderation section ────────────────────────────────────────────
        _SettingsSection(
          title: 'Modération',
          icon: Icons.shield_outlined,
          tiles: [
            _ToggleTile(
              icon: Icons.auto_awesome_outlined,
              label: 'Modération automatique',
              sublabel: 'Filtres IA pré-approbation',
              value: settings.autoModerationEnabled,
              onChanged: (_) => notifier.toggle('autoModerationEnabled'),
              isExperimental: true,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Notifications section ─────────────────────────────────────────
        _SettingsSection(
          title: 'Notifications',
          icon: Icons.notifications_outlined,
          tiles: [
            _ToggleTile(
              icon: Icons.send_outlined,
              label: 'Notifications push',
              sublabel: 'Envoyer des notifications aux utilisateurs',
              value: settings.pushNotificationsEnabled,
              onChanged: (_) => notifier.toggle('pushNotificationsEnabled'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Danger zone ───────────────────────────────────────────────────
        _DangerZone(
          maintenanceMode: settings.maintenanceMode,
          onToggleMaintenance: () => notifier.toggle('maintenanceMode'),
        ),
      ],
    );
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
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction_rounded,
              color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode maintenance actif',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
                Text(
                  'L\'application est inaccessible aux utilisateurs.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDisable,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text('Désactiver',
                style: TextStyle(
                    fontFamily: 'Inter',
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
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF6B21A8)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: value
                ? const Color(0xFF6B21A8).withAlpha(15)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 16,
              color: value
                  ? const Color(0xFF6B21A8)
                  : const Color(0xFF94A3B8)),
        ),
        title: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
            if (isExperimental) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Bêta',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          sublabel,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF6B21A8),
          activeTrackColor: const Color(0xFF6B21A8).withAlpha(80),
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
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                const Text(
                  'Zone dangereuse',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: maintenanceMode
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.construction_rounded,
                size: 16,
                color: maintenanceMode
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444),
              ),
            ),
            title: const Text(
              'Mode maintenance',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              maintenanceMode
                  ? 'Application hors ligne pour les utilisateurs'
                  : 'Mettre l\'app en mode maintenance',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
            trailing: ElevatedButton(
              onPressed: onToggleMaintenance,
              style: ElevatedButton.styleFrom(
                backgroundColor: maintenanceMode
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(maintenanceMode ? 'Désactiver' : 'Activer'),
            ),
          ),
        ],
      ),
    );
  }
}
