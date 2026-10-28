// « Sur le web » : l'auteur donne ou retire son accord pour le site et Google,
// et choisit l'anonymat sur le site, sans que son témoignage repasse en
// modération. Backend : PUT /testimonies/{id}/web — docs serveur
// fonctionnalites/referencement.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../home/models/testimony_model.dart';

/// Envoie l'accord pour le web ; renvoie l'état enregistré par le serveur.
Future<TestimonyWebPublication> saveTestimonyWebPublication(
  ApiService api,
  String testimonyId, {
  bool? publicationWeb,
  bool? isAnonymous,
}) async {
  final res = await api.put<Map<String, dynamic>>(
    AppConstants.testimonyWeb(testimonyId),
    data: {
      'publicationWeb': ?publicationWeb,
      'isAnonymous': ?isAnonymous,
    },
  );
  return TestimonyWebPublication.fromJson(res.data) ??
      TestimonyWebPublication(publicationWeb: publicationWeb ?? true, isAnonymous: isAnonymous ?? false);
}

/// Carte « Sur le web » de la page d'un témoignage, pour son auteur.
class TestimonyWebPublicationCard extends ConsumerStatefulWidget {
  const TestimonyWebPublicationCard({
    required this.testimonyId,
    required this.initial,
    super.key,
  });

  final String testimonyId;
  final TestimonyWebPublication initial;

  @override
  ConsumerState<TestimonyWebPublicationCard> createState() => _TestimonyWebPublicationCardState();
}

class _TestimonyWebPublicationCardState extends ConsumerState<TestimonyWebPublicationCard> {
  late TestimonyWebPublication _web = widget.initial;
  bool _saving = false;

  /// Affichage immédiat, puis état du serveur ; en cas d'échec, retour à l'état précédent.
  Future<void> _save({bool? publicationWeb, bool? isAnonymous}) async {
    final before = _web;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    setState(() {
      _web = _web.copyWith(publicationWeb: publicationWeb, isAnonymous: isAnonymous);
      _saving = true;
    });
    try {
      final saved = await saveTestimonyWebPublication(
        ref.read(apiServiceProvider),
        widget.testimonyId,
        publicationWeb: publicationWeb,
        isAnonymous: isAnonymous,
      );
      if (!mounted) return;
      setState(() => _web = _web.copyWith(publicationWeb: saved.publicationWeb, isAnonymous: saved.isAnonymous));
      messenger?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(saved.publicationWeb ? l10n.testimonyWebSavedOn : l10n.testimonyWebSavedOff),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _web = before);
      final detail = e is LaravelApiException ? e.displayMessage : '';
      messenger?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(detail.isEmpty ? l10n.testimonyWebSaveFailed : detail),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titleStyle = AppTextStyles.labelMedium.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            key: const ValueKey('testimony-web-switch'),
            contentPadding: EdgeInsets.zero,
            value: _web.publicationWeb,
            onChanged: _saving ? null : (v) => _save(publicationWeb: v),
            activeThumbColor: AppColors.primary,
            secondary: const Icon(Icons.travel_explore_rounded, color: AppColors.primary),
            title: Text(l10n.testimonyWebTitle, style: titleStyle),
            subtitle: Text(
              _web.publicationWeb ? l10n.testimonyWebOnHint : l10n.testimonyWebOffHint,
              style: AppTextStyles.bodySmall,
            ),
          ),
          if (_web.publicationWeb)
            CheckboxListTile(
              key: const ValueKey('testimony-web-anonymous'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _web.isAnonymous,
              onChanged: _saving ? null : (v) => _save(isAnonymous: v ?? false),
              activeColor: AppColors.primary,
              title: Text(l10n.publishWebAnonymous, style: titleStyle),
              subtitle: Text(l10n.publishWebAnonymousHint, style: AppTextStyles.bodySmall),
            ),
        ],
      ),
    );
  }
}
