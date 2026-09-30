import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../downloads/widgets/download_button.dart';
import '../models/testimony_model.dart';
import '../providers/home_providers.dart';

/// Formate un compteur : 1234 → « 1.2k ».
String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

/// Rangée d'actions en bas de chaque carte de témoignage (maquette « Accueil »).
///
/// Widget tree:
/// Row
///   ├─ Expanded → Row
///   │    ├─ _ReactionButton  (❤ rouge + nombre, appui long = choix de réaction)
///   │    ├─ _StatAction      (🙏 Je prie + nombre)
///   │    ├─ _StatAction      (💬 commentaires + nombre)
///   │    └─ _StatAction      (partager)
///   ├─ DownloadButton        (hors ligne)
///   └─ bookmark              (sauvegarder)
class TestimonyActionBar extends StatelessWidget {
  const TestimonyActionBar({
    required this.testimony,
    this.isLiked,
    this.isPrayed,
    this.isSaved,
    this.currentReaction,
    this.onReact,
    this.onComment,
    this.onPray,
    this.onShare,
    this.onSave,
    this.showDownload = true,
    super.key,
  });

  final Testimony testimony;

  /// Overrides: si null, on utilise la valeur du modèle.
  final bool? isLiked;
  final bool? isPrayed;
  final bool? isSaved;

  /// Réaction courante de l'utilisateur (null = aucune réaction posée).
  final ReactionType? currentReaction;

  /// Appelé quand l'utilisateur choisit ou retire une réaction.
  /// Passer [null] signifie "retirer la réaction".
  final void Function(ReactionType? type)? onReact;

  final VoidCallback? onComment;
  final VoidCallback? onPray;
  final VoidCallback? onShare;

  /// Sauvegarder / retirer des sauvegardes (icône signet à droite).
  final VoidCallback? onSave;

  /// Bouton de téléchargement hors ligne (audio, vidéo, texte).
  final bool showDownload;

  @override
  Widget build(BuildContext context) {
    final prayed = isPrayed ?? testimony.isPrayed;
    final saved = isSaved ?? testimony.isSaved;
    final stats = testimony.stats;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: _ReactionButton(
                  currentReaction: currentReaction,
                  liked: isLiked ?? testimony.isLiked,
                  count: stats.likes,
                  onReact: onReact,
                ),
              ),
              Flexible(
                child: _StatAction(
                  icon: prayed
                      ? Icons.volunteer_activism
                      : Icons.volunteer_activism_outlined,
                  count: stats.prayers,
                  tooltip: 'Je prie',
                  color: prayed ? AppColors.primary : AppColors.textSecondary,
                  onTap: onPray,
                ),
              ),
              Flexible(
                child: _StatAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: stats.comments,
                  tooltip: 'Commenter',
                  color: AppColors.textSecondary,
                  onTap: onComment,
                ),
              ),
              Flexible(
                child: _StatAction(
                  icon: Icons.share_outlined,
                  tooltip: 'Partager',
                  color: AppColors.textSecondary,
                  onTap: onShare,
                ),
              ),
            ],
          ),
        ),
        if (showDownload) DownloadButton(testimony: testimony, size: 21),
        if (onSave != null)
          IconButton(
            tooltip: saved ? 'Enlever des sauvegardes' : 'Sauvegarder',
            onPressed: onSave,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 22,
              color: saved ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

// ── Icône + compteur ─────────────────────────────────────────────────────────

class _StatAction extends StatelessWidget {
  const _StatAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.count,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                if (count != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      formatCount(count!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reaction button with long-press picker ────────────────────────────────────

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    required this.currentReaction,
    required this.liked,
    required this.count,
    required this.onReact,
  });

  final ReactionType? currentReaction;
  final bool liked;
  final int count;
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Garde la bulle dans l'écran (≈ 300 px de large).
    final left = (buttonOffset.dx - 8).clamp(8.0, (screenWidth - 308).clamp(8.0, double.infinity));

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
            left: left,
            top: buttonOffset.dy - 64,
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
    final reaction = widget.currentReaction;
    final active = reaction != null || widget.liked;

    // J'aime (ou aucune réaction) : cœur rouge ; autre réaction : son émoji.
    final Widget icon = (reaction == null || reaction == ReactionType.like)
        ? Icon(
            active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: AppColors.danger,
          )
        : Text(reaction.emoji, style: const TextStyle(fontSize: 17));

    return Semantics(
      button: true,
      label: reaction?.label ?? "J'aime",
      child: InkWell(
        onTap: _handleTap,
        onLongPress: _showPicker,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    formatCount(widget.count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: active
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
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

// ── Reaction picker bubble ────────────────────────────────────────────────────

class _ReactionPicker extends StatelessWidget {
  const _ReactionPicker({required this.onSelect});

  final void Function(ReactionType type) onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: AppColors.primaryDark.withAlpha(40),
      borderRadius: BorderRadius.circular(32),
      color: AppColors.surface,
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
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
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

// ── Menu « ⋮ » commun aux cartes ─────────────────────────────────────────────

/// Menu contextuel des cartes : sauvegarder, partager, signaler.
class TestimonyCardMenu extends StatelessWidget {
  const TestimonyCardMenu({
    required this.isSaved,
    required this.onSave,
    required this.onShare,
    required this.onReport,
    this.iconColor = AppColors.textSecondary,
    super.key,
  });

  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      iconColor: iconColor,
      padding: EdgeInsets.zero,
      tooltip: 'Plus d’options',
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'save':
            onSave();
          case 'share':
            onShare();
          case 'report':
            onReport();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'save',
          child: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 18,
                color: isSaved ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  isSaved ? 'Enlever des sauvegardes' : 'Sauvegarder',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Flexible(child: Text('Partager', style: AppTextStyles.bodyMedium)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 18, color: AppColors.danger),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Signaler',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
