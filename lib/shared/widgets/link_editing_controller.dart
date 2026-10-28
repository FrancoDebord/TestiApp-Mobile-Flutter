// Saisie qui reconnaît les adresses écrites ou collées (`https://…`, `www.…`) :
// soulignées en couleur dès qu'elles sont dans le champ, comme elles seront
// affichées une fois publiées (liens cliquables, aperçu). Le texte envoyé au
// serveur reste inchangé.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/mention.dart';
import '../utils/rich_text_utils.dart' show kBareUrlPattern;

class LinkEditingController extends TextEditingController {
  LinkEditingController({super.text});

  /// Passages « @Nom » à surligner (voir MentionEditingController).
  @protected
  Iterable<MentionRef> get highlightedMentions => const [];

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // Pendant une composition (clavier prédictif), le soulignement du clavier prime.
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final ranges = linkAndMentionRanges(text, highlightedMentions);
    if (ranges.isEmpty) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final base = style ?? const TextStyle();
    final mention = base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600);
    final link = base.copyWith(
      color: AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );
    final children = <TextSpan>[];
    var last = 0;
    for (final r in ranges) {
      if (r.start > last) children.add(TextSpan(text: text.substring(last, r.start)));
      children.add(TextSpan(text: text.substring(r.start, r.end), style: r.isLink ? link : mention));
      last = r.end;
    }
    if (last < text.length) children.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: style, children: children);
  }
}

/// Mentions et adresses de [text], triées ; une adresse qui chevauche une mention est ignorée.
List<({int start, int end, bool isLink})> linkAndMentionRanges(String text, Iterable<MentionRef> mentions) {
  final mentionRanges = mentions.isEmpty ? const <({int start, int end, MentionRef ref})>[] : MentionCodec.ranges(text, mentions);
  final out = <({int start, int end, bool isLink})>[
    for (final r in mentionRanges) (start: r.start, end: r.end, isLink: false),
  ];
  for (final m in kBareUrlPattern.allMatches(text)) {
    if (mentionRanges.any((r) => m.start < r.end && r.start < m.end)) continue;
    out.add((start: m.start, end: m.end, isLink: true));
  }
  return out..sort((a, b) => a.start.compareTo(b.start));
}
