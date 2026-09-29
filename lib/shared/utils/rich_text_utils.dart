import 'package:flutter/material.dart';

// ── Syntaxe de mise en forme (saisie via la barre d'outils de publication) ────
//
// En ligne :
//   **gras**        __italique__        ~~barré~~
// Par ligne :
//   # Titre         > citation          - élément de liste     1. liste numérotée

const _kInlineMarkers = ['**', '__', '~~'];

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

/// Retire toutes les balises de mise en forme (partage, aperçus en une ligne).
String stripFormatting(String text) {
  return text
      .replaceAllMapped(
          RegExp(r'\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~', dotAll: true),
          (m) => m.group(1) ?? m.group(2) ?? m.group(3) ?? '')
      .replaceAll(RegExp(r'^(#{1,3} |> )', multiLine: true), '')
      .replaceAll(RegExp(r'^- ', multiLine: true), '• ');
}

// ── Block-level body renderer ─────────────────────────────────────────────────

enum _BlockKind { paragraph, quote, heading, bullet, numbered }

class _Block {
  _Block(this.kind, this.text, {this.number});
  final _BlockKind kind;
  final String text;
  final String? number; // "1." pour une liste numérotée
}

final _numberedRe = RegExp(r'^(\d{1,3})[.)] ');

List<_Block> _parseBlocks(String text) {
  final blocks = <_Block>[];
  final para   = StringBuffer();
  final quote  = StringBuffer();

  void flushPara() {
    final t = para.toString().trimRight();
    if (t.isNotEmpty) blocks.add(_Block(_BlockKind.paragraph, t));
    para.clear();
  }

  void flushQuote() {
    final t = quote.toString().trimRight();
    if (t.isNotEmpty) blocks.add(_Block(_BlockKind.quote, t));
    quote.clear();
  }

  for (final line in text.split('\n')) {
    if (line.startsWith('> ')) {
      flushPara();
      if (quote.isNotEmpty) quote.write('\n');
      quote.write(line.substring(2));
      continue;
    }
    flushQuote();

    final heading = RegExp(r'^#{1,3} ').firstMatch(line);
    final number  = _numberedRe.firstMatch(line);
    if (heading != null) {
      flushPara();
      blocks.add(_Block(_BlockKind.heading, line.substring(heading.end)));
    } else if (line.startsWith('- ') || line.startsWith('• ')) {
      flushPara();
      blocks.add(_Block(_BlockKind.bullet, line.substring(2)));
    } else if (number != null) {
      flushPara();
      blocks.add(_Block(_BlockKind.numbered, line.substring(number.end),
          number: '${number.group(1)}.'));
    } else if (line.trim().isEmpty) {
      // Ligne vide = séparation de paragraphes.
      flushPara();
    } else {
      if (para.isNotEmpty) para.write('\n');
      para.write(line);
    }
  }
  flushPara();
  flushQuote();
  return blocks;
}

/// Renders [text] with inline formatting plus block formatting: headings
/// (`# `), blockquotes (`> `), bullet lists (`- `) and numbered lists (`1. `).
///
/// [selectable] : false dans les cartes du fil, où la sélection
/// intercepterait le tap qui ouvre le détail.
///
/// La sélection passe par une seule [SelectionArea] autour du corps, et non
/// par un SelectableText par paragraphe : chaque SelectableText embarque son
/// propre Scrollable qui capte le glissement vertical, ce qui empêchait la
/// page entière de défiler quand le doigt était posé sur le texte.
Widget buildRichBody(String text, TextStyle base, {bool selectable = true}) {
  final body = _buildBlocks(text, base);
  return selectable ? SelectionArea(child: body) : body;
}

Widget _buildBlocks(String text, TextStyle base) {
  Widget rich(String t, TextStyle style) =>
      Text.rich(buildFormattedSpan(t, style));

  final blocks = _parseBlocks(text);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < blocks.length; i++)
        switch (blocks[i].kind) {
          _BlockKind.quote => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuoteBlock(
                child: rich(
                  blocks[i].text,
                  base.copyWith(
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF103675),
                  ),
                ),
              ),
            ),
          _BlockKind.heading => Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6, bottom: 6),
              child: rich(
                blocks[i].text,
                base.copyWith(
                  fontSize: (base.fontSize ?? 15) * 1.15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF103675),
                ),
              ),
            ),
          _BlockKind.bullet || _BlockKind.numbered => Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      blocks[i].number ?? '•',
                      style: base.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF184797),
                      ),
                    ),
                  ),
                  Expanded(child: rich(blocks[i].text, base)),
                ],
              ),
            ),
          _BlockKind.paragraph => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: rich(blocks[i].text, base),
            ),
        },
    ],
  );
}

// ── Blockquote block widget ───────────────────────────────────────────────────

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF184797).withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF184797), width: 3),
        ),
      ),
      child: child,
    );
  }
}

// ── Affichage progressif ──────────────────────────────────────────────────────

/// Position de coupe ≥ [target] qui ne tombe ni au milieu d'un mot ni à
/// l'intérieur d'une balise ouverte (**, __, ~~).
int _safeCut(String text, int target) {
  if (target >= text.length) return text.length;

  // 1. Préférer une fin de paragraphe, sinon de phrase, sinon un espace,
  //    dans une fenêtre raisonnable après la cible.
  final window = text.substring(target, (target + 240).clamp(0, text.length));
  int cut;
  final para = window.indexOf('\n');
  final sentence = RegExp(r'[.!?…](\s)').firstMatch(window);
  final space = window.indexOf(' ');
  if (para >= 0) {
    cut = target + para;
  } else if (sentence != null) {
    cut = target + sentence.start + 1;
  } else if (space >= 0) {
    cut = target + space;
  } else {
    cut = target + window.length;
  }

  // 2. Si une balise reste ouverte, avancer jusqu'à sa fermeture.
  for (var guard = 0; guard < 6; guard++) {
    String? open;
    for (final m in _kInlineMarkers) {
      if (m.allMatches(text.substring(0, cut)).length.isOdd) open = m;
    }
    if (open == null) break;
    final close = text.indexOf(open, cut);
    if (close < 0) break;
    cut = close + open.length;
  }
  return cut.clamp(0, text.length);
}

/// Affiche [text] mis en forme, un morceau à la fois : [initialChars]
/// caractères d'abord, puis [stepChars] de plus à chaque « Lire la suite »,
/// jusqu'au texte complet (puis « Réduire »).
class ProgressiveRichText extends StatefulWidget {
  const ProgressiveRichText({
    required this.text,
    required this.style,
    this.initialChars = 280,
    this.stepChars = 700,
    this.selectable = true,
    this.linkStyle,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int initialChars;
  final int stepChars;
  final bool selectable;
  final TextStyle? linkStyle;

  @override
  State<ProgressiveRichText> createState() => _ProgressiveRichTextState();
}

class _ProgressiveRichTextState extends State<ProgressiveRichText> {
  late int _shown = _safeCut(widget.text, widget.initialChars);

  @override
  void didUpdateWidget(ProgressiveRichText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _shown = _safeCut(widget.text, widget.initialChars);
    }
  }

  void _more() => setState(
      () => _shown = _safeCut(widget.text, _shown + widget.stepChars));

  void _collapse() =>
      setState(() => _shown = _safeCut(widget.text, widget.initialChars));

  @override
  Widget build(BuildContext context) {
    final text     = widget.text;
    final complete = _shown >= text.length;
    final visible  = complete ? text : '${text.substring(0, _shown).trimRight()}…';
    final canCollapse =
        complete && _safeCut(text, widget.initialChars) < text.length;
    final remaining = text.length - _shown;

    final linkStyle = widget.linkStyle ??
        const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF184797),
        );

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildRichBody(visible, widget.style, selectable: widget.selectable),
          if (!complete || canCollapse)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: complete ? _collapse : _more,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  complete
                      ? 'Réduire ‹'
                      // Dernier morceau : inutile d'annoncer une « suite ».
                      : remaining <= widget.stepChars
                          ? 'Lire la fin ›'
                          : 'Lire la suite ›',
                  style: linkStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
