import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/bible/providers/bible_providers.dart' show bibleReaderPositionProvider;
import '../../l10n/app_localizations.dart';
import '../search/search_suggestions.dart';

/// Construit le champ de recherche ; `submit` lance la recherche (à brancher sur
/// `TextField.onSubmitted`) en l'ajoutant aux recherches récentes.
typedef SearchFieldBuilder = Widget Function(BuildContext context, ValueChanged<String> submit);

/// Autocomplétion d'une barre de recherche (docs/fonctionnalites/recherche.md, dépôt du serveur).
///
/// - Dès 2 caractères : suggestions du serveur (GET /search/suggest), anti-rebond de 250 ms,
///   requête obsolète annulée ; partie saisie surlignée ; flèche « Compléter » (remplit sans lancer) ;
///   toucher une suggestion lance la recherche ; résultats directs (icône par type) qui ouvrent la page.
/// - Champ vide : recherches récentes (stockées sur l'appareil, effaçables).
/// - Hors ligne ou serveur indisponible : récentes (et [localResults]) seulement.
/// - Clavier : ↑ ↓ pour parcourir, Entrée pour choisir, → pour compléter, Échap pour fermer.
///
/// Le comportement de soumission de la barre reste celui de l'écran ([onSubmitted]).
class SearchAutocomplete extends ConsumerStatefulWidget {
  const SearchAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fieldBuilder,
    required this.onSubmitted,
    this.scope = SearchScope.all,
    this.recentKey,
    this.onResultSelected,
    this.localResults,
    this.debounce = const Duration(milliseconds: 250),
    this.maxSuggestions = 6,
    this.unfocusOnSubmit = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SearchFieldBuilder fieldBuilder;

  /// Lance la recherche de l'écran (texte validé).
  final ValueChanged<String> onSubmitted;
  final SearchScope scope;

  /// Liste de recherches récentes propre à la barre (défaut : nom de la portée).
  final String? recentKey;

  /// Ouverture d'un résultat direct ; par défaut, navigation vers sa page.
  final void Function(SearchDirectResult result)? onResultSelected;

  /// Résultats calculés sur l'appareil (ex. livres de la Bible téléchargés), disponibles hors ligne.
  final List<SearchDirectResult> Function(String query)? localResults;
  final Duration debounce;
  final int maxSuggestions;
  final bool unfocusOnSubmit;

  @override
  ConsumerState<SearchAutocomplete> createState() => _SearchAutocompleteState();
}

enum _Kind { recent, suggestion, result }

class _Option {
  const _Option(this.kind, this.text, {this.highlight, this.result});
  final _Kind kind;
  final String text;
  final SearchHighlight? highlight;
  final SearchDirectResult? result;
}

class _SearchAutocompleteState extends ConsumerState<SearchAutocomplete> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _targetKey = GlobalKey();
  final _scroll = ScrollController();

  Timer? _timer;
  CancelToken? _cancel;
  int _request = 0;
  String _lastText = '';
  bool _suppress = false;
  bool _loading = false;

  List<String> _recents = const [];
  SearchSuggestResponse _remote = SearchSuggestResponse.empty;
  String _remoteQuery = '';
  List<_Option> _options = const [];
  int _active = -1;

  String get _recentKey => widget.recentKey ?? widget.scope.name;
  String get _query => widget.controller.text.trim();

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onText);
    widget.focusNode.addListener(_onFocus);
    unawaited(_loadRecents());
  }

  @override
  void didUpdateWidget(SearchAutocomplete old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cancel?.cancel();
    widget.controller.removeListener(_onText);
    widget.focusNode.removeListener(_onFocus);
    _scroll.dispose();
    super.dispose();
  }

  // ── Données ────────────────────────────────────────────────────────────────

  Future<void> _loadRecents() async {
    final list = await ref.read(recentSearchStoreProvider).read(_recentKey);
    if (!mounted) return;
    _recents = list;
    _rebuild();
  }

  Future<void> _saveRecents(List<String> list) async {
    setState(() => _recents = list);
    await ref.read(recentSearchStoreProvider).write(_recentKey, list);
  }

  void _onText() {
    final text = widget.controller.text;
    if (text == _lastText) return; // déplacement du curseur seulement
    _lastText = text;
    if (_suppress) return;
    _timer?.cancel();
    final q = text.trim();
    if (q.length < 2 || widget.scope == SearchScope.local) {
      _cancel?.cancel();
      _request++;
      _remote = SearchSuggestResponse.empty;
      _loading = false;
      _rebuild();
      return;
    }
    _rebuild(); // récentes et résultats locaux tout de suite
    _timer = Timer(widget.debounce, () => _fetch(q));
  }

  Future<void> _fetch(String q) async {
    if (!ref.read(searchOnlineProvider)) {
      _rebuild();
      return;
    }
    _cancel?.cancel();
    final token = _cancel = CancelToken();
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final res = await ref.read(searchSuggestFetcherProvider)(q, widget.scope, limit: widget.maxSuggestions, cancelToken: token);
      if (!mounted || request != _request) return;
      _remote = res;
      _remoteQuery = q;
    } catch (_) {
      if (!mounted || request != _request) return;
      _remote = SearchSuggestResponse.empty; // hors ligne ou serveur indisponible : récentes seulement
    } finally {
      if (mounted && request == _request) {
        _loading = false;
        _rebuild();
      }
    }
  }

  void _onFocus() {
    if (widget.focusNode.hasFocus) {
      _rebuild();
    } else {
      _hide();
    }
  }

  // ── Options ────────────────────────────────────────────────────────────────

  void _rebuild() {
    if (!mounted) return;
    final q = _query;
    final options = <_Option>[];
    if (q.isEmpty) {
      options.addAll(_recents.map((s) => _Option(_Kind.recent, s)));
    } else if (q.length >= 2) {
      final recents = _recents
          .where((s) => s.trim() != q && findSearchMatch(s, q) != null)
          .take(3)
          .toList();
      options.addAll(recents.map((s) => _Option(_Kind.recent, s, highlight: findSearchMatch(s, q))));
      final fresh = _remoteQuery.isNotEmpty && foldForSearch(q).startsWith(foldForSearch(_remoteQuery));
      if (fresh || _remoteQuery == q) {
        for (final s in _remote.suggestions) {
          if (recents.contains(s.text) || foldForSearch(s.text) == foldForSearch(q)) continue;
          final hl = findSearchMatch(s.text, q);
          if (hl == null) continue; // suggestion d'une saisie précédente qui ne correspond plus
          options.add(_Option(_Kind.suggestion, s.text, highlight: hl));
        }
      }
      final results = <SearchDirectResult>[
        ...?widget.localResults?.call(q),
        if (fresh || _remoteQuery == q) ..._remote.results.where((r) => findSearchMatch(r.label, q) != null),
      ];
      final seen = <String>{};
      for (final r in results) {
        if (!seen.add('${r.type.name}:${r.id}')) continue;
        options.add(_Option(_Kind.result, r.label, highlight: findSearchMatch(r.label, q), result: r));
        if (seen.length >= 6) break;
      }
    }
    setState(() {
      _options = options;
      _active = _active.clamp(-1, options.length - 1);
    });
    if (widget.focusNode.hasFocus && options.isNotEmpty) {
      _portal.show();
    } else {
      _portal.hide();
    }
  }

  void _hide() {
    _portal.hide();
    if (mounted) setState(() => _active = -1);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _setText(String text) {
    _suppress = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _suppress = false;
  }

  /// Lance la recherche (suggestion, récente ou touche « Rechercher » du clavier).
  void _submit(String text) {
    final q = text.trim();
    _timer?.cancel();
    _cancel?.cancel();
    _request++;
    if (widget.controller.text != text) _setText(text);
    _hide();
    if (q.length >= 2) {
      unawaited(_saveRecents(addRecentSearch(_recents, q)));
      if (widget.scope != SearchScope.local) ref.read(searchLoggerProvider)(q);
    }
    if (widget.unfocusOnSubmit) widget.focusNode.unfocus();
    widget.onSubmitted(text);
  }

  /// Flèche « Compléter » : remplit le champ sans lancer la recherche.
  void _complete(String text) {
    widget.controller.value = TextEditingValue(
      text: '$text ',
      selection: TextSelection.collapsed(offset: text.length + 1),
    );
    widget.focusNode.requestFocus();
  }

  void _open(SearchDirectResult r) {
    final q = _query;
    if (q.length >= 2) unawaited(_saveRecents(addRecentSearch(_recents, q)));
    _hide();
    widget.focusNode.unfocus();
    if (widget.onResultSelected != null) {
      widget.onResultSelected!(r);
    } else {
      openSearchResult(context, ref, r);
    }
  }

  void _choose(_Option o) {
    switch (o.kind) {
      case _Kind.recent:
      case _Kind.suggestion:
        _submit(o.text);
      case _Kind.result:
        _open(o.result!);
    }
  }

  Future<void> _removeRecent(String s) async {
    await _saveRecents(_recents.where((r) => r != s).toList());
    _rebuild();
  }

  Future<void> _clearRecents() async {
    await _saveRecents(const []);
    _rebuild();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent || !_portal.isShowing || _options.isEmpty) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _active = (_active + 1) % _options.length);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _active = _active <= 0 ? _options.length - 1 : _active - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      _hide();
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) && _active >= 0) {
      _choose(_options[_active]);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight && _active >= 0 && _options[_active].kind != _Kind.result &&
        widget.controller.selection.baseOffset == widget.controller.text.length) {
      _complete(_options[_active].text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Affichage ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: KeyedSubtree(key: _targetKey, child: widget.fieldBuilder(context, _submit)),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final box = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final size = box.size;
    final mq = MediaQuery.of(context);
    final top = box.localToGlobal(Offset.zero).dy + size.height;
    final available = mq.size.height - mq.viewInsets.bottom - mq.padding.bottom - top - 12;
    final maxHeight = math.max(120.0, math.min(380.0, available));

    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, 4),
        child: TextFieldTapRegion(
          child: SizedBox(
            width: size.width,
            child: Material(
              elevation: 6,
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: _list(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final children = <Widget>[];
    final q = _query;
    final l10n = context.l10n;
    _Kind? section;
    for (var i = 0; i < _options.length; i++) {
      final o = _options[i];
      if (o.kind != section) {
        section = o.kind;
        children.add(_header(switch (o.kind) {
          _Kind.recent => q.isEmpty ? l10n.sharedSearchRecentSearches : l10n.sharedSearchRecent,
          _Kind.suggestion => l10n.sharedSearchSuggestions,
          _Kind.result => l10n.sharedSearchDirectAccess,
        }, clear: o.kind == _Kind.recent && q.isEmpty));
      }
      children.add(_row(o, i));
    }
    final n = _options.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Annonce du nombre de propositions (lecteur d'écran).
        Semantics(
          liveRegion: true,
          label: _loading ? l10n.sharedSearchLoadingSuggestions : l10n.sharedSearchSuggestionCount(n),
          child: const SizedBox(height: 4),
        ),
        Flexible(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 4),
            shrinkWrap: true,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _header(String title, {bool clear = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .5, color: AppColors.textSecondary),
              ),
            ),
          ),
          if (clear)
            TextButton(
              onPressed: _clearRecents,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(context.l10n.sharedSearchClearAll, semanticsLabel: context.l10n.sharedSearchClearAllSemantics),
            ),
        ],
      ),
    );
  }

  Widget _row(_Option o, int index) {
    final selected = index == _active;
    final r = o.result;
    final typeName = r == null ? null : searchResultTypeLabel(r.type);
    final l10n = context.l10n;
    final semantics = switch (o.kind) {
      _Kind.recent => l10n.sharedSearchRecentSemantics(o.text),
      _Kind.suggestion => l10n.sharedSearchSuggestionSemantics(o.text),
      _Kind.result => '${l10n.sharedSearchResultSemantics(typeName!, o.text)}'
          '${r!.verified ? l10n.sharedSearchVerifiedSuffix : ''}${r.sublabel != null ? ', ${r.sublabel}' : ''}',
    };

    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: false,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        child: InkWell(
          onTap: () => _choose(o),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  ExcludeSemantics(child: _leading(o)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Flexible(child: _highlighted(o.text, o.highlight)),
                              if (r?.verified ?? false) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                              ],
                            ]),
                            if (r != null)
                              Text(
                                r.sublabel ?? typeName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (o.kind == _Kind.recent && _query.isEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.textSecondary,
                      tooltip: l10n.sharedSearchRemoveRecent(o.text),
                      onPressed: () => _removeRecent(o.text),
                    )
                  else if (o.kind != _Kind.result)
                    IconButton(
                      icon: const Icon(Icons.north_west_rounded, size: 18),
                      color: AppColors.textSecondary,
                      tooltip: l10n.sharedSearchComplete(o.text),
                      onPressed: () => _complete(o.text),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading(_Option o) {
    final r = o.result;
    if (r?.avatar != null) {
      return CircleAvatar(radius: 16, backgroundColor: AppColors.border, backgroundImage: NetworkImage(r!.avatar!));
    }
    final icon = switch (o.kind) {
      _Kind.recent => Icons.history_rounded,
      _Kind.suggestion => Icons.search_rounded,
      _Kind.result => searchResultIcon(r!.type),
    };
    return CircleAvatar(
      radius: 16,
      backgroundColor: o.kind == _Kind.result ? AppColors.primarySoft : AppColors.background,
      child: Icon(icon, size: 18, color: o.kind == _Kind.result ? AppColors.primary : AppColors.textSecondary),
    );
  }

  Widget _highlighted(String text, SearchHighlight? hl) {
    const base = TextStyle(fontSize: 15, color: AppColors.textPrimary);
    if (hl == null || hl.$1 < 0 || hl.$2 <= 0 || hl.$1 + hl.$2 > text.length) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: base);
    }
    return Text.rich(
      TextSpan(style: base, children: [
        TextSpan(text: text.substring(0, hl.$1)),
        TextSpan(text: text.substring(hl.$1, hl.$1 + hl.$2), style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: text.substring(hl.$1 + hl.$2)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Champ de recherche standard (contour arrondi) avec autocomplétion.
class SearchAutocompleteField extends StatefulWidget {
  const SearchAutocompleteField({
    super.key,
    required this.onSubmitted,
    this.controller,
    this.focusNode,
    this.scope = SearchScope.all,
    this.recentKey,
    this.hintText,
    this.onChanged,
    this.onResultSelected,
    this.localResults,
    this.autofocus = false,
    this.decoration,
  });

  final ValueChanged<String> onSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final SearchScope scope;
  final String? recentKey;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final void Function(SearchDirectResult result)? onResultSelected;
  final List<SearchDirectResult> Function(String query)? localResults;
  final bool autofocus;
  final InputDecoration? decoration;

  @override
  State<SearchAutocompleteField> createState() => _SearchAutocompleteFieldState();
}

class _SearchAutocompleteFieldState extends State<SearchAutocompleteField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownController?.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAutocomplete(
      controller: _controller,
      focusNode: _focus,
      scope: widget.scope,
      recentKey: widget.recentKey,
      onSubmitted: widget.onSubmitted,
      onResultSelected: widget.onResultSelected,
      localResults: widget.localResults,
      fieldBuilder: (context, submit) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onSubmitted: submit,
          textInputAction: TextInputAction.search,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: widget.hintText ?? context.l10n.sharedSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: context.l10n.sharedSearchClear,
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged?.call('');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
        ),
      ),
    );
  }
}

// ── Types de résultats ────────────────────────────────────────────────────────

IconData searchResultIcon(SearchResultType type) => switch (type) {
      SearchResultType.testimony => Icons.auto_stories_rounded,
      SearchResultType.user => Icons.person_rounded,
      SearchResultType.event => Icons.event_rounded,
      SearchResultType.category => Icons.sell_rounded,
      SearchResultType.bible => Icons.menu_book_rounded,
      SearchResultType.prayerSession => Icons.volunteer_activism_rounded,
      SearchResultType.unknown => Icons.search_rounded,
    };

String searchResultTypeLabel(SearchResultType type) => switch (type) {
      SearchResultType.testimony => L10n.current.modTestimony,
      SearchResultType.user => L10n.current.sharedSearchTypeAccount,
      SearchResultType.event => L10n.current.notifTypeEvent,
      SearchResultType.category => L10n.current.sharedSearchTypeCategory,
      SearchResultType.bible => L10n.current.sharedSearchTypeBibleBook,
      SearchResultType.prayerSession => L10n.current.feedPrayerSession,
      SearchResultType.unknown => L10n.current.sharedSearchTypeResult,
    };

/// Ouverture par défaut d'un résultat direct.
void openSearchResult(BuildContext context, WidgetRef ref, SearchDirectResult r) {
  if (r.type == SearchResultType.bible && r.book != null) {
    final translation = r.translation ?? 'LSG'; // i18n-ignore
    ref.read(bibleReaderPositionProvider.notifier).setPosition(translation, r.book!, 1);
    context.push('/bible/$translation');
    return;
  }
  final route = r.route;
  if (route != null && route.startsWith('/')) context.push(route);
}
