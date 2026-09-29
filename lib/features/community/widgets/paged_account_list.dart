import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/api_service.dart' show LaravelApiException;
import '../data/community_repository.dart';
import '../models/community_account.dart';
import '../providers/follow_provider.dart';
import 'account_tile.dart';

/// Charge une page de comptes (recherche, numéro de page à partir de 1).
typedef AccountPageLoader = Future<CommunityPage> Function(String query, int page);

/// Message lisible pour un échec de chargement d'une liste de comptes.
String accountListErrorMessage(Object error) {
  if (error is LaravelApiException) {
    // 404 : route absente, le serveur n'a pas encore reçu la mise à jour.
    if (error.statusCode == 404) {
      return "Cette liste n'est pas encore disponible sur le serveur. Réessayez plus tard.";
    }
    if (error.statusCode == 401) return 'Connectez-vous pour voir cette liste.';
    if (error.statusCode == 429) return 'Trop de demandes. Patientez un instant puis réessayez.';
    if (error.message.isNotEmpty) return error.message;
  }
  return 'Impossible de charger la liste. Vérifiez votre connexion.';
}

/// Liste de comptes paginée avec recherche, tirer pour actualiser et bouton Suivre.
/// Utilisée par « Communauté » et « Mes abonnements ».
class PagedAccountList extends ConsumerStatefulWidget {
  const PagedAccountList({
    super.key,
    required this.loader,
    required this.searchHint,
    required this.emptyText,
    this.emptyAction,
    this.header,
  });

  final AccountPageLoader loader;
  final String searchHint;
  final String emptyText;

  /// Bouton affiché sous le texte de la liste vide (hors recherche).
  final Widget? emptyAction;

  /// Ligne au-dessus des comptes (par ex. « Vous suivez 12 comptes »), avec le total.
  final Widget Function(int total)? header;

  @override
  ConsumerState<PagedAccountList> createState() => _PagedAccountListState();
}

class _PagedAccountListState extends ConsumerState<PagedAccountList> with AutomaticKeepAliveClientMixin {
  final _items = <CommunityAccount>[];
  final _search = TextEditingController();
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

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _items.length + lead + 1,
          separatorBuilder: (_, i) => i < lead ? const SizedBox.shrink() : const Divider(height: 1, indent: 76),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
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
              );
            }
            if (showHeader && i == 1) {
              return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: widget.header!(_total));
            }
            if (i == _items.length + lead) return _footer();
            return AccountTile(account: _items[i - lead]);
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
          TextButton(onPressed: () => _load(reset: _items.isEmpty), child: const Text('Réessayer')),
        ]),
      );
    }
    if (_items.isEmpty) {
      final searching = _search.text.trim().isNotEmpty;
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Text(
            searching ? 'Aucun compte ne correspond à votre recherche.' : widget.emptyText,
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
