import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:testi_app/core/theme/app_colors.dart';
import 'package:testi_app/core/theme/app_text_styles.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

class ReactionBarState {
  const ReactionBarState({
    this.likeCount = 0,
    this.prayCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isPrayed = false,
  });

  final int likeCount;
  final int prayCount;
  final int commentCount;
  final int shareCount;
  final bool isLiked;
  final bool isPrayed;

  ReactionBarState copyWith({
    int? likeCount,
    int? prayCount,
    int? commentCount,
    int? shareCount,
    bool? isLiked,
    bool? isPrayed,
  }) {
    return ReactionBarState(
      likeCount: likeCount ?? this.likeCount,
      prayCount: prayCount ?? this.prayCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      isLiked: isLiked ?? this.isLiked,
      isPrayed: isPrayed ?? this.isPrayed,
    );
  }
}

// ── Public widget ──────────────────────────────────────────────────────────────

/// A four-action reaction bar (like, pray, comment, share) with animated
/// count updates and togglable active states.
///
/// Supply [state] + individual callbacks to integrate with Riverpod.
/// Or use [ReactionBarSelfManaged] for a standalone version.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    required this.state,
    this.onLike,
    this.onPray,
    this.onComment,
    this.onShare,
    this.divider = true,
    super.key,
  });

  final ReactionBarState state;
  final VoidCallback? onLike;
  final VoidCallback? onPray;
  final VoidCallback? onComment;
  final VoidCallback? onShare;

  /// Whether to draw a top border separator.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (divider) const Divider(color: AppColors.border, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              _ReactionButton(
                icon: Icons.favorite_border_rounded,
                activeIcon: Icons.favorite_rounded,
                label: 'J\'aime',
                count: state.likeCount,
                isActive: state.isLiked,
                activeColor: AppColors.danger,
                onTap: onLike,
              ),
              _ReactionButton(
                icon: Icons.volunteer_activism_outlined,
                activeIcon: Icons.volunteer_activism_rounded,
                label: 'Prier',
                count: state.prayCount,
                isActive: state.isPrayed,
                activeColor: AppColors.secondary,
                onTap: onPray,
              ),
              _ReactionButton(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Commenter',
                count: state.commentCount,
                isActive: false,
                activeColor: AppColors.primary,
                onTap: onComment,
              ),
              _ReactionButton(
                icon: Icons.share_outlined,
                activeIcon: Icons.share_rounded,
                label: 'Partager',
                count: state.shareCount,
                isActive: false,
                activeColor: AppColors.primary,
                onTap: onShare,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Single reaction button ─────────────────────────────────────────────────────

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.count,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int count;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.count;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_ReactionButton old) {
    super.didUpdateWidget(old);
    if (widget.count != _prevCount || widget.isActive != old.isActive) {
      _prevCount = widget.count;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  String _format(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isActive ? widget.activeColor : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: widget.onTap != null ? _handleTap : null,
        borderRadius: BorderRadius.circular(8),
        splashColor: widget.activeColor.withAlpha(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Icon(
                    widget.isActive ? widget.activeIcon : widget.icon,
                    key: ValueKey(widget.isActive),
                    size: 22,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: color,
                      fontSize: 10,
                    ),
                  ),
                  if (widget.count > 0) ...[
                    const SizedBox(width: 3),
                    _AnimatedCount(
                      count: widget.count,
                      color: color,
                      formatter: _format,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated sliding count ─────────────────────────────────────────────────────

class _AnimatedCount extends StatelessWidget {
  const _AnimatedCount({
    required this.count,
    required this.color,
    required this.formatter,
  });

  final int count;
  final Color color;
  final String Function(int) formatter;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: Text(
        formatter(count),
        key: ValueKey(count),
        style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

// ── Self-managed variant ───────────────────────────────────────────────────────

/// Standalone [ReactionBar] that manages its own optimistic UI state.
/// Reports changes via [onLike], [onPray], [onComment], [onShare].
class ReactionBarSelfManaged extends StatefulWidget {
  const ReactionBarSelfManaged({
    required this.initialState,
    this.onLike,
    this.onPray,
    this.onComment,
    this.onShare,
    this.divider = true,
    super.key,
  });

  final ReactionBarState initialState;
  final VoidCallback? onLike;
  final VoidCallback? onPray;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final bool divider;

  @override
  State<ReactionBarSelfManaged> createState() =>
      _ReactionBarSelfManagedState();
}

class _ReactionBarSelfManagedState extends State<ReactionBarSelfManaged> {
  late ReactionBarState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  void _toggleLike() {
    setState(() {
      _state = _state.copyWith(
        isLiked: !_state.isLiked,
        likeCount: _state.isLiked
            ? (_state.likeCount - 1).clamp(0, 999999)
            : _state.likeCount + 1,
      );
    });
    widget.onLike?.call();
  }

  void _togglePray() {
    setState(() {
      _state = _state.copyWith(
        isPrayed: !_state.isPrayed,
        prayCount: _state.isPrayed
            ? (_state.prayCount - 1).clamp(0, 999999)
            : _state.prayCount + 1,
      );
    });
    widget.onPray?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ReactionBar(
      state: _state,
      onLike: _toggleLike,
      onPray: _togglePray,
      onComment: widget.onComment,
      onShare: widget.onShare,
      divider: widget.divider,
    );
  }
}
