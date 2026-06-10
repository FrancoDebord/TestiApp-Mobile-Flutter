import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../l10n/app_localizations.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';
import 'prayer_session_live_screen.dart';

// =============================================================================
// CreatePrayerSessionScreen — créer une session de prière en groupe
// =============================================================================

class CreatePrayerSessionScreen extends ConsumerStatefulWidget {
  const CreatePrayerSessionScreen({super.key});

  @override
  ConsumerState<CreatePrayerSessionScreen> createState() =>
      _CreatePrayerSessionScreenState();
}

class _CreatePrayerSessionScreenState
    extends ConsumerState<CreatePrayerSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  PrayerVisibility _visibility = PrayerVisibility.public;
  bool _startNow = true;
  bool _isRecorded = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final user = ref.read(currentUserProvider);
    final session = GroupPrayerSession(
      id: 'gs_${DateTime.now().millisecondsSinceEpoch}',
      hostId: user?.id ?? 'anon',
      hostName: user?.displayName ?? 'Moi',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : null,
      scheduledAt: DateTime.now(),
      visibility: _visibility,
      status: _startNow
          ? PrayerSessionStatus.live
          : PrayerSessionStatus.scheduled,
      isRecorded: _isRecorded,
    );

    ref.read(groupSessionsProvider.notifier).addSession(session);

    if (!mounted) return;

    if (_startNow) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PrayerSessionLiveScreen(session: session),
        ),
      );
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).createSessionSuccess),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.prayerCreate,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _create,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Text(
                    _startNow ? l10n.createSessionStart : l10n.createSessionCreate,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Title ─────────────────────────────────────────────────────
            _FieldLabel(l10n.createSessionTitleField),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleCtrl,
              style: AppTextStyles.bodyMedium,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration('ex: Prière du jeudi soir'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? l10n.createSessionTitleReq : null,
            ),
            const SizedBox(height: 20),

            // ── Description ───────────────────────────────────────────────
            _FieldLabel(l10n.createSessionDescField),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: AppTextStyles.bodyMedium,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  _inputDecoration("Décrivez l'intention de cette session…"),
            ),
            const SizedBox(height: 20),

            // ── Visibility ────────────────────────────────────────────────
            _FieldLabel(l10n.createSessionVisibility),
            const SizedBox(height: 8),
            _VisibilityRow(
              value: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: 20),

            // ── Options ───────────────────────────────────────────────────
            _FieldLabel(l10n.createSessionOptions),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.radio_button_on_rounded,
              iconColor: const Color(0xFFEF4444),
              title: l10n.createSessionStartNow,
              subtitle: l10n.createSessionStartNowDesc,
              value: _startNow,
              onChanged: (v) => setState(() => _startNow = v),
            ),
            _OptionTile(
              icon: Icons.fiber_manual_record_rounded,
              iconColor: AppColors.primary,
              title: l10n.createSessionRecord,
              subtitle: l10n.createSessionRecordDesc,
              value: _isRecorded,
              onChanged: (v) => setState(() => _isRecorded = v),
            ),
            const SizedBox(height: 32),

            // ── CTA ───────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _create,
                icon: Icon(
                  _startNow
                      ? Icons.video_call_rounded
                      : Icons.calendar_today_rounded,
                ),
                label: Text(
                  _startNow
                      ? l10n.createSessionStartBtn
                      : l10n.createSessionScheduleBtn,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _startNow
                      ? const Color(0xFFEF4444)
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

// ── Visibility row ────────────────────────────────────────────────────────────

class _VisibilityRow extends StatelessWidget {
  const _VisibilityRow({required this.value, required this.onChanged});
  final PrayerVisibility value;
  final ValueChanged<PrayerVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final opts = [
      (PrayerVisibility.public,  Icons.public_rounded, l10n.prayerPublic),
      (PrayerVisibility.friends, Icons.group_rounded,  l10n.prayerFriends),
      (PrayerVisibility.private, Icons.lock_rounded,   l10n.prayerPrivate),
    ];

    return Row(
      children: opts.map((opt) {
        final (vis, icon, label) = opt;
        final sel = value == vis;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(vis),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary.withAlpha(15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel ? AppColors.primary : AppColors.border,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon,
                      size: 20,
                      color:
                          sel ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primary.withAlpha(80),
        activeThumbColor: AppColors.primary,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    );
  }
}
