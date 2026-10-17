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

  static List<(IconData, String, String)> _faq(AppLocalizations l10n) => [
        (Icons.add_circle_outline_rounded, l10n.profileFaqPublishQ, l10n.profileFaqPublishA),
        (Icons.verified_user_outlined, l10n.profileFaqPendingQ, l10n.profileFaqPendingA),
        (Icons.download_rounded, l10n.profileFaqOfflineQ, l10n.profileFaqOfflineA),
        (Icons.person_outline_rounded, l10n.profileFaqAccountQ, l10n.profileFaqAccountA),
        (Icons.lock_outline_rounded, l10n.profileFaqPrivacyQ, l10n.profileFaqPrivacyA),
        (Icons.record_voice_over_outlined, l10n.profileFaqTtsQ, l10n.profileFaqTtsA),
      ];

  Future<void> _openSite(BuildContext context) async {
    final ok = await launchUrl(Uri.parse(AppConstants.webBaseUrl),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.profileAboutSiteOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                      Text(l10n.profileHelpHowCanWeHelp,
                          style: AppTextStyles.h4.copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(l10n.profileHelpQuickAnswers,
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
            child: Text(l10n.profileHelpFaq,
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          for (final (icon, q, a) in _faq(l10n)) ...[
            _FaqCard(icon: icon, question: q, answer: a),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          ProfileMenuCard(
            title: l10n.profileHelpContact,
            children: [
              ProfileMenuTile(
                icon: Icons.public_rounded,
                title: l10n.profileAboutWebsite,
                subtitle: AppConstants.webBaseUrl
                    .replaceFirst(RegExp('^https?://'), ''),
                onTap: () => _openSite(context),
              ),
              ProfileMenuTile(
                icon: Icons.bug_report_outlined,
                title: l10n.profileHelpReportProblem,
                subtitle: l10n.profileHelpReportProblemHint,
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
      subject: context.l10n.profileHelpReportSubject,
      text: context.l10n.profileHelpReportBody(text, platform, '1.0.0'),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
              Text(l10n.profileHelpReportProblem, style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text(
                l10n.profileHelpReportShareInfo,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _ctrl,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.profileHelpReportInputHint,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListenableBuilder(
                listenable: _ctrl,
                builder: (_, _) => AppButton(
                  label: l10n.commonSend,
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
