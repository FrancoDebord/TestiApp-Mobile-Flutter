import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/media/media_http.dart' show fixMediaUrl;
import '../../../core/app_constants.dart';
import '../../../core/local_db/daos/testimony_dao.dart';
import '../../../core/media/youtube.dart';
import '../../../core/local_db/database_service.dart';
import '../../../services/api_service.dart';
import '../../location/location_providers.dart' show homeFeedPlaceProvider, nearbyLabelsProvider;
import '../../location/user_location.dart' show FeedPlace, parseNearbyLabels;
import '../models/testimony_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/media/video_source.dart' show isHlsUrl;
import '../../../shared/models/account_approval.dart';
import '../../../shared/models/mention.dart' show MentionRef;
import '../../repost/repost.dart' show RepostInfo;

// ============================================================================
// ReactionType enum + extension
// ============================================================================

enum ReactionType { like, pray, love, glory, strong, fire, touched }

extension ReactionTypeInfo on ReactionType {
  String get emoji {
    switch (this) {
      case ReactionType.like:
        return '❤️';
      case ReactionType.pray:
        return '🙏';
      case ReactionType.love:
        return '😍';
      case ReactionType.glory:
        return '🙌';
      case ReactionType.strong:
        return '💪';
      case ReactionType.fire:
        return '🔥';
      case ReactionType.touched:
        return '😢';
    }
  }

  String get label {
    switch (this) {
      case ReactionType.like:
        return L10n.current.detailLike;
      case ReactionType.pray:
        return L10n.current.detailPray;
      case ReactionType.love:
        return L10n.current.homeReactionLove;
      case ReactionType.glory:
        return L10n.current.homeReactionGlory;
      case ReactionType.strong:
        return L10n.current.homeReactionInspiring;
      case ReactionType.fire:
        return L10n.current.homeReactionPowerful;
      case ReactionType.touched:
        return L10n.current.homeReactionTouched;
    }
  }

  /// Valeur envoyée au backend (POST /testimonies/{id}/reactions).
  String get apiValue => switch (this) {
        ReactionType.like    => 'like',
        ReactionType.pray    => 'pray',
        ReactionType.love    => 'love',
        ReactionType.glory   => 'glory',
        ReactionType.strong  => 'strong',
        ReactionType.fire    => 'fire',
        ReactionType.touched => 'touched',
      };
}

// ============================================================================
// Helpers : catégorie API slug ↔ enum Flutter
// ============================================================================

TestimonyCategory _categoryFromApiSlug(String slug) => switch (slug) {
      'guerison'          => TestimonyCategory.guerison,
      'delivrance'        => TestimonyCategory.delivrance,
      'conversion'        => TestimonyCategory.conversion,
      'mariage'           => TestimonyCategory.mariage,
      'famille'           => TestimonyCategory.famille,
      'finances'          => TestimonyCategory.finances,
      'miracles'          => TestimonyCategory.miracles,
      'protection_divine' => TestimonyCategory.protection,
      'protection'        => TestimonyCategory.protection,
      'ministere'         => TestimonyCategory.ministere,
      'salut'             => TestimonyCategory.salut,
      _                   => TestimonyCategory.guerison,
    };

/// Slug envoyé au backend (protection → protection_divine).
String toCategoryApiSlug(TestimonyCategory cat) =>
    cat == TestimonyCategory.protection ? 'protection_divine' : cat.name;

// ============================================================================
// Helper : reconstruit un Testimony avec des stats modifiées (optimistic UI)
// ============================================================================

Testimony _applyStatsDelta(
    Testimony t, int likeDelta, int prayDelta, int commentDelta) {
  final s = t.stats;
  final ns = TestimonyStats(
    views:    s.views,
    comments: (s.comments + commentDelta).clamp(0, 999999),
    likes:    (s.likes    + likeDelta).clamp(0, 999999),
    prayers:  (s.prayers  + prayDelta).clamp(0, 999999),
  );
  if (t is TextTestimony) {
    return TextTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      preview: t.preview, coverImageUrl: t.coverImageUrl,
      bibleVerse: t.bibleVerse, bibleVerseRef: t.bibleVerseRef,
      isFeatured: t.isFeatured, isLiked: t.isLiked,
      isPrayed: t.isPrayed, isSaved: t.isSaved,
      shareUrl: t.shareUrl, proofs: t.proofs,
      mentions: t.mentions, repost: t.repost, myReaction: t.myReaction,
      canDelete: t.canDelete, badges: t.badges, featuredSource: t.featuredSource,
      conversion: t.conversion,
    );
  }
  if (t is AudioTestimony) {
    return AudioTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      durationSeconds: t.durationSeconds, transcriptPreview: t.transcriptPreview,
      transcript: t.transcript, transcriptSegments: t.transcriptSegments,
      mediaPath: t.mediaPath, renditions: t.renditions, renditionsStatus: t.renditionsStatus,
      coverImageUrl: t.coverImageUrl,
      bibleVerse: t.bibleVerse, bibleVerseRef: t.bibleVerseRef,
      isFeatured: t.isFeatured, isLiked: t.isLiked,
      isPrayed: t.isPrayed, isSaved: t.isSaved,
      shareUrl: t.shareUrl, proofs: t.proofs,
      mentions: t.mentions, repost: t.repost, myReaction: t.myReaction,
      canDelete: t.canDelete, badges: t.badges, featuredSource: t.featuredSource,
      conversion: t.conversion,
    );
  }
  if (t is VideoTestimony) {
    return VideoTestimony(
      id: t.id, author: t.author, title: t.title,
      category: t.category, createdAt: t.createdAt, stats: ns,
      durationSeconds: t.durationSeconds, thumbnailUrl: t.thumbnailUrl,
      mediaPath: t.mediaPath, renditions: t.renditions, renditionsStatus: t.renditionsStatus,
      bibleVerse: t.bibleVerse, bibleVerseRef: t.bibleVerseRef,
      youtubeId: t.youtubeId, youtubeCredit: t.youtubeCredit, hlsUrl: t.hlsUrl, mp4Url: t.mp4Url,
      videoStatus: t.videoStatus,
      isFeatured: t.isFeatured, isLiked: t.isLiked,
      isPrayed: t.isPrayed, isSaved: t.isSaved,
      shareUrl: t.shareUrl, proofs: t.proofs,
      mentions: t.mentions, repost: t.repost, myReaction: t.myReaction,
      canDelete: t.canDelete, badges: t.badges, featuredSource: t.featuredSource,
      conversion: t.conversion,
    );
  }
  return t;
}

// ============================================================================
// JSON API → Testimony
// ============================================================================

// Convertit int, double ou String en int (robuste face aux types variables de l'API).
int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

// Convertit une URL relative serveur ("/storage/…") en URL absolue.
String? _absUrl(String? raw) {
  if (raw == null || raw.isEmpty) return raw;
  // Ancien domaine (fichiers d'avant le changement de domaine) → domaine actuel.
  if (raw.startsWith('http://') || raw.startsWith('https://')) return fixMediaUrl(raw);
  final root = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/v1.*$'), '');
  return raw.startsWith('/') ? '$root$raw' : '$root/$raw';
}

/// Identifiant YouTube valide (11 caractères) ou `null`.
String? _validYouTubeId(dynamic raw) {
  final v = raw?.toString() ?? '';
  return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(v) ? v : null;
}

/// Vidéo Bunny Stream d'un témoignage. Format actuel : objet imbriqué
/// `video: { status, playback_url, mp4_url, thumbnail_url, duration }`
/// (+ anciens `hls_url` et `mp4_urls: {"240": url, …}`, `null` sans vidéo).
/// Replis : `hls_url` pour la lecture HLS, la plus haute version de `mp4_urls`
/// pour le MP4 de secours, l'ancien format à plat (`hls_url`, `mp4_urls`,
/// `thumbnail_url`, `video_status` sur le témoignage), et enfin `mediaUrl`
/// quand il contient la playlist `.m3u8`. Un champ absent ou null ne fait
/// jamais échouer la lecture du témoignage.
typedef BunnyVideo = ({
  String? status,
  String? hlsUrl,
  String? mp4Url,
  String? thumbnailUrl,
  List<MediaRendition> mp4,
  int duration,
});

BunnyVideo? parseBunnyVideo(Map<String, dynamic> m) {
  final nested = m['video'];
  final v = nested is Map ? Map<String, dynamic>.from(nested) : m;
  String? str(Map<String, dynamic> from, List<String> keys) {
    for (final k in keys) {
      final x = from[k];
      if (x is String && x.trim().isNotEmpty) return x.trim();
    }
    return null;
  }

  final legacyMedia = str(m, ['mediaUrl', 'media_url']);
  final hls = str(v, ['playback_url', 'playbackUrl', 'hls_url', 'hlsUrl']) ??
      (isHlsUrl(legacyMedia) ? legacyMedia : null);
  final status = nested is Map
      ? str(v, ['status'])
      : str(m, ['video_status', 'videoStatus']);
  if (nested is! Map && hls == null && status == null) return null;

  final mp4 = <MediaRendition>[];
  final raw = v['mp4_urls'] ?? v['mp4Urls'];
  if (raw is Map) {
    raw.forEach((k, url) {
      final h = int.tryParse(RegExp(r'\d+').stringMatch(k.toString()) ?? '') ?? 0;
      final u = url is String ? _absUrl(url.trim()) : null;
      if (h > 0 && u != null && u.isNotEmpty) {
        mp4.add(MediaRendition(url: u, label: '${h}p', height: h));
      }
    });
    mp4.sort((a, b) => a.rank.compareTo(b.rank));
  }
  final mp4Url = str(v, ['mp4_url', 'mp4Url']);
  return (
    status: status,
    hlsUrl: _absUrl(hls),
    mp4Url: _absUrl(mp4Url) ?? (mp4.isNotEmpty ? mp4.last.url : null),
    thumbnailUrl: _absUrl(str(v, ['thumbnail_url', 'thumbnailUrl'])),
    mp4: mp4,
    duration: _parseInt(v['duration']),
  );
}

/// Une vidéo Bunny pas encore prête (processing, failed) est gardée : son état
/// est affiché (badge, message, « Renvoyer la vidéo »). Le serveur ne la
/// renvoie qu'à son auteur et à la modération (listes publiques : `ready`).
Testimony? testimonyFromApiJson(dynamic raw) {
  try {
    final m        = raw as Map<String, dynamic>;
    final userMap  = m['user']  as Map<String, dynamic>? ?? {};
    final statsMap = m['stats'] as Map<String, dynamic>? ?? {};

    // Laravel peut renvoyer camelCase ou snake_case selon la version — on essaie les deux.
    final author = TestimonyAuthor(
      uid:         (userMap['id'] ?? m['userId'] ?? m['user_id'])?.toString() ?? '',
      displayName: (userMap['displayName'] ?? userMap['display_name'])  as String? ?? L10n.current.commonAnonymous,
      avatarUrl:   (userMap['avatarUrl']   ?? userMap['avatar_url'])    as String?,
      isOrganization: ((userMap['accountType'] ?? userMap['account_type'])
              as String?) == 'organization',
      isVerified: (userMap['isVerified'] ?? userMap['is_verified'] ??
              userMap['organization_verified']) as bool? ?? false,
      // Badge « Approuvé » du compte (docs serveur fonctionnalites/badge-approuve.md).
      approvalBadge: AccountApprovalBadge.parse(userMap),
    );
    // Badges du témoignage : "verified" (label « Témoignage approuvé »), "featured"
    // (à la une manuelle). Sans tableau badges : repli sur isVerified pour le label,
    // aucun badge « À la une ».
    final rawBadges = m['badges'];
    final badges = rawBadges is List
        ? {for (final b in rawBadges) '$b'}
        : {if (m['isVerified'] == true || m['is_verified'] == true) 'verified'};
    final featuredSource = (m['featured_source'] ?? m['featuredSource']) as String?;
    final renditions = MediaRendition.parseList(
        m['renditions'] ?? m['mediaRenditions'] ?? m['media_renditions'],
        absUrl: _absUrl);
    final id        = m['id']?.toString() ?? '';
    final title     = m['title']    as String? ?? '';
    final category  = _categoryFromApiSlug(
        (m['category'] ?? m['category_slug']) as String? ?? '');
    final createdAt = DateTime.tryParse(
        (m['createdAt'] ?? m['created_at']) as String? ?? '') ?? DateTime.now();
    final stats = TestimonyStats(
      views:    ((statsMap['viewsCount']    ?? statsMap['views_count'])    as int?) ?? 0,
      likes:    ((statsMap['likesCount']    ?? statsMap['likes_count'])    as int?) ?? 0,
      prayers:  ((statsMap['prayersCount']  ?? statsMap['prayers_count'])  as int?) ?? 0,
      comments: ((statsMap['commentsCount'] ?? statsMap['comments_count']) as int?) ?? 0,
    );
    final isFeatured = (m['isFeatured']       ?? m['is_featured'])                              as bool? ?? false;
    final isLiked    = (m['isLikedByMe']      ?? m['is_liked_by_me']  ?? m['is_liked'])        as bool? ?? false;
    final isPrayed   = (m['isPrayedByMe']     ?? m['is_prayed_by_me'] ?? m['is_prayed'])       as bool? ?? false;
    final isSaved    = (m['isBookmarkedByMe'] ?? m['is_bookmarked_by_me'])                     as bool? ?? false;
    final type          = m['type']                                                            as String? ?? 'text';
    final bibleVerse    = (m['bibleVerse']      ?? m['bible_verse'])                          as String?;
    final bibleVerseRef = (m['verseReference']  ?? m['verse_reference'])                      as String?;
    final shareUrl      = (m['shareUrl']        ?? m['share_url'])                            as String?;
    final youtubeId     = _validYouTubeId(m['youtubeId'] ?? m['youtube_id']);
    // Preuves privées : clé absente pour le public (liste vide).
    final proofs        = TestimonyProof.parseList(m['proofs'], absUrl: _absUrl);
    // Mentions « @ » du texte (docs serveur fonctionnalites/mentions.md).
    final mentions      = MentionRef.listFrom(m['mentions']);
    // « X a partagé » (compte suivi d'abord), réaction choisie et droit de suppression.
    final repost        = RepostInfo.fromFeedItem(m);
    final myReaction    = m['myReaction'] as String?;
    final canDelete     = m['canDelete'] as bool? ?? false;
    // Témoignage de conversion (docs serveur fonctionnalites/temoignage-de-conversion.md).
    final conversion    = ConversionDetails.fromTestimonyJson(m);

    switch (youtubeId != null ? 'video' : type) {
      case 'audio':
        final body = (m['bodyText'] ?? m['body_text']) as String? ?? '';
        return AudioTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          durationSeconds:   _parseInt(m['duration'] ?? m['duration_seconds']),
          transcriptPreview: body.length > 180 ? '${body.substring(0, 180)}…' : body,
          transcript: body,
          transcriptSegments: TranscriptSegment.parseList(
              m['transcriptSegments'] ?? m['transcript_segments']),
          mediaPath:     _absUrl((m['mediaUrl'] ?? m['media_url']) as String?),
          renditions:    renditions,
          renditionsStatus: m['renditionsStatus'] as String?,
          coverImageUrl: (m['coverUrl'] ?? m['cover_url']) as String?,
          bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed, isSaved: isSaved,
          shareUrl: shareUrl, proofs: proofs, mentions: mentions,
          repost: repost, myReaction: myReaction, canDelete: canDelete,
          badges: badges, featuredSource: featuredSource, conversion: conversion,
        );
      case 'video':
        final bunny = youtubeId == null ? parseBunnyVideo(m) : null;
        final duration = _parseInt(m['duration'] ?? m['duration_seconds']);
        final cover = (m['coverUrl'] ?? m['cover_url']);
        final media = (m['mediaUrl'] ?? m['media_url']);
        return VideoTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          durationSeconds: (bunny?.duration ?? 0) > 0 ? bunny!.duration : duration,
          thumbnailUrl:    bunny?.thumbnailUrl ??
              (cover is String && cover.isNotEmpty ? _absUrl(cover) : null) ??
              (youtubeId != null ? youTubeThumbnailUrl(youtubeId) : ''),
          // Ancien fichier (/storage/media/…mp4), sinon le MP4 de secours.
          mediaPath:       _absUrl(media is String && media.isNotEmpty ? media : null) ??
              bunny?.mp4Url,
          renditions:      (bunny?.mp4.isNotEmpty ?? false) ? bunny!.mp4 : renditions,
          renditionsStatus: m['renditionsStatus'] as String?,
          bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          youtubeId: youtubeId,
          youtubeCredit: YouTubeCredit.fromJson(m['youtubeCredit'] ?? m['youtube_credit']),
          hlsUrl: bunny?.hlsUrl,
          mp4Url: bunny?.mp4Url,
          videoStatus: bunny?.status,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed, isSaved: isSaved,
          shareUrl: shareUrl, proofs: proofs, mentions: mentions,
          repost: repost, myReaction: myReaction, canDelete: canDelete,
          badges: badges, featuredSource: featuredSource, conversion: conversion,
        );
      default:
        final body = (m['bodyText'] ?? m['body_text']) as String? ?? '';
        return TextTestimony(
          id: id, author: author, title: title,
          category: category, createdAt: createdAt, stats: stats,
          preview: body, // texte complet : l'affichage gère la troncature
          coverImageUrl: (m['coverUrl'] ?? m['cover_url']) as String?,
          bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          isFeatured: isFeatured, isLiked: isLiked, isPrayed: isPrayed, isSaved: isSaved,
          shareUrl: shareUrl, proofs: proofs, mentions: mentions,
          repost: repost, myReaction: myReaction, canDelete: canDelete,
          badges: badges, featuredSource: featuredSource, conversion: conversion,
        );
    }
  } catch (_) {
    return null;
  }
}

// ============================================================================
// FeedNotifier — liste mutable chargée depuis l'API (+ SQLite en fallback)
// ============================================================================

/// Pagination d'une liste Laravel (`meta` : currentPage, lastPage…).
/// Accepte camelCase ou snake_case ; sans `meta`, une seule page.
({int currentPage, int lastPage}) parsePageMeta(Object? meta) {
  if (meta is! Map) return (currentPage: 1, lastPage: 1);
  final current = _parseInt(meta['currentPage'] ?? meta['current_page']);
  final last    = _parseInt(meta['lastPage'] ?? meta['last_page']);
  final c = current < 1 ? 1 : current;
  return (currentPage: c, lastPage: last < c ? c : last);
}

// ============================================================================
// Tri et filtre du fil (docs serveur fonctionnalites/gestion-des-temoignages.md)
// ============================================================================

/// Tri du fil : `?sort=` de GET /testimonies. Par défaut « Récents » : du plus
/// récent au plus ancien (le plus récent entre aussi « À la une »).
enum FeedSort {
  recent('recent'),
  forYou('for_you'),
  popular('popular'),
  mostViewed('most_viewed');

  const FeedSort(this.apiValue);

  final String apiValue;

  String get label => switch (this) {
        FeedSort.forYou => L10n.current.homeSortForYou,
        FeedSort.recent => L10n.current.homeSortRecent,
        FeedSort.popular => L10n.current.homeSortPopular,
        FeedSort.mostViewed => L10n.current.homeSortMostViewed,
      };
}

/// Tri choisi et filtre « Approuvés » (`?verified=1` : label « Témoignage approuvé »).
///
/// Le fil « Pour vous » (sort=for_you) est calculé à part par le serveur
/// (Recommendations::feed) et ignore `verified` : avec « Approuvés », le tri
/// effectif est donc « Récents ».
@immutable
class FeedQuery {
  const FeedQuery({this.sort = FeedSort.recent, this.verifiedOnly = false});

  final FeedSort sort;
  final bool verifiedOnly;

  /// Tri réellement appliqué (« Pour vous » n'est pas filtrable côté serveur).
  FeedSort get effectiveSort =>
      verifiedOnly && sort == FeedSort.forYou ? FeedSort.recent : sort;

  /// Paramètres de GET /testimonies pour la page [page].
  Map<String, dynamic> toQuery({required int page, int limit = AppConstants.defaultPageSize}) => {
        'sort': effectiveSort.apiValue,
        'limit': limit,
        'page': page,
        if (verifiedOnly) 'verified': 1,
      };

  FeedQuery copyWith({FeedSort? sort, bool? verifiedOnly}) =>
      FeedQuery(sort: sort ?? this.sort, verifiedOnly: verifiedOnly ?? this.verifiedOnly);

  @override
  bool operator ==(Object other) =>
      other is FeedQuery && other.sort == sort && other.verifiedOnly == verifiedOnly;

  @override
  int get hashCode => Object.hash(sort, verifiedOnly);
}

class FeedQueryNotifier extends Notifier<FeedQuery> {
  @override
  FeedQuery build() => const FeedQuery();

  void setSort(FeedSort sort) => state = state.copyWith(sort: sort);

  /// « Approuvés » activé depuis « Pour vous » : passage explicite à « Récents ».
  void setVerifiedOnly(bool value) => state = state.copyWith(
        verifiedOnly: value,
        sort: value && state.sort == FeedSort.forYou ? FeedSort.recent : null,
      );
}

final feedQueryProvider = NotifierProvider<FeedQueryNotifier, FeedQuery>(FeedQueryNotifier.new);

/// Fil d'accueil : GET /testimonies?sort=recent&limit=20&page=N (« Pour vous » : sort=for_you).
/// Tri et filtre « Approuvés » : [feedQueryProvider] (le fil se recharge à chaque changement).
/// Le serveur mélange récents et plus vus pour un nouveau compte, puis classe
/// selon les centres d'intérêt et les comptes suivis.
class FeedNotifier extends Notifier<List<Testimony>> {
  /// Vidéos de l'auteur en cours de traitement, gardées en tête du fil (les
  /// listes du serveur ne contiennent que des vidéos prêtes) jusqu'à la fin
  /// de l'encodage.
  final Map<String, Testimony> _ownProcessing = {};

  int  _page     = 0;
  int  _lastPage = 1;
  bool _loadingMore = false;

  @override
  List<Testimony> build() {
    Future.microtask(_loadFromApi);
    // Nouveau tri ou filtre : rechargement depuis la première page.
    ref.listen(feedQueryProvider, (prev, next) {
      if (prev == next) return;
      _page = 0;
      _lastPage = 1;
      state = const [];
      ref.read(feedIsLoadingProvider.notifier).start();
      unawaited(_loadFromApi());
    });
    return const [];
  }

  /// Reste-t-il des pages à charger ?
  bool get hasMore => _page < _lastPage;

  // ── Chargement depuis l'API ───────────────────────────────────────────────

  Future<LaravelResponse<List<dynamic>>> _fetchPage(int page) =>
      ref.read(apiServiceProvider).get<List<dynamic>>(
        AppConstants.testimonies,
        query: ref.read(feedQueryProvider).toQuery(page: page),
      );

  Future<void> _loadFromApi({bool silent = false}) async {
    try {
      final response = await _fetchPage(1);
      final items = response.data
          .map(testimonyFromApiJson)
          .whereType<Testimony>()
          .toList();
      final meta = parsePageMeta(response.meta);
      _page     = meta.currentPage;
      _lastPage = meta.lastPage;
      _readPlace(response.meta);
      final ids = {for (final t in items) t.id};
      _ownProcessing.removeWhere((id, t) =>
          ids.contains(id) || t is! VideoTestimony || !t.isProcessing);
      state = [..._ownProcessing.values, ...items];
      // Synchronise l'état liked/prayed depuis le serveur.
      ref.read(interactionProvider.notifier).seedFromFeed(items);
    } catch (_) {
      // Hors-ligne ou non authentifié → fallback SQLite (seulement au premier chargement)
      if (!silent) await _loadFromDb();
    } finally {
      if (!silent) ref.read(feedIsLoadingProvider.notifier).done();
    }
  }

  /// Zone utilisée par le classement (« Près de chez vous · Cotonou ») et étiquettes des
  /// cartes proches (meta.place, meta.nearby ; docs serveur : localisation.md).
  void _readPlace(Object? meta, {bool firstPage = true}) {
    if (firstPage) ref.read(homeFeedPlaceProvider.notifier).set(FeedPlace.fromMeta(meta));
    ref.read(nearbyLabelsProvider.notifier).merge(parseNearbyLabels(meta));
  }

  /// Page suivante (défilement infini). Ignoré pendant un chargement en cours
  /// ou quand la dernière page est atteinte.
  Future<void> loadMore() async {
    if (_loadingMore || !hasMore || _page == 0) return;
    _loadingMore = true;
    ref.read(feedLoadingMoreProvider.notifier).set(true);
    try {
      final response = await _fetchPage(_page + 1);
      final known = {for (final t in state) t.id};
      final items = response.data
          .map(testimonyFromApiJson)
          .whereType<Testimony>()
          // Le classement peut évoluer entre deux pages : pas de doublons.
          .where((t) => !known.contains(t.id))
          .toList();
      final meta = parsePageMeta(response.meta);
      _readPlace(response.meta, firstPage: false);
      // Toujours avancer, même si le serveur renvoie une page courante figée.
      _page     = meta.currentPage > _page ? meta.currentPage : _page + 1;
      _lastPage = meta.lastPage;
      if (items.isNotEmpty) {
        state = [...state, ...items];
        ref.read(interactionProvider.notifier).seedFromFeed(items);
      }
    } catch (_) {
      // Réseau indisponible : on réessaiera au prochain défilement.
    } finally {
      _loadingMore = false;
      ref.read(feedLoadingMoreProvider.notifier).set(false);
    }
  }

  /// Ajuste les compteurs en mémoire sans attendre le serveur (optimistic UI).
  void applyOptimisticDelta(String id,
      {int likes = 0, int prayers = 0, int comments = 0}) {
    if (likes == 0 && prayers == 0 && comments == 0) return;
    state = [
      for (final t in state)
        t.id == id ? _applyStatsDelta(t, likes, prayers, comments) : t,
    ];
  }

  // ── Fallback SQLite ───────────────────────────────────────────────────────

  Future<void> _loadFromDb() async {
    try {
      final dao  = TestimonyDao(DatabaseService());
      final rows = await dao.getFeed();
      if (rows.isEmpty) return;

      final fromDb = rows
          .map(_rowToTestimony)
          .whereType<Testimony>()
          .toList();
      if (fromDb.isNotEmpty) state = fromDb;
    } catch (_) {}
  }

  // ── SQLite row → Testimony ────────────────────────────────────────────────

  static Testimony? _rowToTestimony(Map<String, dynamic> row) {
    try {
      final type   = row['type']   as String? ?? 'text';
      final id     = row['id']?.toString() ?? '';
      final author = TestimonyAuthor(
        uid:         row['user_id']?.toString() ?? '',
        displayName: row['author_name']   as String? ?? L10n.current.commonAnonymous,
        avatarUrl:   row['author_avatar'] as String?,
      );
      final title    = row['title']    as String? ?? '';
      final catName  = row['category'] as String? ?? '';
      final category = TestimonyCategory.values
          .firstWhere((c) => c.name == catName,
              orElse: () => TestimonyCategory.guerison);
      final createdAt =
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();
      final stats = TestimonyStats(
        views:    row['views']         as int? ?? 0,
        likes:    row['like_count']    as int? ?? 0,
        prayers:  row['prayer_count']  as int? ?? 0,
        comments: row['comment_count'] as int? ?? 0,
      );

      final bibleVerse    = row['bible_verse'] as String?;
      final bibleVerseRef = row['bible_ref']   as String?;

      switch (type) {
        case 'audio':
          return AudioTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds:   row['duration_sec'] as int? ?? 0,
            transcriptPreview: row['body_text']    as String? ?? '',
            mediaPath:         _absUrl(row['media_url'] as String?),
            bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          );
        case 'video':
          return VideoTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            durationSeconds: row['duration_sec'] as int? ?? 0,
            thumbnailUrl:    row['cover_url']    as String? ?? '',
            mediaPath:       _absUrl(row['media_url'] as String?),
            bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          );
        default:
          final body = row['body_text'] as String? ?? '';
          return TextTestimony(
            id: id, author: author, title: title,
            category: category, createdAt: createdAt, stats: stats,
            preview: body, // texte complet : l'affichage gère la troncature
            bibleVerse: bibleVerse, bibleVerseRef: bibleVerseRef,
          );
      }
    } catch (_) {
      return null;
    }
  }

  // ── Mutations mémoire ─────────────────────────────────────────────────────

  void addTestimony(Testimony testimony) {
    state = [testimony, ...state];
  }

  void removeTestimony(String id) {
    _ownProcessing.remove(id);
    state = state.where((t) => t.id != id).toList();
  }

  /// Remplace un témoignage déjà affiché (vidéo prête ou en échec…). Sans
  /// effet s'il n'est pas dans le fil.
  void replaceTestimony(Testimony testimony) {
    if (_ownProcessing.containsKey(testimony.id)) {
      _ownProcessing[testimony.id] = testimony;
    }
    if (!state.any((t) => t.id == testimony.id)) return;
    state = [for (final t in state) t.id == testimony.id ? testimony : t];
  }

  /// Vidéo de l'auteur affichée « en traitement » en tête du fil dès la fin
  /// de l'envoi (gardée aux rechargements tant que l'encodage dure).
  void showOwnProcessing(Testimony testimony) {
    if (testimony is VideoTestimony && testimony.isProcessing) {
      _ownProcessing[testimony.id] = testimony;
    }
    if (state.any((t) => t.id == testimony.id)) {
      replaceTestimony(testimony);
    } else {
      addTestimony(testimony);
    }
  }

  /// Rafraîchit le feed depuis l'API sans afficher l'état de chargement (appelé en arrière-plan).
  Future<void> refresh() => _loadFromApi(silent: state.isNotEmpty);
}

final feedNotifierProvider =
    NotifierProvider<FeedNotifier, List<Testimony>>(FeedNotifier.new);

/// `true` tant que le premier chargement (API ou SQLite) n'est pas terminé.
/// Utilisé par HomeScreen pour afficher les skeleton cards plutôt que l'état vide.
class _FeedLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void done() => state = false;
  void start() => state = true;
}

final feedIsLoadingProvider =
    NotifierProvider<_FeedLoadingNotifier, bool>(_FeedLoadingNotifier.new);

class _FeedFlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) {
    if (state != value) state = value;
  }
}

/// `true` pendant le chargement d'une page supplémentaire (loader en bas du fil).
final feedLoadingMoreProvider =
    NotifierProvider<_FeedFlagNotifier, bool>(_FeedFlagNotifier.new);

// ============================================================================
// Feed filtré par catégorie (utilisé par HomeScreen)
// ============================================================================

final feedProvider = Provider<List<Testimony>>((ref) {
  final all      = ref.watch(feedNotifierProvider);
  final selected = ref.watch(selectedCategoryProvider);
  final type     = ref.watch(selectedFeedTypeProvider);
  // « Approuvés » : envoyé au serveur (?verified=1) ; filtré aussi ici, au cas où
  // la réponse viendrait du cache local ou d'un serveur qui ignore le paramètre.
  final verifiedOnly = ref.watch(feedQueryProvider.select((q) => q.verifiedOnly));
  if (selected == null && type == null && !verifiedOnly) return all;
  return all
      .where((t) =>
          (selected == null || t.category == selected) &&
          (type == null || t.type == type) &&
          (!verifiedOnly || t.hasApprovedLabel))
      .toList();
});

// ============================================================================
// Filtre par type (onglets « Tous / Vidéos / Audios / Textes » de l'accueil)
// ============================================================================

class _SelectedFeedTypeNotifier extends Notifier<TestimonyType?> {
  @override
  TestimonyType? build() => null;
  void select(TestimonyType? type) => state = type;
}

/// `null` = tous les types.
final selectedFeedTypeProvider =
    NotifierProvider<_SelectedFeedTypeNotifier, TestimonyType?>(
  _SelectedFeedTypeNotifier.new,
);

// ============================================================================
// Featured
// ============================================================================

/// « À la une » du serveur (GET /testimonies/featured), du plus récemment publié au plus
/// ancien (Testimony::latestPublished). Vide hors ligne ou en cas d'erreur.
final featuredFromApiProvider = FutureProvider.autoDispose<List<Testimony>>((ref) async {
  try {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.testimoniesFeatured);
    final list = res.data is List ? res.data as List : const [];
    return [for (final raw in list) ?testimonyFromApiJson(raw)];
  } catch (_) {
    return const [];
  }
});

/// « À la une », du plus récent au plus ancien : la liste du serveur (déjà triée ; le
/// témoignage publié le plus récent y entre toujours), sinon, hors ligne, les
/// témoignages à la une du fil chargé plus le plus récent, triés par date décroissante.
final featuredProvider = Provider<List<Testimony>>((ref) {
  final fromApi = ref.watch(featuredFromApiProvider).value ?? const <Testimony>[];
  if (fromApi.isNotEmpty) return fromApi;
  final feed = ref.watch(feedNotifierProvider);
  if (feed.isEmpty) return const [];
  final newest = feed.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
  return {newest, ...feed.where((t) => t.isFeatured)}.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

// ============================================================================
// Interactions : likes, prières, réactions emoji — avec appels API
// ============================================================================

/// Compteurs « j'aime » et « je prie » à jour (réponse du serveur ou mise à jour optimiste).
typedef TestimonyCounts = ({int likes, int prayers});

/// Réaction de l'application ← valeur de l'API (`myReaction`). `amen` : anciennes réactions « Gloire ».
ReactionType? reactionTypeFromApi(String? value) => switch (value) {
      'like'    => ReactionType.like,
      'love'    => ReactionType.love,
      'glory'   => ReactionType.glory,
      'amen'    => ReactionType.glory,
      'strong'  => ReactionType.strong,
      'fire'    => ReactionType.fire,
      'touched' => ReactionType.touched,
      _         => null,
    };

/// État des réactions de la personne connectée.
///
/// Le serveur fait foi (docs serveur fonctionnalites/reactions.md) : une seule réaction « j'aime »
/// (like, love, fire…) et une seule « je prie » par personne et par témoignage. Tant qu'un
/// témoignage n'a pas été touché ici (`known`), on lit l'état renvoyé par l'API dans le modèle
/// (`isLiked`, `myReaction`, `stats`) ; ensuite, l'état local (mis à jour par la réponse du serveur).
class TestimonyInteractions {
  const TestimonyInteractions({
    this.liked     = const {},
    this.prayed    = const {},
    this.saved     = const {},
    this.reactions = const {},
    this.counts    = const {},
    this.known     = const {},
  });

  final Set<String> liked;
  final Set<String> prayed;
  final Set<String> saved;
  final Map<String, ReactionType> reactions;
  final Map<String, TestimonyCounts> counts;

  /// Témoignages dont l'état local fait foi (réaction posée ici ou réponse du serveur reçue).
  final Set<String> known;

  bool likedOf(Testimony t) => known.contains(t.id) ? liked.contains(t.id) : t.isLiked;
  bool prayedOf(Testimony t) => known.contains(t.id) ? prayed.contains(t.id) : t.isPrayed;

  ReactionType? reactionOf(Testimony t) {
    if (known.contains(t.id)) return reactions[t.id];
    return reactionTypeFromApi(t.myReaction) ?? (t.isLiked ? ReactionType.like : null);
  }

  int likesOf(Testimony t) => counts[t.id]?.likes ?? t.stats.likes;
  int prayersOf(Testimony t) => counts[t.id]?.prayers ?? t.stats.prayers;

  TestimonyInteractions copyWith({
    Set<String>? liked,
    Set<String>? prayed,
    Set<String>? saved,
    Map<String, ReactionType>? reactions,
    Map<String, TestimonyCounts>? counts,
    Set<String>? known,
  }) =>
      TestimonyInteractions(
        liked:     liked     ?? this.liked,
        prayed:    prayed    ?? this.prayed,
        saved:     saved     ?? this.saved,
        reactions: reactions ?? this.reactions,
        counts:    counts    ?? this.counts,
        known:     known     ?? this.known,
      );

  /// Nouvel état d'un témoignage (les autres sont conservés).
  TestimonyInteractions withEntry(
    String id, {
    required bool liked,
    required bool prayed,
    required ReactionType? reaction,
    required TestimonyCounts counts,
  }) {
    final r = Map<String, ReactionType>.from(reactions);
    if (reaction == null) {
      r.remove(id);
    } else {
      r[id] = reaction;
    }
    return copyWith(
      liked: liked ? {...this.liked, id} : ({...this.liked}..remove(id)),
      prayed: prayed ? {...this.prayed, id} : ({...this.prayed}..remove(id)),
      reactions: r,
      counts: {...this.counts, id: counts},
      known: {...known, id},
    );
  }
}

class InteractionNotifier extends Notifier<TestimonyInteractions> {
  /// Dernière requête envoyée par témoignage : une réponse plus ancienne est ignorée.
  final _requests = <String, int>{};

  @override
  TestimonyInteractions build() => const TestimonyInteractions();

  // ── Seed depuis le serveur (appelé après chaque chargement du feed) ─────────

  /// État frais renvoyé par l'API : remplace l'état local de ces témoignages,
  /// sauf ceux dont une réaction est en cours d'envoi.
  void seedFromFeed(List<Testimony> testimonies) {
    var next = state;
    final saved = {...state.saved};
    for (final t in testimonies) {
      if (t.isSaved) saved.add(t.id);
      if (_requests.containsKey(t.id)) continue;
      next = next.withEntry(
        t.id,
        liked: t.isLiked,
        prayed: t.isPrayed,
        reaction: reactionTypeFromApi(t.myReaction) ?? (t.isLiked ? ReactionType.like : null),
        counts: (likes: t.stats.likes, prayers: t.stats.prayers),
      );
    }
    state = next.copyWith(saved: saved);
  }

  // ── Réactions « j'aime » (une seule à la fois) ───────────────────────────

  /// Pose la réaction [type] (remplace la précédente) ou la retire si null.
  /// Le compteur ne change que si la personne passe de « aucune » à « une » réaction.
  void react(Testimony t, ReactionType? type) {
    final wasLiked = state.likedOf(t);
    final isLiked = type != null;
    final likes = state.likesOf(t) + (isLiked == wasLiked ? 0 : (isLiked ? 1 : -1));
    _optimistic(t, liked: isLiked, reaction: type, likes: likes < 0 ? 0 : likes);
    _send(t, () {
      final api = ref.read(apiServiceProvider);
      return type != null
          ? api.post<Map<String, dynamic>>(AppConstants.testimonyReactions(t.id), data: {'type': type.apiValue})
          : api.delete<Map<String, dynamic>>(AppConstants.testimonyReactions(t.id), query: const {'group': 'appreciation'});
    });
  }

  /// Appui simple sur le cœur : retire la réaction posée, sinon « J'aime ».
  void toggleLike(Testimony t) => react(t, state.likedOf(t) ? null : ReactionType.like);

  // ── Prière (une seule « je prie ») ────────────────────────────────────────

  void togglePray(Testimony t) {
    final prayed = !state.prayedOf(t);
    final prayers = state.prayersOf(t) + (prayed ? 1 : -1);
    _optimistic(t, prayed: prayed, prayers: prayers < 0 ? 0 : prayers);
    _send(t, () {
      final api = ref.read(apiServiceProvider);
      return prayed
          ? api.post<Map<String, dynamic>>(AppConstants.testimonyReactions(t.id), data: const {'type': 'pray'})
          : api.delete<Map<String, dynamic>>(AppConstants.testimonyReactions(t.id), query: const {'group': 'prayer'});
    });
  }

  bool isLiked(Testimony t) => state.likedOf(t);
  bool isPrayed(Testimony t) => state.prayedOf(t);

  void _optimistic(Testimony t, {bool? liked, bool? prayed, ReactionType? reaction, int? likes, int? prayers}) {
    final s = state;
    state = s.withEntry(
      t.id,
      liked: liked ?? s.likedOf(t),
      prayed: prayed ?? s.prayedOf(t),
      reaction: liked == null ? s.reactionOf(t) : reaction,
      counts: (likes: likes ?? s.likesOf(t), prayers: prayers ?? s.prayersOf(t)),
    );
  }

  /// Envoie la requête ; la réponse (état et compteurs du serveur) remplace l'état optimiste.
  /// En cas d'échec, l'état d'avant est rétabli.
  Future<void> _send(Testimony t, Future<LaravelResponse<Map<String, dynamic>>> Function() call) async {
    final before = state;
    final request = (_requests[t.id] ?? 0) + 1;
    _requests[t.id] = request;
    try {
      final res = await call();
      if (_requests[t.id] != request) return;
      final d = res.data;
      final s = state;
      state = s.withEntry(
        t.id,
        liked: d['isLikedByMe'] as bool? ?? s.likedOf(t),
        prayed: d['isPrayedByMe'] as bool? ?? s.prayedOf(t),
        reaction: d.containsKey('myReaction') ? reactionTypeFromApi(d['myReaction'] as String?) : s.reactionOf(t),
        counts: (
          likes: (d['likesCount'] as num?)?.toInt() ?? s.likesOf(t),
          prayers: (d['prayersCount'] as num?)?.toInt() ?? s.prayersOf(t),
        ),
      );
    } catch (e) {
      debugPrint('réaction ✗ $e');
      if (_requests[t.id] == request) {
        // Rétablit seulement ce témoignage.
        state = state.withEntry(
          t.id,
          liked: before.likedOf(t),
          prayed: before.prayedOf(t),
          reaction: before.reactionOf(t),
          counts: (likes: before.likesOf(t), prayers: before.prayersOf(t)),
        );
      }
    } finally {
      if (_requests[t.id] == request) _requests.remove(t.id);
    }
  }

  // ── Sauvegarde ────────────────────────────────────────────────────────────

  void toggleSave(String id) {
    final saved = {...state.saved};
    if (saved.contains(id)) {
      saved.remove(id);
      state = state.copyWith(saved: saved);
      _callApi(() async {
        final api = ref.read(apiServiceProvider);
        await api.delete<void>(AppConstants.testimonyUnsave(id));
      });
    } else {
      saved.add(id);
      state = state.copyWith(saved: saved);
      _callApi(() async {
        final api = ref.read(apiServiceProvider);
        await api.put<void>(AppConstants.testimonySave(id));
      });
    }
  }

  // ── Partage (fire-and-forget, incrémente share_count côté serveur) ───────────

  void recordShare(String id) {
    _callApi(() async {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(AppConstants.testimonyShare(id));
    });
  }

  bool isSaved(String id)  => state.saved.contains(id);

  Future<void> _callApi(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }
}

final interactionProvider =
    NotifierProvider<InteractionNotifier, TestimonyInteractions>(
        InteractionNotifier.new);

final savedIdsProvider =
    Provider<Set<String>>((ref) => ref.watch(interactionProvider).saved);

// ============================================================================
// Filtre de catégorie
// ============================================================================

class _SelectedCategoryNotifier extends Notifier<TestimonyCategory?> {
  @override
  TestimonyCategory? build() => null;
  void select(TestimonyCategory? category) => state = category;
}

final selectedCategoryProvider =
    NotifierProvider<_SelectedCategoryNotifier, TestimonyCategory?>(
  _SelectedCategoryNotifier.new,
);

// ============================================================================
// Verset du jour
// ============================================================================

const _kFallbackVerse = DailyVerse(
  text: '« Car je connais les projets que j\'ai formés sur vous, dit l\'Éternel, ' // i18n-ignore
      'projets de paix et non de malheur, afin de vous donner un avenir et de l\'espérance. »', // i18n-ignore
  reference: 'Jérémie 29 : 11', // i18n-ignore
);

class DailyVerseNotifier extends AsyncNotifier<DailyVerse> {
  @override
  Future<DailyVerse> build() async {
    // 1. Try network first
    try {
      final api    = ref.read(apiServiceProvider);
      final result = await api.get<Map<String, dynamic>>(AppConstants.verseToday);
      final verse  = DailyVerse.fromJson(result.data);
      if (verse.text.isNotEmpty) {
        await _saveToCache(verse);
        return verse;
      }
    } catch (_) {}

    // 2. Fallback to today's cached verse
    try {
      final cached = await _loadFromCache();
      if (cached != null) return cached;
    } catch (e) {
      debugPrint('DailyVerse cache read error: $e');
    }

    // 3. Hard-coded fallback
    return _kFallbackVerse;
  }

  // ── Cache helpers (one file per calendar date) ────────────────────────────

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/daily_verse_${_todayKey()}.json');
  }

  Future<DailyVerse?> _loadFromCache() async {
    final file = await _cacheFile();
    if (!file.existsSync()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final verse = DailyVerse.fromJson(json);
    return verse.text.isNotEmpty ? verse : null;
  }

  Future<void> _saveToCache(DailyVerse verse) async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode({
        'id':            verse.id,
        'text':          verse.text,
        'reference':     verse.reference,
        'like_count':    verse.likeCount,
        'prayer_count':  verse.prayerCount,
        'is_liked':      verse.isLiked,
        'is_prayed':     verse.isPrayed,
        'comment_count': verse.commentCount,
        // Hors connexion le même jour : design du jour du serveur (pas les
        // préférences du membre, gardées dans shared_preferences).
        'design_of_the_day': verse.designOfTheDay,
      }));
    } catch (e) {
      debugPrint('DailyVerse cache write error: $e');
    }
  }

  /// Relit le verset du jour sur le serveur sans indicateur de chargement :
  /// « J'aime », « Je prie » et commentaires faits ailleurs (site, autre
  /// téléphone) apparaissent dans l'application. Erreur réseau : rien ne change.
  Future<void> refresh() async {
    try {
      final result = await ref.read(apiServiceProvider).get<Map<String, dynamic>>(AppConstants.verseToday);
      final verse = DailyVerse.fromJson(result.data);
      if (verse.text.isEmpty || !ref.mounted) return;
      state = AsyncValue.data(verse);
      await _saveToCache(verse);
    } catch (_) {}
  }

  Future<void> toggleLike() => _react('like');

  /// « Je prie » : l'écran appelant ouvre d'abord le temps de prière
  /// (`prayForDailyVerse`), comme partout ailleurs.
  Future<void> togglePray() => _react('pray');

  /// Réaction posée ou retirée ; la réponse du serveur (compteurs et réactions à jour,
  /// y compris celles faites ailleurs) remplace l'état optimiste.
  Future<void> _react(String type) async {
    final verse = state.value;
    if (verse == null) return;
    final like = type == 'like';
    final was = like ? verse.isLiked : verse.isPrayed;
    state = AsyncValue.data(like
        ? verse.copyWith(isLiked: !was, likeCount: (verse.likeCount + (was ? -1 : 1)).clamp(0, 1 << 30))
        : verse.copyWith(isPrayed: !was, prayerCount: (verse.prayerCount + (was ? -1 : 1)).clamp(0, 1 << 30)));
    try {
      final api = ref.read(apiServiceProvider);
      if (verse.id > 0) {
        // POST /daily-verse/{id}/react { type, active } → verset complet à jour.
        final res = await api.post<Map<String, dynamic>>(
          AppConstants.verseReactTo(verse.id),
          data: {'type': type, 'active': !was},
        );
        final fresh = DailyVerse.fromJson(res.data);
        if (fresh.text.isNotEmpty && ref.mounted) {
          state = AsyncValue.data(fresh);
          await _saveToCache(fresh);
        }
      } else if (was) {
        await api.delete<void>(AppConstants.verseReact, data: {'type': type});
      } else {
        await api.post<void>(AppConstants.verseReact, data: {'type': type});
      }
    } catch (_) {
      if (ref.mounted) state = AsyncValue.data(verse);
    }
  }

  Future<void> recordShare() async {
    final verse = state.value;
    if (verse == null) return;
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(AppConstants.verseShare);
    } catch (_) {}
  }
}

final dailyVerseProvider =
    AsyncNotifierProvider<DailyVerseNotifier, DailyVerse>(
  DailyVerseNotifier.new,
);

// ============================================================================
// Bannière verset — état étendu/replié
// ============================================================================

class _VerseBannerNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void update(bool value) => state = value;
}

final verseBannerExpandedProvider =
    NotifierProvider<_VerseBannerNotifier, bool>(_VerseBannerNotifier.new);
