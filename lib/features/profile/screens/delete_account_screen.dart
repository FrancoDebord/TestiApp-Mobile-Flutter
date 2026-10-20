// Supprimer mon compte (Paramètres › Compte) : explique ce qui est supprimé,
// double confirmation (mot à saisir, puis fenêtre finale), DELETE /me ;
// ensuite déconnexion, effacement des données du téléphone et du jeton de
// notification, retour à l'accueil en mode invité.
// Serveur : docs/fonctionnalites/confidentialite-et-suppression.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show authStateProvider, currentUserProvider;

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState
    extends ConsumerState<DeleteAccountScreen> {
  final _ctrl        = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _isDeleting  = false;
  bool  _confirmed   = false;
  String? _error;

  /// Mot à saisir pour confirmer (« SUPPRIMER »).
  String get _kWord => context.l10n.profileDeleteConfirmWord;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final ok = _ctrl.text.trim() == _kWord;
      if (ok != _confirmed) setState(() => _confirmed = ok);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _hasPassword => ref.read(currentUserProvider)?.hasPassword ?? true;

  /// Seconde confirmation : fenêtre « Supprimer définitivement ? ».
  Future<bool> _confirmFinal() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: AppColors.danger),
        title: Text(l10n.accountDeleteFinalTitle),
        content: Text(l10n.accountDeleteFinalBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const ValueKey('delete-account-final'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileDeleteForever),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// DELETE /me : `{ password }` pour un compte e-mail, `{ confirm: true }`
  /// pour un compte téléphone / Google (sans mot de passe).
  Future<void> _delete() async {
    if (_hasPassword && _passwordCtrl.text.isEmpty) {
      setState(() => _error = context.l10n.profileDeleteEnterPassword);
      return;
    }
    if (!await _confirmFinal() || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final deletedMessage = context.l10n.accountDeletedDone;
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await ref.read(apiServiceProvider).delete<dynamic>(
            AppConstants.deleteAccount,
            data: _hasPassword
                ? {'password': _passwordCtrl.text}
                : {'confirm': true},
          );
    } on LaravelApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = e.statusCode == 403
            ? context.l10n.profileDeleteWrongPassword
            : e.displayMessage;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = context.l10n.profileServerUnreachable;
      });
      return;
    }
    // Compte supprimé : données du téléphone et jeton de notification effacés,
    // mode invité, retour à l'accueil.
    await ref.read(authStateProvider.notifier).accountDeleted();
    router.go(AppPaths.homePath);
    messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(deletedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsDelete,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.textPrimary,
            )),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        iconTheme:
            const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icône d'avertissement
            Center(
              child: Container(
                width: 80, height: 80,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.danger.withAlpha(60), width: 2),
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppColors.danger, size: 40),
              ),
            ),

            Text(
              l10n.profileDeleteIrreversible,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Ce qui est supprimé (même liste que la page /suppression-compte du site).
            Text(l10n.accountDeleteWhatTitle, style: AppTextStyles.h4),
            const SizedBox(height: 12),
            _WarningItem(icon: Icons.person_off_outlined, text: l10n.accountDeleteWhatProfile),
            _WarningItem(icon: Icons.auto_stories_outlined, text: l10n.accountDeleteWhatTestimonies),
            _WarningItem(icon: Icons.volunteer_activism_outlined, text: l10n.accountDeleteWhatPrayers),
            _WarningItem(icon: Icons.event_busy_outlined, text: l10n.accountDeleteWhatEvents),
            _WarningItem(icon: Icons.forum_outlined, text: l10n.accountDeleteWhatInteractions),
            _WarningItem(icon: Icons.phone_android_rounded, text: l10n.accountDeleteWhatDevice),
            const SizedBox(height: 4),
            Text(
              l10n.accountDeleteWhatNote,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),

            const SizedBox(height: 32),

            // Champ de confirmation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.danger.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: l10n.profileDeleteTypePrefix),
                        TextSpan(
                          text: _kWord,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                            fontFamily: AppFonts.family,
                          ),
                        ),
                        TextSpan(text: l10n.profileDeleteTypeSuffix),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('delete-account-word'),
                    controller: _ctrl,
                    autocorrect: false,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 1,
                    ),
                    decoration: InputDecoration(
                      hintText: _kWord,
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: AppFonts.family,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.danger, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            if (_hasPassword) ...[
              const SizedBox(height: 16),
              AppTextField(
                label: l10n.authPasswordLabel,
                hint: l10n.profileDeletePasswordHint,
                controller: _passwordCtrl,
                isPassword: true,
                textInputAction: TextInputAction.done,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 13,
                  color: AppColors.danger,
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Bouton supprimer
            AppButton(
              key: const ValueKey('delete-account-submit'),
              label: l10n.profileDeleteForever,
              variant: AppButtonVariant.danger,
              size: AppButtonSize.large,
              fullWidth: true,
              isLoading: _isDeleting,
              onPressed: (_confirmed && !_isDeleting) ? _delete : null,
            ),

            const SizedBox(height: 12),

            // Annuler
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningItem extends StatelessWidget {
  const _WarningItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                )),
          ),
        ],
      ),
    );
  }
}

