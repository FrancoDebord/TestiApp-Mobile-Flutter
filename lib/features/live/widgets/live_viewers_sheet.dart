import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/live_repository.dart';
import '../models/live_models.dart';
import 'live_widgets.dart';

/// Compteur de spectateurs cliquable : ouvre « Qui regarde » (visible de tous).
class LiveViewersChip extends ConsumerWidget {
  const LiveViewersChip({required this.liveId, required this.viewers, super.key});

  final String liveId;
  final int viewers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(liveRepositoryProvider);
    return Semantics(
      button: true,
      label: context.l10n.liveViewersSemantics(viewers),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showLiveViewersSheet(context, liveId: liveId, repository: repository),
        child: LiveChip(icon: Icons.visibility_rounded, label: '$viewers'),
      ),
    );
  }
}

/// « Qui regarde » : comptes connectés (vers leur profil) et nombre de visiteurs non connectés.
/// Backend : GET /lives/{id}/viewers — docs/fonctionnalites/lives.md
Future<void> showLiveViewersSheet(BuildContext context, {required String liveId, required LiveRepository repository}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: FutureBuilder<LiveViewers>(
        future: repository.viewers(liveId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return SizedBox(
              height: 160,
              child: Center(
                child: Text(snap.error is LiveFailure ? '${snap.error}' : context.l10n.liveViewersLoadError,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          final v = snap.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(context.l10n.liveViewersTitle(v.total),
                    style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              if (v.people.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    v.anonymous > 0 ? context.l10n.liveViewersNoAccount : context.l10n.liveViewersNobody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: v.people.length,
                    itemBuilder: (context, i) {
                      final p = v.people[i];
                      return ListTile(
                        leading: LiveAvatar(person: p, size: 36),
                        title: Text(p.displayName),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/users/${p.id}');
                        },
                      );
                    },
                  ),
                ),
              if (v.anonymous > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    context.l10n.liveViewersAnonymous(v.anonymous),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
