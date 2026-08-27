// lib/features/publish/screens/video_camera_screen.dart
//
// Écran caméra plein-écran pour l'enregistrement vidéo in-app.
// Retourne le chemin du fichier via Navigator.pop(context, path).
//
// Flux :
//   Initialisation → prévisualisation live → enregistrement
//   → confirmation (reprendre / utiliser) → retour avec chemin.

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Durée max d'enregistrement ────────────────────────────────────────────
const int _kMaxSeconds = 300; // 5 minutes

// ═══════════════════════════════════════════════════════════════════════════
// Widget principal
// ═══════════════════════════════════════════════════════════════════════════

class VideoCameraScreen extends StatefulWidget {
  const VideoCameraScreen({super.key});

  @override
  State<VideoCameraScreen> createState() => _VideoCameraScreenState();
}

class _VideoCameraScreenState extends State<VideoCameraScreen>
    with WidgetsBindingObserver {
  // ── État ─────────────────────────────────────────────────────────────────

  CameraController? _ctrl;
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;

  bool _initialized = false;
  bool _isRecording = false;
  String? _recordedPath;

  int _elapsed = 0;
  Timer? _timer;

  FlashMode _flashMode = FlashMode.off;

  bool _hasError = false;
  String _errorMsg = '';

  // ── Cycle de vie ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupController(_camIndex);
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Demander les permissions sur mobile uniquement (le web les gère nativement)
    if (!kIsWeb) {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();

      if (!cam.isGranted || !mic.isGranted) {
        _setError(
          'Les permissions caméra et microphone sont requises.\n\n'
          'Activez-les dans les réglages de l\'application.',
        );
        return;
      }
    }

    try {
      _cameras = await availableCameras();
    } catch (e) {
      _setError('Impossible de détecter les caméras : $e');
      return;
    }

    if (_cameras.isEmpty) {
      _setError('Aucune caméra disponible sur cet appareil.');
      return;
    }

    // Préférer la caméra arrière comme point de départ
    final backIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    _camIndex = backIndex >= 0 ? backIndex : 0;
    await _setupController(_camIndex);
  }

  Future<void> _setupController(int index) async {
    if (mounted) setState(() => _initialized = false);

    await _ctrl?.dispose();

    final controller = CameraController(
      _cameras[index],
      kIsWeb ? ResolutionPreset.medium : ResolutionPreset.high,
      enableAudio: true,
    );
    _ctrl = controller;

    try {
      await controller.initialize();
      if (!kIsWeb) {
        // Le mode flash n'est pas disponible sur web
        await controller.setFlashMode(_flashMode);
      }
      if (mounted) setState(() => _initialized = true);
    } on CameraException catch (e) {
      _setError('Erreur caméra : ${e.description ?? e.code}');
    }
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMsg = msg;
      });
    }
  }

  // ── Enregistrement ────────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    _isRecording ? await _stopRecording() : await _startRecording();
  }

  Future<void> _startRecording() async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    try {
      await ctrl.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _elapsed = 0;
        });
        _startTimer();
      }
    } on CameraException catch (e) {
      debugPrint('startVideoRecording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final ctrl = _ctrl;
    if (ctrl == null) return;

    try {
      final file = await ctrl.stopVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordedPath = file.path;
        });
      }
    } on CameraException catch (e) {
      debugPrint('stopVideoRecording error: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_elapsed >= _kMaxSeconds) {
        _stopRecording();
        return;
      }
      setState(() => _elapsed++);
    });
  }

  // ── Contrôles caméra ──────────────────────────────────────────────────────

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    final newIndex = (_camIndex + 1) % _cameras.length;
    _camIndex = newIndex;
    await _setupController(newIndex);
  }

  Future<void> _toggleFlash() async {
    if (_ctrl == null || _isRecording || kIsWeb) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _ctrl!.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {}
  }

  // ── Post-enregistrement ───────────────────────────────────────────────────

  void _useVideo() => Navigator.pop(context, _recordedPath);

  void _retake() {
    setState(() {
      _recordedPath = null;
      _elapsed = 0;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ═════════════════════════════════════════════════════════════════════════
  // Build
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _ErrorView(message: _errorMsg);

    if (!_initialized || _ctrl == null) {
      return const _LoadingView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Prévisualisation ──────────────────────────────────────────
          _recordedPath == null
              ? _LivePreview(controller: _ctrl!)
              : _RecordedConfirmView(
                  path: _recordedPath!,
                  duration: _fmtDuration(_elapsed),
                ),

          // ── Barre du haut ─────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: _TopBar(
                isRecording: _isRecording,
                elapsed: _elapsed,
                formatDuration: _fmtDuration,
                flashMode: _flashMode,
                showFlash: !kIsWeb && _recordedPath == null,
                onClose: () => Navigator.pop(context),
                onFlash: _toggleFlash,
              ),
            ),
          ),

          // ── Contrôles du bas ──────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              top: false,
              child: _recordedPath != null
                  ? _PostRecordControls(
                      onRetake: _retake,
                      onUse: _useVideo,
                    )
                  : _RecordControls(
                      isRecording: _isRecording,
                      canFlip: _cameras.length > 1 && !kIsWeb,
                      elapsed: _elapsed,
                      maxSeconds: _kMaxSeconds,
                      formatDuration: _fmtDuration,
                      onFlip: _flipCamera,
                      onToggle: _toggleRecording,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sous-widgets
// ═══════════════════════════════════════════════════════════════════════════

// ── Prévisualisation live avec pinch-to-zoom ─────────────────────────────

class _LivePreview extends StatefulWidget {
  const _LivePreview({required this.controller});
  final CameraController controller;

  @override
  State<_LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<_LivePreview> {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final camRatio    = widget.controller.value.aspectRatio;
          final screenRatio = constraints.maxWidth / constraints.maxHeight;
          final scale = screenRatio < camRatio
              ? constraints.maxHeight * camRatio / constraints.maxWidth
              : constraints.maxWidth / (constraints.maxHeight * camRatio);

          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: scale,
                child: Center(child: CameraPreview(widget.controller)),
              ),
              // Zoom level indicator
              if (_currentZoom > _minZoom + 0.05)
                Positioned(
                  bottom: 160,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
          );
        },
      ),
    );
  }
}

// ── Vue confirmation post-enregistrement ─────────────────────────────────

class _RecordedConfirmView extends StatelessWidget {
  const _RecordedConfirmView({
    required this.path,
    required this.duration,
  });
  final String path;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final filename = path.split('/').last.split('\\').last;
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green, size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Vidéo enregistrée !',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Durée : $duration',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                filename,
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Inter',
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre du haut ─────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isRecording,
    required this.elapsed,
    required this.formatDuration,
    required this.flashMode,
    required this.showFlash,
    required this.onClose,
    required this.onFlash,
  });

  final bool isRecording;
  final int elapsed;
  final String Function(int) formatDuration;
  final FlashMode flashMode;
  final bool showFlash;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Bouton fermer
          _CircleIconButton(
            icon: Icons.close_rounded,
            onTap: onClose,
          ),

          const Spacer(),

          // Timer (pendant l'enregistrement)
          if (isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDuration(elapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Bouton flash
          if (showFlash)
            _CircleIconButton(
              icon: flashMode == FlashMode.off
                  ? Icons.flash_off_rounded
                  : Icons.flash_on_rounded,
              onTap: onFlash,
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ── Contrôles pendant l'enregistrement ───────────────────────────────────

class _RecordControls extends StatelessWidget {
  const _RecordControls({
    required this.isRecording,
    required this.canFlip,
    required this.elapsed,
    required this.maxSeconds,
    required this.formatDuration,
    required this.onFlip,
    required this.onToggle,
  });

  final bool isRecording;
  final bool canFlip;
  final int elapsed;
  final int maxSeconds;
  final String Function(int) formatDuration;
  final VoidCallback onFlip;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barre de progression (enregistrement)
          if (isRecording) ...[
            Row(
              children: [
                Text(
                  formatDuration(elapsed),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDuration(maxSeconds),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: elapsed / maxSeconds,
                backgroundColor: Colors.white24,
                color: Colors.red,
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Boutons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flip caméra
              if (canFlip && !isRecording)
                _CircleIconButton(
                  icon: Icons.flip_camera_ios_rounded,
                  onTap: onFlip,
                  size: 44,
                )
              else
                const SizedBox(width: 44),

              const SizedBox(width: 40),

              // Bouton d'enregistrement principal
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      width: isRecording ? 28 : 60,
                      height: isRecording ? 28 : 60,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(
                          isRecording ? 6 : 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 40),
              const SizedBox(width: 44), // symétrie avec flip
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isRecording ? 'Appuyez pour arrêter' : 'Appuyez pour enregistrer',
            style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contrôles post-enregistrement ─────────────────────────────────────────

class _PostRecordControls extends StatelessWidget {
  const _PostRecordControls({
    required this.onRetake,
    required this.onUse,
  });

  final VoidCallback onRetake;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reprendre
          _ActionButton(
            icon: Icons.replay_rounded,
            label: 'Reprendre',
            color: Colors.white70,
            onTap: onRetake,
          ),
          // Utiliser
          _ActionButton(
            icon: Icons.check_rounded,
            label: 'Utiliser',
            color: Colors.green,
            filled: true,
            onTap: onUse,
          ),
        ],
      ),
    );
  }
}

// ── États de chargement et d'erreur ──────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 16),
            Text(
              'Initialisation de la caméra…',
              style: TextStyle(
                color: Colors.white70,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white38,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white70),
                  label: const Text(
                    'Retour',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Inter',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(100),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: filled ? Colors.white : color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
