import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../community/data/community_repository.dart';
import '../../community/models/community_account.dart';
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';

/// Avatar rond (photo ou initiales).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({required this.name, this.url, this.initials, this.size = 38, super.key});

  final String name;
  final String? url;
  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final i = initials ??
        name
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primarySoft,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(i.isEmpty ? '?' : i,
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36))
          : null,
    );
  }
}

/// Choisir une personne (comptes personnels de la Communauté) ; renvoie son compte.
Future<CommunityAccount?> pickPerson(BuildContext context, {required String title, Set<String> exclude = const {}}) {
  return showModalBottomSheet<CommunityAccount>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _PersonPicker(title: title, exclude: exclude),
  );
}

class _PersonPicker extends ConsumerStatefulWidget {
  const _PersonPicker({required this.title, required this.exclude});
  final String title;
  final Set<String> exclude;

  @override
  ConsumerState<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends ConsumerState<_PersonPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<CommunityAccount> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(communityRepositoryProvider).community(CommunityTab.people, query: q);
      if (!mounted) return;
      setState(() {
        _results = page.accounts.where((a) => !a.isOrganization && !widget.exclude.contains(a.id)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Recherche impossible. Vérifiez votre connexion.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(widget.title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: const InputDecoration(
                    hintText: 'Nom ou adresse e-mail',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center))
              else if (_results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _query.text.trim().length < 2
                        ? 'Tapez au moins deux lettres du nom de la personne.'
                        : 'Aucun compte personnel trouvé.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final a = _results[i];
                      return ListTile(
                        leading: PersonAvatar(name: a.displayName, url: a.avatarUrl),
                        title: Text(a.displayName),
                        subtitle: a.city == null ? null : Text(a.city!),
                        trailing: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                        onTap: () => Navigator.pop(context, a),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille « Co-gestionnaires » d'un événement (2 au plus).
class EventManagersSheet extends ConsumerStatefulWidget {
  const EventManagersSheet({required this.event, required this.currentUserId, super.key});

  final ChristianEvent event;
  final String? currentUserId;

  @override
  ConsumerState<EventManagersSheet> createState() => _EventManagersSheetState();
}

class _EventManagersSheetState extends ConsumerState<EventManagersSheet> {
  late ChristianEvent _event = widget.event;
  bool _busy = false;

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));

  Future<void> _apply(Future<ChristianEvent> Function() call, String ok) async {
    setState(() => _busy = true);
    try {
      final e = await call();
      if (!mounted) return;
      setState(() => _event = e);
      ref.read(eventDetailProvider(e.id).notifier).replace(e);
      _snack(ok);
    } on EventFailure catch (err) {
      _snack(err.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add() async {
    final picked = await pickPerson(
      context,
      title: 'Ajouter un co-gestionnaire',
      exclude: {..._event.managers.map((m) => m.id), _event.organizer.id},
    );
    if (picked == null || !mounted) return;
    await _apply(() => ref.read(eventsRepositoryProvider).addManager(_event.id, picked.id),
        '${picked.displayName} peut maintenant gérer l\'événement.');
  }

  Future<void> _remove(EventPerson p) async {
    final self = p.id == widget.currentUserId;
    await _apply(() => ref.read(eventsRepositoryProvider).removeManager(_event.id, p.id),
        self ? 'Vous ne gérez plus cet événement.' : 'Co-gestionnaire retiré.');
    if (self && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = _event;
    final full = e.managers.length >= ChristianEvent.maxManagers;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Co-gestionnaires (${e.managers.length}/${ChristianEvent.maxManagers})',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Ils modifient la page, enregistrent les témoignages et lancent le direct. '
              'Seul l\'organisateur les désigne et peut supprimer l\'événement.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PersonAvatar(name: e.organizer.displayName, url: e.organizer.avatarUrl, initials: e.organizer.initials),
              title: Text(e.organizer.displayName),
              subtitle: const Text('Organisateur'),
            ),
            for (final m in e.managers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PersonAvatar(name: m.displayName, url: m.avatarUrl, initials: m.initials),
                title: Text(m.displayName),
                subtitle: const Text('Co-gestionnaire'),
                trailing: e.canAdministrate || m.id == widget.currentUserId
                    ? TextButton(
                        onPressed: _busy ? null : () => _remove(m),
                        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                        child: Text(m.id == widget.currentUserId ? 'Me retirer' : 'Retirer'),
                      )
                    : null,
              ),
            if (e.canAdministrate) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy || full ? null : _add,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(full ? 'Deux co-gestionnaires au plus' : 'Ajouter un co-gestionnaire'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
