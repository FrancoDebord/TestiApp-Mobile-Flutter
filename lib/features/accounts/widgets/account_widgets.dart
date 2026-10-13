// Administrateurs de compte : bandeau « Vous agissez au nom de X », feuille
// « Mes comptes » (bascule), garde des écrans réservés au titulaire.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/organization_badge.dart';
import '../../auth/providers/auth_notifier.dart' show realUserProvider;
import '../../events/widgets/manager_widgets.dart' show PersonAvatar;
import '../data/accounts_repository.dart';
import '../models/account_models.dart';
import '../providers/acting_account_provider.dart';

/// Message des écrans réservés au titulaire quand on agit pour un autre compte.
const kOwnerOnlyMessage = 'Revenez sur votre compte pour cette action.';

// ── Bascule ─────────────────────────────────────────────────────────────────

/// Agit au nom de [account] (ou revient à son compte), puis retour à l'accueil
/// et message de confirmation. [onSwitched] (ex. fermer la feuille) est appelé
/// juste avant la navigation.
Future<bool> switchToAccount(
  BuildContext context,
  WidgetRef ref,
  AccountSummary account, {
  VoidCallback? onSwitched,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.maybeOf(context);
  try {
    await ref.read(actingAccountProvider.notifier).actAs(account);
  } on AccountsFailure catch (e) {
    messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)));
    return false;
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating, content: Text('Bascule impossible. Réessayez.')));
    return false;
  }
  final acting = ref.read(actingAccountProvider);
  onSwitched?.call();
  router?.go('/home');
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(acting == null
          ? 'Vous êtes revenu sur votre compte.'
          : 'Vous agissez au nom de ${acting.displayName}'),
    ));
  return true;
}

/// Revient sur son propre compte ([goHome] : retour à l'accueil, comme une bascule).
Future<void> returnToOwnAccount(BuildContext context, WidgetRef ref, {bool goHome = false}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = goHome ? GoRouter.maybeOf(context) : null;
  await ref.read(actingAccountProvider.notifier).stopActing();
  router?.go('/home');
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating, content: Text('Vous êtes revenu sur votre compte.')));
}

/// Ouvre la feuille « Mes comptes ».
Future<void> showAccountSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const AccountSwitcherSheet(),
  );
}

/// Feuille « Mes comptes » : son compte (« Vous ») et les comptes administrés ;
/// coche sur le compte actif.
class AccountSwitcherSheet extends ConsumerStatefulWidget {
  const AccountSwitcherSheet({super.key});

  @override
  ConsumerState<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<AccountSwitcherSheet> {
  String? _busyId;

  Future<void> _pick(AccountSummary a, String activeId) async {
    if (_busyId != null) return;
    if (a.id == activeId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busyId = a.id);
    final navigator = Navigator.of(context);
    final ok = await switchToAccount(context, ref, a, onSwitched: () {
      if (navigator.canPop()) navigator.pop();
    });
    if (!ok && mounted) setState(() => _busyId = null);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myAccountsProvider);
    final acting = ref.watch(actingAccountProvider);
    final realId = ref.watch(realUserProvider)?.id;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text('Mes comptes', style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Choisissez le compte au nom duquel vous agissez : publications, commentaires, '
                'réactions et abonnements seront faits en son nom.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ),
            switch (async) {
              AsyncValue(:final value?) => Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in value.accounts)
                        _AccountTile(
                          account: a,
                          isMine: a.isOwner || a.id == realId,
                          active: a.id == (acting?.id ?? value.owner?.id ?? realId),
                          busy: _busyId == a.id,
                          onTap: () => _pick(a, acting?.id ?? value.owner?.id ?? realId ?? ''),
                        ),
                      if (value.managed.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: Text(
                            "Vous n'administrez aucun autre compte pour le moment.",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              AsyncValue(:final error?) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    error is AccountsFailure ? error.message : 'Chargement impossible.',
                    textAlign: TextAlign.center,
                  ),
                ),
              _ => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
              title: const Text('Administrateurs du compte'),
              onTap: () {
                final router = GoRouter.maybeOf(context);
                Navigator.of(context).pop();
                router?.push('/managers');
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isMine,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final AccountSummary account;
  final bool isMine;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = isMine
        ? 'Vous'
        : [
            if (account.isOrganization) 'Organisation',
            if (account.username != null) '@${account.username}',
          ].join(' · ');
    return ListTile(
      selected: active,
      selectedTileColor: AppColors.primarySoft,
      leading: PersonAvatar(name: account.displayName, url: account.avatarUrl, initials: account.initials),
      title: Row(
        children: [
          Flexible(
            child: Text(account.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          OrganizationBadge(isOrganization: account.isOrganization, isVerified: account.isVerified, size: 15),
        ],
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : active
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, semanticLabel: 'Compte actif')
              : null,
      onTap: onTap,
    );
  }
}

// ── Bandeau persistant ──────────────────────────────────────────────────────

/// « Vous agissez au nom de **X** » + « Revenir à mon compte » (rien sinon).
class ActingAsBanner extends ConsumerWidget {
  const ActingAsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acting = ref.watch(actingAccountProvider);
    if (acting == null) return const SizedBox.shrink();
    final style = AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontSize: 12, height: 1.25);
    return Material(
      color: AppColors.secondarySoft,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.secondary, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            const Icon(Icons.supervisor_account_rounded, size: 18, color: AppColors.secondaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Vous agissez au nom de '),
                    TextSpan(text: acting.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: TextButton(
                onPressed: () => returnToOwnAccount(context, ref, goHome: true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(48, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Revenir à mon compte',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Écrans réservés au titulaire ────────────────────────────────────────────

/// Encadré « Revenez sur votre compte pour cette action » + bouton de retour.
class OwnerOnlyNotice extends ConsumerWidget {
  const OwnerOnlyNotice({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acting = ref.watch(actingAccountProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.secondary.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_person_outlined, color: AppColors.secondaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  acting == null
                      ? kOwnerOnlyMessage
                      : 'Vous agissez au nom de ${acting.displayName}. $kOwnerOnlyMessage',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
          if (!compact && acting != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => returnToOwnAccount(context, ref),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Revenir à mon compte'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Écran réservé au titulaire du compte (mot de passe, suppression,
/// vérification, localisation…) : masqué quand on agit pour un autre compte.
class OwnerOnlyGate extends ConsumerWidget {
  const OwnerOnlyGate({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isActingForOtherProvider)) return child;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(AppSpacing.screen),
        child: Align(alignment: Alignment.topCenter, child: OwnerOnlyNotice()),
      ),
    );
  }
}

/// À appeler avant une action réservée au titulaire : `false` (et message) si
/// la personne agit pour un autre compte.
bool ensureOwnerAction(BuildContext context, WidgetRef ref) {
  if (!ref.read(isActingForOtherProvider)) return true;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: const Text(kOwnerOnlyMessage),
      action: SnackBarAction(label: 'Revenir', onPressed: () => returnToOwnAccount(context, ref)),
    ));
  return false;
}
