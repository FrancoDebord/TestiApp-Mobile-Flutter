import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';

// =============================================================================
// PrayerRequestDetailScreen — détail + messages d'inspiration
// =============================================================================

class PrayerRequestDetailScreen extends ConsumerStatefulWidget {
  const PrayerRequestDetailScreen({required this.requestId, super.key});
  final String requestId;

  @override
  ConsumerState<PrayerRequestDetailScreen> createState() =>
      _PrayerRequestDetailScreenState();
}

class _PrayerRequestDetailScreenState
    extends ConsumerState<PrayerRequestDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _verseCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showVerseField = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _verseCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  PrayerRequest? _findRequest(List<PrayerRequest> list) {
    try {
      return list.firstWhere((r) => r.id == widget.requestId);
    } catch (_) {
      return null;
    }
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final msg = InspirationMessage(
      id: 'im_${DateTime.now().millisecondsSinceEpoch}',
      requestId: widget.requestId,
      authorId: user?.id ?? 'anon',
      authorName: user?.displayName ?? 'Moi',
      body: text,
      createdAt: DateTime.now(),
      bibleVerse: _verseCtrl.text.trim().isNotEmpty
          ? _verseCtrl.text.trim()
          : null,
    );

    ref.read(inspirationMessagesProvider.notifier).addMessage(msg);
    ref
        .read(prayerRequestsProvider.notifier)
        .incrementMessages(widget.requestId);

    _msgCtrl.clear();
    _verseCtrl.clear();
    setState(() => _showVerseField = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final request = _findRequest(
        ref.watch(prayerRequestsProvider).asData?.value ?? []);
    final messages =
        ref.watch(inspirationMessagesProvider)[widget.requestId] ?? [];

    if (request == null) {
      return const Scaffold(
        body: Center(child: Text('Requête introuvable')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        title: const Text(
          'Requête de prière',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Request card ───────────────────────────────────────────
                _RequestHeaderCard(request: request),
                const SizedBox(height: 20),

                // ── Pray CTA ───────────────────────────────────────────────
                _PrayCta(request: request),
                const SizedBox(height: 24),

                // ── Messages section ───────────────────────────────────────
                Row(
                  children: [
                    const Text(
                      'Messages d\'inspiration',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${messages.length}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (messages.isEmpty)
                  _EmptyMessages(
                    onTap: () {
                      FocusScope.of(context).requestFocus(_focusNode);
                    },
                  )
                else
                  ...messages.map((msg) => _MessageBubble(message: msg)),
              ],
            ),
          ),

          // ── Compose bar ────────────────────────────────────────────────
          _ComposeBar(
            controller: _msgCtrl,
            verseController: _verseCtrl,
            focusNode: _focusNode,
            showVerseField: _showVerseField,
            onToggleVerse: () =>
                setState(() => _showVerseField = !_showVerseField),
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── Request header card ───────────────────────────────────────────────────────

class _RequestHeaderCard extends StatelessWidget {
  const _RequestHeaderCard({required this.request});
  final PrayerRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(initials: request.initials),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.authorName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(request.timeAgo, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            request.body,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.volunteer_activism_outlined,
                  size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                '${request.prayerCount} personnes prient',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pray CTA ──────────────────────────────────────────────────────────────────

class _PrayCta extends ConsumerWidget {
  const _PrayCta({required this.request});
  final PrayerRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPrayed = request.userHasPrayed;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => ref
            .read(prayerRequestsProvider.notifier)
            .togglePray(request.id, 'me'),
        icon: Text(
          hasPrayed ? '✅' : '🙏',
          style: const TextStyle(fontSize: 18),
        ),
        label: Text(
          hasPrayed ? 'Je prie pour toi' : 'Prier pour cette personne',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasPrayed ? AppColors.primary.withAlpha(20) : AppColors.primary,
          foregroundColor:
              hasPrayed ? AppColors.primary : Colors.white,
          side: hasPrayed
              ? const BorderSide(color: AppColors.primary)
              : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: hasPrayed ? 0 : 2,
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final InspirationMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(initials: message.initials),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.authorName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(message.timeAgo,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.body,
                        style: AppTextStyles.bodyMedium.copyWith(
                            height: 1.55),
                      ),
                      if (message.bibleVerse != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.menu_book_rounded,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              message.bibleVerse!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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

// ── Compose bar ───────────────────────────────────────────────────────────────

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({
    required this.controller,
    required this.verseController,
    required this.focusNode,
    required this.showVerseField,
    required this.onToggleVerse,
    required this.onSend,
  });
  final TextEditingController controller;
  final TextEditingController verseController;
  final FocusNode focusNode;
  final bool showVerseField;
  final VoidCallback onToggleVerse;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showVerseField) ...[
              TextField(
                controller: verseController,
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary),
                decoration: InputDecoration(
                  hintText: 'Référence biblique (ex: Jean 3:16)…',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.menu_book_rounded,
                      size: 16, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.primary.withAlpha(10),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.primary.withAlpha(60)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.menu_book_rounded,
                    color: showVerseField
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: onToggleVerse,
                  tooltip: 'Ajouter un verset',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: 3,
                    minLines: 1,
                    style: AppTextStyles.bodyMedium,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Écrivez un message d\'inspiration…',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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
      ),
    );
  }
}

// ── Empty messages ────────────────────────────────────────────────────────────

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Text('✉️', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier à envoyer un message d\'inspiration.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}
