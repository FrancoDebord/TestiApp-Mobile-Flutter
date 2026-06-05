import 'package:flutter/material.dart';
import 'package:testi_app/core/theme/app_colors.dart';

// ── Variant enum ───────────────────────────────────────────────────────────────

enum SkeletonVariant { card, listItem, profile }

// ── Public widget ──────────────────────────────────────────────────────────────

/// Shimmer skeleton loader with three layout variants.
///
/// Example:
/// ```dart
/// SkeletonLoader(variant: SkeletonVariant.card)
/// SkeletonLoader(variant: SkeletonVariant.listItem, itemCount: 5)
/// SkeletonLoader(variant: SkeletonVariant.profile)
/// ```
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    this.variant = SkeletonVariant.card,
    this.itemCount = 1,
    super.key,
  });

  final SkeletonVariant variant;

  /// Only used by [SkeletonVariant.listItem] — renders [itemCount] rows.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: switch (variant) {
        SkeletonVariant.card => const _CardSkeleton(),
        SkeletonVariant.listItem => _ListItemsSkeleton(count: itemCount),
        SkeletonVariant.profile => const _ProfileSkeleton(),
      },
    );
  }
}

// ── Shimmer engine ─────────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _anim.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

// ── Primitive block ────────────────────────────────────────────────────────────

class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    this.radius = 6,
    this.isCircle = false,
  });

  final double width;
  final double height;
  final double radius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius:
            isCircle ? null : BorderRadius.circular(radius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

// ── Card skeleton ──────────────────────────────────────────────────────────────

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          _Block(
            width: double.infinity,
            height: 160,
            radius: 10,
          ),
          const SizedBox(height: 14),

          // Avatar row
          Row(
            children: [
              const _Block(width: 40, height: 40, isCircle: true),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 120, height: 12),
                  const SizedBox(height: 6),
                  _Block(width: 80, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Category chip
          _Block(width: 80, height: 24, radius: 20),
          const SizedBox(height: 10),

          // Title
          _Block(width: double.infinity, height: 16),
          const SizedBox(height: 6),
          _Block(width: 200, height: 16),
          const SizedBox(height: 10),

          // Body lines
          _Block(width: double.infinity, height: 12),
          const SizedBox(height: 5),
          _Block(width: double.infinity, height: 12),
          const SizedBox(height: 5),
          _Block(width: 180, height: 12),
          const SizedBox(height: 14),

          // Action bar
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Block(width: double.infinity, height: 32, radius: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List-item skeleton ─────────────────────────────────────────────────────────

class _ListItemsSkeleton extends StatelessWidget {
  const _ListItemsSkeleton({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => const _ListItemSkeleton()),
    );
  }
}

class _ListItemSkeleton extends StatelessWidget {
  const _ListItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar
          const _Block(width: 48, height: 48, isCircle: true),
          const SizedBox(width: 12),

          // Text lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(width: double.infinity, height: 13),
                const SizedBox(height: 7),
                _Block(width: 200, height: 11),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _Block(width: 60, height: 22, radius: 20),
                    const SizedBox(width: 8),
                    _Block(width: 40, height: 10),
                    const SizedBox(width: 12),
                    _Block(width: 40, height: 10),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),
          // Thumbnail
          _Block(width: 56, height: 56, radius: 8),
        ],
      ),
    );
  }
}

// ── Profile skeleton ───────────────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cover photo
          _Block(width: double.infinity, height: 130, radius: 16),
          const SizedBox(height: 0),

          // Avatar (overlapping cover)
          Transform.translate(
            offset: const Offset(0, -36),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const _Block(width: 72, height: 72, isCircle: true),
            ),
          ),

          // Name & handle
          _Block(width: 140, height: 16),
          const SizedBox(height: 8),
          _Block(width: 90, height: 12),
          const SizedBox(height: 16),

          // Bio lines
          _Block(width: double.infinity, height: 12),
          const SizedBox(height: 5),
          _Block(width: 240, height: 12),
          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (_) => Column(
                children: [
                  _Block(width: 44, height: 18),
                  const SizedBox(height: 6),
                  _Block(width: 60, height: 11),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // CTA button
          _Block(width: double.infinity, height: 48, radius: 12),
          const SizedBox(height: 24),

          // List items
          ...[1, 2, 3].map((_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _ListItemSkeleton(),
              )),
        ],
      ),
    );
  }
}
