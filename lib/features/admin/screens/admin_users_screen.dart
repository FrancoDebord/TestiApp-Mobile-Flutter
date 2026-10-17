import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_model.dart' show UserRole;
import '../providers/admin_provider.dart';
import '../widgets/admin_user_row.dart';
import '../../../shared/search/search_suggestions.dart';
import '../../../shared/widgets/search_autocomplete_field.dart';
import '../../../l10n/app_localizations.dart';

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
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(adminUserSearchProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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
            child: Text(
              context.l10n.commonCancel,
              style: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFF667085)),
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
            child: Text(
              context.l10n.commonConfirm,
              style: const TextStyle(
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
          // Autocomplétion des noms de comptes (docs/fonctionnalites/recherche.md).
          child: SearchAutocomplete(
            controller: _searchController,
            focusNode: _searchFocus,
            scope: SearchScope.users,
            recentKey: 'admin-users',
            onSubmitted: (v) =>
                ref.read(adminUserSearchProvider.notifier).update(v),
            fieldBuilder: (context, submit) => TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onSubmitted: submit,
              onChanged: (v) =>
                  ref.read(adminUserSearchProvider.notifier).update(v),
              decoration: InputDecoration(
                hintText: context.l10n.adminSearchUsersHint,
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
                Expanded(
                  child: Text(
                    context.l10n.adminRoleUser,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                Text(
                  context.l10n.adminResultCount(users.length),
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
                ? Center(
                    child: Text(
                      context.l10n.adminNoUserFound,
                      style: const TextStyle(
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
                          context.l10n.adminSuspendTitle(user.displayName),
                          context.l10n.adminSuspendBody,
                          const Color(0xFFF79009),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .suspend(user.uid),
                        ),
                        onBan: () => _showConfirm(
                          context.l10n.adminBanTitle(user.displayName),
                          context.l10n.adminBanBody,
                          const Color(0xFFD92D20),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .ban(user.uid),
                        ),
                        onPromote: () => _showConfirm(
                          context.l10n.adminPromoteTitle(user.displayName),
                          context.l10n.adminPromoteUserBody,
                          const Color(0xFF184797),
                          () => ref
                              .read(adminUsersNotifierProvider.notifier)
                              .updateRole(user.uid, UserRole.moderateur),
                        ),
                        onRestore: () => _showConfirm(
                          context.l10n.adminRestoreTitle(user.displayName),
                          context.l10n.adminRestoreBody,
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
          Text(
            context.l10n.adminSearchUserTitle,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF263238),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.adminSearchUserBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
