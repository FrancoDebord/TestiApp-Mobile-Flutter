import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/manager_widgets.dart';

/// Gestionnaires : pour une organisation, les 2 personnes qui gèrent ses
/// événements en son nom ; pour une personne, les organisations qu'elle gère.
/// Backend : docs/fonctionnalites/evenements.md
class OrganizationManagersScreen extends ConsumerStatefulWidget {
  const OrganizationManagersScreen({super.key});

  @override
  ConsumerState<OrganizationManagersScreen> createState() => _OrganizationManagersScreenState();
}

class _OrganizationManagersScreenState extends ConsumerState<OrganizationManagersScreen> {
  OrganizationManagers? _org;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isOrganization => ref.read(currentUserProvider)?.isOrganization ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!_isOrganization) {
      setState(() => _loading = false);
      return;
    }
    try {
      final m = await ref.read(eventsRepositoryProvider).organizationManagers();
      if (mounted) setState(() => _org = m);
    } on EventFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  Future<void> _add() async {
    final picked = await pickPerson(
      context,
      title: 'Ajouter un gestionnaire',
      exclude: {...?_org?.managers.map((m) => m.id)},
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final m = await ref.read(eventsRepositoryProvider).addOrganizationManager(picked.id);
      if (mounted) setState(() => _org = m);
      _snack('${picked.displayName} peut maintenant gérer vos événements.');
    } on EventFailure catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(EventPerson p) async {
    setState(() => _busy = true);
    try {
      final m = await ref.read(eventsRepositoryProvider).removeOrganizationManager(p.id);
      if (mounted) setState(() => _org = m);
      _snack('Gestionnaire retiré.');
    } on EventFailure catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _leave(EventPerson org) async {
    try {
      await ref.read(eventsRepositoryProvider).leaveOrganization(org.id);
      ref.invalidate(managedOrganizationsProvider);
      _snack('Vous ne gérez plus les événements de ${org.displayName}.');
    } on EventFailure catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOrg = ref.watch(currentUserProvider)?.isOrganization ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isOrg ? "Gestionnaires de l'organisation" : 'Organisations que je gère'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          _Explanation(isOrganization: isOrg),
          const SizedBox(height: 16),
          if (isOrg) ..._organizationBody() else _ManagedOrganizations(onLeave: _leave),
        ],
      ),
    );
  }

  List<Widget> _organizationBody() {
    if (_loading) return const [Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))];
    if (_error != null) return [Text(_error!, textAlign: TextAlign.center)];
    final org = _org!;
    final full = org.managers.length >= org.max;
    return [
      Text('Gestionnaires (${org.managers.length}/${org.max})',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (org.managers.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Aucun gestionnaire pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      for (final m in org.managers)
        Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.cardRadius, side: const BorderSide(color: AppColors.border)),
          child: ListTile(
            leading: PersonAvatar(name: m.displayName, url: m.avatarUrl, initials: m.initials),
            title: Text(m.displayName),
            trailing: TextButton(
              onPressed: _busy ? null : () => _remove(m),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Retirer'),
            ),
          ),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _busy || full ? null : _add,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(full ? 'Deux gestionnaires au plus' : 'Ajouter un gestionnaire'),
      ),
    ];
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.isOrganization});
  final bool isOrganization;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOrganization
                  ? 'Désignez jusqu\'à deux personnes de confiance : avec leur propre compte, elles '
                      'créent et gèrent vos événements en votre nom (page, témoignages, direct, '
                      'co-gestionnaires). Vous pouvez les retirer à tout moment.'
                  : 'Une organisation vous a confié la gestion de ses événements : vous les créez '
                      'et les gérez en son nom depuis la page Événements.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedOrganizations extends ConsumerWidget {
  const _ManagedOrganizations({required this.onLeave});
  final Future<void> Function(EventPerson org) onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(managedOrganizationsProvider);
    return switch (async) {
      AsyncValue(:final value?) when value.isEmpty => const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Vous ne gérez aucune organisation.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      AsyncValue(:final value?) => Column(
          children: [
            for (final (org, verified) in value)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.cardRadius, side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  leading: PersonAvatar(name: org.displayName, url: org.avatarUrl),
                  title: Text(org.displayName),
                  subtitle: Text(verified ? 'Organisation vérifiée' : 'En attente de vérification : pas encore d\'événement'),
                  trailing: TextButton(
                    onPressed: () => onLeave(org),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Ne plus gérer'),
                  ),
                ),
              ),
          ],
        ),
      AsyncValue(:final error?) => Text(error is EventFailure ? error.message : 'Chargement impossible.'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
