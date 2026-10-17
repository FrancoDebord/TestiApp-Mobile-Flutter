// Section « Témoignages de conversion » : témoignages publiés (kind = conversion),
// du plus récent au plus ancien ; invitation à raconter le sien.
// Backend : docs/fonctionnalites/temoignage-de-conversion.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../home/widgets/compact_testimony_tile.dart';
import '../data/conversion_repository.dart';
import '../providers/conversion_providers.dart';
import '../widgets/conversion_widgets.dart';

class ConversionTestimoniesScreen extends ConsumerWidget {
  const ConversionTestimoniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversionListProvider);
    final user = ref.watch(currentUserProvider);
    final mine = ref.watch(myConversionProvider).value;

    // En-tête : invitation (compte personnel sans témoignage de conversion), le mien,
    // ou « Se connecter pour raconter ma conversion » pour un visiteur.
    final Widget header;
    if (user == null) {
      header = OutlinedButton.icon(
        onPressed: () => context.push('/login'),
        icon: const Icon(Icons.login_rounded),
        label: Text(context.l10n.conversionLoginToTell),
      );
    } else if (mine?.testimony case final t?) {
      header = ConversionFeaturedCard(
        testimony: t,
        statusLabel: conversionStatusLabel(context, mine!),
        onEdit: () => context.push('/conversions/mine/edit'),
      );
    } else if (mine?.canCreate ?? false) {
      header = const ConversionInviteCard();
    } else {
      header = const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.l10n.conversionSectionTitle,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myConversionProvider);
          await ref.read(conversionListProvider.notifier).refreshAll();
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              ref.read(conversionListProvider.notifier).loadMore();
            }
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 40),
            children: [
              Text(context.l10n.conversionSectionIntro,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              header,
              const SizedBox(height: 18),
              ...switch (async) {
                AsyncValue(:final value?) when value.items.isEmpty => [
                    _Empty(text: context.l10n.conversionEmpty),
                  ],
                AsyncValue(:final value?) => [
                    for (final t in value.items) ...[
                      CompactTestimonyTile(testimony: t),
                      const SizedBox(height: 10),
                    ],
                    if (value.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                AsyncValue(:final error?) => [
                    _Empty(
                      text: error is ConversionFailure ? error.message : context.l10n.conversionLoadError,
                      onRetry: () => ref.invalidate(conversionListProvider),
                    ),
                  ],
                _ => const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(conversionIcon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}
