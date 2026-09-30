import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../widgets/profile_menu.dart';

/// Aide et support : FAQ, contact, signaler un problème.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = <(IconData, String, String)>[
    (
      Icons.add_circle_outline_rounded,
      'Comment publier un témoignage ?',
      'Touchez le bouton « + Publier » au centre de la barre du bas, puis '
          'choisissez vidéo, audio, texte ou image. Ajoutez un titre, une '
          'description et une catégorie, puis touchez « Publier ».',
    ),
    (
      Icons.verified_user_outlined,
      'Pourquoi mon témoignage est-il « en attente » ?',
      'Chaque témoignage est relu par notre équipe de modération avant sa '
          'publication. Vous recevez une notification dès qu\'il est approuvé '
          'ou si une correction est demandée.',
    ),
    (
      Icons.download_rounded,
      'Comment regarder hors connexion ?',
      'Sur un témoignage, touchez « Télécharger ». Retrouvez-le ensuite dans '
          'l\'onglet « Téléchargements ». Activez « Mode hors ligne » dans les '
          'paramètres pour ne lire que les témoignages téléchargés.',
    ),
    (
      Icons.person_outline_rounded,
      'Comment modifier ou supprimer mon compte ?',
      'Profil › Modifier le profil pour vos informations. Paramètres › '
          'Compte et sécurité pour supprimer définitivement votre compte.',
    ),
    (
      Icons.lock_outline_rounded,
      'Mes données sont-elles protégées ?',
      'Vos informations personnelles ne sont jamais vendues. Votre carnet '
          'privé n\'est visible que par vous, et vous choisissez qui peut '
          'commenter vos témoignages dans les paramètres.',
    ),
    (
      Icons.record_voice_over_outlined,
      'Comment fonctionne la lecture vocale ?',
      'Les témoignages écrits sont lus à voix haute automatiquement à '
          'l\'ouverture. Utilisez les commandes de lecture pour mettre en '
          'pause, reprendre ou arrêter la voix.',
    ),
  ];

  Future<void> _openSite(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(AppConstants.webBaseUrl),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir le site web")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profileHelp, style: AppTextStyles.h4.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xxxl),
        children: [
          // Bandeau d'accueil
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.surface, shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Comment pouvons-nous vous aider ?',
                          style: AppTextStyles.h4.copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('Réponses rapides aux questions fréquentes.',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
            child: Text('Questions fréquentes',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          for (final (icon, q, a) in _faq) ...[
            _FaqCard(icon: icon, question: q, answer: a),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          ProfileMenuCard(
            title: 'Nous contacter',
            children: [
              ProfileMenuTile(
                icon: Icons.public_rounded,
                title: 'Site web',
                subtitle: AppConstants.webBaseUrl
                    .replaceFirst(RegExp('^https?://'), ''),
                onTap: () => _openSite(context),
              ),
              ProfileMenuTile(
                icon: Icons.bug_report_outlined,
                title: 'Signaler un problème',
                subtitle: 'Décrivez ce qui ne fonctionne pas',
                onTap: () => _showReportSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ReportSheet(),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({required this.icon, required this.question, required this.answer});
  final IconData icon;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppShadows.cardDecoration,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
          collapsedShape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(60, 0, AppSpacing.lg, AppSpacing.lg),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          title: Text(
            question,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(answer, style: AppTextStyles.bodySmall.copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await SharePlus.instance.share(ShareParams(
      subject: 'Témoignages de Gloire — signalement d\'un problème',
      text: '$text\n\n— Plateforme : $platform · Version 1.0.0',
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signaler un problème', style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text(
                'Votre message sera partagé via l\'application de votre choix '
                '(e-mail, WhatsApp…).',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _ctrl,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Que s\'est-il passé ? Sur quel écran ?',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListenableBuilder(
                listenable: _ctrl,
                builder: (_, _) => AppButton(
                  label: 'Envoyer',
                  leadingIcon: Icons.send_rounded,
                  fullWidth: true,
                  onPressed: _ctrl.text.trim().isEmpty ? null : _send,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
