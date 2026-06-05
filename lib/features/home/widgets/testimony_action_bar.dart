import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';

/// Shared action bar rendered at the bottom of every testimony card.
///
/// Widget tree:
/// Row
///   ├─ _ReactionButton  (emoji reaction with long-press picker)
///   ├─ _ActionButton    (💬 Commenter)
///   ├─ _ActionButton    (🙏 Je prie)
///   └─ _ActionButton    (📤 Partager)
class TestimonyActionBar extends StatelessWidget {
  const TestimonyActionBar({
    required this.testimony,
    this.isLiked,
    this.isPrayed,
    this.currentReaction,
    this.onReact,
    this.onComment,
    this.onPray,
    this.onShare,
    super.key,
  });

  final Testimony testimony;

  /// Overrides: si null, on utilise la valeur du modèle.
  final bool? isLiked;
  final bool? isPrayed;

  /// Réaction courante de l'utilisateur (null = aucune réaction posée).
  final ReactionType? currentReaction;

  /// Appelé quand l'utilisateur choisit ou retire une réaction.
  /// Passer [null] signifie "retirer la réaction".
  final void Function(ReactionType? type)? onReact;

  final VoidCallback? onComment;
  final VoidCallback? onPray;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final prayed = isPrayed ?? testimony.isPrayed;

    return Row(
      children: [
        _ReactionButton(
          currentReaction: currentReaction,
          onReact: onReact,
        ),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Commenter',
          color: AppColors.textSecondary,
          onTap: onComment,
        ),
        _ActionButton(
          icon: prayed
              ? Icons.volunteer_activism
              : Icons.volunteer_activism_outlined,
          label: 'Je prie',
          color: prayed ? AppColors.primary : AppColors.textSecondary,
          onTap: onPray,
        ),
        _ActionButton(
          icon: Icons.share_outlined,
          label: 'Partager',
          color: AppColors.textSecondary,
          onTap: onShare,
        ),
      ],
    );
  }
}

// ── Reaction button with long-press picker ────────────────────────────────────

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    required this.currentReaction,
    required this.onReact,
  });

  final ReactionType? currentReaction;
  final void Function(ReactionType? type)? onReact;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _dismissPicker();
    _animationController.dispose();
    super.dispose();
  }

  // ── Overlay picker ──────────────────────────────────────────────────────

  void _showPicker() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final overlay = Overlay.of(context);
    final buttonOffset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // Transparent barrier — tap outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissPicker,
            ),
          ),
          // Picker bubble
          Positioned(
            left: buttonOffset.dx - 80,
            top:  buttonOffset.dy - 72,
            child: ScaleTransition(
              alignment: Alignment.bottomLeft,
              scale: _scaleAnimation,
              child: _ReactionPicker(
                onSelect: (type) {
                  _dismissPicker();
                  widget.onReact?.call(type);
                },
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
    _animationController.forward(from: 0);
  }

  void _dismissPicker() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Short tap: toggle like / remove reaction ──────────────────────────────

  void _handleTap() {
    if (widget.currentReaction != null) {
      // Tap on active reaction → remove it
      widget.onReact?.call(null);
    } else {
      // No reaction yet → default to like
      widget.onReact?.call(ReactionType.like);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final reaction  = widget.currentReaction;
    final hasReaction = reaction != null;
    final emoji     = reaction?.emoji ?? '❤️';
    final label     = reaction?.label ?? "J'aime";
    final color     = hasReaction ? AppColors.danger : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: _showPicker,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: TextStyle(
                  fontSize: 18,
                  // Tint via colorFilter not directly possible on Text; use
                  // AnimatedDefaultTextStyle to highlight active state.
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: color,
                  fontWeight:
                      hasReaction ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reaction picker bubble ────────────────────────────────────────────────────

class _ReactionPicker extends StatelessWidget {
  const _ReactionPicker({required this.onSelect});

  final void Function(ReactionType type) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(32),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ReactionType.values.map((type) {
            return _ReactionPickerItem(
              emoji: type.emoji,
              label: type.label,
              onTap: () => onSelect(type),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ReactionPickerItem extends StatefulWidget {
  const _ReactionPickerItem({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ReactionPickerItem> createState() => _ReactionPickerItemState();
}

class _ReactionPickerItemState extends State<_ReactionPickerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp:   (_) => _controller.reverse(),
      onTapCancel:  () => _controller.reverse(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ScaleTransition(
          scale: _scale,
          child: Tooltip(
            message: widget.label,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}

// ── Single icon action button ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
