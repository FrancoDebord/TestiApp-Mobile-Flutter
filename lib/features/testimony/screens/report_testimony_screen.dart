import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/guest_gate.dart';

// =============================================================================
// ReportTestimonyScreen
//
// Permet à l'utilisateur de signaler un témoignage avec une raison + commentaire.
// Submit → POST /testimonies/{id}/report → pop avec snackbar de confirmation.
// =============================================================================

enum _Reason {
  inappropriateContent,
  falseTesti,
  hateSpeech,
  spam,
  other;

  String get apiValue => switch (this) {
        _Reason.inappropriateContent => 'inappropriate_content',
        _Reason.falseTesti           => 'false_testimony',
        _Reason.hateSpeech           => 'hate_speech',
        _Reason.spam                 => 'spam',
        _Reason.other                => 'other',
      };

  String get label => switch (this) {
        _Reason.inappropriateContent => 'Contenu inapproprié',
        _Reason.falseTesti           => 'Faux témoignage',
        _Reason.hateSpeech           => 'Discours haineux',
        _Reason.spam                 => 'Spam ou publicité',
        _Reason.other                => 'Autre raison',
      };
}

class ReportTestimonyScreen extends ConsumerStatefulWidget {
  const ReportTestimonyScreen({required this.testimonyId, super.key});

  final String testimonyId;

  @override
  ConsumerState<ReportTestimonyScreen> createState() =>
      _ReportTestimonyScreenState();
}

class _ReportTestimonyScreenState
    extends ConsumerState<ReportTestimonyScreen> {
  _Reason? _selectedReason;
  final _commentController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null) return;
    // Mode invité : signaler demande un compte.
    if (!await requireAccount(context, ref, reason: 'signaler un contenu')) {
      return;
    }
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.post<void>(
        AppConstants.testimonyReport(widget.testimonyId),
        data: {
          'reason': reason.apiValue,
          if (_commentController.text.trim().isNotEmpty)
            'comment': _commentController.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signalement envoyé. Merci pour votre contribution.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur est survenue. Veuillez réessayer.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Signaler ce témoignage',
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        foregroundColor: AppColors.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Intro ─────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.sunSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sunBorder),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.warning),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Votre signalement est anonyme et sera examiné par notre équipe de modération.',
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 13,
                              color: AppColors.sunText,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Raison ────────────────────────────────────────────────
                  const Text(
                    'Raison du signalement',
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sélectionnez la raison qui correspond le mieux',
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._Reason.values.map(
                    (r) => _ReasonTile(
                      reason: r,
                      selected: _selectedReason == r,
                      onTap: () => setState(() => _selectedReason = r),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Commentaire optionnel ─────────────────────────────────
                  const Text(
                    'Détails supplémentaires (optionnel)',
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          'Décrivez le problème avec plus de précision…',
                      hintStyle: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bouton soumettre ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_selectedReason != null && !_loading)
                    ? _submit
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Envoyer le signalement',
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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

// ── Tile de raison ─────────────────────────────────────────────────────────────

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final _Reason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withAlpha(10)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.inputBorder,
                  width: 2,
                ),
                color: selected ? AppColors.primary : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              reason.label,
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
