import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../l10n/app_localizations.dart';
import '../models/prayer_models.dart';
import '../providers/prayer_providers.dart';

// =============================================================================
// SubmitPrayerRequestScreen — soumettre une nouvelle requête de prière
// =============================================================================

class SubmitPrayerRequestScreen extends ConsumerStatefulWidget {
  const SubmitPrayerRequestScreen({super.key});

  @override
  ConsumerState<SubmitPrayerRequestScreen> createState() =>
      _SubmitPrayerRequestScreenState();
}

class _SubmitPrayerRequestScreenState
    extends ConsumerState<SubmitPrayerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bodyCtrl = TextEditingController();
  PrayerVisibility _visibility = PrayerVisibility.public;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));

    final user = ref.read(currentUserProvider);
    final req = PrayerRequest(
      id: 'pr_${DateTime.now().millisecondsSinceEpoch}',
      authorId: user?.id ?? 'anon',
      authorName: user?.displayName ?? 'Moi',
      body: _bodyCtrl.text.trim(),
      createdAt: DateTime.now(),
      visibility: _visibility,
    );

    ref.read(prayerRequestsProvider.notifier).addRequest(req);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).submitPrayerSuccess),
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
          l10n.submitPrayerTitle,
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
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Text(
                    l10n.commonShare,
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
            // ── Intro ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Text('🙏', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.submitPrayerIntro,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Text field ─────────────────────────────────────────────────
            Text(
              l10n.submitPrayerField,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 6,
              maxLength: 600,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.submitPrayerHint,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return l10n.submitPrayerValidation;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Visibility ─────────────────────────────────────────────────
            Text(
              l10n.submitPrayerVisibility,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _VisibilitySelector(
              value: _visibility,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            const SizedBox(height: 40),

            // ── Submit button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  l10n.submitPrayerButton,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
}

// ── Visibility selector ───────────────────────────────────────────────────────

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector(
      {required this.value, required this.onChanged});
  final PrayerVisibility value;
  final ValueChanged<PrayerVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      (PrayerVisibility.public,  Icons.public_rounded, l10n.prayerPublic,  l10n.submitPrayerVisPublicDesc),
      (PrayerVisibility.friends, Icons.group_rounded,  l10n.prayerFriends, l10n.submitPrayerVisFriendsDesc),
      (PrayerVisibility.private, Icons.lock_rounded,   l10n.prayerPrivate, l10n.submitPrayerVisPrivateDesc),
    ];

    return Column(
      children: options.map((opt) {
        final (vis, icon, label, desc) = opt;
        final selected = value == vis;
        return GestureDetector(
          onTap: () => onChanged(vis),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withAlpha(15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(desc, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
