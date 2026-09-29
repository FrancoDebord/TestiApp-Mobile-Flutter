import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../../publish/models/publish_models.dart';
import '../../publish/providers/publish_provider.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/journal_offline_controller.dart';
import '../data/journal_repository.dart';
import '../widgets/journal_offline_sheet.dart';
import '../models/journal_entry.dart';

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
  'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

String journalMonthLabel(DateTime d) {
  final label = '${_months[d.month - 1]} ${d.year}';
  return label[0].toUpperCase() + label.substring(1);
}

String journalDayLabel(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

IconData journalTypeIcon(JournalEntryType t) => switch (t) {
      JournalEntryType.text  => Icons.edit_note_rounded,
      JournalEntryType.audio => Icons.mic_rounded,
      JournalEntryType.video => Icons.videocam_rounded,
    };

/// Ouvre le parcours d'enregistrement en mode carnet privé.
Future<void> startJournalEntry(BuildContext context, WidgetRef ref) async {
  final format = await showModalBottomSheet<TestimonyFormat>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouveau témoignage privé', style: AppTextStyles.h4),
            const SizedBox(height: 4),
            Text('Gardé pour vous seul. Vous pourrez le partager plus tard.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            for (final (f, icon, label, hint) in [
              (TestimonyFormat.text, Icons.edit_note_rounded, 'Écrire', 'Un texte, avec mise en forme'),
              (TestimonyFormat.audio, Icons.mic_rounded, 'Enregistrer ma voix', 'Un audio'),
              (TestimonyFormat.video, Icons.videocam_rounded, 'Filmer', 'Une vidéo'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(20),
                  child: Icon(icon, color: AppColors.primary),
                ),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(hint),
                onTap: () => Navigator.pop(context, f),
              ),
          ],
        ),
      ),
    ),
  );
  if (format == null || !context.mounted) return;
  ref.read(publishProvider.notifier).selectFormat(format, journal: true);
  ref.read(publishStepProvider.notifier).goTo(1);
  // Route propre au carnet (hors du shell), voir app_router.dart.
  context.push('/journal/new', extra: format);
}

/// Carnet privé : les témoignages que l'on garde pour soi.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  JournalEntryType? _type;
  final List<JournalEntry> _entries = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  int _total = 0;
  String? _error;

  /// Évite qu'une réponse lente écrase une recherche plus récente.
  int _requestId = 0;

  /// Affichage de la copie du téléphone (pas de connexion).
  bool _showingOffline = false;
  bool _askedThisSession = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        unawaited(_loadMore());
      }
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _entries.clear();
    _page = 0;
    _hasMore = true;
    _error = null;
    _showingOffline = false;
    await _loadMore(force: true);
    // En ligne : mettre à jour la copie du téléphone (si l'option est active).
    if (!_showingOffline && _error == null && mounted) {
      unawaited(ref.read(journalOfflineProvider.notifier).sync());
      _maybeAskOffline();
    }
  }

  /// Première visite : proposer de garder une copie sur ce téléphone.
  void _maybeAskOffline() {
    final offline = ref.read(journalOfflineProvider);
    if (!kJournalOfflineSupported || _askedThisSession || !offline.loaded ||
        offline.settings.asked || ref.read(currentUserProvider) == null) {
      return;
    }
    _askedThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(askJournalOffline(context, ref));
    });
  }

  /// Pas de connexion : afficher la copie du téléphone, si elle existe.
  Future<bool> _loadOffline(int requestId) async {
    final offline = ref.read(journalOfflineProvider);
    final uid = ref.read(currentUserProvider)?.id;
    if (!offline.enabled || uid == null) return false;
    final local = await ref
        .read(journalOfflineStoreProvider)
        .search(uid, type: _type, query: _search.text);
    if (!mounted || requestId != _requestId) return true;
    setState(() {
      _entries
        ..clear()
        ..addAll(local);
      _hasMore = false;
      _total = local.length;
      _showingOffline = true;
      _error = null;
    });
    return true;
  }

  Future<void> _loadMore({bool force = false}) async {
    if ((_loading && !force) || !_hasMore) return;
    final requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final page = await ref.read(journalRepositoryProvider).list(
            page: _page + 1,
            type: _type,
            query: _search.text,
          );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _entries.addAll(page.entries);
        _page = page.currentPage;
        _hasMore = page.hasMore;
        _total = page.total;
      });
    } on JournalFailure catch (e) {
      if (!mounted || requestId != _requestId) return;
      // Pas de connexion (statut 0) : se rabattre sur la copie du téléphone.
      if (e.statusCode == 0 && _page == 0 && await _loadOffline(requestId)) return;
      if (mounted && requestId == _requestId) setState(() => _error = e.message);
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(_reload()));
  }

  @override
  Widget build(BuildContext context) {
    // Nouvelle entrée, partage, suppression → rechargement.
    ref.listen(journalRefreshProvider, (_, _) => unawaited(_reload()));

    // publishProvider / publishStepProvider sont en autoDispose : sans
    // écouteur, le brouillon préparé par startJournalEntry (format + visibilité
    // privée) serait détruit avant l'ouverture du parcours, qui repartirait
    // en « Texte » et… en public. Le carnet les garde en vie pendant le parcours.
    ref.listen(publishProvider, (_, _) {});
    ref.listen(publishStepProvider, (_, _) {});

    // Réglages hors ligne chargés après la liste : poser la question alors.
    ref.listen(journalOfflineProvider.select((s) => s.loaded), (_, loaded) {
      if (loaded && !_loading && !_showingOffline && _error == null) {
        _maybeAskOffline();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon carnet privé'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (kJournalOfflineSupported) const JournalOfflineButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => startJournalEntry(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau témoignage'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Header(total: _total)),
            if (_showingOffline)
              SliverToBoxAdapter(
                child: _OfflineBanner(onRetry: _reload),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher dans mon carnet…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              unawaited(_reload());
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    for (final t in <JournalEntryType?>[null, ...JournalEntryType.values])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t?.label ?? 'Tous'),
                          avatar: t == null ? null : Icon(journalTypeIcon(t), size: 16),
                          selected: _type == t,
                          onSelected: (_) {
                            setState(() => _type = t);
                            unawaited(_reload());
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ..._buildList(),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    if (_entries.isEmpty) {
      if (_loading) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }
      if (_error != null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Empty(
              icon: Icons.wifi_off_rounded,
              text: _error!,
              action: TextButton(onPressed: _reload, child: const Text('Réessayer')),
            ),
          ),
        ];
      }
      final filtered = _type != null || _search.text.trim().isNotEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Empty(
            icon: filtered ? Icons.search_off_rounded : Icons.auto_stories_rounded,
            text: filtered
                ? 'Aucun témoignage ne correspond.'
                : 'Votre carnet est vide.\nNotez ce que Dieu a fait pour vous, '
                    'pour ne jamais l\'oublier.',
            action: filtered
                ? null
                : FilledButton.icon(
                    onPressed: () => startJournalEntry(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Mon premier témoignage'),
                  ),
          ),
        ),
      ];
    }

    // Regroupement par mois (liste déjà triée du plus récent au plus ancien).
    final widgets = <Widget>[];
    String? currentMonth;
    final group = <JournalEntry>[];
    void flush() {
      if (group.isEmpty) return;
      final entries = List<JournalEntry>.of(group);
      widgets
        ..add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(currentMonth!,
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
        ))
        ..add(SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) => _EntryTile(entry: entries[i]),
        ));
      group.clear();
    }

    for (final e in _entries) {
      final month = e.createdAt == null ? 'Sans date' : journalMonthLabel(e.createdAt!);
      if (month != currentMonth) {
        flush();
        currentMonth = month;
      }
      group.add(e);
    }
    flush();

    if (_loading) {
      widgets.add(const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ));
    }
    return widgets;
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(journalOfflineProvider).settings.lastSyncAt;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              last == null
                  ? 'Hors ligne : copie enregistrée sur ce téléphone.'
                  : 'Hors ligne : copie du ${journalDayLabel(last.toLocal())}.',
              style: AppTextStyles.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF103675), Color(0xFF184797)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ce que Dieu a fait pour moi',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0
                      ? '$total témoignage${total > 1 ? 's' : ''} · visible${total > 1 ? 's' : ''} par vous seul'
                      : 'Visible uniquement par vous · sans modération',
                  style: TextStyle(
                      color: Colors.white.withAlpha(215),
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final excerpt = stripFormatting(entry.body).replaceAll('\n', ' ').trim();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        // L'entrée est passée à l'écran de détail : elle s'affiche tout de
        // suite, même si le serveur ne répond pas à GET /testimonies/{id}.
        onTap: () => context.push('/journal/${entry.id}', extra: entry),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(20),
          child: Icon(journalTypeIcon(entry.type), color: AppColors.primary),
        ),
        title: Text(entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (entry.createdAt != null) journalDayLabel(entry.createdAt!),
            if (excerpt.isNotEmpty) excerpt,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
