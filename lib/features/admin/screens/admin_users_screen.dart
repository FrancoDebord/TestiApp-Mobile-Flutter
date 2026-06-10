import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';
import '../widgets/admin_user_row.dart';

// =============================================================================
// AdminUsersScreen — User Management section
//
// Widget tree:
//   Column
//     _SearchBar
//     Expanded → ListView.builder → AdminUserRow
// =============================================================================

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersListProvider);
    final searchController = TextEditingController(
      text: ref.read(adminUserSearchProvider),
    );

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: searchController,
            onChanged: (v) =>
                ref.read(adminUserSearchProvider.notifier).update(v),
            decoration: InputDecoration(
              hintText: 'Rechercher un utilisateur…',
              hintStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        searchController.clear();
                        ref.read(adminUserSearchProvider.notifier).update('');
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF6B21A8), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        // ── Column header ────────────────────────────────────────────────────
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  'Utilisateur',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Text(
                '${users.length} résultat${users.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        // ── User list ────────────────────────────────────────────────────────
        Expanded(
          child: users.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun utilisateur trouvé.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return AdminUserRow(
                      user: user,
                      onSuspend: () => _showConfirm(
                        context,
                        'Suspendre ${user.displayName} ?',
                        'L\'utilisateur ne pourra plus se connecter temporairement.',
                        const Color(0xFFF59E0B),
                      ),
                      onBan: () => _showConfirm(
                        context,
                        'Bannir ${user.displayName} ?',
                        'Cette action est définitive. Le compte sera désactivé.',
                        const Color(0xFFEF4444),
                      ),
                      onPromote: () => _showConfirm(
                        context,
                        'Promouvoir ${user.displayName} ?',
                        'Cet utilisateur deviendra modérateur.',
                        const Color(0xFF6B21A8),
                      ),
                      onRestore: () => _showConfirm(
                        context,
                        'Réactiver ${user.displayName} ?',
                        'Le compte sera de nouveau accessible.',
                        const Color(0xFF22C55E),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showConfirm(
    BuildContext context,
    String title,
    String message,
    Color color,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text(
              'Confirmer',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
