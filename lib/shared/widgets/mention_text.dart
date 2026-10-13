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

export '../models/mention.dart';

/// Texte avec mentions cliquables (profil `/users/{id}` par défaut).
class MentionText extends StatefulWidget {
  const MentionText(
    this.text, {
    this.mentions = const [],
    this.style,
    this.mentionStyle,
    this.maxLines,
    this.overflow,
    this.onMentionTap,
    super.key,
  });

  /// Texte lisible (« @Nom ») ou contenant des jetons `@[Nom](user:id)`.
  final String text;
  final List<MentionRef> mentions;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final int? maxLines;
  final TextOverflow? overflow;

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

    final ranges = MentionCodec.ranges(text, mentions);
    if (ranges.isEmpty) {
      return Text(text, style: base, maxLines: widget.maxLines, overflow: widget.overflow);
    }

    final spans = <InlineSpan>[];
    var last = 0;
    for (final r in ranges) {
      if (r.start > last) spans.add(TextSpan(text: text.substring(last, r.start)));
      final recognizer = TapGestureRecognizer()..onTap = () => _open(r.ref);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: text.substring(r.start, r.end),
        style: linkStyle,
        recognizer: recognizer,
      ));
      last = r.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
