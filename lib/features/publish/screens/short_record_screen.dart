import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Entry-point widget
// ---------------------------------------------------------------------------

class ShortRecordScreen extends StatefulWidget {
  const ShortRecordScreen({super.key});

  @override
  State<ShortRecordScreen> createState() => _ShortRecordScreenState();
}

// ---------------------------------------------------------------------------
// Category chip model
// ---------------------------------------------------------------------------

class _Category {
  const _Category(this.label, this.colors);
  final String label;
  final List<Color> colors;
}

const _categories = <_Category>[
  _Category('Guérison', AppColors.guerisonGradient),
  _Category('Délivrance', AppColors.delivranceGradient),
  _Category('Conversion', AppColors.conversionGradient),
  _Category('Mariage', AppColors.mariageGradient),
  _Category('Famille', AppColors.familleGradient),
  _Category('Finances', AppColors.financesGradient),
  _Category('Miracles', AppColors.miraclesGradient),
  _Category('Protection', AppColors.protectionGradient),
  _Category('Ministère', AppColors.ministereGradient),
  _Category('Salut', AppColors.salutGradient),
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _ShortRecordScreenState extends State<ShortRecordScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  List<CameraDescription> _cameras = [];
  CameraController? _cameraCtrl;
  int _camIndex = 0;
  FlashMode _flash = FlashMode.off;

  // Recording state
  bool _initialized = false;
  bool _isRecording = false;
  bool _hasError = false;
  String? _errorMessage;
  String? _recordedPath;

  // Timer / progress
  int _elapsedSeconds = 0;
  Timer? _timer;
  static const int _maxSeconds = 60;

  // Category selection
  int _selectedCategory = 0;

  // Pulse animation for the record button while recording
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _cameraCtrl?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Camera initialisation
  // ---------------------------------------------------------------------------

  Future<void> _initCamera() async {
    // Request permissions
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      setState(() {
        _hasError = true;
        _errorMessage =
            'Accès à la caméra et au microphone requis.\nVeuillez autoriser ces permissions dans les paramètres.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Aucune caméra disponible sur cet appareil.';
        });
        return;
      }

      // Prefer back camera on first launch
      _camIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_camIndex < 0) _camIndex = 0;

      await _attachController(_cameras[_camIndex]);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Erreur d\'initialisation de la caméra: $e';
      });
    }
  }

  Future<void> _attachController(CameraDescription cam) async {
    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await ctrl.initialize();
    if (!mounted) return;
    await ctrl.setFlashMode(_flash);
    setState(() {
      _cameraCtrl = ctrl;
      _initialized = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Recording controls
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_cameraCtrl == null || !_initialized || _isRecording) return;

    try {
      await _cameraCtrl!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _elapsedSeconds = 0;
        _recordedPath = null;
      });

      _pulseCtrl.repeat(reverse: true);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= _maxSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('startVideoRecording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraCtrl == null || !_isRecording) return;
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.reset();

    try {
      final file = await _cameraCtrl!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _recordedPath = file.path;
      });
    } catch (e) {
      debugPrint('stopVideoRecording error: $e');
      setState(() => _isRecording = false);
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  // ---------------------------------------------------------------------------
  // Camera flip & flash
  // ---------------------------------------------------------------------------

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _timer?.cancel();
    if (_isRecording) {
      await _cameraCtrl?.stopVideoRecording().catchError(
            (Object _) => XFile(''),
          );
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }

    await _cameraCtrl?.dispose();
    setState(() {
      _initialized = false;
      _isRecording = false;
      _elapsedSeconds = 0;
    });

    _camIndex = (_camIndex + 1) % _cameras.length;
    await _attachController(_cameras[_camIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_cameraCtrl == null || !_initialized) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await _cameraCtrl!.setFlashMode(next);
    setState(() => _flash = next);
  }

  // ---------------------------------------------------------------------------
  // Reset after preview
  // ---------------------------------------------------------------------------

  void _resetRecording() {
    setState(() {
      _recordedPath = null;
      _elapsedSeconds = 0;
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String get _durationLabel {
    final elapsed = _elapsedSeconds;
    final total = _maxSeconds;
    final eMin = elapsed ~/ 60;
    final eSec = elapsed % 60;
    final tMin = total ~/ 60;
    final tSec = total % 60;
    return '$eMin:${eSec.toString().padLeft(2, '0')} / $tMin:${tSec.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorScreen();
    if (_recordedPath != null) return _buildPreviewScreen();
    return _buildCameraScreen();
  }

  // ---------------------------------------------------------------------------
  // Error screen
  // ---------------------------------------------------------------------------

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 72),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'Une erreur s\'est produite.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Preview screen (after recording)
  // ---------------------------------------------------------------------------

  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon & title
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.success, width: 2),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: AppColors.success,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Court Témoignage enregistré !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Durée: $_elapsedSeconds seconde${_elapsedSeconds > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 48),

            // Category selected
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _categories[_selectedCategory].colors,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categories[_selectedCategory].label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  // REPRENDRE
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetRecording,
                      icon: const Icon(Icons.refresh),
                      label: const Text('REPRENDRE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // UTILISER
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(_recordedPath),
                      icon: const Icon(Icons.check),
                      label: const Text('UTILISER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Camera screen
  // ---------------------------------------------------------------------------

  Widget _buildCameraScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera preview
          _buildCameraPreview(),

          // 2. Gradient overlays
          _buildGradientOverlays(),

          // 3. Top bar
          _buildTopBar(),

          // 4. Flash toggle (top-right)
          _buildFlashButton(),

          // 5. Bottom controls (duration + record button + hint)
          _buildBottomControls(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Camera preview — fills the screen
  // ---------------------------------------------------------------------------

  Widget _buildCameraPreview() {
    if (!_initialized || _cameraCtrl == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenRatio = constraints.maxWidth / constraints.maxHeight;
        final previewRatio = _cameraCtrl!.value.aspectRatio;

        double w, h;
        if (screenRatio < previewRatio) {
          h = constraints.maxHeight;
          w = h * previewRatio;
        } else {
          w = constraints.maxWidth;
          h = w / previewRatio;
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: CameraPreview(_cameraCtrl!),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Gradient overlays
  // ---------------------------------------------------------------------------

  Widget _buildGradientOverlays() {
    return Column(
      children: [
        // Top gradient
        Container(
          height: 120,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        // Bottom gradient
        Container(
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Close button
            _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),

            // Title
            const Text(
              'Short Témoignage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            const Spacer(),

            // Flip camera
            _CircleIconButton(
              icon: Icons.flip_camera_ios_outlined,
              onTap: _flipCamera,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Flash button (top-right, below top bar)
  // ---------------------------------------------------------------------------

  Widget _buildFlashButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 64,
      right: 16,
      child: _CircleIconButton(
        icon: _flash == FlashMode.off ? Icons.flash_off : Icons.flash_on,
        onTap: _toggleFlash,
        color: _flash == FlashMode.off ? Colors.white70 : AppColors.secondary,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom controls
  // ---------------------------------------------------------------------------

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duration label
            Text(
              _durationLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 12),

            // Record button with arc
            GestureDetector(
              onTap: _toggleRecording,
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: _buildRecordButton(),
            ),
            const SizedBox(height: 10),

            // Hint text
            Text(
              _isRecording
                  ? 'Appuyez pour arrêter'
                  : 'Appuyez pour enregistrer',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 16),

            // Category chips
            _buildCategoryChips(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Record button
  // ---------------------------------------------------------------------------

  Widget _buildRecordButton() {
    final progress = _maxSeconds > 0 ? _elapsedSeconds / _maxSeconds : 0.0;
    const outerSize = 88.0;
    const innerSize = 64.0;

    return ScaleTransition(
      scale: _isRecording ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
        width: outerSize,
        height: outerSize,
        child: CustomPaint(
          painter: _ArcPainter(
            progress: progress,
            isRecording: _isRecording,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(
                  _isRecording ? 12 : innerSize / 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withAlpha(120),
                    blurRadius: _isRecording ? 16 : 8,
                    spreadRadius: _isRecording ? 4 : 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Category chips
  // ---------------------------------------------------------------------------

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = _selectedCategory == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: cat.colors)
                    : null,
                color: selected ? null : Colors.white24,
                borderRadius: BorderRadius.circular(18),
                border: selected
                    ? null
                    : Border.all(color: Colors.white38, width: 1),
              ),
              child: Text(
                cat.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Arc CustomPainter
// ---------------------------------------------------------------------------

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.isRecording});

  final double progress;
  final bool isRecording;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    // Background track (thin white ring)
    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = isRecording ? AppColors.success : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      const startAngle = -pi / 2; // 12 o'clock
      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.isRecording != isRecording;
}

// ---------------------------------------------------------------------------
// Reusable circle icon button
// ---------------------------------------------------------------------------

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
