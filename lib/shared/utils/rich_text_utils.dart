import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mention.dart';
import '../../l10n/app_localizations.dart';

// ── Syntaxe de mise en forme (saisie via la barre d'outils de publication) ────
//
// En ligne :
//   **gras**        __italique__        ~~barré~~        [texte](https://…)
// Par ligne :
//   # Titre         > citation          - élément de liste     1. liste numérotée
//   ![légende](https://…)               image (seule sur sa ligne)

const _kInlineMarkers = ['**', '__', '~~'];

/// Lien `[texte](https://…)` — ni une image `![…](…)` ni une mention `@[Nom](user:id)`.
final kRichLinkPattern =
    RegExp(r'(?<![!@])\[([^\]\n]+)\]\((https?://[^\s)]+)\)');

/// Adresse `https://…` (ou `www.…`) écrite ou collée telle quelle : lien aussi
/// (comme sur le site). La ponctuation finale (« . », « , », « ! »…) n'en fait pas partie.
final kBareUrlPattern = RegExp(
    r'''((?:https?://|(?<![\w.@/])www\.)[^\s<>()\[\]"']*[^\s<>()\[\]"'.,;:!?»])''',
    caseSensitive: false);

/// Adresse ouvrable : « www.… » reçoit `https://`.
String normalizeLinkUrl(String url) =>
    RegExp(r'^https?://', caseSensitive: false).hasMatch(url) ? url : 'https://$url';

/// Première adresse de [text] (lien `[texte](https://…)` ou adresse nue),
/// images exclues ; null s'il n'y en a pas. Sert à l'aperçu du lien.
String? firstLinkUrl(String text) {
  final withoutImages = text.replaceAll(RegExp(r'!\[[^\]\n]*\]\([^\s)]*\)'), ' ');
  final link = kRichLinkPattern.firstMatch(withoutImages);
  final bare = kBareUrlPattern.firstMatch(withoutImages);
  if (link == null && bare == null) return null;
  if (bare == null || (link != null && link.start <= bare.start)) return link!.group(2);
  return normalizeLinkUrl(bare.group(1)!);
}

/// Image insérée dans le texte : `![légende](https://…)`, seule sur sa ligne.
final kRichImageLinePattern =
    RegExp(r'^!\[([^\]\n]*)\]\((https?://[^\s)]+)\)\s*$');

/// Lien ou image : le texte n'est jamais coupé au milieu d'une adresse.
final _anyLinkToken = RegExp(r'!?\[[^\]\n]*\]\([^\s)]*\)');

/// Adresses des images insérées dans [text], dans l'ordre.
List<String> richBodyImageUrls(String text) => [
      for (final line in text.split('\n'))
        if (kRichImageLinePattern.firstMatch(line.trim()) case final m?) m.group(2)!,
    ];

/// Demande confirmation (adresse complète affichée) puis ouvre [url] hors de l'application.
Future<void> openRichTextLink(BuildContext context, String url) async {
  url = normalizeLinkUrl(url);
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.sharedLinkOpenTitle),
      content: Text(l10n.sharedLinkOpenBody(url)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.sharedLinkOpen)),
      ],
    ),
  );
  if (ok != true) return;
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(l10n.sharedLinkOpenFailed)));
  }
}

// ── Inline span parser ────────────────────────────────────────────────────────

/// Parses inline markdown markers and returns a rich [TextSpan]:
///   **bold**       → FontWeight.w700
///   __italic__     → FontStyle.italic
///   ~~strikethrough~~ → TextDecoration.lineThrough
///
/// Child spans inherit [base]; only the affected property is overridden.
///
/// [mentions] : comptes mentionnés (« @Nom », docs serveur fonctionnalites/mentions.md),
/// rendus en couleur et cliquables via [mentionRecognizer].
///
/// [linkRecognizer] : rend cliquables les liens `[texte](https://…)`.
TextSpan buildFormattedSpan(
  String text,
  TextStyle base, {
  List<MentionRef> mentions = const [],
  GestureRecognizer? Function(MentionRef ref)? mentionRecognizer,
  GestureRecognizer? Function(String url)? linkRecognizer,
}) {
  final pattern = RegExp(
      r'\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~|(?<![!@])\[([^\]\n]+)\]\((https?://[^\s)]+)\)|'
      '${kBareUrlPattern.pattern}',
      dotAll: true);
  if (!pattern.hasMatch(text) && mentions.isEmpty) return TextSpan(text: text, style: base);

  /// Morceau de texte, mentions « @Nom » mises en évidence.
  InlineSpan piece(String t, [TextStyle? style]) {
    final ranges = mentions.isEmpty ? const <({int start, int end, MentionRef ref})>[] : MentionCodec.ranges(t, mentions);
    if (ranges.isEmpty) return TextSpan(text: t, style: style);
    final children = <InlineSpan>[];
    var last = 0;
    for (final r in ranges) {
      if (r.start > last) children.add(TextSpan(text: t.substring(last, r.start)));
      children.add(TextSpan(
        text: t.substring(r.start, r.end),
        style: const TextStyle(color: Color(0xFF184797), fontWeight: FontWeight.w600),
        recognizer: mentionRecognizer?.call(r.ref),
      ));
      last = r.end;
    }
    if (last < t.length) children.add(TextSpan(text: t.substring(last)));
    return TextSpan(style: style, children: children);
  }

  // Récursif : un lien ou un italique peut se trouver dans un passage en gras.
  List<InlineSpan> parse(String t) {
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in pattern.allMatches(t)) {
      if (m.start > last) {
        spans.add(piece(t.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
            style: const TextStyle(fontWeight: FontWeight.w700), children: parse(m.group(1)!)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            style: const TextStyle(fontStyle: FontStyle.italic), children: parse(m.group(2)!)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            style: const TextStyle(decoration: TextDecoration.lineThrough),
            children: parse(m.group(3)!)));
      } else if (m.group(4) != null || m.group(6) != null) {
        spans.add(TextSpan(
          text: m.group(4) ?? m.group(6),
          style: const TextStyle(
            color: Color(0xFF184797),
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF184797),
          ),
          recognizer: linkRecognizer?.call(m.group(5) ?? m.group(6)!),
        ));
      }
      last = m.end;
    }
    if (last < t.length) {
      spans.add(piece(t.substring(last)));
    }
    return spans;
  }

  return TextSpan(style: base, children: parse(text));
}

/// Retire toutes les balises de mise en forme (partage, aperçus en une ligne).
String stripFormatting(String text) {
  return text
      // Images retirées, liens réduits à leur texte.
      .replaceAll(RegExp(r'^!\[[^\]\n]*\]\([^\s)]*\)[ \t]*\n?', multiLine: true), '')
      .replaceAll(RegExp(r'!\[[^\]\n]*\]\(https?://[^\s)]+\)'), '')
      .replaceAllMapped(kRichLinkPattern, (m) => m.group(1)!)
      .replaceAllMapped(
          RegExp(r'\*\*(.+?)\*\*|__(.+?)__|~~(.+?)~~', dotAll: true),
          (m) => m.group(1) ?? m.group(2) ?? m.group(3) ?? '')
      .replaceAll(RegExp(r'^(#{1,3} |> )', multiLine: true), '')
      .replaceAll(RegExp(r'^- ', multiLine: true), '• ');
}

// ── Block-level body renderer ─────────────────────────────────────────────────

enum _BlockKind { paragraph, quote, heading, bullet, numbered, image }

class _Block {
  _Block(this.kind, this.text, {this.number, this.url});
  final _BlockKind kind;
  final String text; // légende pour une image
  final String? number; // "1." pour une liste numérotée
  final String? url; // adresse d'une image
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
    final image   = kRichImageLinePattern.firstMatch(line.trim());
    if (image != null) {
      flushPara();
      blocks.add(_Block(_BlockKind.image, image.group(1)!.trim(), url: image.group(2)));
    } else if (heading != null) {
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
Widget buildRichBody(
  String text,
  TextStyle base, {
  bool selectable = true,
  List<MentionRef> mentions = const [],
  GestureRecognizer? Function(MentionRef ref)? mentionRecognizer,
}) {
  final body = _buildBlocks(text, base, mentions, mentionRecognizer);
  return selectable ? SelectionArea(child: body) : body;
}

Widget _buildBlocks(
  String text,
  TextStyle base,
  List<MentionRef> mentions,
  GestureRecognizer? Function(MentionRef ref)? mentionRecognizer,
) {
  Widget rich(String t, TextStyle style) => _FormattedText(
      text: t, style: style, mentions: mentions, mentionRecognizer: mentionRecognizer);

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
          _BlockKind.image => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: _BodyImage(url: blocks[i].url!, caption: blocks[i].text, base: base),
            ),
        },
    ],
  );
}

/// Paragraphe mis en forme dont les liens sont cliquables (un reconnaisseur
/// par adresse, gardé d'une construction à l'autre puis libéré).
class _FormattedText extends StatefulWidget {
  const _FormattedText({
    required this.text,
    required this.style,
    required this.mentions,
    required this.mentionRecognizer,
  });

  final String text;
  final TextStyle style;
  final List<MentionRef> mentions;
  final GestureRecognizer? Function(MentionRef ref)? mentionRecognizer;

  @override
  State<_FormattedText> createState() => _FormattedTextState();
}

class _FormattedTextState extends State<_FormattedText> {
  final Map<String, TapGestureRecognizer> _links = {};

  @override
  void dispose() {
    for (final r in _links.values) {
      r.dispose();
    }
    super.dispose();
  }

  GestureRecognizer _linkFor(String url) =>
      _links.putIfAbsent(url, TapGestureRecognizer.new)
        ..onTap = () => openRichTextLink(context, url);

  @override
  Widget build(BuildContext context) => Text.rich(buildFormattedSpan(
        widget.text,
        widget.style,
        mentions: widget.mentions,
        mentionRecognizer: widget.mentionRecognizer,
        linkRecognizer: _linkFor,
      ));
}

// ── Image insérée dans le texte ───────────────────────────────────────────────

/// Image du corps du témoignage ; un appui l'ouvre en grand (zoom).
class _BodyImage extends StatelessWidget {
  const _BodyImage({required this.url, required this.caption, required this.base});

  final String url;
  final String caption;
  final TextStyle base;

  void _open(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: ctx.l10n.commonClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _open(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: CachedNetworkImage(
                imageUrl: url,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(height: 180, color: const Color(0xFFEFF2F7)),
                errorWidget: (_, _, _) => Container(
                  height: 120,
                  color: const Color(0xFFEFF2F7),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Color(0xFF8A94A6)),
                ),
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: base.copyWith(
                fontSize: (base.fontSize ?? 15) * 0.85,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF5B6475),
              ),
            ),
          ),
      ],
    );
  }
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

  // 2. Ne pas couper un lien ou une image au milieu.
  for (final m in _anyLinkToken.allMatches(text)) {
    if (m.start >= cut) break;
    if (m.end > cut) cut = m.end;
  }

  // 3. Si une balise reste ouverte, avancer jusqu'à sa fermeture.
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
    this.mentions = const [],
    this.onMentionTap,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int initialChars;
  final int stepChars;
  final bool selectable;
  final TextStyle? linkStyle;

  /// Comptes mentionnés (« @Nom ») : en couleur, un appui ouvre le profil (`/users/{id}`).
  final List<MentionRef> mentions;

  /// Remplace l'ouverture du profil.
  final ValueChanged<MentionRef>? onMentionTap;

  @override
  State<ProgressiveRichText> createState() => _ProgressiveRichTextState();
}

class _ProgressiveRichTextState extends State<ProgressiveRichText> {
  late int _shown = _safeCut(widget.text, widget.initialChars);
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  GestureRecognizer _recognizerFor(MentionRef ref) =>
      _recognizers.putIfAbsent(ref.id, () => TapGestureRecognizer())
        ..onTap = () {
          if (widget.onMentionTap != null) {
            widget.onMentionTap!(ref);
          } else {
            context.push('/users/${ref.id}');
          }
        };

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
          buildRichBody(
            visible,
            widget.style,
            selectable: widget.selectable,
            mentions: widget.mentions,
            mentionRecognizer: widget.mentions.isEmpty ? null : _recognizerFor,
          ),
          if (!complete || canCollapse)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: complete ? _collapse : _more,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  complete
                      ? context.l10n.sharedTextCollapse
                      // Dernier morceau : inutile d'annoncer une « suite ».
                      : remaining <= widget.stepChars
                          ? context.l10n.sharedTextReadEnd
                          : context.l10n.sharedTextReadMore,
                  style: linkStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
