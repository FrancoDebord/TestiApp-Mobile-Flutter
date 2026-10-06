// Verset du jour en plein écran (inspiré de « Proclamer » des paroles
// prophétiques) : grand texte sur fond bleu, versions de la Bible (choix
// mémorisé, « Comparer »), J'aime / Je prie, partage, lecture vocale, mode
// lecture ; puis sujets de prière, commentaires et témoignages liés.
// Docs serveur : fonctionnalites/verset-du-jour.md

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

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
import '../models/daily_verse_models.dart';
import '../providers/daily_verse_providers.dart';

/// Ouvre le verset du jour par-dessus l'écran courant (fondu + léger glissement).
Future<void> openDailyVerse(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => const DailyVerseScreen(),
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

const _kNight = Color(0xFF0A2149);
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
  bool _compare = false;
  bool _reading = false;
  bool _speaking = false;
  int _speechRun = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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

  Future<void> _share(String text, String reference, String label) async {
    final suffix = label == 'Texte du jour' ? '' : ' ($label)';
    await SharePlus.instance.share(ShareParams(text: '« ${_strip(text)} »\n— $reference$suffix'));
    await ref.read(dailyVerseProvider.notifier).recordShare();
  }

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kNight,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark, _kNight],
              stops: [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  reading: _reading,
                  speaking: _speaking,
                  onClose: () => Navigator.of(context).maybePop(),
                  onSpeak: () => _toggleSpeech(shown.text, reference, shown.version),
                  onShare: () => _share(shown.text, reference, shown.label),
                  onReading: () => setState(() => _reading = !_reading),
                ),
                Expanded(
                  child: _reading
                      ? _ReadingView(text: shown.text, reference: reference, version: shown.version)
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _VerseHero(
                              text: shown.text,
                              reference: reference,
                              label: shown.label,
                              version: shown.version,
                              missing: shown.missing,
                            ),
                            _ReactionsRow(
                              verse: verse,
                              onLike: () => _react(pray: false),
                              onPray: () => _react(pray: true),
                            ),
                            _VersionSelector(
                              async: versionsAsync,
                              compare: _compare,
                              onCompare: () => setState(() => _compare = !_compare),
                            ),
                            if (_compare && data != null) _CompareList(data: data),
                            const SizedBox(height: AppSpacing.lg),
                            _Participation(
                              verse: verse,
                              tabs: _tabs,
                              onTestify: () => _testify(verse, data),
                            ),
                          ],
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

// ── Barre du haut ────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.reading,
    required this.speaking,
    required this.onClose,
    required this.onSpeak,
    required this.onShare,
    required this.onReading,
  });

  final bool reading;
  final bool speaking;
  final VoidCallback onClose;
  final VoidCallback onSpeak;
  final VoidCallback onShare;
  final VoidCallback onReading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Fermer',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              'Verset du jour',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.sun, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: speaking ? 'Arrêter la lecture' : 'Écouter',
            onPressed: onSpeak,
            icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Partager',
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
          IconButton(
            tooltip: reading ? 'Quitter le mode lecture' : 'Mode lecture',
            onPressed: onReading,
            icon: Icon(reading ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Le verset ────────────────────────────────────────────────────────────────

/// Texte du passage, avec les numéros de versets si la version en a plusieurs.
class _PassageText extends StatelessWidget {
  const _PassageText({required this.text, required this.version, required this.style});

  final String text;
  final VerseVersion? version;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = version?.lines ?? const <VerseLine>[];
    if (lines.length < 2) {
      final t = version == null ? text : '« ${text.trim()} »';
      return Text(t, style: style);
    }
    return Text.rich(TextSpan(style: style, children: [
      for (final l in lines) ...[
        TextSpan(
          text: '${l.verse} ',
          style: style.copyWith(
            fontSize: (style.fontSize ?? 20) * 0.6,
            color: AppColors.sun,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: '${l.text} '),
      ],
    ]));
  }
}

class _VerseHero extends StatelessWidget {
  const _VerseHero({
    required this.text,
    required this.reference,
    required this.label,
    required this.version,
    required this.missing,
  });

  final String text;
  final String reference;
  final String label;
  final VerseVersion? version;
  final String? missing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.sunGradient),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: 18),
          _PassageText(
            text: text,
            version: version,
            style: AppTextStyles.verseQuote.copyWith(color: Colors.white, fontSize: 24, height: 1.55),
          ),
          const SizedBox(height: 16),
          Text(
            reference,
            style: AppTextStyles.verseReference.copyWith(color: AppColors.sun, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
          if (missing != null) ...[
            const SizedBox(height: 8),
            Text(
              'Passage absent de la version « $missing » : texte du jour affiché.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingView extends StatelessWidget {
  const _ReadingView({required this.text, required this.reference, required this.version});

  final String text;
  final String reference;
  final VerseVersion? version;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PassageText(
                text: text,
                version: version,
                style: AppTextStyles.verseQuote.copyWith(color: Colors.white, fontSize: 30, height: 1.5),
              ),
              const SizedBox(height: 24),
              Text(reference, style: AppTextStyles.verseReference.copyWith(color: AppColors.sun, fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionsRow extends StatelessWidget {
  const _ReactionsRow({required this.verse, required this.onLike, required this.onPray});

  final DailyVerse verse;
  final VoidCallback onLike;
  final VoidCallback onPray;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _GlassButton(
            icon: verse.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: verse.likeCount > 0 ? "J'aime · ${verse.likeCount}" : "J'aime",
            active: verse.isLiked,
            onTap: onLike,
          ),
          _GlassButton(
            icon: verse.isPrayed ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
            label: verse.prayerCount > 0 ? 'Je prie · ${verse.prayerCount}' : 'Je prie',
            active: verse.isPrayed,
            onTap: onPray,
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primaryDark : Colors.white;
    return Material(
      color: active ? AppColors.sun : Colors.white.withAlpha(28),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                  style: AppTextStyles.labelMedium.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
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
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Versions de la Bible',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white70, letterSpacing: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Text(note, style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
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
    final fg = selected ? AppColors.primaryDark : (enabled ? Colors.white : Colors.white38);
    final chip = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.sun : Colors.white.withAlpha(enabled ? 28 : 12),
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.sun : Colors.white24)),
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
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.sun, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              body,
            ],
          ),
        );
    final style = AppTextStyles.bodyMedium.copyWith(color: Colors.white, height: 1.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          block('Texte du jour', Text(data.originalText, style: style)),
          for (final v in data.versions)
            block(
              '${v.code} · ${v.name}',
              v.available
                  ? _PassageText(text: v.text!, version: v, style: style)
                  : Text("Ce passage n'est pas disponible dans cette version.",
                      style: style.copyWith(color: Colors.white60, fontStyle: FontStyle.italic)),
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
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.5),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
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
