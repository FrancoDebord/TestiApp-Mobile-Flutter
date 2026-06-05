import 'package:flutter/material.dart';

import '../models/moderation_models.dart';

// =============================================================================
// ReviewBottomSheet
// Shown for Rejeter (rejection reason selector) and Demander modif (note field).
// =============================================================================

enum ReviewAction { reject, requestEdit }

class ReviewBottomSheet extends StatefulWidget {
  const ReviewBottomSheet({
    required this.item,
    required this.action,
    required this.onConfirm,
    super.key,
  });

  final ModerationItem item;
  final ReviewAction action;

  /// Called with (rejectionReason, moderatorNote).
  final void Function(RejectionReason? reason, String? note) onConfirm;

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  RejectionReason? _selectedReason;
  final _noteController = TextEditingController();

  bool get _isReject => widget.action == ReviewAction.reject;

  bool get _canConfirm =>
      _isReject ? _selectedReason != null : _noteController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPad),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ───────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── Title ─────────────────────────────────────────────────────────
          Text(
            _isReject ? 'Rejeter le témoignage' : 'Demander une modification',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          // ── Testimony title preview ────────────────────────────────────────
          Text(
            widget.item.truncatedTitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // ── Full content preview (scrollable excerpt) ──────────────────────
          if (widget.item.contentPreview != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                widget.item.contentPreview!,
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  height: 1.6,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Rejection reason dropdown (reject only) ───────────────────────
          if (_isReject) ...[
            const Text(
              'Motif du rejet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RejectionReason>(
              initialValue: _selectedReason,
              hint: const Text(
                'Sélectionner un motif',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF6B21A8), width: 1.5),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              items: RejectionReason.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
            ),
            const SizedBox(height: 16),
          ],

          // ── Moderator note text field ──────────────────────────────────────
          Text(
            _isReject
                ? 'Note optionnelle pour le modérateur'
                : 'Instructions pour l\'auteur',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: _isReject
                  ? 'Ajouter une note interne (optionnel)…'
                  : 'Expliquer les modifications attendues…',
              hintStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF6B21A8), width: 1.5),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 24),

          // ── Confirm button ─────────────────────────────────────────────────
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _canConfirm
                  ? () {
                      widget.onConfirm(
                        _selectedReason,
                        _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                      );
                      Navigator.of(context).pop();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isReject ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isReject ? 'Confirmer le rejet' : 'Envoyer la demande',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
