// lib/features/daily_verse/design/verse_share_image.dart
//
// Image de partage du verset du jour : le verset dans le design choisi, avec la
// référence et le nom de l'application en petit. Rendue hors écran
// (RepaintBoundary → PNG 1080 × 1350), puis partagée en fichier avec le texte.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/daily_verse_models.dart' show VerseVersion;
import 'verse_background_painter.dart';
import 'verse_design.dart';
import 'verse_layout.dart';
import 'verse_style_prefs.dart';

/// Nom de l'application, en pied de l'image.
const String kVerseShareAppName = 'Témoignages';

/// Taille logique de l'image (× 3 → 1080 × 1350 px, format 4:5).
const Size kVerseShareSize = Size(360, 450);

/// Composition de l'image partagée.
class VerseShareCard extends StatelessWidget {
  const VerseShareCard({
    required this.design,
    required this.prefs,
    required this.text,
    required this.reference,
    this.version,
    super.key,
  });

  final VerseDesign design;
  final VerseStylePrefs prefs;
  final String text;
  final String reference;
  final VerseVersion? version;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(30, 30, 30, 22);
    // Rendu hors écran : style de texte de base (sans le soulignement de débogage).
    return Material(
      type: MaterialType.transparency,
      child: VerseCanvas(
        design: design,
        size: kVerseShareSize,
        animate: false,
        builder: (context, r) {
          final align = prefs.align;
          final cross = align == VerseAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start;
          final shown = version == null ? text : '« ${text.trim()} »';
          final size = fitVerseFontSize(
            text: shown,
            surface: VerseSurface.share,
            prefs: prefs,
            maxWidth: kVerseShareSize.width - pad.horizontal,
            maxHeight: kVerseShareSize.height - pad.vertical - 110,
          );
          return Padding(
            padding: pad,
            child: Column(
              crossAxisAlignment: cross,
              children: [
                Text(
                  'VERSET DU JOUR',
                  style: verseLabelStyle(r.ink),
                  textScaler: TextScaler.noScaling,
                ),
                const Spacer(),
                VerseAccentLine(resolved: r, align: align),
                VersePassageText(
                  text: text,
                  version: version,
                  accent: r.accent,
                  textAlign: align.textAlign,
                  style: verseTextStyle(prefs, size, r.ink),
                  maxLines: 12,
                ),
                const SizedBox(height: 16),
                Text(
                  reference,
                  style: verseReferenceStyle(r.accent, size: 16),
                  textAlign: align.textAlign,
                  textScaler: TextScaler.noScaling,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: align == VerseAlign.center
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 13, color: r.ink),
                    const SizedBox(width: 6),
                    Text(
                      kVerseShareAppName,
                      style: verseLabelStyle(
                        r.ink,
                      ).copyWith(fontSize: 11, letterSpacing: 0.3),
                      textScaler: TextScaler.noScaling,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Rend [widget] hors écran à [logicalSize] et renvoie un PNG.
Future<Uint8List> renderWidgetToPng(
  Widget widget, {
  required ui.FlutterView view,
  Size logicalSize = kVerseShareSize,
  double pixelRatio = 3,
}) async {
  await VerseGrain.ensure();
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(logicalSize),
      physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: MediaQuery(
      data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
      child: Directionality(textDirection: TextDirection.ltr, child: widget),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner
    ..buildScope(root)
    ..finalizeTree();
  pipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Partage le verset en image (design choisi) avec le texte en complément.
/// Sans image possible (web, erreur), partage le texte seul.
Future<void> shareVerseImage(
  BuildContext context, {
  required VerseDesign design,
  required VerseStylePrefs prefs,
  required String text,
  required String reference,
  required String shareText,
  VerseVersion? version,
}) async {
  final theme = Theme.of(context);
  final view = View.of(context);
  try {
    if (kIsWeb) throw UnsupportedError('web');
    final png = await renderWidgetToPng(
      Theme(
        data: theme,
        child: VerseShareCard(
          design: design,
          prefs: prefs,
          text: text,
          reference: reference,
          version: version,
        ),
      ),
      view: view,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}verset-du-jour.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
      ),
    );
  } catch (_) {
    await SharePlus.instance.share(ShareParams(text: shareText));
  }
}
