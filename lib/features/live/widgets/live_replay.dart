// Direct terminé : revoir la discussion (messages avec leur moment dans le
// direct) et témoigner sur ce direct (témoignage rattaché, `live_id`).
// Backend : docs/fonctionnalites/lives.md
//   GET /lives/{id}/comments?page=&limit=  (du plus ancien au plus récent, offsetSeconds)
//   GET /lives/{id}/testimonies            (témoignages publiés rattachés)
//   POST /testimonies { …, live_id }       (direct terminé)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/guest_gate.dart' show requireAccount;
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/youtube_video_player.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show testimonyFromApiJson, parsePageMeta;
import '../../home/widgets/compact_testimony_tile.dart';
import '../../publish/providers/publish_provider.dart' show publishLiveProvider;
import '../models/live_models.dart';

/// Message du chat d'un direct terminé, avec son moment dans le direct.
typedef ReplayMessage = ({LiveComment comment, int? offsetSeconds});

/// Page de la discussion d'un direct terminé.
typedef ReplayPage = ({List<ReplayMessage> items, bool hasMore});

Future<ReplayPage> fetchLiveReplay(ApiService api, String liveId, {int page = 1}) async {
  final res = await api.get<dynamic>(AppConstants.liveComments(liveId), query: {'page': page, 'limit': 100});
  final data = res.data;
  final items = <ReplayMessage>[
    for (final m in (data is List ? data : const []))
      if (m is Map)
        (
          comment: LiveComment.fromJson(Map<String, dynamic>.from(m)),
          offsetSeconds: (m['offsetSeconds'] as num?)?.toInt(),
        ),
  ];
  final meta = parsePageMeta(res.meta);
  return (items: items, hasMore: meta.currentPage < meta.lastPage);
}

final liveTestimoniesProvider = FutureProvider.autoDispose.family<List<Testimony>, String>((ref, liveId) async {
  try {
    final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.liveTestimonies(liveId));
    final data = res.data;
    return [for (final t in (data is List ? data : const [])) ?testimonyFromApiJson(t)];
  } on LaravelApiException catch (e) {
    if (e.statusCode == 404) return const [];
    rethrow;
  }
});

/// « 1:02:05 » / « 12:30 ».
String formatLiveOffset(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Section sous le bilan d'un direct terminé.
class LiveAfterwardsSection extends ConsumerWidget {
  const LiveAfterwardsSection({required this.liveId, required this.title, this.youtubeId, super.key});

  final String liveId;
  final String title;

  /// Direct diffusé sur YouTube : la vidéo sert de rediffusion.
  final String? youtubeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final testimonies = ref.watch(liveTestimoniesProvider(liveId)).value ?? const <Testimony>[];
    return Column(
      key: const ValueKey('live-afterwards'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (youtubeId != null) ...[
          const SizedBox(height: 22),
          ClipRRect(
            key: const ValueKey('live-youtube-replay'),
            borderRadius: BorderRadius.circular(14),
            child: YouTubeVideoPlayer(videoId: youtubeId!, autoPlay: false),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          key: const ValueKey('live-testify'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sun,
            foregroundColor: AppColors.primaryDark,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () async {
            if (!await requireAccount(context, ref, reason: l10n.liveTestifyReason)) return;
            ref.read(publishLiveProvider.notifier).attach(liveId, title);
            if (context.mounted) context.go('/publish');
          },
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(l10n.liveTestify),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('live-replay-chat'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
            minimumSize: const Size.fromHeight(46),
          ),
          onPressed: () => showLiveReplaySheet(context, liveId: liveId),
          icon: const Icon(Icons.forum_outlined),
          label: Text(l10n.liveReplayChat),
        ),
        if (testimonies.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(l10n.liveTestimoniesTitle(testimonies.length),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          for (final t in testimonies) ...[
            CompactTestimonyTile(testimony: t),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

Future<void> showLiveReplaySheet(BuildContext context, {required String liveId}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: _ReplaySheet(liveId: liveId)),
    );

class _ReplaySheet extends ConsumerStatefulWidget {
  const _ReplaySheet({required this.liveId});
  final String liveId;

  @override
  ConsumerState<_ReplaySheet> createState() => _ReplaySheetState();
}

class _ReplaySheetState extends ConsumerState<_ReplaySheet> {
  final _items = <ReplayMessage>[];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final p = await fetchLiveReplay(ref.read(apiServiceProvider), widget.liveId, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(p.items);
        _hasMore = p.hasMore;
        _error = null;
      });
    } on LaravelApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.commonError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.liveReplayChat,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _items.isEmpty && !_loading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? l10n.liveReplayEmpty,
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 300) _load();
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _items.length + (_loading ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      if (i >= _items.length) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      final m = _items[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              m.offsetSeconds == null ? '' : formatLiveOffset(m.offsetSeconds!),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.comment.user.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                MentionText(m.comment.body, mentions: m.comment.mentions),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
