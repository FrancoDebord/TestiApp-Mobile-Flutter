import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../providers/follow_provider.dart';

/// Bouton « Suivre » / « Abonné » (docs/fonctionnalites/abonnements.md).
/// Rien pour son propre compte ; personne non connectée : ouvre la connexion.
/// [onCountChanged] reçoit le nouveau nombre d'abonnés renvoyé par le serveur.
class FollowButton extends ConsumerWidget {
  const FollowButton({
    required this.userId,
    this.displayName,
    this.compact = false,
    this.onCountChanged,
    super.key,
  });

  final String userId;
  final String? displayName;
  final bool compact;
  final ValueChanged<int>? onCountChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    if (userId.isEmpty || me == userId) return const SizedBox.shrink();

    final state = ref.watch(followProvider);
    final following = state.isFollowing(userId);
    final busy = state.pending.contains(userId);
    final label = following ? 'Abonné' : 'Suivre';
    final name = displayName == null ? '' : ' $displayName';

    Future<void> onTap() async {
      if (me == null) {
        context.push('/login');
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      try {
        final count = await ref.read(followProvider.notifier).toggle(userId);
        if (count != null) onCountChanged?.call(count);
      } on FollowFailure catch (e) {
        messenger.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.message)));
      }
    }

    final style = following
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            shape: const StadiumBorder(),
            visualDensity: compact ? VisualDensity.compact : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
          )
        : FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: const StadiumBorder(),
            visualDensity: compact ? VisualDensity.compact : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
          );
    final icon = Icon(following ? Icons.check_rounded : Icons.person_add_alt_1_rounded, size: compact ? 16 : 18);
    final text = Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600, fontSize: compact ? 12 : 14));

    return Semantics(
      button: true,
      label: following ? 'Ne plus suivre$name' : 'Suivre$name',
      excludeSemantics: true,
      child: following
          ? OutlinedButton.icon(onPressed: busy ? null : onTap, style: style, icon: icon, label: text)
          : FilledButton.icon(onPressed: busy ? null : onTap, style: style, icon: icon, label: text),
    );
  }
}
