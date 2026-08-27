import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/bible_models.dart';
import '../providers/bible_providers.dart';

class BibleScreen extends ConsumerWidget {
  const BibleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationsAsync = ref.watch(bibleTranslationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Bible', style: AppTextStyles.h3),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Actualiser',
            onPressed: () =>
                ref.invalidate(bibleTranslationsProvider),
          ),
        ],
      ),
      body: translationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _ErrorBody(
          message: err.toString(),
          onRetry: () => ref.invalidate(bibleTranslationsProvider),
        ),
        data: (translations) => translations.isEmpty
            ? const _EmptyBody()
            : _TranslationList(translations: translations),
      ),
    );
  }
}

// ── Language helpers ──────────────────────────────────────────────────────────

String _languageLabel(String lang) => switch (lang.toLowerCase()) {
      'fr' => 'Français',
      'en' => 'English',
      'es' => 'Español',
      'pt' => 'Português',
      'de' => 'Deutsch',
      'it' => 'Italiano',
      'ar' => 'العربية',
      'sw' => 'Kiswahili',
      'ln' => 'Lingala',
      'yo' => 'Yoruba',
      'ha' => 'Hausa',
      'ig' => 'Igbo',
      'am' => 'Amharique',
      'rw' => 'Kinyarwanda',
      'wo' => 'Wolof',
      _    => lang.toUpperCase(),
    };

/// Trie les langues : fr en premier, en deuxième, puis les autres par label.
List<String> _sortedLanguages(Iterable<String> langs) {
  const priority = ['fr', 'en', 'es', 'pt'];
  final result = langs.toList()
    ..sort((a, b) {
      final ai = priority.indexOf(a);
      final bi = priority.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return _languageLabel(a).compareTo(_languageLabel(b));
    });
  return result;
}

// ── Translation list ──────────────────────────────────────────────────────────

class _TranslationList extends ConsumerWidget {
  const _TranslationList({required this.translations});
  final List<BibleTranslation> translations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group by language
    final grouped = <String, List<BibleTranslation>>{};
    for (final t in translations) {
      grouped.putIfAbsent(t.language, () => []).add(t);
    }
    final langs = _sortedLanguages(grouped.keys);

    // Flatten into a widget list: header → cards
    final children = <Widget>[];
    for (var li = 0; li < langs.length; li++) {
      if (li > 0) children.add(const SizedBox(height: 8));
      children.add(_LangHeader(language: langs[li]));
      children.add(const SizedBox(height: 10));
      final cards = grouped[langs[li]]!;
      for (var ci = 0; ci < cards.length; ci++) {
        children.add(_TranslationCard(translation: cards[ci]));
        if (ci < cards.length - 1) children.add(const SizedBox(height: 12));
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: children,
    );
  }
}

// ── Language section header ───────────────────────────────────────────────────

class _LangHeader extends StatelessWidget {
  const _LangHeader({required this.language});
  final String language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _languageLabel(language).toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(color: AppColors.border, height: 1),
        ),
      ],
    );
  }
}

// ── Translation card ──────────────────────────────────────────────────────────

class _TranslationCard extends ConsumerWidget {
  const _TranslationCard({required this.translation});
  final BibleTranslation translation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = translation;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: t.isDownloaded
              ? AppColors.primary.withAlpha(60)
              : AppColors.border,
          width: t.isDownloaded ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                _AbbreviationBadge(
                  abbreviation: t.abbreviation,
                  downloaded: t.isDownloaded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_languageLabel(t.language)}'
                        '${t.verseCount > 0 ? '  ·  ${_formatCount(t.verseCount)} versets' : ''}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (t.isDownloaded)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 20, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'delete') {
                        _confirmDelete(context, ref, t.code, t.name);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Supprimer',
                                style:
                                    TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // ── Progress bar ─────────────────────────────────────────────────
            if (t.isDownloading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: t.downloadProgress,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
                minHeight: 5,
              ),
              const SizedBox(height: 6),
              Text(
                t.downloadProgress != null
                    ? '${(t.downloadProgress! * 100).round()} %'
                    : 'Connexion…',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // ── Error ─────────────────────────────────────────────────────────
            if (t.downloadStatus == DownloadStatus.error &&
                t.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                'Erreur : ${t.errorMessage}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.danger),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Action buttons ────────────────────────────────────────────────
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (t.isDownloaded)
                  _ActionButton(
                    label: 'Lire',
                    icon: Icons.import_contacts_rounded,
                    onTap: () => context.push('/bible/${t.code}'),
                    primary: true,
                  )
                else if (t.isDownloading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  )
                else ...[
                  if (t.downloadStatus == DownloadStatus.error)
                    _ActionButton(
                      label: 'Réessayer',
                      icon: Icons.refresh_rounded,
                      onTap: () => ref
                          .read(bibleTranslationsProvider.notifier)
                          .download(t.code),
                      primary: false,
                    )
                  else
                    _ActionButton(
                      label: 'Télécharger',
                      icon: Icons.download_rounded,
                      onTap: () => ref
                          .read(bibleTranslationsProvider.notifier)
                          .download(t.code),
                      primary: false,
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la version ?'),
        content: Text(
          'La version "$name" sera supprimée de votre appareil. '
          'Vous pourrez la re-télécharger à tout moment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(bibleTranslationsProvider.notifier)
                  .delete(id);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(0)}k' : '$n';
}

// ── Abbreviation badge ────────────────────────────────────────────────────────

class _AbbreviationBadge extends StatelessWidget {
  const _AbbreviationBadge({
    required this.abbreviation,
    required this.downloaded,
  });
  final String abbreviation;
  final bool   downloaded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: downloaded
              ? [AppColors.primary, AppColors.primaryLight]
              : [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          abbreviation,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });
  final String       label;
  final IconData     icon;
  final VoidCallback onTap;
  final bool         primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.primary
              : AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(50),
          border: primary
              ? null
              : Border.all(color: AppColors.primary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: primary ? Colors.white : AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: primary ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded,
                size: 64,
                color: AppColors.textSecondary.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              'Aucune version disponible',
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Les versions de la Bible seront disponibles '
              'dès que le serveur les proposera.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger les versions',
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
