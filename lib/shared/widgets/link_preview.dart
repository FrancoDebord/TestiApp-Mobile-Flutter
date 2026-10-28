// Aperçu d'un lien collé dans un commentaire, une réponse ou une description :
// miniature, site, titre, début de la description.
//
// Lu par le serveur (docs serveur fonctionnalites/liens-et-apercus.md), qui
// filtre les adresses internes, suit les redirections et garde le résultat en
// cache : `GET /api/v1/link-preview?url=` connecté, `GET /liens/apercu?url=`
// (site, ouvert) pour un visiteur. Réponse `{ url, title, description, image,
// siteName, host }` ou `null`. Aucune erreur affichée : sans aperçu, le lien
// reste simplement cliquable dans le texte.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../services/api_service.dart' show apiServiceProvider;
import '../utils/rich_text_utils.dart';

/// Aperçu renvoyé par le serveur.
class LinkPreviewData {
  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    String? host,
  }) : _host = host;

  /// Adresse finale (après redirections).
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? _host;

  /// Domaine affiché sous le titre (`www.` retiré).
  String get host => (_host?.isNotEmpty ?? false)
      ? _host!
      : (Uri.tryParse(url)?.host ?? '').replaceFirst(RegExp(r'^www\.'), '');

  bool get isEmpty => (title ?? '').isEmpty && (imageUrl ?? '').isEmpty;

  /// `data` de la réponse ; null si la page n'a pas d'aperçu.
  static LinkPreviewData? fromJson(Object? data, String requested) {
    if (data is! Map) return null;
    String? str(String k) {
      final v = data[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final image = str('image');
    final preview = LinkPreviewData(
      url: str('url') ?? requested,
      title: str('title'),
      description: str('description'),
      imageUrl: image != null && image.startsWith('https://') ? image : null,
      siteName: str('siteName'),
      host: str('host'),
    );
    return preview.isEmpty ? null : preview;
  }
}

/// Lecture de l'aperçu d'une adresse (remplaçable dans les tests).
typedef LinkPreviewFetcher = Future<LinkPreviewData?> Function(String url);

final linkPreviewFetcherProvider = Provider<LinkPreviewFetcher>((ref) {
  final api = ref.watch(apiServiceProvider);
  final signedIn = ref.watch(currentUserProvider) != null;
  // Visiteur : route ouverte du site (même réponse, sans enveloppe `success`).
  final web = Dio(BaseOptions(
    baseUrl: AppConstants.webBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Accept': 'application/json'},
  ));
  ref.onDispose(web.close);

  return (String url) async {
    if (signedIn) {
      final res = await api.get<dynamic>(AppConstants.linkPreview, query: {'url': url});
      return LinkPreviewData.fromJson(res.data, url);
    }
    final res = await web.get<Map<String, dynamic>>(AppConstants.webLinkPreview, queryParameters: {'url': url});
    return LinkPreviewData.fromJson(res.data?['data'], url);
  };
});

/// Aperçu de [url], gardé pour la session ; null si indisponible.
final linkPreviewProvider = FutureProvider.family<LinkPreviewData?, String>((ref, url) async {
  try {
    return await ref.read(linkPreviewFetcherProvider)(url);
  } catch (_) {
    return null;
  }
});

/// Carte d'aperçu du premier lien de [text] ; rien s'il n'y en a pas.
class TextLinkPreview extends StatelessWidget {
  const TextLinkPreview(this.text, {this.padding = const EdgeInsets.only(top: 8), super.key});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final url = firstLinkUrl(text);
    if (url == null) return const SizedBox.shrink();
    return LinkPreviewCard(url: url, padding: padding);
  }
}

/// Miniature, titre et domaine de [url] ; un appui ouvre le lien (après confirmation).
/// Rien n'est affiché pendant la lecture ni si la page ne donne aucun aperçu.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({required this.url, this.padding = EdgeInsets.zero, super.key});

  final String url;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(linkPreviewProvider(url)).value;
    if (data == null) return const SizedBox.shrink();
    final image = data.imageUrl;
    final hasText = (data.title ?? '').isNotEmpty;

    return Padding(
      padding: padding,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openRichTextLink(context, url),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (image != null)
                  AspectRatio(
                    aspectRatio: hasText ? 1.91 : 4 / 3,
                    child: CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const ColoredBox(color: Color(0xFFEFF2F7)),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: Color(0xFFEFF2F7),
                        child: Icon(Icons.link_rounded, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data.siteName ?? data.host).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (hasText) ...[
                        const SizedBox(height: 2),
                        Text(
                          data.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                      if ((data.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          data.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
