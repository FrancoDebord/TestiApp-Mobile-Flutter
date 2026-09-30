// lib/shared/widgets/guest_gate.dart
//
// Garde « compte requis » du mode invité.
//
//   if (!await requireAccount(context, ref, reason: 'réagir aux témoignages')) {
//     return;
//   }
//   // … action réservée aux membres
//
// Pour un invité : affiche une feuille « Créez un compte pour … » avec
// « Se connecter » (ouvre l'écran de connexion) et « Plus tard », puis
// renvoie false. Pour un membre connecté : renvoie true immédiatement.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/providers/auth_notifier.dart'
    show AuthStateAuthenticated, AuthStateGuest, authStateProvider;
import 'app_button.dart';
import 'app_logo.dart';

/// Vrai en mode invité (navigation sans compte).
final isGuestProvider = Provider<bool>(
    (ref) => ref.watch(authStateProvider).value is AuthStateGuest);

/// Renvoie true si l'utilisateur a un compte ; sinon explique pourquoi un
/// compte est nécessaire (invité) ou ouvre la connexion, et renvoie false.
Future<bool> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  String reason = 'profiter de toutes les fonctionnalités',
}) async {
  final state = ref.read(authStateProvider).value;
  if (state is AuthStateAuthenticated) return true;
  if (state is AuthStateGuest) {
    await showAccountRequiredSheet(context, reason: reason);
    return false;
  }
  // Non connecté (cas marginal) : direction la connexion.
  if (context.mounted) context.goNamed(AppRoutes.login);
  return false;
}

/// Feuille « Créez un compte pour … ». Utilisable sans WidgetRef (routeur).
/// Renvoie true si l'utilisateur a choisi « Se connecter ».
Future<bool> showAccountRequiredSheet(
  BuildContext context, {
  String reason = 'profiter de toutes les fonctionnalités',
}) async {
  final goLogin = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (sheetContext) => AccountRequiredSheet(reason: reason),
  );
  if (goLogin == true && context.mounted) {
    GoRouter.of(context).pushNamed(AppRoutes.login);
  }
  return goLogin == true;
}

/// Contenu de la feuille (public pour les tests de mise en page).
class AccountRequiredSheet extends StatelessWidget {
  const AccountRequiredSheet({required this.reason, super.key});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Center(child: AppLogoMark(size: 56)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Créez un compte pour $reason',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'C\'est gratuit et rapide. Vous pourrez partager, réagir et '
              'retrouver vos témoignages sur tous vos appareils.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Se connecter',
              leadingIcon: Icons.login_rounded,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Plus tard',
              variant: AppButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
