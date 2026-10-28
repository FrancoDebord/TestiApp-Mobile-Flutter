// « Qui a réagi ? » : effectif de chaque réaction (j'aime, je prie…) d'une publication et
// personnes qui ont réagi, avec le nombre de fois qu'elles ont prié ; onglet « Commentaires »
// (« Encouragements » pour une requête de prière) : qui a commenté, et quoi.
// API : GET {publication}/{id}/reactions/people?type=&page= (type=comments : `comments`)
// Doc serveur : fonctionnalites/qui-a-reagi.md, prier-plusieurs-fois.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../events/widgets/manager_widgets.dart' show PersonAvatar;
import '../home/providers/home_providers.dart' show parsePageMeta;
import '../home/widgets/testimony_action_bar.dart' show formatCount;

/// Publication dont on liste les réactions (segment d'URL de l'API).
enum ReactionSubject {
  testimony('/testimonies'),
  event('/events'),
  prayerRequest('/prayer/requests'),
  prayerSession('/prayer/sessions'),
  dailyVerse('/daily-verse');

  const ReactionSubject(this.prefix);
  final String prefix;

  String peoplePath(String id) => '$prefix/$id/reactions/people';

  /// Libellé de l'onglet des commentaires (« Encouragements » pour une requête de prière).
  String get commentsLabel =>
      this == ReactionSubject.prayerRequest ? L10n.current.reactionPeopleEncouragements : L10n.current.detailComments;
}

/// Effectif d'une réaction présente (`summary.types`).
class ReactionTypeCount {
  const ReactionTypeCount({required this.type, required this.group, required this.label, required this.emoji, required this.count});

  final String type;
  final String group;
  final String label;
  final String emoji;
  final int count;

  static ReactionTypeCount? fromJson(Object? raw) {
    if (raw is! Map || raw['type'] is! String) return null;
    return ReactionTypeCount(
      type: raw['type'] as String,
      group: raw['group'] as String? ?? '',
      label: raw['label'] as String? ?? raw['type'] as String,
      emoji: raw['emoji'] as String? ?? '',
      count: raw['count'] is num ? (raw['count'] as num).toInt() : 0,
    );
  }
}

/// Effectifs : personnes au total, par groupe et par réaction.
class ReactionSummary {
  const ReactionSummary({
    this.total = 0,
    this.likesCount = 0,
    this.prayersCount = 0,
    this.commentsCount = 0,
    this.types = const [],
  });

  final int total;
  final int likesCount;
  final int prayersCount;

  /// Commentaires visibles (onglet « Commentaires » ; 0 pour une session de prière).
  final int commentsCount;
  final List<ReactionTypeCount> types;

  static ReactionSummary fromJson(Object? raw) {
    if (raw is! Map) return const ReactionSummary();
    int n(Object? v) => v is num ? v.toInt() : 0;
    return ReactionSummary(
      total: n(raw['total']),
      likesCount: n(raw['likesCount']),
      prayersCount: n(raw['prayersCount']),
      commentsCount: n(raw['commentsCount']),
      types: [
        if (raw['types'] is List)
          for (final t in raw['types'] as List)
            ?ReactionTypeCount.fromJson(t),
      ],
    );
  }

  String emojiOf(String type) {
    for (final t in types) {
      if (t.type == type) return t.emoji;
    }
    return '';
  }
}

/// Personne qui a réagi, avec toutes ses réactions et le nombre de fois qu'elle a prié.
class ReactionPerson {
  const ReactionPerson({
    required this.id,
    required this.displayName,
    this.initials,
    this.avatarUrl,
    this.isVerified = false,
    this.reactions = const [],
    this.prayerTimes = 0,
  });

  final String id;
  final String displayName;
  final String? initials;
  final String? avatarUrl;
  final bool isVerified;
  final List<String> reactions;
  final int prayerTimes;

  static ReactionPerson? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final avatar = raw['avatarUrl'] as String?;
    return ReactionPerson(
      id: '${raw['id']}',
      displayName: raw['displayName'] as String? ?? '',
      initials: raw['initials'] as String?,
      avatarUrl: avatar == null || avatar.isEmpty ? null : avatar,
      isVerified: raw['isVerified'] == true,
      reactions: [if (raw['reactions'] is List) for (final r in raw['reactions'] as List) '$r'],
      prayerTimes: raw['prayerTimes'] is num ? (raw['prayerTimes'] as num).toInt() : 0,
    );
  }
}

/// Commentaire de l'onglet « Commentaires » : qui, quoi, quand.
class ReactionComment {
  const ReactionComment({required this.id, required this.body, required this.author, this.createdAt});

  final String id;
  final String body;
  final ReactionPerson author;
  final DateTime? createdAt;

  static ReactionComment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final author = ReactionPerson.fromJson(raw['user']);
    if (author == null) return null;
    return ReactionComment(
      id: '${raw['id']}',
      body: raw['body'] as String? ?? '',
      author: author,
      createdAt: DateTime.tryParse(raw['createdAt'] as String? ?? ''),
    );
  }
}

/// Une page de personnes ou de commentaires (et les effectifs, toujours pour toutes les réactions).
typedef ReactionPeoplePage = ({
  ReactionSummary summary,
  List<ReactionPerson> people,
  List<ReactionComment> comments,
  int lastPage,
});

/// GET …/reactions/people. [type] : null (toutes), un groupe (appreciation, prayer), une réaction
/// ou `comments`.
Future<ReactionPeoplePage> fetchReactionPeople(ApiService api, String path, {String? type, int page = 1}) async {
  final res = await api.get<dynamic>(path, query: {'type': ?type, 'page': page});
  final data = res.data is Map ? res.data as Map : const {};
  return (
    summary: ReactionSummary.fromJson(data['summary']),
    people: [
      if (data['people'] is List)
        for (final p in data['people'] as List)
          ?ReactionPerson.fromJson(p),
    ],
    comments: [
      if (data['comments'] is List)
        for (final c in data['comments'] as List)
          ?ReactionComment.fromJson(c),
    ],
    lastPage: parsePageMeta(res.meta).lastPage,
  );
}

/// Ouvre la feuille « Qui a réagi ? » sur [initialType] (null : toutes ; `prayer` : ceux qui prient).
Future<void> showReactionPeople(
  BuildContext context, {
  required ReactionSubject subject,
  required String id,
  String? initialType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheet) {
      // Affichage bord à bord (Android 15) : la barre de navigation du téléphone
      // recouvre le bas de la feuille (useSafeArea ne protège que le haut). Le
      // contenu est remonté au-dessus d'elle, avec une marge, et la feuille garde
      // une hauteur minimale pour ne jamais rester collée au bas de l'écran.
      final height = MediaQuery.sizeOf(sheet).height;
      final bottom = MediaQuery.viewPaddingOf(sheet).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom + 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height * 0.4,
            maxHeight: height * 0.75 - bottom,
          ),
          child: ReactionPeopleSheet(
            path: subject.peoplePath(id),
            initialType: initialType,
            commentsLabel: subject.commentsLabel,
            // Pas de commentaires sur une session de prière.
            hasComments: subject != ReactionSubject.prayerSession,
          ),
        ),
      );
    },
  );
}

class ReactionPeopleSheet extends ConsumerStatefulWidget {
  const ReactionPeopleSheet({
    required this.path,
    this.initialType,
    this.commentsLabel,
    this.hasComments = true,
    super.key,
  });

  /// Filtre de l'onglet des commentaires (API).
  static const commentsType = 'comments';

  final String path;
  final String? initialType;

  /// « Commentaires » ou « Encouragements » (requête de prière).
  final String? commentsLabel;

  /// Onglet des commentaires, toujours visible (même à 0) sauf pour une session de prière.
  final bool hasComments;

  @override
  ConsumerState<ReactionPeopleSheet> createState() => _ReactionPeopleSheetState();
}

class _ReactionPeopleSheetState extends ConsumerState<ReactionPeopleSheet> {
  ReactionSummary? _summary;
  late String? _type = widget.initialType;
  final _people = <ReactionPerson>[];
  final _comments = <ReactionComment>[];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _error = false;

  /// Requête en cours (un changement d'onglet ignore la réponse précédente).
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = false;
      if (reset) {
        _people.clear();
        _comments.clear();
        _page = 0;
        _lastPage = 1;
      }
    });
    try {
      final res = await fetchReactionPeople(ref.read(apiServiceProvider), widget.path, type: _type, page: _page + 1);
      if (!mounted || request != _request) return;
      setState(() {
        _summary = res.summary;
        // Groupe d'une seule réaction (que des « je prie ») : l'onglet de cette réaction, même liste.
        final ofGroup = [for (final t in res.summary.types) if (t.group == _type) t.type];
        if (ofGroup.length == 1) _type = ofGroup.single;
        _people.addAll(res.people);
        _comments.addAll(res.comments);
        _page += 1;
        _lastPage = res.lastPage;
        _loading = false;
      });
    } catch (e) {
      debugPrint('qui a réagi ✗ $e');
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _select(String? type) {
    if (type == _type) return;
    _type = type;
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = _summary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(l10n.reactionPeopleTitle, style: AppTextStyles.h4),
        ),
        // Onglets à la ligne (jamais de défilement horizontal) ; « Commentaires » juste après
        // « Toutes », toujours visible — comme le popup du site.
        if (summary != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tab(null, l10n.reactionPeopleAll, summary.total),
                if (widget.hasComments)
                  _tab(ReactionPeopleSheet.commentsType, '💬 ${widget.commentsLabel ?? l10n.detailComments}',
                      summary.commentsCount),
                // Ouvert sur un groupe (« Je prie » : pray, amen, worship) : son onglet.
                if (_type == 'prayer') _tab('prayer', '🙏 ${l10n.detailPray}', summary.prayersCount),
                if (_type == 'appreciation') _tab('appreciation', '❤️ ${l10n.detailLike}', summary.likesCount),
                for (final t in summary.types) _tab(t.type, '${t.emoji} ${t.label}', t.count),
              ],
            ),
          ),
        const Divider(height: 16),
        Flexible(child: _body(context)),
      ],
    );
  }

  Widget _tab(String? type, String label, int count) => ChoiceChip(
        label: Text('$label  ${formatCount(count)}'),
        selected: _type == type,
        onSelected: (_) => _select(type),
      );

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final comments = _type == ReactionPeopleSheet.commentsType;
    final count = comments ? _comments.length : _people.length;
    if (count == 0) {
      if (_loading) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                _error
                    ? l10n.reactionPeopleError
                    : (comments ? l10n.reactionPeopleEmptyComments : l10n.reactionPeopleEmpty),
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            if (_error) TextButton(onPressed: () => _load(reset: true), child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    final more = _page < _lastPage;
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: count + (more || _error ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == count) {
          return Center(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                : TextButton(onPressed: _load, child: Text(_error ? l10n.commonRetry : l10n.reactionPeopleMore)),
          );
        }
        if (comments) return _commentTile(context, _comments[i]);
        final p = _people[i];
        return ListTile(
          leading: PersonAvatar(name: p.displayName, url: p.avatarUrl, initials: p.initials, size: 38),
          title: Row(
            children: [
              Flexible(child: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (p.isVerified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified_rounded, size: 15, color: AppColors.primary, semanticLabel: l10n.communityVerifiedAccount),
              ],
            ],
          ),
          subtitle: p.prayerTimes >= 2 ? Text(l10n.reactionPeoplePrayedTimes(p.prayerTimes)) : null,
          trailing: Text(
            [for (final r in p.reactions) _summary?.emojiOf(r) ?? ''].where((e) => e.isNotEmpty).join(' '),
            style: const TextStyle(fontSize: 18),
          ),
          onTap: () => _openProfile(context, p.id),
        );
      },
    );
  }

  void _openProfile(BuildContext context, String userId) {
    Navigator.of(context).pop();
    GoRouter.maybeOf(context)?.push('/users/$userId');
  }

  /// Qui a commenté (vers son profil), quand, et son message.
  Widget _commentTile(BuildContext context, ReactionComment c) {
    final a = c.author;
    return ListTile(
      leading: PersonAvatar(name: a.displayName, url: a.avatarUrl, initials: a.initials, size: 38),
      title: Row(
        children: [
          Flexible(child: Text(a.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (a.isVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified_rounded, size: 15, color: AppColors.primary, semanticLabel: context.l10n.communityVerifiedAccount),
          ],
          if (c.createdAt != null) ...[
            const SizedBox(width: 6),
            Text('· ${formatTimeAgo(c.createdAt!)}',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(c.body, maxLines: 6, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.35)),
      ),
      onTap: () => _openProfile(context, a.id),
    );
  }
}

/// Bouton « Qui a réagi ? » (icône personnes), à côté des réactions.
class ReactionPeopleButton extends StatelessWidget {
  const ReactionPeopleButton({required this.subject, required this.id, this.initialType, this.size = 20, super.key});

  final ReactionSubject subject;
  final String id;
  final String? initialType;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.reactionPeopleTitle,
      visualDensity: VisualDensity.compact,
      onPressed: () => showReactionPeople(context, subject: subject, id: id, initialType: initialType),
      icon: Icon(Icons.groups_outlined, size: size, color: AppColors.textSecondary),
    );
  }
}
