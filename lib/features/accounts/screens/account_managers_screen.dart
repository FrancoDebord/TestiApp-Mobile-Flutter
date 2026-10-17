import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../auth/providers/auth_notifier.dart' show realUserProvider;
import '../../events/providers/events_providers.dart' show managedOrganizationsProvider;
import '../../events/widgets/manager_widgets.dart' show PersonAvatar, pickPerson;
import '../data/accounts_repository.dart';
import '../models/account_models.dart';
import '../providers/acting_account_provider.dart';
import '../widgets/account_widgets.dart';

/// Administrateurs de mon compte (2 au plus).
final accountManagersProvider = FutureProvider.autoDispose<AccountManagers>(
  (ref) => ref.watch(accountsRepositoryProvider).managers(),
);

/// Journal des actions faites en mon nom.
final managerActivityProvider = FutureProvider.autoDispose<List<ManagerActivity>>(
  (ref) => ref.watch(accountsRepositoryProvider).activity(),
);

/// Comptes que j'administre.
final managedAccountsProvider = FutureProvider.autoDispose<List<AccountSummary>>(
  (ref) => ref.watch(accountsRepositoryProvider).managedAccounts(),
);

/// « Administrateurs du compte » (tous les comptes, personnels et organisations) :
/// les 2 personnes au plus qui agissent en mon nom, le journal de leurs actions,
/// et les comptes que j'administre moi-même (agir en leur nom, me retirer).
class AccountManagersScreen extends ConsumerStatefulWidget {
  const AccountManagersScreen({super.key});

  @override
  ConsumerState<AccountManagersScreen> createState() => _AccountManagersScreenState();
}

class _AccountManagersScreenState extends ConsumerState<AccountManagersScreen> {
  bool _busy = false;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  Future<bool> _confirm({required String title, required String body, required String action}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: AppTextStyles.h4),
        content: Text(body, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(context.l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } on AccountsFailure catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add(AccountManagers current) async {
    final me = ref.read(realUserProvider)?.id;
    final picked = await pickPerson(
      context,
      title: context.l10n.accountsAddManager,
      exclude: {...current.managers.map((m) => m.id), ?me},
    );
    if (picked == null || !mounted) return;
    await _run(() async {
      await ref.read(accountsRepositoryProvider).addManager(picked.id);
      ref.invalidate(accountManagersProvider);
      _snack(L10n.current.accountsManagerAdded(picked.displayName));
    });
  }

  Future<void> _remove(AccountSummary m) async {
    final ok = await _confirm(
      title: context.l10n.accountsRemoveManagerTitle,
      body: context.l10n.accountsRemoveManagerBody(m.displayName),
      action: context.l10n.commonRemove,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(accountsRepositoryProvider).removeManager(m.id);
      ref.invalidate(accountManagersProvider);
      _snack(L10n.current.accountsManagerRemoved);
    });
  }

  Future<void> _leave(AccountSummary a) async {
    final ok = await _confirm(
      title: context.l10n.accountsLeaveTitle,
      body: context.l10n.accountsLeaveBody(a.displayName),
      action: context.l10n.accountsLeaveAction,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      if (ref.read(actingAccountProvider)?.id == a.id) {
        await ref.read(actingAccountProvider.notifier).stopActing();
      }
      await ref.read(accountsRepositoryProvider).leave(a.id);
      ref
        ..invalidate(managedAccountsProvider)
        ..invalidate(myAccountsProvider)
        ..invalidate(managedOrganizationsProvider);
      _snack(L10n.current.accountsLeft(a.displayName));
    });
  }

  @override
  Widget build(BuildContext context) {
    final acting = ref.watch(isActingForOtherProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.accountsManagersTitle),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(accountManagersProvider)
            ..invalidate(managerActivityProvider)
            ..invalidate(managedAccountsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            const _Explanation(),
            const SizedBox(height: 16),
            // Nommer ses administrateurs : réservé au titulaire.
            if (acting)
              const OwnerOnlyNotice()
            else ...[
              _ManagersSection(busy: _busy, onAdd: _add, onRemove: _remove),
              const SizedBox(height: 24),
              const _ActivitySection(),
            ],
            const SizedBox(height: 24),
            _ManagedAccountsSection(busy: _busy, onLeave: _leave),
          ],
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.cardRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.accountsManagersExplanation,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
    );

Widget _card(Widget child) => Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius, side: BorderSide(color: AppColors.border)),
      child: child,
    );

Widget _muted(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );

Widget _errorText(Object error) =>
    _muted(error is AccountsFailure ? error.message : L10n.current.accountsLoadFailed);

const _loading = Padding(
  padding: EdgeInsets.all(16),
  child: Center(child: CircularProgressIndicator()),
);

class _ManagersSection extends ConsumerWidget {
  const _ManagersSection({required this.busy, required this.onAdd, required this.onRemove});

  final bool busy;
  final Future<void> Function(AccountManagers current) onAdd;
  final Future<void> Function(AccountSummary m) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountManagersProvider);
    final l10n = context.l10n;
    return switch (async) {
      AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(l10n.accountsManagersCount(value.managers.length, value.max)),
            if (value.managers.isEmpty) _muted(l10n.accountsNoManagers),
            for (final m in value.managers)
              _card(ListTile(
                leading: PersonAvatar(name: m.displayName, url: m.avatarUrl, initials: m.initials),
                title: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: m.since == null ? null : Text(l10n.accountsManagerSince(_formatDate(m.since!))),
                trailing: TextButton(
                  onPressed: busy ? null : () => onRemove(m),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: Text(l10n.commonRemove),
                ),
              )),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy || value.isFull ? null : () => onAdd(value),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(value.isFull ? l10n.accountsManagersFull : l10n.accountsAddManager),
            ),
          ],
        ),
      AsyncValue(:final error?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_sectionTitle(l10n.accountsManagersSection), _errorText(error)],
        ),
      _ => _loading,
    };
  }
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(managerActivityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context.l10n.accountsActivityLog),
        switch (async) {
          AsyncValue(:final value?) when value.isEmpty =>
            _muted(context.l10n.accountsNoActivity),
          AsyncValue(:final value?) => _card(Column(
              children: [
                for (final (i, a) in value.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_rounded, color: AppColors.textSecondary),
                    title: Text.rich(TextSpan(children: [
                      TextSpan(text: a.actorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: a.action.isEmpty ? '' : ' · ${a.action}'),
                    ])),
                    subtitle: a.createdAt == null ? null : Text(_formatDateTime(a.createdAt!)),
                  ),
                ],
              ],
            )),
          AsyncValue(:final error?) => _errorText(error),
          _ => _loading,
        },
      ],
    );
  }
}

class _ManagedAccountsSection extends ConsumerWidget {
  const _ManagedAccountsSection({required this.busy, required this.onLeave});

  final bool busy;
  final Future<void> Function(AccountSummary a) onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(managedAccountsProvider);
    final actingId = ref.watch(actingAccountProvider)?.id;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(l10n.accountsManagedTitle),
        switch (async) {
          AsyncValue(:final value?) when value.isEmpty => _muted(l10n.accountsNoneManaged),
          AsyncValue(:final value?) => Column(
              children: [
                for (final a in value)
                  _card(Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            PersonAvatar(name: a.displayName, url: a.avatarUrl, initials: a.initials),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(a.displayName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            OrganizationBadge(isOrganization: a.isOrganization, isVerified: a.isVerified, size: 15),
                          ],
                        ),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => onLeave(a),
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                              child: Text(l10n.accountsLeaveAction),
                            ),
                            if (actingId == a.id)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: Text(l10n.accountsActive,
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                              )
                            else
                              TextButton.icon(
                                onPressed: busy ? null : () => switchToAccount(context, ref, a),
                                icon: const Icon(Icons.swap_horiz_rounded),
                                label: Text(l10n.accountsActOnBehalf),
                              ),
                          ],
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          AsyncValue(:final error?) => _errorText(error),
          _ => _loading,
        },
      ],
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

String _formatDate(DateTime d) {
  final l = d.toLocal();
  return L10n.current.accountsDateNumeric(_two(l.day), _two(l.month), '${l.year}');
}

String _formatDateTime(DateTime d) {
  final l = d.toLocal();
  return L10n.current.accountsDateTimeAt(_formatDate(l), _two(l.hour), _two(l.minute));
}
