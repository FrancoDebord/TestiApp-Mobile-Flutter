import 'package:flutter/material.dart';

// ── Inline span parser ────────────────────────────────────────────────────────

/// Parses inline markdown markers and returns a rich [TextSpan]:
///   **bold**       → FontWeight.w700
///   __italic__     → FontStyle.italic
///   ~~strikethrough~~ → TextDecoration.lineThrough
///
/// Child spans inherit [base]; only the affected property is overridden.
TextSpan buildFormattedSpan(String text, TextStyle base) {
  final pattern =
      RegExp(r'\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~', dotAll: true);
  final matches = pattern.allMatches(text).toList();
  if (matches.isEmpty) return TextSpan(text: text, style: base);

  final spans = <InlineSpan>[];
  int last = 0;
  for (final m in matches) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    if (m.group(1) != null) {
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(
        text: m.group(2),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    } else if (m.group(3) != null) {
      spans.add(TextSpan(
        text: m.group(3),
        style: const TextStyle(decoration: TextDecoration.lineThrough),
      ));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return TextSpan(style: base, children: spans);
}

// ── Block-level body renderer ─────────────────────────────────────────────────

/// Renders [text] as a Column of inline spans and blockquote blocks.
/// Lines that start with `> ` are grouped and rendered as a styled blockquote.
Widget buildRichBody(String text, TextStyle base) {
  final lines    = text.split('\n');
  final segments = <_Segment>[];

  bool isQuote = lines.isNotEmpty && lines.first.startsWith('> ');
  final buf    = StringBuffer();

  void flush() {
    final content = buf.toString().trimRight();
    if (content.isNotEmpty) segments.add(_Segment(content, isQuote));
    buf.clear();
  }

  for (final line in lines) {
    final lineIsQuote = line.startsWith('> ');
    if (lineIsQuote != isQuote) {
      flush();
      isQuote = lineIsQuote;
    }
    if (buf.isNotEmpty) buf.write('\n');
    buf.write(lineIsQuote ? line.substring(2) : line);
  }
  flush();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: segments.map((s) {
      if (s.isQuote) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _QuoteBlock(text: s.text, base: base),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SelectableText.rich(buildFormattedSpan(s.text, base)),
      );
    }).toList(),
  );
}

class _Segment {
  const _Segment(this.text, this.isQuote);
  final String text;
  final bool isQuote;
}

// ── Blockquote block widget ───────────────────────────────────────────────────

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.text, required this.base});

  final String text;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final quoteStyle = base.copyWith(
      fontStyle: FontStyle.italic,
      color: const Color(0xFF4C1D95),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6B21A8).withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF6B21A8), width: 3),
        ),
      ),
      child: SelectableText.rich(buildFormattedSpan(text, quoteStyle)),
    );
  }
}
