// Suppression par l'auteur d'un élément (témoignage, y compris de conversion ;
// sujet de prière ; parole prophétique) sans supprimer son compte : confirmation,
// appel à l'API, retrait de toutes les listes ouvertes et des caches, puis
// SnackBar « Supprimé » (ou message d'erreur clair).
// API : DELETE /testimonies/{id}, DELETE /prayer/requests/{id}, DELETE /prophecies/{id}
// (docs serveur fonctionnalites/confidentialite-et-suppression.md).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../features/conversion/providers/conversion_providers.dart'
    show conversionListProvider, latestConversionsProvider, myConversionProvider, userConversionProvider;
import '../features/home/providers/home_providers.dart' show feedNotifierProvider, featuredFromApiProvider;
import '../features/prayer/providers/prayer_providers.dart'
    show prayerRequestListProvider, prayerRequestProvider, prayerRequestsPageProvider;
import '../features/profile/providers/profile_provider.dart' show myTestimoniesNotifierProvider;
import '../features/prophecies/data/prophecy_reminders.dart';
import '../features/prophecies/providers/prophecies_providers.dart' show propheciesListProvider, prophecyProvider;
import '../l10n/app_localizations.dart';
import '../core/app_constants.dart';
import '../features/prayer/data/prayer_repository.dart' show prayerRepositoryProvider;
import '../features/prophecies/data/prophecies_repository.dart' show propheciesRepositoryProvider;
import '../services/api_service.dart' show LaravelApiException, apiServiceProvider;

/// Éléments que leur auteur peut supprimer.
enum DeletableContent { testimony, prayerRequest, prophecy }

/// Éléments supprimés pendant la session (« type:id ») : masqués dans toutes les
/// listes déjà chargées (accueil, Mon fil, profil, Mes données…).
class DeletedContentNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(DeletableContent kind, String id) => state = {...state, '${kind.name}:$id'};
}

final deletedContentProvider =
    NotifierProvider<DeletedContentNotifier, Set<String>>(DeletedContentNotifier.new);

/// À appeler dans `build` : vrai si l'élément vient d'être supprimé.
bool watchIsDeleted(WidgetRef ref, DeletableContent kind, String id) =>
    ref.watch(deletedContentProvider).contains('${kind.name}:$id');

/// Confirmation, suppression, nettoyage des listes et caches, SnackBar.
/// Renvoie vrai si l'élément a été supprimé.
Future<bool> confirmDeleteContent(
  BuildContext context,
  WidgetRef ref, {
  required DeletableContent kind,
  required String id,
  required String title,
  required String body,
  required Future<void> Function() delete,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.commonCancel)),
        FilledButton(
          key: const ValueKey('confirm-delete'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.commonDelete),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  void snack(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  try {
    await delete();
  } catch (e) {
    final detail = _errorMessage(e);
    snack(detail == null ? l10n.contentDeleteFailed : l10n.contentDeleteFailedWith(detail));
    return false;
  }
  ref.read(deletedContentProvider.notifier).add(kind, id);
  await _forget(ref, kind, id);
  snack(l10n.contentDeleted);
  return true;
}

/// Message du serveur (LaravelApiException, PrayerFailure, ProphecyFailure…).
String? _errorMessage(Object e) {
  if (e is LaravelApiException) return e.displayMessage;
  try {
    final m = (e as dynamic).message;
    if (m is String && m.trim().isNotEmpty) return m;
  } catch (_) {}
  return null;
}

/// Retire l'élément des listes et caches ouverts ; chaque étape est indépendante.
Future<void> _forget(WidgetRef ref, DeletableContent kind, String id) async {
  void step(void Function() run) {
    try {
      run();
    } catch (_) {}
  }

  switch (kind) {
    case DeletableContent.testimony:
      step(() => ref.read(feedNotifierProvider.notifier).removeTestimony(id));
      step(() => ref.read(myTestimoniesNotifierProvider.notifier).removeLocal(id));
      step(() => ref.invalidate(featuredFromApiProvider));
      step(() => ref.invalidate(myConversionProvider));
      step(() => ref.invalidate(userConversionProvider));
      step(() => ref.invalidate(latestConversionsProvider));
      step(() => ref.invalidate(conversionListProvider));
    case DeletableContent.prayerRequest:
      step(() => ref.invalidate(prayerRequestListProvider));
      step(() => ref.invalidate(prayerRequestsPageProvider));
      step(() => ref.invalidate(prayerRequestProvider(id)));
    case DeletableContent.prophecy:
      try {
        await ProphecyReminders.cancel(id);
      } catch (_) {}
      step(() => ref.invalidate(propheciesListProvider));
      step(() => ref.invalidate(prophecyProvider(id)));
  }
}

// ── Par type ─────────────────────────────────────────────────────────────────

/// Témoignage (y compris de conversion) : DELETE /testimonies/{id}.
Future<bool> deleteTestimonyContent(BuildContext context, WidgetRef ref, String id, {String? body}) =>
    confirmDeleteContent(
      context,
      ref,
      kind: DeletableContent.testimony,
      id: id,
      title: context.l10n.testimonyDeleteTitle,
      body: body ?? context.l10n.testimonyDeleteMineBody,
      delete: () => ref.read(apiServiceProvider).delete<void>(AppConstants.testimonyById(id)),
    );

/// Sujet de prière : DELETE /prayer/requests/{id}.
Future<bool> deletePrayerRequestContent(BuildContext context, WidgetRef ref, String id) => confirmDeleteContent(
      context,
      ref,
      kind: DeletableContent.prayerRequest,
      id: id,
      title: context.l10n.prayerDeleteRequestTitle,
      body: context.l10n.prayerDeleteRequestBody,
      delete: () => ref.read(prayerRepositoryProvider).deleteRequest(id),
    );

/// Parole prophétique du carnet : DELETE /prophecies/{id} (rappel annulé).
Future<bool> deleteProphecyContent(BuildContext context, WidgetRef ref, String id) => confirmDeleteContent(
      context,
      ref,
      kind: DeletableContent.prophecy,
      id: id,
      title: context.l10n.prophecyDeleteTitle,
      body: context.l10n.prophecyDeleteBody,
      delete: () => ref.read(propheciesRepositoryProvider).delete(id),
    );
