// Verset du jour en plein écran. Premier écran immersif : le verset, la
// référence, les actions (J'aime, Je prie, Commentaires, Partager) et la
// vignette du sélecteur de designs posés directement sur le design du jour
// (lib/features/daily_verse/design). En faisant défiler : versions de la Bible
// (choix mémorisé, « Comparer ») puis sujets de prière, commentaires et
// témoignages liés, sur des cartes blanches. Lecture vocale, mode lecture,
// partage en image.
// Docs serveur : fonctionnalites/verset-du-jour.md

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/tts_service.dart';
import '../../../shared/widgets/guest_gate.dart';
import '../../../shared/widgets/mention_text.dart';
import '../../../shared/widgets/mention_text_field.dart';
import '../../bible/providers/bible_providers.dart'
    show BibleVerseRef, bibleVerseRefProvider, bibleVerseToInsertProvider;
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart' show dailyVerseProvider;
import '../../home/widgets/testimony_card_header.dart' show timeAgoFr;
import '../../prayer/data/prayer_repository.dart';
import '../../prayer/models/prayer_models.dart';
import '../../prayer/widgets/prayer_widgets.dart';
import '../../testimony/providers/tts_provider.dart' show ttsEngineProvider;
import '../data/daily_verse_repository.dart';
import '../design/verse_design.dart';
import '../design/verse_design_picker.dart';
import '../design/verse_layout.dart';
import '../design/verse_share_image.dart';
import '../design/verse_style_prefs.dart';
import '../models/daily_verse_models.dart';
import '../providers/daily_verse_providers.dart';

/// Ouvre le verset du jour par-dessus l'écran courant (fondu + léger glissement).
/// [initialTab] : 0 sujets de prière, 1 commentaires, 2 témoignages.
Future<void> openDailyVerse(BuildContext context, {int initialTab = 0}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => DailyVerseScreen(initialTab: initialTab),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  ));
}

const _kFallbackVerse = DailyVerse(
  text: '« Car je connais les projets que j\'ai formés sur vous, dit l\'Éternel, '
      'projets de paix et non de malheur, afin de vous donner un avenir et de l\'espérance. »',
  reference: 'Jérémie 29 : 11',
);

class DailyVerseScreen extends ConsumerStatefulWidget {
  const DailyVerseScreen({this.initialTab = 0, super.key});

  /// 0 : sujets de prière · 1 : commentaires · 2 : témoignages.
  final int initialTab;

  @override
  ConsumerState<DailyVerseScreen> createState() => _DailyVerseScreenState();
}

class _DailyVerseScreenState extends ConsumerState<DailyVerseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
  final _scroll = ScrollController();
  final _participationKey = GlobalKey();
  bool _compare = false;
  bool _reading = false;

  /// Premier écran quitté : la barre compacte apparaît.
  bool _pastHero = false;
  double _heroHeight = 0;
  bool _speaking = false;
  int _speechRun = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final past = _heroHeight > 0 && _scroll.offset > _heroHeight - 120;
      if (past != _pastHero && mounted) setState(() => _pastHero = past);
    });
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tabs.dispose();
    if (_speaking) unawaited(ref.read(ttsEngineProvider).stop());
    super.dispose();
  }

  /// Version affichée : la préférée si elle contient le passage, sinon le texte du jour.
  ({String text, String label, VerseVersion? version, String? missing}) _display(
      DailyVerse verse, DailyVerseVersions? data) {
    final preferred = ref.watch(preferredVerseTranslationProvider);
    final v = data?.byCode(preferred);
    if (v != null && v.available) {
      return (text: v.text!, label: v.name, version: v, missing: null);
    }
    final missing = preferred != null && data != null ? (v?.name ?? preferred) : null;
    return (text: data?.originalText ?? verse.text, label: 'Texte du jour', version: null, missing: missing);
  }

  String _reference(DailyVerse verse, DailyVerseVersions? data) =>
      data?.parsed?.label ?? verse.reference;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _share(String text, String reference, String label, VerseVersion? version) async {
    final suffix = label == 'Texte du jour' ? '' : ' ($label)';
    await shareVerseImage(
      context,
      design: ref.read(currentVerseDesignProvider),
      prefs: ref.read(verseStylePrefsProvider),
      text: text,
      reference: version == null ? reference : '$reference$suffix',
      version: version,
      shareText: '« ${_strip(text)} »\n— $reference$suffix',
    );
    await ref.read(dailyVerseProvider.notifier).recordShare();
  }

  /// Ouvre l'onglet Commentaires et fait défiler jusqu'à lui.
  void _openComments() {
    _tabs.animateTo(1);
    final ctx = _participationKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  void _scrollDown(double heroHeight) => _scroll.animateTo(
        heroHeight - MediaQuery.paddingOf(context).top,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );

  static String _strip(String t) => t.trim().replaceAll(RegExp(r'^[«"\s]+|[»"\s]+$'), '');

  Future<void> _toggleSpeech(String text, String reference, VerseVersion? version) async {
    final engine = ref.read(ttsEngineProvider);
    if (_speaking) {
      _speechRun++;
      setState(() => _speaking = false);
      await engine.stop();
      return;
    }
    final run = ++_speechRun;
    setState(() => _speaking = true);
    final lang = version?.language ?? detectTextLanguage(text);
    final ok = await engine.configure(language: ttsLanguageFor(lang), rate: 1.0);
    if (!ok) {
      if (!mounted) return;
      setState(() => _speaking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La lecture à voix haute n'est pas disponible sur cet appareil.")),
      );
      return;
    }
    for (final chunk in [...splitIntoSpeechChunks(_strip(text)), reference]) {
      if (run != _speechRun || !mounted) return;
      final done = await engine.speak(chunk);
      if (!done) break;
    }
    if (mounted && run == _speechRun) setState(() => _speaking = false);
  }

  Future<void> _react({required bool pray}) async {
    if (!await requireAccount(context, ref, reason: pray ? 'prier avec ce verset' : 'aimer ce verset')) return;
    final notifier = ref.read(dailyVerseProvider.notifier);
    await (pray ? notifier.togglePray() : notifier.toggleLike());
  }

  Future<void> _testify(DailyVerse verse, DailyVerseVersions? data) async {
    if (!await requireAccount(context, ref, reason: 'témoigner sur ce verset')) return;
    if (!mounted) return;
    final reference = _reference(verse, data);
    ref.read(bibleVerseToInsertProvider.notifier).set(reference);
    final parsed = data?.parsed;
    if (parsed != null) {
      ref.read(bibleVerseRefProvider.notifier).set(BibleVerseRef(
            translationCode: ref.read(preferredVerseTranslationProvider) ?? 'LSG',
            bookNumber: parsed.book,
            bookName: parsed.bookName,
            chapter: parsed.chapter,
            verseNumbers: [for (var v = parsed.verseStart; v <= parsed.verseEnd; v++) v],
          ));
    }
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/publish/preview');
  }

  // ── Construction ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final verse = ref.watch(dailyVerseProvider).value ?? _kFallbackVerse;
    final versionsAsync = ref.watch(dailyVerseVersionsProvider(dailyVerseKey(verse)));
    final data = versionsAsync.value;
    final shown = _display(verse, data);
    final reference = _reference(verse, data);

    final design = ref.watch(currentVerseDesignProvider);
    final prefs = ref.watch(verseStylePrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final topBar = _TopBar(
          reading: _reading,
          speaking: _speaking,
          onClose: () => Navigator.of(context).maybePop(),
          onSpeak: () => _toggleSpeech(shown.text, reference, shown.version),
          onShare: () => _share(shown.text, reference, shown.label, shown.version),
          onReading: () => setState(() => _reading = !_reading),
        );

        if (_reading) {
          return _VerseHero(
            size: screen,
            design: design,
            prefs: prefs,
            topBar: topBar,
            text: shown.text,
            reference: reference,
            label: null,
            version: shown.version,
            missing: null,
            reading: true,
          );
        }

        final hero = _VerseHero.layout(
          screen: screen,
          design: design,
          prefs: prefs,
          text: shown.text,
          version: shown.version,
          scale: verseTextScale(context),
          safe: MediaQuery.paddingOf(context),
          missing: shown.missing != null,
          verse: verse,
        );
        _heroHeight = hero.height;
        final list = ListView(
          controller: _scroll,
          padding: EdgeInsets.zero,
          children: [
            _VerseHero(
              size: Size(screen.width, hero.height),
              fontSize: hero.fontSize,
              design: design,
              prefs: prefs,
              topBar: topBar,
              text: shown.text,
              reference: reference,
              label: shown.label,
              version: shown.version,
              missing: shown.missing,
              actions: (r) => _ReactionsRow(
                verse: verse,
                resolved: r,
                onLike: () => _react(pray: false),
                onPray: () => _react(pray: true),
                onComments: _openComments,
                onShare: () => _share(shown.text, reference, shown.label, shown.version),
                picker: VerseDesignStackButton(
                  design: design,
                  ink: r.ink,
                  onTap: () => showVerseDesignPicker(context, text: _strip(shown.text), reference: reference),
                ),
              ),
              onScrollHint: () => _scrollDown(hero.height),
            ),
            // ── Sous le premier écran : cartes blanches ─────────────────
            const SizedBox(height: AppSpacing.lg),
            _WhiteCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VersionSelector(
                    async: versionsAsync,
                    compare: _compare,
                    onCompare: () => setState(() => _compare = !_compare),
                  ),
                  if (_compare && data != null) _CompareList(data: data),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _WhiteCard(
              key: _participationKey,
              padding: EdgeInsets.zero,
              child: _Participation(
                verse: verse,
                tabs: _tabs,
                onTestify: () => _testify(verse, data),
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl),
          ],
        );
        return Stack(
          children: [
            list,
            // Barre compacte une fois le premier écran quitté.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_pastHero,
                child: AnimatedOpacity(
                  opacity: _pastHero ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: _CompactBar(
                    onClose: () => Navigator.of(context).maybePop(),
                    onShare: () => _share(shown.text, reference, shown.label, shown.version),
                    onTop: () => _scroll.animateTo(0,
                        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Barre blanche affichée sous le premier écran (fermer, partager, remonter).
class _CompactBar extends StatelessWidget {
  const _CompactBar({required this.onClose, required this.onShare, required this.onTop});

  final VoidCallback onClose;
  final VoidCallback onShare;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Material(
        color: AppColors.surface,
        elevation: 1,
        shadowColor: AppColors.border,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                ),
                Expanded(
                  child: Text('Verset du jour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  tooltip: 'Partager',
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
                ),
                IconButton(
                  tooltip: 'Revenir au verset',
                  onPressed: onTop,
                  icon: const Icon(Icons.vertical_align_top_rounded, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte blanche des sections sous le premier écran.
class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.padding = const EdgeInsets.fromLTRB(0, 16, 0, 16), super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      padding: padding,
      decoration: AppShadows.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ── Barre du haut ────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.reading,
    required this.speaking,
    required this.onClose,
    required this.onSpeak,
    required this.onShare,
    required this.onReading,
    this.ink = Colors.white,
    this.accent = AppColors.sun,
  });

  final bool reading;
  final bool speaking;
  final VoidCallback onClose;
  final VoidCallback onSpeak;
  final VoidCallback onShare;
  final VoidCallback onReading;

  /// Couleurs du design (contraste garanti).
  final Color ink;
  final Color accent;

  _TopBar colored(ResolvedVerseDesign r) => _TopBar(
        reading: reading,
        speaking: speaking,
        onClose: onClose,
        onSpeak: onSpeak,
        onShare: onShare,
        onReading: onReading,
        ink: r.ink,
        accent: r.accent,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: ink),
          ),
          Expanded(
            child: Text(
              'Verset du jour',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: verseLabelStyle(accent).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: speaking ? 'Arrêter la lecture' : 'Écouter',
            onPressed: onSpeak,
            icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded, color: ink),
          ),
          IconButton(
            tooltip: 'Partager',
            onPressed: onShare,
            icon: Icon(Icons.share_rounded, color: ink),
          ),
          IconButton(
            tooltip: reading ? 'Quitter le mode lecture' : 'Mode lecture',
            onPressed: onReading,
            icon: Icon(reading ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: ink),
          ),
        ],
      ),
    );
  }
}

// ── Le verset ────────────────────────────────────────────────────────────────

/// Premier écran : le design en plein cadre, la barre du haut, le verset
/// (taille ajustée à la place, ≥ 22 sp), la référence, les actions, la
/// vignette du sélecteur et l'indicateur « Faire défiler ».
class _VerseHero extends StatelessWidget {
  const _VerseHero({
    required this.size,
    required this.design,
    required this.prefs,
    required this.topBar,
    required this.text,
    required this.reference,
    required this.label,
    required this.version,
    required this.missing,
    this.fontSize,
    this.actions,
    this.onScrollHint,
    this.reading = false,
  });

  final Size size;
  final VerseDesign design;
  final VerseStylePrefs prefs;
  final _TopBar topBar;
  final String text;
  final String reference;
  final String? label;
  final VerseVersion? version;
  final String? missing;

  /// Taille du verset (calculée par [layout]) ; null en mode lecture.
  final double? fontSize;
  final Widget Function(ResolvedVerseDesign r)? actions;
  final VoidCallback? onScrollHint;
  final bool reading;

  static const _side = 24.0;

  /// Place prise par tout ce qui entoure le verset (barre, référence,
  /// libellé, actions, indicateur), en pixels logiques.
  /// Marge de sécurité incluse (arrondis, actions sur deux lignes).
  static double _chrome(VerseDesign d, double scale, EdgeInsets safe,
          {required bool label, required bool missing, required double actionsHeight}) =>
      safe.top + 52 + 20 + (d.accent == VerseAccent.line ? 17 : 0) +
      (16 + 26) * scale +
      (label ? (4 + 18) * scale : 0) +
      (missing ? 8 + 36 * scale : 0) +
      actionsHeight +
      (6 + 16 + 22 + 6) * scale + 8 + 16 + safe.bottom;

  /// Hauteur du premier écran (au moins l'écran) et taille du verset.
  static ({double height, double fontSize}) layout({
    required Size screen,
    required VerseDesign design,
    required VerseStylePrefs prefs,
    required String text,
    required VerseVersion? version,
    required double scale,
    required EdgeInsets safe,
    required DailyVerse verse,
    bool label = true,
    bool missing = false,
  }) {
    final actionsHeight = _ReactionsRow.measureHeight(verse, screen.width, scale);
    final shown = version == null ? text : '« ${text.trim()} »';
    final width = screen.width - 2 * _side;
    final room = screen.height -
        _chrome(design, scale, safe, label: label, missing: missing, actionsHeight: actionsHeight);
    final size = fitVerseFontSize(
      text: shown,
      surface: VerseSurface.fullscreen,
      prefs: prefs,
      maxWidth: width,
      maxHeight: room,
      scale: scale,
    );
    // Verset très long : le premier écran s'allonge plutôt que de rapetisser le texte.
    final needed = measureVerseHeight(shown, prefs, size, width) + 8;
    return (height: needed > room ? screen.height + needed - room : screen.height, fontSize: size);
  }

  @override
  Widget build(BuildContext context) {
    return VerseCanvas(
      design: design,
      size: size,
      builder: (context, r) {
        final align = prefs.align;
        final cross = align == VerseAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
        final safe = MediaQuery.paddingOf(context);
        final verseSize = fontSize ??
            fitVerseFontSize(
              text: text,
              surface: VerseSurface.fullscreen,
              prefs: prefs.copyWith(size: VerseTextSize.large),
              maxWidth: size.width - 2 * _side,
              maxHeight: size.height - safe.vertical - 160,
              scale: verseTextScale(context),
            );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: r.lightInk ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Padding(
            padding: EdgeInsets.only(top: safe.top, bottom: safe.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                topBar.colored(r),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: 'Verset du jour, $reference',
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(_side, 12, _side, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: cross,
                        children: [
                          VerseAccentLine(resolved: r, align: align),
                          VersePassageText(
                            text: text,
                            version: version,
                            accent: r.accent,
                            textAlign: align.textAlign,
                            style: verseTextStyle(prefs, verseSize, r.ink),
                          ),
                          const SizedBox(height: 16),
                          Text(reference,
                              textAlign: align.textAlign,
                              style: verseReferenceStyle(r.accent, size: reading ? 20 : 17)),
                          if (label != null) ...[
                            const SizedBox(height: 4),
                            Text(label!, textAlign: align.textAlign, style: verseLabelStyle(r.ink)),
                          ],
                          if (missing != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Passage absent de la version « $missing » : texte du jour affiché.',
                              textAlign: align.textAlign,
                              style: verseLabelStyle(r.ink).copyWith(fontWeight: FontWeight.w400),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (actions != null) actions!(r),
                if (onScrollHint != null)
                  Center(
                    child: Semantics(
                      button: true,
                      label: 'Faire défiler : versions, prière, commentaires',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: onScrollHint,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Faire défiler', style: verseLabelStyle(r.ink).copyWith(fontSize: 11.5)),
                              Icon(Icons.keyboard_arrow_down_rounded, color: r.ink, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({
    required this.verse,
    required this.resolved,
    required this.onLike,
    required this.onPray,
    required this.onComments,
    required this.onShare,
    required this.picker,
  });

  final DailyVerse verse;
  final ResolvedVerseDesign resolved;
  final VoidCallback onLike;
  final VoidCallback onPray;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final Widget picker;

  static String likeLabel(DailyVerse v) => v.likeCount > 0 ? "J'aime · ${v.likeCount}" : "J'aime";
  static String prayLabel(DailyVerse v) => v.prayerCount > 0 ? 'Je prie · ${v.prayerCount}' : 'Je prie';
  static const _commentLabel = 'Commenter';
  static const _shareLabel = 'Partager';
  static const _padding = EdgeInsets.fromLTRB(20, 4, 12, 4);
  static const _pickerWidth = 56.0 + 8;
  static const _pickerHeight = 64.0;

  /// Hauteur exacte de la rangée (retour à la ligne des boutons simulé).
  static double measureHeight(DailyVerse verse, double width, double scale) {
    final style = AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700);
    final available = width - _padding.horizontal - _pickerWidth;
    double textWidth(String t) {
      final p = TextPainter(
        text: TextSpan(text: t, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(scale),
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final buttonHeight = 16 + 2 + 19.6 * scale;
    var rows = 1;
    var x = 0.0;
    for (final l in [likeLabel(verse), prayLabel(verse), _commentLabel, _shareLabel]) {
      final w = 12 + 18 + 6 + textWidth(l) + 12 + 4;
      if (x > 0 && x + 8 + w > available) {
        rows++;
        x = w;
      } else {
        x += (x > 0 ? 8 : 0) + w;
      }
    }
    final wrap = rows * buttonHeight + (rows - 1) * 8;
    return _padding.vertical + (wrap > _pickerHeight ? wrap : _pickerHeight);
  }

  @override
  Widget build(BuildContext context) {
    final r = resolved;
    return Padding(
      padding: _padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _GlassButton(
                  icon: verse.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: likeLabel(verse),
                  active: verse.isLiked,
                  resolved: r,
                  onTap: onLike,
                ),
                _GlassButton(
                  icon: verse.isPrayed ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
                  label: prayLabel(verse),
                  active: verse.isPrayed,
                  resolved: r,
                  onTap: onPray,
                ),
                _GlassButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _commentLabel,
                  active: false,
                  resolved: r,
                  onTap: onComments,
                ),
                _GlassButton(
                  icon: Icons.ios_share_rounded,
                  label: _shareLabel,
                  active: false,
                  resolved: r,
                  onTap: onShare,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          picker,
        ],
      ),
    );
  }
}

/// Bouton posé sur le design : contour et texte à l'encre (ou à l'accent
/// quand il est actif), sans fond, pour garder le contraste calculé.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.resolved,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final ResolvedVerseDesign resolved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? resolved.accent : resolved.ink;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        type: MaterialType.transparency,
        shape: StadiumBorder(side: BorderSide(color: fg.withValues(alpha: active ? 1 : 0.55), width: active ? 1.6 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: fg,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
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

// ── Versions ─────────────────────────────────────────────────────────────────

class _VersionSelector extends ConsumerWidget {
  const _VersionSelector({required this.async, required this.compare, required this.onCompare});

  final AsyncValue<DailyVerseVersions> async;
  final bool compare;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferred = ref.watch(preferredVerseTranslationProvider);
    final data = async.value;
    final note = switch (async) {
      AsyncLoading() when data == null => 'Recherche des versions…',
      _ when data == null => 'Versions indisponibles pour le moment.',
      _ when data.parsed == null => 'Référence non reconnue : seul le texte du jour est proposé.',
      _ when data.versions.isEmpty && data.offline =>
        'Hors connexion : téléchargez une Bible (onglet Bible) pour lire d\'autres versions.',
      _ when data.versions.isEmpty => 'Aucune autre version installée.',
      _ when data.offline => 'Hors connexion : versions téléchargées sur l\'appareil.',
      _ => null,
    };

    final notifier = ref.read(preferredVerseTranslationProvider.notifier);
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Versions de la Bible',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _VersionChip(
                  label: 'Texte du jour',
                  selected: !compare && (preferred == null || data?.byCode(preferred)?.available != true),
                  onTap: () => notifier.select(null),
                ),
                for (final v in data?.versions ?? const <VerseVersion>[])
                  _VersionChip(
                    label: v.code,
                    tooltip: v.available ? v.name : '${v.name} : passage absent de cette version',
                    selected: !compare && preferred == v.code && v.available,
                    onTap: v.available ? () => notifier.select(v.code) : null,
                  ),
                if ((data?.versions.isNotEmpty ?? false))
                  _VersionChip(
                    label: 'Comparer',
                    icon: Icons.view_agenda_outlined,
                    selected: compare,
                    onTap: onCompare,
                  ),
              ],
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(note, style: AppTextStyles.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label, required this.selected, this.onTap, this.icon, this.tooltip});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = selected ? AppColors.surface : (enabled ? AppColors.textPrimary : AppColors.textSecondary);
    final chip = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    decoration: enabled ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: tooltip == null ? chip : Tooltip(message: tooltip!, child: chip),
    );
  }
}

class _CompareList extends StatelessWidget {
  const _CompareList({required this.data});
  final DailyVerseVersions data;

  @override
  Widget build(BuildContext context) {
    Widget block(String title, Widget body) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              body,
            ],
          ),
        );
    final style = AppTextStyles.bodyMedium.copyWith(height: 1.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          block('Texte du jour', Text(data.originalText, style: style)),
          for (final v in data.versions)
            block(
              '${v.code} · ${v.name}',
              v.available
                  ? VersePassageText(text: v.text!, version: v, style: style, accent: AppColors.secondaryDark)
                  : Text("Ce passage n'est pas disponible dans cette version.",
                      style: style.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }
}

// ── Participation ────────────────────────────────────────────────────────────

class _Participation extends StatelessWidget {
  const _Participation({required this.verse, required this.tabs, required this.onTestify});

  final DailyVerse verse;
  final TabController tabs;
  final VoidCallback onTestify;

  @override
  Widget build(BuildContext context) {
    final online = verse.id > 0;
    return Container(
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.4),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.secondary,
            labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTextStyles.labelMedium,
            tabs: const [
              Tab(icon: Icon(Icons.volunteer_activism_outlined, size: 20), text: 'Sujets de prière', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.chat_bubble_outline_rounded, size: 20), text: 'Commentaires', iconMargin: EdgeInsets.only(bottom: 2)),
              Tab(icon: Icon(Icons.auto_awesome_outlined, size: 20), text: 'Témoignages', iconMargin: EdgeInsets.only(bottom: 2)),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: !online
                ? const _Notice(
                    icon: Icons.cloud_off_rounded,
                    text: 'Les sujets de prière, commentaires et témoignages seront disponibles une fois en ligne.',
                  )
                : switch (tabs.index) {
                    0 => _PrayerTab(verseId: verse.id),
                    1 => _CommentsTab(verseId: verse.id),
                    _ => _TestimoniesTab(verseId: verse.id, onTestify: onTestify),
                  },
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
          ],
        ],
      ),
    );
  }
}

/// Liste asynchrone avec chargement, erreur (hors connexion) et état vide.
class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({
    required this.async,
    required this.empty,
    required this.itemBuilder,
    required this.onRetry,
  });

  final AsyncValue<List<T>> async;
  final String empty;
  final Widget Function(T item) itemBuilder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = async.error;
    if (error != null && !async.isLoading) {
      return _Notice(
        icon: error is DailyVerseFailure && error.offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
        text: '$error',
        onRetry: onRetry,
      );
    }
    final value = async.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (value.isEmpty) return _Notice(icon: Icons.inbox_outlined, text: empty);
    return Column(
      children: [
        for (final item in value)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: itemBuilder(item)),
      ],
    );
  }
}

// ── Sujets de prière ─────────────────────────────────────────────────────────

class _PrayerTab extends ConsumerWidget {
  const _PrayerTab({required this.verseId});
  final int verseId;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (!await requireAccount(context, ref, reason: 'confier un sujet de prière')) return;
    if (!context.mounted) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (_) => VersePrayerSheet(verseId: verseId),
    );
    if (created == true) ref.invalidate(dailyVersePrayerRequestsProvider(verseId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Confiez un sujet de prière inspiré par ce verset ; d\'autres prieront avec vous.',
            style: AppTextStyles.bodySmall),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => _create(context, ref),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Confier un sujet de prière'),
        ),
        const SizedBox(height: 16),
        _AsyncList<PrayerRequest>(
          async: ref.watch(dailyVersePrayerRequestsProvider(verseId)),
          empty: 'Aucun sujet de prière pour le moment. Soyez le premier !',
          itemBuilder: (r) => PrayerRequestFeedCard(request: r, showEvent: false, maxLines: 5),
          onRetry: () => ref.invalidate(dailyVersePrayerRequestsProvider(verseId)),
        ),
      ],
    );
  }
}

/// Feuille « Confier un sujet de prière » rattaché au verset du jour.
class VersePrayerSheet extends ConsumerStatefulWidget {
  const VersePrayerSheet({required this.verseId, super.key});
  final int verseId;

  @override
  ConsumerState<VersePrayerSheet> createState() => _VersePrayerSheetState();
}

class _VersePrayerSheetState extends ConsumerState<VersePrayerSheet> {
  final _form = GlobalKey<FormState>();
  final _body = TextEditingController();
  late final _draft = PrayerRequestDraft(dailyVerseId: widget.verseId);
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    _draft.body = _body.text;
    try {
      await ref.read(prayerRepositoryProvider).create(_draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre requête est publiée. Que Dieu vous réponde !')),
      );
      Navigator.of(context).pop(true);
    } on PrayerFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sujet de prière sur le verset du jour', style: AppTextStyles.h4),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Seigneur, à la lumière de ce verset, je te confie…'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Écrivez votre requête de prière.';
                    if (t.length < 10) return 'Votre requête est trop courte (10 caractères au moins).';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PrayerVisibility>(
                  initialValue: _draft.visibility,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Qui peut la voir ?'),
                  items: [
                    for (final v in PrayerVisibility.values)
                      DropdownMenuItem(value: v, child: Text(v.label, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _draft.visibility = v ?? PrayerVisibility.public),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.isAnonymous,
                  onChanged: (v) => setState(() => _draft.isAnonymous = v),
                  title: const Text('Publier anonymement'),
                  subtitle: const Text('Votre nom reste visible de vous et de la modération.'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(48)),
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: const Text('Publier ma requête'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Commentaires ─────────────────────────────────────────────────────────────

class _CommentsTab extends ConsumerStatefulWidget {
  const _CommentsTab({required this.verseId});
  final int verseId;

  @override
  ConsumerState<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends ConsumerState<_CommentsTab> {
  final _ctrl = MentionEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(dailyVerseCommentsProvider(widget.verseId));

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _send() async {
    if (_sending || _ctrl.text.trim().length < 2) return;
    if (!await requireAccount(context, ref, reason: 'commenter le verset du jour')) return;
    final body = _ctrl.encodedText;
    setState(() => _sending = true);
    try {
      await ref.read(dailyVerseRepositoryProvider).addComment(widget.verseId, body);
      _ctrl.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _refresh();
    } on DailyVerseFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(VerseComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le commentaire ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dailyVerseRepositoryProvider).deleteComment(widget.verseId, c.id);
      _refresh();
    } on DailyVerseFailure catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  Future<void> _report(VerseComment c) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Signaler ce commentaire', style: AppTextStyles.h4)),
            for (final e in kVerseCommentReportReasons.entries)
              ListTile(title: Text(e.value), onTap: () => Navigator.pop(ctx, e.key)),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await ref.read(dailyVerseRepositoryProvider).reportComment(widget.verseId, c.id, reason);
      if (mounted) _snack('Merci, le commentaire a été signalé à la modération.');
    } on DailyVerseFailure catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = ref.watch(isGuestProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              // Invité : lecture seule, la saisie propose de se connecter.
              child: guest
                  ? TextField(
                      readOnly: true,
                      onTap: () => requireAccount(context, ref, reason: 'commenter le verset du jour'),
                      decoration: const InputDecoration(hintText: 'Ce que ce verset vous dit aujourd\'hui…'),
                    )
                  : MentionTextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Ce que ce verset vous dit aujourd\'hui… (@ pour mentionner)',
                        counterText: '',
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Envoyer',
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _AsyncList<VerseComment>(
          async: ref.watch(dailyVerseCommentsProvider(widget.verseId)),
          empty: 'Aucun commentaire. Partagez ce que ce verset vous inspire.',
          itemBuilder: (c) => _CommentTile(
            comment: c,
            onDelete: c.canDelete ? () => _delete(c) : null,
            onReport: c.canReport ? () => _report(c) : null,
          ),
          onRetry: _refresh,
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, this.onDelete, this.onReport});

  final VerseComment comment;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final c = comment;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 12),
      decoration: AppShadows.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            foregroundImage: c.avatarUrl != null && c.avatarUrl!.isNotEmpty ? NetworkImage(c.avatarUrl!) : null,
            child: Text(c.initials, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: c.authorName, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    if (c.createdAt != null)
                      TextSpan(text: ' · ${timeAgoFr(c.createdAt!)}', style: AppTextStyles.bodySmall),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (c.isHidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Retiré après signalement', style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning)),
                  ),
                const SizedBox(height: 4),
                MentionText(c.body, mentions: c.mentions, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          if (onDelete != null || onReport != null)
            PopupMenuButton<String>(
              tooltip: 'Options',
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
              onSelected: (v) => v == 'delete' ? onDelete?.call() : onReport?.call(),
              itemBuilder: (_) => [
                if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                if (onReport != null) const PopupMenuItem(value: 'report', child: Text('Signaler')),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Témoignages liés ─────────────────────────────────────────────────────────

class _TestimoniesTab extends ConsumerWidget {
  const _TestimoniesTab({required this.verseId, required this.onTestify});
  final int verseId;
  final VoidCallback onTestify;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ce verset s\'est accompli dans votre vie ? Racontez-le.', style: AppTextStyles.bodySmall),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onTestify,
          style: FilledButton.styleFrom(backgroundColor: AppColors.secondary, minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Témoigner sur ce verset'),
        ),
        const SizedBox(height: 16),
        _AsyncList<Testimony>(
          async: ref.watch(dailyVerseTestimoniesProvider(verseId)),
          empty: 'Aucun témoignage ne cite encore ce verset.',
          itemBuilder: (t) => _TestimonyTile(testimony: t),
          onRetry: () => ref.invalidate(dailyVerseTestimoniesProvider(verseId)),
        ),
      ],
    );
  }
}

class _TestimonyTile extends StatelessWidget {
  const _TestimonyTile({required this.testimony});
  final Testimony testimony;

  @override
  Widget build(BuildContext context) {
    final t = testimony;
    final icon = switch (t.type) {
      TestimonyType.video => Icons.play_circle_outline_rounded,
      TestimonyType.audio => Icons.headphones_rounded,
      TestimonyType.text => Icons.article_outlined,
    };
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => GoRouter.of(context).push('/testimony/${t.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${t.author.displayName} · ${timeAgoFr(t.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
