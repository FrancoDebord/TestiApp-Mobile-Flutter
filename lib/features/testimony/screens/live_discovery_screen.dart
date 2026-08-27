// lib/features/testimony/screens/live_discovery_screen.dart
//
// VIEWER perspective — discover and watch live testimonies.
//
// Widget tree:
//   LiveDiscoveryScreen (ConsumerStatefulWidget)
//   ├─ AppBar  ("En Direct" + red dot + go-live icon)
//   └─ body
//      ├─ GridView  (live cards from API)
//      │  └─ _LiveCard (thumbnail gradient, badges, author info)
//      └─ on tap → _LiveViewerScreen

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/api_service.dart' show apiServiceProvider;
import 'live_screen.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class LiveStream {
  const LiveStream({
    required this.id,
    required this.authorName,
    required this.title,
    required this.category,
    required this.viewerCount,
    required this.gradientColors,
    required this.initials,
    this.thumbnailUrl,
  });

  final String id;
  final String authorName;
  final String title;
  final String category;
  final int viewerCount;
  final List<Color> gradientColors;
  final String initials;
  final String? thumbnailUrl;

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static List<Color> _gradientForCategory(String slug) => switch (slug) {
    'guerison'          => AppColors.guerisonGradient,
    'delivrance'        => AppColors.delivranceGradient,
    'conversion'        => AppColors.conversionGradient,
    'mariage'           => AppColors.mariageGradient,
    'famille'           => AppColors.familleGradient,
    'finances'          => AppColors.financesGradient,
    'miracles'          => AppColors.miraclesGradient,
    'protection_divine' => AppColors.protectionGradient,
    'ministere'         => AppColors.ministereGradient,
    'salut'             => AppColors.salutGradient,
    _                   => AppColors.guerisonGradient,
  };

  factory LiveStream.fromJson(Map<String, dynamic> m) {
    final author  = m['user'] as Map<String, dynamic>? ?? {};
    final name    = (author['display_name'] ?? author['displayName'] ?? 'Anonyme') as String;
    final catSlug = (m['category'] ?? '') as String;
    return LiveStream(
      id:           m['id']?.toString() ?? '',
      authorName:   name,
      title:        m['title'] as String? ?? '',
      category:     m['category_label'] as String? ?? catSlug,
      viewerCount:  (m['viewer_count'] ?? m['viewerCount'] ?? 0) as int,
      gradientColors: _gradientForCategory(catSlug),
      initials:     _initials(name),
      thumbnailUrl: m['thumbnail_url'] as String?,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final liveStreamsProvider =
    AsyncNotifierProvider<_LiveStreamsNotifier, List<LiveStream>>(
        _LiveStreamsNotifier.new);

class _LiveStreamsNotifier extends AsyncNotifier<List<LiveStream>> {
  @override
  Future<List<LiveStream>> build() => _fetch();

  Future<List<LiveStream>> _fetch() async {
    try {
      final api      = ref.read(apiServiceProvider);
      final response = await api.get<dynamic>(AppConstants.liveStreams);
      final raw      = response.data;
      final items    = raw is List
          ? raw
          : raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(LiveStream.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

// =============================================================================
// LiveDiscoveryScreen
// =============================================================================

class LiveDiscoveryScreen extends ConsumerWidget {
  const LiveDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStreams = ref.watch(liveStreamsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingDot(),
            const SizedBox(width: 8),
            Text('En Direct', style: AppTextStyles.h3),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Démarrer un live',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_a_photo_rounded, size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LiveScreen(),
                  fullscreenDialog: true,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: asyncStreams.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (err, st) => _buildEmptyState(context, ref),
        data:    (lives) => lives.isEmpty
            ? _buildEmptyState(context, ref)
            : _buildGrid(context, lives),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.live_tv_outlined,
              size: 64, color: AppColors.textSecondary.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'Aucun live en cours',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Revenez plus tard ou démarrez votre propre live.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                ref.read(liveStreamsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Actualiser',
                style: TextStyle(fontFamily: 'Inter')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<LiveStream> lives) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.danger.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.danger, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${lives.length} témoignage${lives.length > 1 ? 's' : ''} en direct maintenant',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 9 / 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final live = lives[index];
                return _LiveCard(
                  live: live,
                  onTap: () => _openViewerMode(context, live),
                );
              },
              childCount: lives.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _openViewerMode(BuildContext context, LiveStream live) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _LiveViewerScreen(live: live),
        fullscreenDialog: true,
      ),
    );
  }
}

// =============================================================================
// _LiveCard — grid tile
// =============================================================================

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.live, required this.onTap});

  final LiveStream live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient thumbnail background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: live.gradientColors,
                ),
              ),
            ),

            // Author initials centered (represents avatar/thumbnail)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      live.initials,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.play_circle_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ],
              ),
            ),

            // Dark gradient overlay (bottom)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(30),
                      Colors.black.withAlpha(180),
                    ],
                    stops: const [0.4, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // TOP-LEFT: EN DIRECT badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 6),
                    SizedBox(width: 4),
                    Text(
                      'EN DIRECT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // TOP-RIGHT: viewer count
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_red_eye_rounded,
                      color: Colors.white70,
                      size: 10,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${live.viewerCount}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTTOM: author + title + category chip
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Text(
                        live.category,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Title
                    Text(
                      live.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.white,
                        height: 1.3,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Author name
                    Text(
                      live.authorName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _PulsingDot — animated red dot in AppBar title
// =============================================================================

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// =============================================================================
// _LiveViewerScreen — stub viewer mode
// =============================================================================

class _LiveViewerScreen extends StatefulWidget {
  const _LiveViewerScreen({required this.live});
  final LiveStream live;

  @override
  State<_LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<_LiveViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _connecting = true;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Simulate connection delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _connecting = false);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.live;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  live.gradientColors.first.withAlpha(120),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Connecting indicator or live content
          if (_connecting)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Connexion en cours…',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    live.title,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            // Stub "connected" live layout
            Stack(
              fit: StackFit.expand,
              children: [
                // Author avatar centered
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: live.gradientColors,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          live.initials,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        live.authorName,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Simulated audio wave bars
                      _AudioWaveIndicator(gradientColors: live.gradientColors),
                    ],
                  ),
                ),

                // Dark gradient overlay bottom
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black54,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                        stops: const [0.0, 0.2, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // TOP-LEFT: EN DIRECT badge (always visible once connected)
          if (!_connecting)
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                right: false,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _pulseAnim,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'EN DIRECT',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // TOP-RIGHT: viewer count + close
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              left: false,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_connecting)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👁', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              '${live.viewerCount}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTTOM: title + category + stub comment input
          if (!_connecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: live.gradientColors.first.withAlpha(180),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          live.category,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        live.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 6),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),

                      // Stub comment input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Réagissez au live…',
                                hintStyle: const TextStyle(
                                  color: Colors.white38,
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: Colors.black54,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Commentaire envoyé ! (stub)',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// _AudioWaveIndicator — animated bars simulating audio activity
// =============================================================================

class _AudioWaveIndicator extends StatefulWidget {
  const _AudioWaveIndicator({required this.gradientColors});
  final List<Color> gradientColors;

  @override
  State<_AudioWaveIndicator> createState() => _AudioWaveIndicatorState();
}

class _AudioWaveIndicatorState extends State<_AudioWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barCount = 7;
    const maxHeight = 32.0;
    const minHeight = 6.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final phase = (i / barCount + _ctrl.value) % 1.0;
            final height = minHeight +
                (maxHeight - minHeight) *
                    (0.5 + 0.5 * _sinApprox(phase * 2 * 3.14159));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: widget.gradientColors.last.withAlpha(200),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Sine approximation without dart:math import
  double _sinApprox(double x) {
    // Simple Bhaskara I approximation for sin in [0, pi]
    final normalized = x % (2 * 3.14159);
    final inPi = normalized <= 3.14159 ? normalized : normalized - 3.14159;
    final sign = normalized <= 3.14159 ? 1.0 : -1.0;
    return sign *
        (4 * inPi * (3.14159 - inPi)) /
        (3.14159 * 3.14159 - inPi * (3.14159 - inPi));
  }
}
