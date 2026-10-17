import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../data/community_repository.dart';
import '../models/community_account.dart';
import '../providers/follow_provider.dart';
import 'account_tile.dart';
import '../../../shared/search/search_suggestions.dart';
import '../../../shared/widgets/search_autocomplete_field.dart';
import '../../../l10n/app_localizations.dart';

/// Charge une page de comptes (recherche, numéro de page à partir de 1).
typedef AccountPageLoader = Future<CommunityPage> Function(String query, int page);

/// Message lisible pour un échec de chargement d'une liste de comptes.
String accountListErrorMessage(Object error) {
  if (error is LaravelApiException) {
    // 404 : route absente, le serveur n'a pas encore reçu la mise à jour.
    if (error.statusCode == 404) {
      return L10n.current.communityListNotDeployed;
    }
    if (error.statusCode == 401) return L10n.current.communityListSignIn;
    if (error.statusCode == 429) return L10n.current.communityListTooMany;
    if (error.message.isNotEmpty) return error.message;
  }
  return L10n.current.communityListError;
}

/// Liste de comptes paginée avec recherche, tirer pour actualiser et bouton Suivre.
/// Utilisée par « Communauté », « Mes abonnés » et « Mes abonnements ».
class PagedAccountList extends ConsumerStatefulWidget {
  const PagedAccountList({
    super.key,
    required this.loader,
    required this.searchHint,
    required this.emptyText,
    this.emptyAction,
    this.header,
    this.followIdleLabel,
    this.searchRecentKey = 'accounts',
  });

  final AccountPageLoader loader;
  final String searchHint;
  final String emptyText;

  /// Bouton affiché sous le texte de la liste vide (hors recherche).
  final Widget? emptyAction;

  /// Ligne au-dessus des comptes (par ex. « Vous suivez 12 comptes »), avec le total.
  final Widget Function(int total)? header;

  /// Texte du bouton Suivre tant qu'on ne suit pas (« Suivre en retour » dans Mes abonnés).
  final String? followIdleLabel;

  /// Liste de recherches récentes de la barre (autocomplétion).
  final String searchRecentKey;

  @override
  ConsumerState<PagedAccountList> createState() => _PagedAccountListState();
}

class _PagedAccountListState extends ConsumerState<PagedAccountList> with AutomaticKeepAliveClientMixin {
  final _items = <CommunityAccount>[];
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;
  int _page = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  /// Défilement de la liste : sert à enchaîner les pages tant que l'écran n'est pas rempli.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final request = ++_request; // une recherche plus récente remplace la précédente
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loader(_search.text.trim(), reset ? 1 : _page + 1);
      if (!mounted || request != _request) return;
      // L'état « Suivre » renvoyé par le serveur alimente l'état partagé.
      final follow = ref.read(followProvider.notifier);
      for (final a in page.accounts) {
        if (a.isFollowing != null) follow.remember(a.id, a.isFollowing!);
      }
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.accounts);
        _page = page.currentPage;
        _total = page.total ?? _items.length;
        _hasMore = page.hasMore;
      });
      // Une page qui ne remplit pas l'écran ne déclenche aucun défilement : on charge la suivante.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasMore && _scroll.hasClients && _scroll.position.extentAfter < 400) unawaited(_load());
      });
    } catch (e) {
      debugPrint('comptes ✗ $e');
      if (mounted && request == _request) setState(() => _error = accountListErrorMessage(e));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showHeader = widget.header != null && _items.isNotEmpty;
    final lead = showHeader ? 2 : 1;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) unawaited(_load());
          return false;
        },
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _items.length + lead + 1,
          separatorBuilder: (_, i) => i < lead ? const SizedBox.shrink() : const Divider(height: 1, indent: 76),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                // Autocomplétion des noms de comptes (docs/fonctionnalites/recherche.md).
                child: SearchAutocomplete(
                  controller: _search,
                  focusNode: _searchFocus,
                  scope: SearchScope.users,
                  recentKey: widget.searchRecentKey,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    unawaited(_load(reset: true));
                  },
                  fieldBuilder: (context, submit) => TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: _onSearch,
                    onSubmitted: submit,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              );
            }
            if (showHeader && i == 1) {
              return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: widget.header!(_total));
            }
            if (i == _items.length + lead) return _footer();
            return AccountTile(account: _items[i - lead], followIdleLabel: widget.followIdleLabel);
          },
        ),
      ),
    );
  }

  Widget _footer() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          TextButton(onPressed: () => _load(reset: _items.isEmpty), child: Text(context.l10n.commonRetry)),
        ]),
      );
    }
    if (_items.isEmpty) {
      final searching = _search.text.trim().isNotEmpty;
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Text(
            searching ? context.l10n.communityNoMatch : widget.emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (!searching && widget.emptyAction != null) ...[
            const SizedBox(height: 12),
            widget.emptyAction!,
          ],
        ]),
      );
    }
    return const SizedBox(height: 8);
  }
}
