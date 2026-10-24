// Affichage natif d'un HTML simple produit par le serveur (Markdown rendu :
// titres, paragraphes, listes, tableaux, gras, italique, liens, code), aux
// styles de la charte. Pas de navigateur : les liens s'ouvrent à part.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';

class HtmlContent extends StatefulWidget {
  const HtmlContent(this.html, {this.onLink, super.key});

  final String html;

  /// Lien touché (par défaut : application externe — navigateur, e-mail).
  final void Function(Uri uri)? onLink;

  @override
  State<HtmlContent> createState() => _HtmlContentState();
}

class _HtmlContentState extends State<HtmlContent> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _open(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    final onLink = widget.onLink;
    if (onLink != null) return onLink(uri);
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  TextStyle get _body => AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.55);

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final fragment = html_parser.parseFragment(widget.html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _blocks(fragment.nodes),
    );
  }

  // ── Blocs ─────────────────────────────────────────────────────────────────

  List<Widget> _blocks(List<dom.Node> nodes) {
    final out = <Widget>[];
    final inline = <dom.Node>[];

    void flushInline() {
      if (inline.isEmpty) return;
      final spans = _inline(List.of(inline), _body);
      inline.clear();
      if (_isBlank(spans)) return;
      out.add(_paragraph(spans));
    }

    for (final node in nodes) {
      final tag = node is dom.Element ? node.localName : null;
      if (tag == null || !_blockTags.contains(tag)) {
        inline.add(node);
        continue;
      }
      flushInline();
      final el = node as dom.Element;
      switch (tag) {
        case 'h1' || 'h2':
          out.add(_heading(el, AppTextStyles.h3.copyWith(color: AppColors.primary), top: AppSpacing.xl));
        case 'h3':
          out.add(_heading(el, AppTextStyles.h4, top: AppSpacing.lg));
        case 'h4' || 'h5' || 'h6':
          out.add(_heading(el, AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700), top: AppSpacing.md));
        case 'p':
          final spans = _inline(el.nodes, _body);
          if (!_isBlank(spans)) out.add(_paragraph(spans));
        case 'ul' || 'ol':
          out.add(_list(el, ordered: tag == 'ol'));
        case 'table':
          out.add(_table(el));
        case 'blockquote':
          out.add(Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.primarySoft, width: 4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(el.nodes)),
          ));
        case 'pre':
          out.add(Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(el.text, style: _body.copyWith(fontFamily: 'monospace')), // i18n-ignore
          ));
        case 'hr':
          out.add(const Divider(height: AppSpacing.xxl));
        default:
          out.addAll(_blocks(el.nodes));
      }
    }
    flushInline();
    return out;
  }

  Widget _heading(dom.Element el, TextStyle style, {required double top}) => Padding(
        padding: EdgeInsets.only(top: top, bottom: AppSpacing.sm),
        child: Text.rich(TextSpan(children: _inline(el.nodes, style)), style: style),
      );

  Widget _paragraph(List<InlineSpan> spans) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text.rich(TextSpan(children: spans), style: _body),
      );

  Widget _list(dom.Element el, {required bool ordered}) {
    final items = el.children.where((c) => c.localName == 'li').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      ordered ? '${i + 1}.' : '•',
                      style: _body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: _listItem(items[i])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Élément de liste : texte, puis éventuels paragraphes ou sous-listes.
  Widget _listItem(dom.Element li) {
    final blocks = _blocks(li.nodes);
    if (blocks.length == 1 && blocks.single is Padding) {
      // Texte seul : sans la marge basse d'un paragraphe.
      return ((blocks.single as Padding).child)!;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: blocks);
  }

  Widget _table(dom.Element el) {
    final rows = el.querySelectorAll('tr');
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.map((r) => r.children.length).reduce((a, b) => a > b ? a : b);
    final head = _body.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary);
    final cellStyle = _body.copyWith(fontSize: 13);

    TableRow row(dom.Element tr, int index) {
      final isHead = tr.children.any((c) => c.localName == 'th');
      final cells = tr.children.where((c) => c.localName == 'td' || c.localName == 'th').toList();
      return TableRow(
        decoration: BoxDecoration(
          color: isHead ? AppColors.primarySoft : (index.isEven ? AppColors.surface : AppColors.background),
        ),
        children: [
          for (var i = 0; i < columns; i++)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: i < cells.length
                  ? Text.rich(TextSpan(children: _inline(cells[i].nodes, isHead ? head : cellStyle)),
                      style: isHead ? head : cellStyle)
                  : const SizedBox.shrink(),
            ),
        ],
      );
    }

    // Écran étroit : colonnes de largeur égale, le texte passe à la ligne.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Table(
          border: TableBorder.all(color: AppColors.border),
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [for (var i = 0; i < rows.length; i++) row(rows[i], i)],
        ),
      ),
    );
  }

  // ── En ligne ──────────────────────────────────────────────────────────────

  List<InlineSpan> _inline(List<dom.Node> nodes, TextStyle style, {bool trimStart = true}) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) spans.add(TextSpan(text: text));
        continue;
      }
      if (node is! dom.Element) continue;
      switch (node.localName) {
        case 'br':
          spans.add(const TextSpan(text: '\n'));
        case 'strong' || 'b':
          spans.add(TextSpan(
            style: const TextStyle(fontWeight: FontWeight.w700),
            children: _inline(node.nodes, style, trimStart: false),
          ));
        case 'em' || 'i':
          spans.add(TextSpan(
            style: const TextStyle(fontStyle: FontStyle.italic),
            children: _inline(node.nodes, style, trimStart: false),
          ));
        case 'code':
          spans.add(TextSpan(
            text: node.text,
            style: TextStyle(
              fontFamily: 'monospace', // i18n-ignore
              fontSize: (style.fontSize ?? 14) - 1,
              backgroundColor: AppColors.primarySoft,
            ),
          ));
        case 'a':
          final href = node.attributes['href'];
          final recognizer = href == null ? null : (TapGestureRecognizer()..onTap = () => _open(href));
          if (recognizer != null) _recognizers.add(recognizer);
          spans.add(TextSpan(
            text: node.text,
            recognizer: recognizer,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ));
        default:
          spans.addAll(_inline(node.nodes, style, trimStart: false));
      }
    }
    if (trimStart) _trim(spans);
    return spans;
  }

  /// Retire les espaces en début et fin de bloc (retours à la ligne du HTML).
  static void _trim(List<InlineSpan> spans) {
    while (spans.isNotEmpty && spans.first is TextSpan && (spans.first as TextSpan).children == null) {
      final t = (spans.first as TextSpan);
      final text = t.text?.trimLeft() ?? '';
      if (text.isEmpty) {
        spans.removeAt(0);
      } else {
        spans[0] = TextSpan(text: text, style: t.style, recognizer: t.recognizer);
        break;
      }
    }
    while (spans.isNotEmpty && spans.last is TextSpan && (spans.last as TextSpan).children == null) {
      final t = (spans.last as TextSpan);
      final text = t.text?.trimRight() ?? '';
      if (text.isEmpty) {
        spans.removeLast();
      } else {
        spans[spans.length - 1] = TextSpan(text: text, style: t.style, recognizer: t.recognizer);
        break;
      }
    }
  }

  static bool _isBlank(List<InlineSpan> spans) => spans.isEmpty;

  static const _blockTags = {
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'p', 'ul', 'ol', 'table', 'blockquote', 'pre', 'hr', 'div', 'section',
  };
}
