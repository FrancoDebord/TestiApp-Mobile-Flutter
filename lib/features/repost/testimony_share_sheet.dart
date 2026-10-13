// Feuille « Partager » commune aux cartes, à la page détail et aux lecteurs :
// « Partager sur TestiApp » (partage interne) en premier, puis les autres applis
// et la copie du lien. Ouverte sur le navigateur racine, au-dessus de la barre du
// bas, avec la marge de la zone système (sinon la feuille était trop basse).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../home/models/testimony_model.dart';
import '../home/providers/home_providers.dart' show interactionProvider;
import 'repost_widgets.dart' show showRepostSheet;

/// [excerpt] : extrait ajouté au texte partagé vers les autres applications.
Future<void> showTestimonyShareSheet(
  BuildContext context,
  WidgetRef ref,
  Testimony testimony, {
  String? excerpt,
}) {
  final me = ref.read(currentUserProvider)?.id ?? '';
  final isMine = me.isNotEmpty && testimony.author.uid == me;

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) {
      final l10n = AppLocalizations.of(sheet);
      final messenger = ScaffoldMessenger.of(context);
      void close() => Navigator.of(sheet).pop();

      void repost() {
        close();
        if (testimony.id.startsWith('local_')) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Ce témoignage n’est pas encore publié.'),
            behavior: SnackBarBehavior.floating,
          ));
        } else if (isMine) {
          messenger.showSnackBar(const SnackBar(
            content: Text('C’est votre témoignage : il est déjà visible par vos abonnés.'),
            behavior: SnackBarBehavior.floating,
          ));
        } else {
          showRepostSheet(context, ref,
              testimonyId: testimony.id, authorName: testimony.author.displayName);
        }
      }

      void shareExternal() {
        close();
        final e = excerpt?.trim() ?? '';
        SharePlus.instance.share(ShareParams(
          text: '${testimony.title}\n\n'
              '${e.isEmpty ? '' : '$e\n\n'}'
              '${testimony.shareLink}',
        ));
        ref.read(interactionProvider.notifier).recordShare(testimony.id);
      }

      void copyLink() {
        Clipboard.setData(ClipboardData(text: testimony.shareLink));
        close();
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.detailLinkCopied),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.detailShareTitle,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  testimony.shareLink,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ShareOption(
                          key: const ValueKey('repost-on-testiapp'),
                          icon: Icons.repeat_rounded,
                          label: 'Sur TestiApp',
                          color: AppColors.primary,
                          onTap: repost,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ShareOption(
                          icon: Icons.copy_rounded,
                          label: l10n.detailCopyLink,
                          color: AppColors.primary,
                          onTap: copyLink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ShareOption(
                          icon: Icons.share_rounded,
                          label: l10n.detailShareOn,
                          color: AppColors.secondary,
                          onTap: shareExternal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withAlpha(60)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
