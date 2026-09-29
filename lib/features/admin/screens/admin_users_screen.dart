import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_model.dart' show UserRole;
import '../providers/admin_provider.dart';
import '../widgets/admin_user_row.dart';

// =============================================================================
// AdminUsersScreen — User Management section
//
// Widget tree:
//   Column
//     _SearchBar
//     if query empty → _SearchPrompt
//     else → header + ListView.builder → AdminUserRow
// =============================================================================

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(adminUserSearchProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(adminUserSearchProvider.notifier).update('');
  }

  void _showConfirm(
    String title,
    String message,
    Color color,
    Future<void> Function() action,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF263238),
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 13,
            color: Color(0xFF667085),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Annuler',
              style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF667085)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              action();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text(
              'Confirmer',
              style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminUserSearchProvider);
    final users = ref.watch(adminUsersListProvider);

    return Column(
      children: [
        // ── Barre de recherche ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) =>
                ref.read(adminUserSearchProvider.notifier).update(v),
            decoration: InputDecoration(
              hintText: 'Rechercher par nom ou e-mail…',
              hintStyle: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 13,
                color: Color(0xFF98A2B3),
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: Color(0xFF98A2B3)),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 16, color: Color(0xFF98A2B3)),
                      onPressed: _clearSearch,
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF184797), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // ── Corps ────────────────────────────────────────────────────────────
        if (query.isEmpty)
          const Expanded(child: _SearchPrompt())
        else ...[
          // En-tête colonne
          Container(
            color: const Color(0xFFF8FAFC),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 48),
                const Expanded(
                  child: Text(
                    'Utilisateur',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                Text(
                  '${users.length} résultat${users.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun utilisateur trouvé.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        color: Color(0xFF667085),
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
                          'Suspendre ${user.displayName} ?',
                          "L'utilisateur ne pourra plus se connecter temporairement.",
                          const Color(0xFFF79009),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .suspend(user.uid),
                        ),
                        onBan: () => _showConfirm(
                          'Bannir ${user.displayName} ?',
                          'Cette action est définitive. Le compte sera désactivé.',
                          const Color(0xFFD92D20),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .ban(user.uid),
                        ),
                        onPromote: () => _showConfirm(
                          'Promouvoir ${user.displayName} ?',
                          'Cet utilisateur deviendra modérateur.',
                          const Color(0xFF184797),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .updateRole(user.uid, UserRole.moderateur),
                        ),
                        onRestore: () => _showConfirm(
                          'Réactiver ${user.displayName} ?',
                          'Le compte sera de nouveau accessible.',
                          const Color(0xFF12B76A),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .activate(user.uid),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

// ─── Search prompt (état initial, aucune recherche) ───────────────────────────

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF184797).withAlpha(15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              size: 36,
              color: Color(0xFF184797),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rechercher un utilisateur',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF263238),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Saisissez un nom ou une adresse e-mail\npour trouver un compte.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              color: Color(0xFF667085),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
