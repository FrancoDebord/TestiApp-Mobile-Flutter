import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../l10n/app_localizations.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';

// =============================================================================
// PrayerSessionLiveScreen — écran live d'une session de prière en groupe
// =============================================================================

class PrayerSessionLiveScreen extends ConsumerStatefulWidget {
  const PrayerSessionLiveScreen({required this.session, super.key});
  final GroupPrayerSession session;

  @override
  ConsumerState<PrayerSessionLiveScreen> createState() =>
      _PrayerSessionLiveScreenState();
}

class _PrayerSessionLiveScreenState
    extends ConsumerState<PrayerSessionLiveScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focus = FocusNode();

  Duration _elapsed = Duration.zero;
  Timer? _timer;

  final List<_ChatMessage> _messages = [];
  bool _isMuted = false;
  bool _isRecording = false;
  int _participants = 0;

  @override
  void initState() {
    super.initState();
    _participants = widget.session.participantCount + 1;
    _isRecording = widget.session.isRecorded;

    // Start elapsed timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    // Seed a welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _messages.add(_ChatMessage(
          author: widget.session.hostName,
          text: l10n.prayerWelcome,
          isSystem: true,
        ));
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(currentUserProvider);
    setState(() {
      _messages.add(_ChatMessage(
        author: user?.displayName ?? 'Moi',
        text: text,
      ));
    });
    _msgCtrl.clear();
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _leaveSession() async {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endSession() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.prayerEndTitle),
        content: Text(l10n.prayerEndDesc),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.prayerEnd),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref
          .read(groupSessionsProvider.notifier)
          .updateStatus(widget.session.id, PrayerSessionStatus.ended);
      Navigator.of(context).pop();
    }
  }

  String _formatElapsed() {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────────────────
              _TopBar(
                session: widget.session,
                elapsed: _formatElapsed(),
                participants: _participants,
                isRecording: _isRecording,
                isHost: widget.session.hostId ==
                    (ref.watch(currentUserProvider)?.id ?? ''),
                onEnd: _endSession,
                onLeave: _leaveSession,
              ),
              const SizedBox(height: 12),

              // ── Prayer circle ──────────────────────────────────────────
              _PrayerCircle(
                hostName: widget.session.hostName,
                participants: _participants,
              ),
              const SizedBox(height: 12),

              // ── Chat messages ──────────────────────────────────────────
              Expanded(
                child: _ChatList(
                  messages: _messages,
                  scrollController: _scrollCtrl,
                ),
              ),

              // ── Controls + compose ─────────────────────────────────────
              _BottomControls(
                isMuted: _isMuted,
                isRecording: _isRecording,
                onToggleMute: () => setState(() => _isMuted = !_isMuted),
                onToggleRecord: () =>
                    setState(() => _isRecording = !_isRecording),
                controller: _msgCtrl,
                focusNode: _focus,
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.session,
    required this.elapsed,
    required this.participants,
    required this.isRecording,
    required this.isHost,
    required this.onEnd,
    required this.onLeave,
  });
  final GroupPrayerSession session;
  final String elapsed;
  final int participants;
  final bool isRecording;
  final bool isHost;
  final VoidCallback onEnd;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Live badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'EN DIRECT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      elapsed,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.people_outline_rounded,
                        size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      '$participants',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if (isRecording) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.fiber_manual_record_rounded,
                        size: 10,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'Enregistrement',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Seul l'hôte peut terminer la session ; les autres peuvent quitter
          Builder(
            builder: (ctx) {
              final l10n = AppLocalizations.of(ctx);
              return TextButton(
                onPressed: isHost ? onEnd : onLeave,
                style: TextButton.styleFrom(
                  foregroundColor: isHost
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF94A3B8),
                  backgroundColor: isHost
                      ? const Color(0xFFEF4444).withAlpha(20)
                      : const Color(0xFF94A3B8).withAlpha(20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  isHost ? l10n.prayerEnd : l10n.prayerLeave,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Prayer circle ─────────────────────────────────────────────────────────────

class _PrayerCircle extends StatelessWidget {
  const _PrayerCircle({
    required this.hostName,
    required this.participants,
  });
  final String hostName;
  final int participants;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          const Text('🙏', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            'Session animée par $hostName',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$participants participants en prière',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.primary.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat list ─────────────────────────────────────────────────────────────────

class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.messages,
    required this.scrollController,
  });
  final List<_ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Commencez à prier ensemble…',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Color(0xFF475569),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        if (msg.isSystem) {
          return _SystemBubble(text: msg.text);
        }
        return _ChatBubble(message: msg);
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              message.author.isNotEmpty ? message.author[0].toUpperCase() : '?',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.author,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: AppColors.primary.withAlpha(220),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Bottom controls ───────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.isMuted,
    required this.isRecording,
    required this.onToggleMute,
    required this.onToggleRecord,
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });
  final bool isMuted;
  final bool isRecording;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRecord;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mute + Record controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: isMuted
                    ? AppLocalizations.of(context).prayerMute
                    : AppLocalizations.of(context).prayerMic,
                active: !isMuted,
                onTap: onToggleMute,
              ),
              const SizedBox(width: 20),
              _ControlButton(
                icon: Icons.fiber_manual_record_rounded,
                label: isRecording
                    ? AppLocalizations.of(context).prayerStopRec
                    : AppLocalizations.of(context).prayerRecord,
                active: isRecording,
                activeColor: const Color(0xFFEF4444),
                onTap: onToggleRecord,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).prayerMessageHint,
                    hintStyle: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFF475569),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? AppColors.primary) : const Color(0xFF475569);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? color.withAlpha(25)
                  : const Color(0xFF1E293B),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _ChatMessage {
  const _ChatMessage({
    required this.author,
    required this.text,
    this.isSystem = false,
  });
  final String author;
  final String text;
  final bool isSystem;
}
