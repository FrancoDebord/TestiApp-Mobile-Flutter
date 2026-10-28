// Saisie d'un témoignage écrit avec mise en forme visible en direct.
//
// Le texte reste dans la syntaxe de rich_text_utils.dart (**gras**, # titre,
// [lien](https://…), ![](https://…)…) : c'est ce que le serveur enregistre et
// ce que tous les écrans savent afficher. Le champ, lui, montre déjà le
// résultat : passages en gras, titres plus grands, citations, liens soulignés ;
// les balises restent visibles mais estompées (le curseur peut les traverser
// et les effacer comme n'importe quel caractère).

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../models/mention.dart';
import '../utils/rich_text_utils.dart' show kRichImageLinePattern;
import 'mention_text_field.dart';

class RichMentionEditingController extends MentionEditingController {
  RichMentionEditingController({super.text});

  static final _inline = RegExp(
      r'(\*\*)(.+?)(\*\*)|(__)(.+?)(__)|(~~)(.+?)(~~)|(?<![!@])(\[)([^\]\n]+)(\]\(https?://[^\s)]+\))');
  static final _heading = RegExp(r'^#{1,3} ');
  static final _listItem = RegExp(r'^(- |• |\d{1,3}[.)] )');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (text.isEmpty) return TextSpan(text: text, style: base);
    final mentionRanges = MentionCodec.ranges(text, mentions);
    final out = <InlineSpan>[];
    var offset = 0;
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      _line(lines[i], offset, base, mentionRanges, out);
      offset += lines[i].length;
      if (i < lines.length - 1) {
        out.add(const TextSpan(text: '\n'));
        offset += 1;
      }
    }
    return TextSpan(style: base, children: out);
  }

  static TextStyle _marker(TextStyle s) =>
      s.copyWith(color: AppColors.textSecondary.withAlpha(140), fontWeight: FontWeight.w400);

  void _line(
    String line,
    int start,
    TextStyle base,
    List<({int start, int end, MentionRef ref})> mentionRanges,
    List<InlineSpan> out,
  ) {
    // Image : ligne entière, présentée comme une pastille discrète.
    if (kRichImageLinePattern.hasMatch(line.trim())) {
      out.add(TextSpan(
        text: line,
        style: _marker(base).copyWith(
          fontSize: (base.fontSize ?? 15) * 0.8,
          backgroundColor: AppColors.primarySoft,
          color: AppColors.primary.withAlpha(170),
        ),
      ));
      return;
    }

    var content = base;
    var prefixLength = 0;
    var prefixStyle = _marker(base);
    if (_heading.firstMatch(line) case final m?) {
      prefixLength = m.end;
      content = base.copyWith(
        fontSize: (base.fontSize ?? 15) * 1.15,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryDark,
      );
    } else if (line.startsWith('> ')) {
      prefixLength = 2;
      content = base.copyWith(fontStyle: FontStyle.italic, color: AppColors.primaryDark);
      prefixStyle = base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700);
    } else if (_listItem.firstMatch(line) case final m?) {
      prefixLength = m.end;
      prefixStyle = base.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700);
    }
    if (prefixLength > 0) {
      out.add(TextSpan(text: line.substring(0, prefixLength), style: prefixStyle));
    }
    _inlineSpans(line.substring(prefixLength), start + prefixLength, content, mentionRanges, out);
  }

  /// Gras, italique, barré et liens d'une ligne ; balises estompées.
  void _inlineSpans(
    String s,
    int start,
    TextStyle style,
    List<({int start, int end, MentionRef ref})> mentionRanges,
    List<InlineSpan> out,
  ) {
    var last = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > last) _plain(s.substring(last, m.start), start + last, style, mentionRanges, out);
      // Groupes (ouvrant, contenu, fermant) : 1-3 gras, 4-6 italique, 7-9 barré, 10-12 lien.
      final g = m.group(1) != null
          ? 1
          : m.group(4) != null
              ? 4
              : m.group(7) != null
                  ? 7
                  : 10;
      final open = m.group(g)!;
      final inner = m.group(g + 1)!;
      final close = m.group(g + 2)!;
      final innerStyle = switch (g) {
        1 => style.copyWith(fontWeight: FontWeight.w700),
        4 => style.copyWith(fontStyle: FontStyle.italic),
        7 => style.copyWith(decoration: TextDecoration.lineThrough),
        _ => style.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
      };
      out.add(TextSpan(text: open, style: _marker(style)));
      final innerStart = start + m.start + open.length;
      if (g == 10) {
        out.add(TextSpan(text: inner, style: innerStyle));
      } else {
        _inlineSpans(inner, innerStart, innerStyle, mentionRanges, out);
      }
      out.add(TextSpan(
        text: close,
        // Adresse du lien : plus petite, pour laisser le texte au premier plan.
        style: g == 10
            ? _marker(style).copyWith(fontSize: (style.fontSize ?? 15) * 0.8)
            : _marker(style),
      ));
      last = m.end;
    }
    if (last < s.length) _plain(s.substring(last), start + last, style, mentionRanges, out);
  }

  /// Texte sans balise ; « @Nom » mis en évidence.
  void _plain(
    String s,
    int start,
    TextStyle style,
    List<({int start, int end, MentionRef ref})> mentionRanges,
    List<InlineSpan> out,
  ) {
    final end = start + s.length;
    var cursor = start;
    for (final r in mentionRanges) {
      if (r.end <= cursor || r.start >= end) continue;
      final a = r.start < cursor ? cursor : r.start;
      final b = r.end > end ? end : r.end;
      if (a > cursor) out.add(TextSpan(text: s.substring(cursor - start, a - start), style: style));
      out.add(TextSpan(
        text: s.substring(a - start, b - start),
        style: style.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
      ));
      cursor = b;
    }
    if (cursor < end) out.add(TextSpan(text: s.substring(cursor - start), style: style));
  }
}
