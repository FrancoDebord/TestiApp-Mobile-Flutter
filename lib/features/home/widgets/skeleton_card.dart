import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Animated shimmer skeleton shown while feed items load.
///
/// Widget tree:
/// Card (elevation 0, border)
///   └─ Padding
///       └─ Column
///           ├─ Row (_SkeletonCircle + Column(_SkeletonLine × 2))
///           ├─ SizedBox
///           ├─ _SkeletonLine (wide  — title)
///           ├─ SizedBox
///           ├─ _SkeletonLine (wide)
///           ├─ _SkeletonLine (medium)
///           ├─ _SkeletonLine (narrow)
///           └─ SizedBox
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmer = Color.lerp(
          AppColors.border,
          const Color(0xFFE8EDF2),
          _anim.value,
        )!;
        return Card(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    _SkeletonCircle(size: 40, color: shimmer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonLine(width: 140, height: 12, color: shimmer),
                          const SizedBox(height: 6),
                          _SkeletonLine(width: 80, height: 10, color: shimmer),
                        ],
                      ),
                    ),
                    _SkeletonLine(width: 52, height: 26, color: shimmer,
                        radius: 50),
                  ],
                ),
                const SizedBox(height: 14),
                // Category chip
                _SkeletonLine(width: 80, height: 22, color: shimmer, radius: 50),
                const SizedBox(height: 12),
                // Title
                _SkeletonLine(width: double.infinity, height: 14, color: shimmer),
                const SizedBox(height: 6),
                _SkeletonLine(width: 200, height: 14, color: shimmer),
                const SizedBox(height: 12),
                // Body lines
                _SkeletonLine(width: double.infinity, height: 11, color: shimmer),
                const SizedBox(height: 5),
                _SkeletonLine(width: double.infinity, height: 11, color: shimmer),
                const SizedBox(height: 5),
                _SkeletonLine(width: 160, height: 11, color: shimmer),
                const SizedBox(height: 16),
                // Stats row
                _SkeletonLine(width: 220, height: 11, color: shimmer),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 4,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
