// Saisie avec mentions « @ » réutilisable (commentaires de témoignages, directs, requêtes de prière,
// verset du jour…). Backend : GET /users/mention-search — docs/fonctionnalites/mentions.md
//
// Utilisation :
//   final ctrl = MentionEditingController();
//   MentionTextField(controller: ctrl, testimonyId: id, decoration: …)
//   // à l'envoi : api.post(…, data: {'text': ctrl.encodedText}); ctrl.clear();
//
// Le champ affiche « @Nom » (surligné) ; `encodedText` produit les jetons `@[Nom](user:id)`
// que le serveur valide. Suggestions : anti-rebond 300 ms, réponses périmées ignorées,
// états chargement / aucun résultat / erreur. Sans connexion (invité), aucune suggestion.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_service.dart';
import 'link_editing_controller.dart';
import 'mention_text.dart';
import '../models/account_approval.dart';
import 'approval_badges.dart';
import '../../l10n/app_localizations.dart';

export 'link_editing_controller.dart';

/// Compte proposé après « @ ».
class MentionCandidate {
  const MentionCandidate({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.initials,
    this.isVerified = false,
    this.isOrganization = false,
    this.isFollowing = false,
    this.approvalBadge,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? initials;
  final bool isVerified;
  final bool isOrganization;
  final bool isFollowing;

  /// Badge « Approuvé » du compte (`approval_badge`).
  final AccountApprovalBadge? approvalBadge;

  factory MentionCandidate.fromJson(Map<String, dynamic> j) => MentionCandidate(
        id: '${j['id'] ?? ''}',
        displayName: '${j['displayName'] ?? j['display_name'] ?? ''}',
        avatarUrl: (j['avatarUrl'] ?? j['avatar_url']) as String?,
        initials: j['initials'] as String?,
        isVerified: j['isVerified'] == true || j['is_verified'] == true,
        isOrganization: j['isOrganization'] == true,
        isFollowing: j['isFollowing'] == true,
        approvalBadge: AccountApprovalBadge.parse(j),
      );

  MentionRef get ref => MentionRef(id: id, displayName: displayName);
}

/// Recherche des comptes à mentionner.
typedef MentionSearch = Future<List<MentionCandidate>> Function(String query, {String? testimonyId});

/// Recherche par défaut : API `GET /users/mention-search`.
final mentionSearchProvider = Provider<MentionSearch>((ref) {
  final api = ref.watch(apiServiceProvider);
  return (String query, {String? testimonyId}) async {
    final res = await api.get<dynamic>(AppConstants.mentionSearch, query: {
      'q': query,
      'limit': 8,
      if (testimonyId != null && testimonyId.isNotEmpty) 'testimony_id': testimonyId,
    });
    final data = res.data;
    return data is List
        ? data
            .whereType<Map>()
            .map((e) => MentionCandidate.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.id.isNotEmpty && c.displayName.isNotEmpty)
            .toList()
        : const <MentionCandidate>[];
  };
});

/// Contrôleur de saisie qui retient les comptes choisis et surligne « @Nom »
/// (et les adresses collées, comme [LinkEditingController]).
class MentionEditingController extends LinkEditingController {
  MentionEditingController({super.text});

  final Map<String, MentionRef> _picked = {}; // nom affiché → compte

  /// Mentions choisies encore présentes dans le texte.
  List<MentionRef> get mentions =>
      MentionCodec.ranges(text, _picked.values).map((r) => r.ref).toSet().toList();

  /// Texte à envoyer au serveur (jetons `@[Nom](user:id)`).
  String get encodedText => MentionCodec.encode(text.trim(), _picked.values);

  /// Retient un compte (par ex. « Répondre à » préremplit « @Nom »).
  void remember(MentionRef ref) => _picked[ref.displayName] = ref;

  /// Remplace le texte par « @Nom » suivi d'une espace (réponse à un commentaire).
  void startWithMention(MentionRef ref) {
    remember(ref);
    final prefix = '@${ref.displayName} ';
    value = TextEditingValue(text: prefix, selection: TextSelection.collapsed(offset: prefix.length));
  }

  @override
  void clear() {
    _picked.clear();
    super.clear();
  }

  @override
  Iterable<MentionRef> get highlightedMentions => _picked.values;
}

/// « @requête » juste avant le curseur, ou null.
({String query, int start, int end})? mentionQueryAt(TextEditingValue value) {
  final sel = value.selection;
  if (!sel.isValid || !sel.isCollapsed) return null;
  final caret = sel.baseOffset;
  if (caret < 1 || caret > value.text.length) return null;
  final before = value.text.substring(0, caret);
  final m = RegExp(r'(?:^|[\s(])@([^@\n\[\]]{0,40})$').firstMatch(before);
  if (m == null) return null;
  final q = m.group(1)!;
  if (q.contains('  ') || q.split(' ').length > 3) return null;
  return (query: q, start: caret - q.length - 1, end: caret);
}

/// Champ de saisie avec autocomplétion des mentions (suggestions affichées au-dessus du champ).
class MentionTextField extends ConsumerStatefulWidget {
  const MentionTextField({
    required this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.keyboardType,
    this.cursorColor,
    this.onSubmitted,
    this.onChanged,
    this.enabled,
    this.autofocus = false,
    this.testimonyId,
    this.search,
    this.maxSuggestionsHeight = 220,
    super.key,
  });

  final MentionEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextStyle? style;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Color? cursorColor;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool? enabled;
  final bool autofocus;

  /// Témoignage commenté : ses participants sont proposés en premier.
  final String? testimonyId;

  /// Recherche à utiliser (tests, autre source) ; par défaut [mentionSearchProvider].
  final MentionSearch? search;
  final double maxSuggestionsHeight;

  @override
  ConsumerState<MentionTextField> createState() => _MentionTextFieldState();
}

enum _Status { idle, loading, ready, error }

class _MentionTextFieldState extends ConsumerState<MentionTextField> {
  static const _debounce = Duration(milliseconds: 300);

  Timer? _timer;
  int _requestId = 0;
  ({String query, int start, int end})? _range;
  List<MentionCandidate> _results = const [];
  _Status _status = _Status.idle;
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant MentionTextField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) _close();
  }

  void _close() {
    _timer?.cancel();
    _requestId++; // toute réponse en cours est ignorée
    if (_range != null || _status != _Status.idle) {
      setState(() {
        _range = null;
        _results = const [];
        _status = _Status.idle;
      });
    }
  }

  void _onChanged() {
    final r = mentionQueryAt(widget.controller.value);
    if (r == null) {
      _close();
      return;
    }
    if (_range?.query == r.query && _range?.start == r.start) return;
    _timer?.cancel();
    final id = ++_requestId;
    setState(() {
      _range = r;
      _status = _Status.loading;
    });
    _timer = Timer(_debounce, () => _run(r.query, id));
  }

  Future<void> _run(String query, int id) async {
    final MentionSearch search = widget.search ?? ref.read(mentionSearchProvider);
    try {
      final results = await search(query, testimonyId: widget.testimonyId);
      if (!mounted || id != _requestId) return; // réponse périmée
      setState(() {
        _results = results;
        _status = _Status.ready;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _status = _Status.error;
      });
    }
  }

  void _choose(MentionCandidate c) {
    final ctrl = widget.controller;
    final r = _range ?? mentionQueryAt(ctrl.value);
    if (r == null) return;
    ctrl.remember(c.ref);
    final insert = '@${c.displayName} ';
    final text = ctrl.text.replaceRange(r.start, r.end, insert);
    _requestId++;
    _timer?.cancel();
    setState(() {
      _range = null;
      _results = const [];
      _status = _Status.idle;
    });
    ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: r.start + insert.length));
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final showPanel = _range != null && _status != _Status.idle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPanel)
          _MentionPanel(
            status: _status,
            results: _results,
            query: _range!.query,
            maxHeight: widget.maxSuggestionsHeight,
            onTap: _choose,
          ),
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          decoration: widget.decoration,
          style: widget.style,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          cursorColor: widget.cursorColor,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

class _MentionPanel extends StatelessWidget {
  const _MentionPanel({
    required this.status,
    required this.results,
    required this.query,
    required this.maxHeight,
    required this.onTap,
  });

  final _Status status;
  final List<MentionCandidate> results;
  final String query;
  final double maxHeight;
  final ValueChanged<MentionCandidate> onTap;

  @override
  Widget build(BuildContext context) {
    Widget message(String text, {Widget? leading}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          ]),
        );

    final Widget body = switch (status) {
      _Status.loading => message(context.l10n.sharedMentionSearching,
          leading: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
      _Status.error => message(context.l10n.sharedMentionSearchError),
      _ when results.isEmpty =>
        message(query.isEmpty ? context.l10n.sharedMentionTypeName : context.l10n.sharedMentionNoMatch(query)),
      _ => ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: results.length,
          itemBuilder: (_, i) => _MentionTile(candidate: results[i], onTap: () => onTap(results[i])),
        ),
    };

    return Material(
      color: AppColors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Semantics(container: true, label: context.l10n.sharedMentionSuggestions, child: body),
      ),
    );
  }
}

class _MentionTile extends StatelessWidget {
  const _MentionTile({required this.candidate, required this.onTap});

  final MentionCandidate candidate;
  final VoidCallback onTap;

  String get _initials {
    if (candidate.initials != null && candidate.initials!.isNotEmpty) return candidate.initials!;
    final parts = candidate.displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first.characters.first + (parts.length > 1 ? parts[1].characters.first : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary.withAlpha(30),
      child: Text(_initials,
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
    );
    final url = candidate.avatarUrl;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            url == null || url.isEmpty
                ? fallback
                : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => fallback,
                      errorWidget: (_, _, _) => fallback,
                    ),
                  ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                candidate.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            if (candidate.approvalBadge case final badge?) AccountApprovalIcon(badge: badge, size: 15),
            const Spacer(),
            if (candidate.isFollowing)
              Text(context.l10n.sharedMentionFollowing, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
