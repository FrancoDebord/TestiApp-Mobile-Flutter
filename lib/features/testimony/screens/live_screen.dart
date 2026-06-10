// lib/features/testimony/screens/live_screen.dart
//
// GO LIVE screen — broadcaster perspective.
//
// Widget tree (simplified):
//   LiveScreen (ConsumerStatefulWidget)
//   ├─ _SetupView   (pre-live setup form over camera preview)
//   ├─ _LiveView    (full-screen live session with overlays)
//   └─ _SummaryView (post-live summary)

import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/local_db/daos/testimony_dao.dart';
import '../../../core/local_db/database_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../features/auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const List<String> _kCategories = [
  'Guérison',
  'Délivrance',
  'Conversion',
  'Mariage',
  'Famille',
  'Finances',
  'Miracles',
  'Protection',
  'Ministère',
  'Salut',
];

const List<String> _kStubComments = [
  'Marie N. : Gloire à Dieu ! 🙌',
  'Jean P. : Amen ! Dieu est bon 🙏',
  'Esther K. : Ce témoignage me touche ❤️',
  'Samuel B. : Merci Seigneur ! 🔥',
  'Grace M. : Je prie avec vous !',
  'Paul T. : Alléluia ! 🙌',
  'Ruth A. : Que Dieu soit loué ! ✨',
  'David M. : Incroyable grâce de Dieu 🙏',
  'Lydie B. : Merci pour ce partage ❤️',
  "Timothée S. : Cela m'encourage tellement !",
];

// ─── Data models ──────────────────────────────────────────────────────────────

class _LiveViewer {
  const _LiveViewer({required this.name, required this.initials});
  final String name;
  final String initials;
}

class _LiveComment {
  _LiveComment({
    required this.authorName,
    required this.text,
    required this.timestamp,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String authorName;
  final String text;
  final DateTime timestamp;

  String get initials {
    final parts = authorName.trim().split(' ');
    if (parts.length >= 2 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return authorName.isNotEmpty ? authorName[0].toUpperCase() : '?';
  }

  // Separate "Name :" prefix from comment body for display
  String get displayName {
    final colonIdx = text.indexOf(' : ');
    if (colonIdx != -1) return text.substring(0, colonIdx);
    return authorName;
  }

  String get displayText {
    final colonIdx = text.indexOf(' : ');
    if (colonIdx != -1) return text.substring(colonIdx + 3);
    return text;
  }
}

// =============================================================================
// LiveScreen
// =============================================================================

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Core state ────────────────────────────────────────────────────────────

  bool _isLive = false;
  bool _showSummary = false;

  // ── Setup form ────────────────────────────────────────────────────────────

  final TextEditingController _titleCtrl = TextEditingController();
  String? _selectedCategory;
  bool _videoMode = true; // true=video, false=audio only

  // ── Live session ──────────────────────────────────────────────────────────

  int _elapsedSeconds = 0;
  int _viewerCount = 1;
  int _peakViewers = 1;
  final List<_LiveComment> _comments = [];
  final ScrollController _commentsScrollCtrl = ScrollController();
  final TextEditingController _commentInputCtrl = TextEditingController();

  // ── Timers ────────────────────────────────────────────────────────────────

  Timer? _durationTimer;
  Timer? _commentTimer;
  Timer? _viewerTimer;

  // ── Camera ────────────────────────────────────────────────────────────────

  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  bool _cameraInitialized = false;
  bool _cameraError = false;
  bool _isMuted = false;

  // ── Animations ────────────────────────────────────────────────────────────

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Spectateurs (stub) ────────────────────────────────────────────────────

  bool _showViewers = false;
  final List<_LiveViewer> _viewers = [
    _LiveViewer(name: 'Marie N.',    initials: 'MN'),
    _LiveViewer(name: 'Jean P.',     initials: 'JP'),
    _LiveViewer(name: 'Esther K.',   initials: 'EK'),
    _LiveViewer(name: 'Samuel B.',   initials: 'SB'),
    _LiveViewer(name: 'Grace M.',    initials: 'GM'),
  ];

  // ── Sauvegarde rediffusion ────────────────────────────────────────────────

  bool    _isSaving     = false;
  bool    _replaySaved  = false;
  String? _recordingPath;           // chemin du fichier vidéo enregistré

  // ── RNG ───────────────────────────────────────────────────────────────────

  final Random _rng = Random();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPulse();
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleCtrl.dispose();
    _commentInputCtrl.dispose();
    _commentsScrollCtrl.dispose();
    _pulseCtrl.dispose();
    _cancelTimers();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
      _cameraCtrl = null;
      if (mounted) setState(() => _cameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera(_camIndex);
    }
  }

  // ── Animation init ────────────────────────────────────────────────────────

  void _initPulse() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (!kIsWeb) {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted || !mic.isGranted) {
        if (mounted) setState(() => _cameraError = true);
        return;
      }
    }

    try {
      _cameras = await availableCameras();
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
      return;
    }

    if (_cameras.isEmpty) {
      if (mounted) setState(() => _cameraError = true);
      return;
    }

    // Prefer front camera for live (selfie mode)
    final frontIdx = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    _camIndex = frontIdx >= 0 ? frontIdx : 0;
    await _setupCamera(_camIndex);
  }

  Future<void> _setupCamera(int index) async {
    if (mounted) setState(() => _cameraInitialized = false);

    await _cameraCtrl?.dispose();

    final ctrl = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
    );
    _cameraCtrl = ctrl;

    try {
      await ctrl.initialize();
      if (mounted) setState(() => _cameraInitialized = true);
    } on CameraException {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  // ── Live session logic ────────────────────────────────────────────────────

  Future<void> _startLive() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un titre pour votre live.'),
        ),
      );
      return;
    }

    // TODO: connect to RTMP server / Agora / LiveKit
    // Example integration point:
    //   await AgoraRtcEngine.create(appId);
    //   await AgoraRtcEngine.enableVideo();
    //   await AgoraRtcEngine.joinChannel(token, channelName, null, 0);
    // Or for RTMP:
    //   await RtmpPublisher.publish(streamUrl);

    HapticFeedback.mediumImpact();

    setState(() {
      _isLive = true;
      _elapsedSeconds = 0;
      _viewerCount = 1;
      _peakViewers = 1;
      _comments.clear();
    });

    _startDurationTimer();
    _startCommentTimer();
    _startViewerTimer();

    // Démarre l'enregistrement vidéo réel (non disponible sur Web)
    if (!kIsWeb && _cameraInitialized && _cameraCtrl != null) {
      try {
        await _cameraCtrl!.startVideoRecording();
      } catch (_) {
        // L'appareil ne supporte pas l'enregistrement — le live continue sans capture
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _startCommentTimer() {
    _commentTimer?.cancel();
    // First comment after 3 seconds
    _scheduleNextComment(3);
  }

  void _scheduleNextComment(int delaySeconds) {
    _commentTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted || !_isLive) return;
      _addStubComment();
      // Next comment in 8–15 seconds
      _scheduleNextComment(8 + _rng.nextInt(8));
    });
  }

  void _addStubComment() {
    final raw = _kStubComments[_rng.nextInt(_kStubComments.length)];
    final colonIdx = raw.indexOf(' : ');
    final author = colonIdx != -1 ? raw.substring(0, colonIdx) : 'Anonyme';
    final comment = _LiveComment(
      authorName: author,
      text: raw,
      timestamp: DateTime.now(),
    );
    setState(() => _comments.add(comment));

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_commentsScrollCtrl.hasClients) {
        _commentsScrollCtrl.animateTo(
          _commentsScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startViewerTimer() {
    _viewerTimer?.cancel();
    _viewerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !_isLive) return;
      final increment = 1 + _rng.nextInt(3);
      setState(() {
        _viewerCount += increment;
        if (_viewerCount > _peakViewers) _peakViewers = _viewerCount;
      });
    });
  }

  void _cancelTimers() {
    _durationTimer?.cancel();
    _commentTimer?.cancel();
    _viewerTimer?.cancel();
  }

  void _sendComment() {
    final text = _commentInputCtrl.text.trim();
    if (text.isEmpty) return;
    final comment = _LiveComment(
      authorName: 'Moi',
      text: 'Moi : $text',
      timestamp: DateTime.now(),
    );
    setState(() => _comments.add(comment));
    _commentInputCtrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_commentsScrollCtrl.hasClients) {
        _commentsScrollCtrl.animateTo(
          _commentsScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── End live ──────────────────────────────────────────────────────────────

  Future<void> _confirmEndLive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Terminer le live ?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Votre diffusion en direct sera arrêtée. '
          'Vous pouvez sauvegarder la rediffusion ensuite.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annuler',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Terminer',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _cancelTimers();

      // Arrête l'enregistrement et récupère le fichier
      String? path;
      if (!kIsWeb && (_cameraCtrl?.value.isRecordingVideo ?? false)) {
        try {
          final xFile = await _cameraCtrl!.stopVideoRecording();
          path = xFile.path;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isLive        = false;
          _showSummary   = true;
          _recordingPath = path;
        });
      }
    }
  }

  // ── Camera controls ───────────────────────────────────────────────────────

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;

    // Arrête temporairement l'enregistrement pendant le flip
    if (!kIsWeb && (_cameraCtrl?.value.isRecordingVideo ?? false)) {
      try { await _cameraCtrl!.stopVideoRecording(); } catch (_) {}
    }

    final newIndex = (_camIndex + 1) % _cameras.length;
    _camIndex = newIndex;
    await _setupCamera(newIndex);

    // Reprend l'enregistrement si le live est toujours actif
    if (_isLive && !kIsWeb && _cameraInitialized && _cameraCtrl != null) {
      try { await _cameraCtrl!.startVideoRecording(); } catch (_) {}
    }
  }

  void _toggleMute() => setState(() => _isMuted = !_isMuted);

  // ── Spectateurs ───────────────────────────────────────────────────────────

  void _toggleViewers() => setState(() => _showViewers = !_showViewers);

  // ── Sauvegarde rediffusion ────────────────────────────────────────────────

  Future<void> _saveLive() async {
    if (_replaySaved || _isSaving) return;
    setState(() => _isSaving = true);

    final user = ref.read(currentUserProvider);
    final now  = DateTime.now();
    final id   = 'live_${now.millisecondsSinceEpoch}';

    final testimony = VideoTestimony(
      id:              id,
      author:          TestimonyAuthor(
        uid:         user?.id ?? 'anon',
        displayName: user?.displayName ?? 'Anonyme',
      ),
      title:           _titleCtrl.text.trim(),
      category:        _selectedCategory != null
          ? TestimonyCategory.values.firstWhere(
              (c) => c.name.toLowerCase() ==
                  _selectedCategory!.toLowerCase().replaceAll('é', 'e')
                      .replaceAll('è', 'e').replaceAll('ê', 'e'),
              orElse: () => TestimonyCategory.miracles,
            )
          : TestimonyCategory.miracles,
      createdAt:       now,
      stats:           TestimonyStats(
        views:    _peakViewers,
        likes:    0,
        prayers:  0,
        comments: _comments.length,
      ),
      durationSeconds: _elapsedSeconds,
      thumbnailUrl: '',
      mediaPath: _recordingPath,
    );

    // Insert SQLite
    try {
      final dao = TestimonyDao(DatabaseService());
      await dao.upsert({
        'id':           id,
        'user_id':      user?.id ?? 'anon',
        'author_name':  user?.displayName ?? 'Anonyme',
        'type':         'video',
        'title':        testimony.title,
        'category':     testimony.category.name,
        'duration_sec': _elapsedSeconds,
        'views':        _peakViewers,
        'like_count':   0,
        'prayer_count': 0,
        'comment_count': _comments.length,
        'media_url':    _recordingPath ?? '',
        'status':       'published',
        'created_at':   now.toIso8601String(),
        'updated_at':   now.toIso8601String(),
      });
    } catch (_) {
      // SQLite indisponible — on continue quand même en mémoire
    }

    // Ajouter au feed en mémoire
    ref.read(feedNotifierProvider.notifier).addTestimony(testimony);

    if (mounted) {
      setState(() {
        _isSaving    = false;
        _replaySaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rediffusion sauvegardée et publiée !'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ==========================================================================
  // Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_showSummary) return _buildSummaryView();
    if (_isLive) return _buildLiveView();
    return _buildSetupView();
  }

  // ── Setup view ────────────────────────────────────────────────────────────

  Widget _buildSetupView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview background
          if (_cameraInitialized && _cameraCtrl != null && _videoMode)
            _CameraPreviewWidget(controller: _cameraCtrl!)
          else
            Container(
              color: Colors.black,
              child: Center(
                child: _cameraError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam_off_rounded,
                            color: Colors.white38,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Caméra indisponible',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      )
                    : !_videoMode
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mic_rounded,
                                color: Colors.white54,
                                size: 72,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Mode Audio',
                                style: AppTextStyles.h3.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator(
                            color: Colors.white54,
                          ),
              ),
            ),

          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0.0, 0.2, 0.5, 1.0],
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    Text(
                      'Témoignage en Direct',
                      style: AppTextStyles.h4.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),

          // Bottom setup panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SetupPanel(
              titleCtrl: _titleCtrl,
              selectedCategory: _selectedCategory,
              videoMode: _videoMode,
              onCategorySelected: (cat) =>
                  setState(() => _selectedCategory = cat),
              onVideoModeToggled: (val) => setState(() => _videoMode = val),
              onStartLive: _startLive,
            ),
          ),
        ],
      ),
    );
  }

  // ── Live view ─────────────────────────────────────────────────────────────

  Widget _buildLiveView() {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_cameraInitialized && _cameraCtrl != null && _videoMode)
            _CameraPreviewWidget(controller: _cameraCtrl!)
          else
            Container(
              color: const Color(0xFF1A1A2E),
              child: const Center(
                child: Icon(Icons.mic_rounded, color: Colors.white38, size: 80),
              ),
            ),

          // Dark gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0.0, 0.25, 0.55, 1.0],
              ),
            ),
          ),

          // 1. TOP-LEFT: EN DIRECT badge
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              right: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 12),
                child: _LiveBadge(pulseAnim: _pulseAnim),
              ),
            ),
          ),

          // 2. TOP-RIGHT: timer + end button
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        _formatDuration(_elapsedSeconds),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _confirmEndLive,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
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

          // 3. TOP-CENTER: title
          Positioned(
            top: 0,
            left: 80,
            right: 90,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  _titleCtrl.text,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // 4. RIGHT-SIDE: viewer count badge (tappable → shows list)
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.2,
            child: GestureDetector(
              onTap: _toggleViewers,
              child: _ViewerBadge(count: _viewerCount),
            ),
          ),

          // 4b. Viewers slide-in panel
          if (_showViewers)
            Positioned(
              right: 0,
              top: MediaQuery.of(context).size.height * 0.12,
              bottom: 180,
              width: 200,
              child: _ViewersPanel(
                viewers: _viewers,
                onClose: _toggleViewers,
              ),
            ),

          // 5. BOTTOM: comments overlay + input
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scrolling comments list
                  SizedBox(
                    height: 200,
                    child: _CommentsOverlay(
                      comments: _comments,
                      scrollCtrl: _commentsScrollCtrl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Comment input row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentInputCtrl,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).liveCommentHint,
                              hintStyle: const TextStyle(
                                color: Colors.white54,
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
                            onSubmitted: (_) => _sendComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _sendComment,
                          child: Container(
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. BOTTOM-RIGHT: FABs (flip, mute, share)
          Positioned(
            right: 12,
            bottom: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveFab(
                  icon: Icons.flip_camera_ios_rounded,
                  label: 'Retourner',
                  onTap: _flipCamera,
                ),
                const SizedBox(height: 12),
                _LiveFab(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _isMuted ? 'Activer' : 'Couper',
                  onTap: _toggleMute,
                  active: _isMuted,
                ),
                const SizedBox(height: 12),
                _LiveFab(
                  icon: Icons.share_rounded,
                  label: 'Partager',
                  onTap: () {
                    final slug = _titleCtrl.text.trim()
                        .replaceAll(' ', '_')
                        .toLowerCase();
                    final link = 'testi://app/live/$slug';
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lien copié dans le presse-papiers !'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary view ──────────────────────────────────────────────────────────

  Widget _buildSummaryView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.danger, width: 2),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: AppColors.danger,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Live terminé !',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '"${_titleCtrl.text}"',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryStatCard(
                      icon: Icons.timer_rounded,
                      label: 'Durée',
                      value: _formatDuration(_elapsedSeconds),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryStatCard(
                      icon: Icons.remove_red_eye_rounded,
                      label: 'Spectateurs max',
                      value: '$_peakViewers',
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryStatCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Commentaires',
                      value: '${_comments.length}',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save replay option
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.save_alt_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    _replaySaved
                        ? '${AppLocalizations.of(context).liveSaveReplay} ✓'
                        : AppLocalizations.of(context).liveSaveReplay,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _replaySaved
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _replaySaved
                        ? 'Votre live est maintenant disponible en replay'
                        : 'Rendre votre live disponible en replay',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _replaySaved
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: _replaySaved
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                  onTap: (_replaySaved || _isSaving) ? null : _saveLive,
                ),
              ),
              const SizedBox(height: 32),

              // Back button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(
                    AppLocalizations.of(context).commonBack,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SetupPanel — bottom form overlay for pre-live setup
// =============================================================================

class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.titleCtrl,
    required this.selectedCategory,
    required this.videoMode,
    required this.onCategorySelected,
    required this.onVideoModeToggled,
    required this.onStartLive,
  });

  final TextEditingController titleCtrl;
  final String? selectedCategory;
  final bool videoMode;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<bool> onVideoModeToggled;
  final VoidCallback onStartLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE6000000), // black with ~90% opacity
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title field
          TextField(
            controller: titleCtrl,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.white,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Titre de votre témoignage en direct',
              hintStyle: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Inter',
                fontSize: 15,
              ),
              filled: true,
              fillColor: Colors.white10,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryLight, width: 1.5),
              ),
              prefixIcon: const Icon(
                Icons.title_rounded,
                color: Colors.white38,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category label
          const Text(
            'Catégorie',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),

          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kCategories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = _kCategories[i];
                final isSelected = cat == selectedCategory;
                return GestureDetector(
                  onTap: () => onCategorySelected(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white30,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Video / Audio toggle
          Row(
            children: [
              const Icon(Icons.videocam_rounded, color: Colors.white54, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  videoMode ? 'Vidéo' : 'Audio seulement',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ),
              Switch(
                value: videoMode,
                onChanged: onVideoModeToggled,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primaryLight,
                inactiveTrackColor: Colors.white24,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Start live button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.live_tv_rounded, size: 22),
              label: Text(
                AppLocalizations.of(context).liveStart,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              onPressed: onStartLive,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

// ── Camera preview with pinch-to-zoom ─────────────────────────────────────────

class _CameraPreviewWidget extends StatefulWidget {
  const _CameraPreviewWidget({required this.controller});
  final CameraController controller;

  @override
  State<_CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<_CameraPreviewWidget> {
  double _currentZoom = 1.0;
  double _baseZoom    = 1.0;
  double _minZoom     = 1.0;
  double _maxZoom     = 8.0;

  @override
  void initState() {
    super.initState();
    _loadZoomBounds();
  }

  Future<void> _loadZoomBounds() async {
    try {
      final min = await widget.controller.getMinZoomLevel();
      final max = await widget.controller.getMaxZoomLevel();
      if (mounted) setState(() { _minZoom = min; _maxZoom = max; });
    } catch (_) {}
  }

  void _handleScaleStart(ScaleStartDetails _) {
    _baseZoom = _currentZoom;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    final zoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((zoom - _currentZoom).abs() < 0.01) return;
    setState(() => _currentZoom = zoom);
    try {
      await widget.controller.setZoomLevel(zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart:  _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover: fills entire screen in portrait, slight crop on sides
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: 1,
                height: 1 / widget.controller.value.aspectRatio,
                child: CameraPreview(widget.controller),
              ),
            ),
          ),
          // Zoom indicator (shows briefly when user pinches)
          if (_currentZoom > _minZoom + 0.05)
            Positioned(
              bottom: 160,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}×',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── EN DIRECT badge with pulsing dot ─────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.pulseAnim});
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withAlpha(80),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: pulseAnim,
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
          Text(
            AppLocalizations.of(context).liveBadge,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Viewer count badge ────────────────────────────────────────────────────────

class _ViewerBadge extends StatelessWidget {
  const _ViewerBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👁', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live comments overlay ─────────────────────────────────────────────────────

class _CommentsOverlay extends StatelessWidget {
  const _CommentsOverlay({
    required this.comments,
    required this.scrollCtrl,
  });

  final List<_LiveComment> comments;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(
        child: Text(
          'Les commentaires apparaîtront ici…',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Colors.white38,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: comments.length,
      itemBuilder: (ctx, i) => _CommentBubble(comment: comments[i]),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({required this.comment});
  final _LiveComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(180),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              comment.initials,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${comment.displayName}  ',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    TextSpan(
                      text: comment.displayText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white,
                      ),
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

// ── Live FAB button ───────────────────────────────────────────────────────────

class _LiveFab extends StatelessWidget {
  const _LiveFab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.danger.withAlpha(200)
                  : Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.danger : Colors.white38,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circular icon button ──────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Viewers side panel ────────────────────────────────────────────────────────

class _ViewersPanel extends StatelessWidget {
  const _ViewersPanel({required this.viewers, required this.onClose});

  final List<_LiveViewer> viewers;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(200),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
            child: Row(
              children: [
                const Text(
                  'En ligne',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: viewers.length,
              itemBuilder: (_, i) {
                final v = viewers[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(180),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          v.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          v.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary stat card ─────────────────────────────────────────────────────────

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
