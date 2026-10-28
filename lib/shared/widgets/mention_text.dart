// Mentions « @ » : affichage cliquable et format d'échange avec le serveur.
// Backend : docs/fonctionnalites/mentions.md
//
// Le serveur enregistre `@[Nom affiché](user:uuid)` et renvoie le texte lisible (`@Nom affiché`)
// accompagné de `mentions: [{id, displayName}]`. [MentionText] accepte les deux formes
// (texte lisible + liste, ou texte contenant encore des jetons, par ex. un envoi en attente).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../models/mention.dart';
import '../utils/rich_text_utils.dart' show kBareUrlPattern, openRichTextLink;
import 'link_preview.dart';

export '../models/mention.dart';

/// Texte avec mentions cliquables (profil `/users/{id}` par défaut) et adresses
/// `https://…` / `www.…` cliquables (confirmation puis navigateur).
class MentionText extends StatefulWidget {
  const MentionText(
    this.text, {
    this.mentions = const [],
    this.style,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onMentionTap,
    this.prefix = const [],
    this.textAlign,
    this.linkPreview = false,
    super.key,
  });

  /// Morceaux affichés avant le texte, sur la même ligne (ex. nom de l'auteur
  /// d'un message de chat, comme sur YouTube).
  final List<InlineSpan> prefix;

  /// Texte lisible (« @Nom ») ou contenant des jetons `@[Nom](user:id)`.
  final String text;
  final List<MentionRef> mentions;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// Carte d'aperçu (miniature, titre) du premier lien sous le texte :
  /// commentaires, réponses, descriptions.
  final bool linkPreview;

  /// Remplace l'ouverture du profil.
  final ValueChanged<MentionRef>? onMentionTap;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _open(MentionRef ref) {
    if (widget.onMentionTap != null) {
      widget.onMentionTap!(ref);
    } else {
      context.push('/users/${ref.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final decoded = MentionCodec.decode(widget.text);
    final mentions = [...widget.mentions, ...decoded.mentions.where((d) => !widget.mentions.any((m) => m.id == d.id))];
    final text = decoded.text;
    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final linkStyle = widget.mentionStyle ?? base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600);
    final urlStyle = linkStyle.copyWith(decoration: TextDecoration.underline, decorationColor: linkStyle.color);

    // Mentions et adresses, dans l'ordre ; une adresse qui chevauche une mention est ignorée.
    final ranges = <({int start, int end, MentionRef? ref, String? url})>[
      for (final r in MentionCodec.ranges(text, mentions)) (start: r.start, end: r.end, ref: r.ref, url: null),
    ];
    for (final m in kBareUrlPattern.allMatches(text)) {
      if (ranges.any((r) => r.ref != null && m.start < r.end && r.start < m.end)) continue;
      ranges.add((start: m.start, end: m.end, ref: null, url: m.group(1)));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));

    final Widget body;
    if (ranges.isEmpty && widget.prefix.isEmpty) {
      body = Text(text, style: base, maxLines: widget.maxLines, overflow: widget.overflow, textAlign: widget.textAlign);
    } else {
      final spans = <InlineSpan>[...widget.prefix];
      var last = 0;
      for (final r in ranges) {
        if (r.start > last) spans.add(TextSpan(text: text.substring(last, r.start)));
        final recognizer = TapGestureRecognizer()
          ..onTap = r.ref != null ? () => _open(r.ref!) : () => openRichTextLink(context, r.url!);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: text.substring(r.start, r.end),
          style: r.ref != null ? linkStyle : urlStyle,
          recognizer: recognizer,
        ));
        last = r.end;
      }
      if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
      body = Text.rich(
        TextSpan(style: base, children: spans),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    if (!widget.linkPreview || !ranges.any((r) => r.url != null)) return body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (widget.textAlign) {
        TextAlign.center => CrossAxisAlignment.center,
        _ => CrossAxisAlignment.start,
      },
      children: [body, TextLinkPreview(text)],
    );
  }
}
