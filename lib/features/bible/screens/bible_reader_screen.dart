import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/bible_models.dart';
import '../providers/bible_providers.dart';

class BibleReaderScreen extends ConsumerWidget {
  const BibleReaderScreen({required this.translationCode, super.key});

  final String translationCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(bibleBookListProvider(translationCode));

    return booksAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: const BackButton(color: AppColors.textPrimary),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Erreur : $e',
            style:
                AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (books) {
        if (books.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: const BackButton(color: AppColors.textPrimary),
              backgroundColor: AppColors.surface,
              elevation: 0,
            ),
            body: const Center(
              child: Text('Aucun contenu téléchargé.'),
            ),
          );
        }
        return _ReaderBody(
          translationCode: translationCode,
          books: books,
        );
      },
    );
  }
}

// ── Reader body ───────────────────────────────────────────────────────────────

class _ReaderBody extends ConsumerStatefulWidget {
  const _ReaderBody({
    required this.translationCode,
    required this.books,
  });
  final String         translationCode;
  final List<BibleBook> books;

  @override
  ConsumerState<_ReaderBody> createState() => _ReaderBodyState();
}

class _ReaderBodyState extends ConsumerState<_ReaderBody> {
  late int _bookIndex;
  late int _chapter;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    final pos = ref
        .read(bibleReaderPositionProvider.notifier)
        .positionFor(widget.translationCode);
    _bookIndex = widget.books
        .indexWhere((b) => b.bookNumber == pos.$1)
        .clamp(0, widget.books.length - 1);
    _chapter = pos.$2;
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  BibleBook get _currentBook => widget.books[_bookIndex];

  void _navigate(int bookIndex, int chapter) {
    setState(() {
      _bookIndex = bookIndex;
      _chapter   = chapter;
    });
    ref.read(bibleReaderPositionProvider.notifier).setPosition(
          widget.translationCode,
          widget.books[bookIndex].bookNumber,
          chapter,
        );
  }

  void _prevChapter() {
    if (_chapter > 1) {
      _navigate(_bookIndex, _chapter - 1);
    } else if (_bookIndex > 0) {
      final prevBook = widget.books[_bookIndex - 1];
      _navigate(_bookIndex - 1, prevBook.chaptersCount.clamp(1, 9999));
    }
  }

  void _nextChapter(int totalChapters) {
    if (_chapter < totalChapters) {
      _navigate(_bookIndex, _chapter + 1);
    } else if (_bookIndex < widget.books.length - 1) {
      _navigate(_bookIndex + 1, 1);
    }
  }

  Future<void> _toggleSpeech(List<BibleVerse> verses) async {
    if (_isSpeaking) {
      await _tts.stop();
      return;
    }
    final text = verses.map((v) => '${v.verseNumber}. ${v.text}').join(' ');
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final chapterCountAsync = ref.watch(bibleChapterCountProvider((
      translationCode: widget.translationCode,
      bookNumber:      _currentBook.bookNumber,
    )));
    final versesAsync = ref.watch(bibleVerseListProvider((
      translationCode: widget.translationCode,
      bookNumber:      _currentBook.bookNumber,
      chapter:         _chapter,
    )));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        leading: const BackButton(color: AppColors.textPrimary),
        title: GestureDetector(
          onTap: () => _showBookPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${_currentBook.name}  $_chapter',
                  style: AppTextStyles.h4.copyWith(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.primary, size: 22),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.volume_up_rounded,
              color: _isSpeaking
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            onPressed: () {
              final verses = versesAsync.value;
              if (verses != null && verses.isNotEmpty) {
                _toggleSpeech(verses);
              }
            },
            tooltip: _isSpeaking ? 'Arrêter la lecture' : 'Lire le chapitre',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary),
            onPressed: () {},
            tooltip: 'Rechercher',
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          final count = chapterCountAsync.value ?? 1;
          if (velocity < -500) { _nextChapter(count); }
          else if (velocity > 500) { _prevChapter(); }
        },
        child: Column(
          children: [
          // ── Chapter chips ────────────────────────────────────────────────
          chapterCountAsync.when(
            loading: () => const SizedBox(height: 44),
            error: (_, _) => const SizedBox(height: 44),
            data: (count) => _ChapterBar(
              totalChapters: count,
              currentChapter: _chapter,
              onSelect: (c) => _navigate(_bookIndex, c),
            ),
          ),

          // ── Verse list ───────────────────────────────────────────────────
          Expanded(
            child: _VerseList(
              translationCode: widget.translationCode,
              bookNumber:      _currentBook.bookNumber,
              bookName:        _currentBook.name,
              chapter:         _chapter,
            ),
          ),

          // ── Prev / Next navigation ───────────────────────────────────────
          chapterCountAsync.when(
            loading: () => const SizedBox(height: 56),
            error: (_, _) => const SizedBox(height: 56),
            data: (count) => _NavigationBar(
              canPrev: _bookIndex > 0 || _chapter > 1,
              canNext: _bookIndex < widget.books.length - 1 ||
                  _chapter < count,
              prevLabel: _chapter > 1
                  ? '${_currentBook.name} ${_chapter - 1}'
                  : (_bookIndex > 0
                      ? widget.books[_bookIndex - 1].name
                      : ''),
              nextLabel: _chapter < count
                  ? '${_currentBook.name} ${_chapter + 1}'
                  : (_bookIndex < widget.books.length - 1
                      ? widget.books[_bookIndex + 1].name
                      : ''),
              onPrev: _prevChapter,
              onNext: () => _nextChapter(count),
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _showBookPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Choisir un livre', style: AppTextStyles.h3),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: widget.books.length,
                itemBuilder: (_, i) {
                  final book = widget.books[i];
                  final isSelected = i == _bookIndex;
                  return ListTile(
                    leading: Text(
                      '${book.bookNumber}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    title: Text(
                      book.name,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      '${book.chaptersCount} ch.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigate(i, 1);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chapter chip bar ──────────────────────────────────────────────────────────

class _ChapterBar extends StatelessWidget {
  const _ChapterBar({
    required this.totalChapters,
    required this.currentChapter,
    required this.onSelect,
  });
  final int totalChapters;
  final int currentChapter;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: totalChapters,
        itemBuilder: (_, i) {
          final ch = i + 1;
          final selected = ch == currentChapter;
          return GestureDetector(
            onTap: () => onSelect(ch),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 4),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '$ch',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Verse list ────────────────────────────────────────────────────────────────

class _VerseList extends ConsumerWidget {
  const _VerseList({
    required this.translationCode,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
  });
  final String translationCode;
  final int    bookNumber;
  final String bookName;
  final int    chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (
      translationCode: translationCode,
      bookNumber:      bookNumber,
      chapter:         chapter,
    );
    final versesAsync = ref.watch(bibleVerseListProvider(key));
    final highlights  = ref.watch(bibleHighlightsProvider(key)).value ?? {};

    return versesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text('Erreur : $e',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.danger)),
      ),
      data: (verses) {
        if (verses.isEmpty) {
          return const Center(
            child: Text('Ce chapitre ne contient aucun verset.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: verses.length,
          itemBuilder: (_, i) => _VerseRow(
            verse:      verses[i],
            highlight:  highlights[verses[i].verseNumber],
            onTap:      () => _showVerseActions(context, ref, verses[i], highlights),
          ),
        );
      },
    );
  }

  void _showVerseActions(
    BuildContext context,
    WidgetRef ref,
    BibleVerse verse,
    Map<int, String> highlights,
  ) {
    final key = (
      translationCode: translationCode,
      bookNumber:      bookNumber,
      chapter:         chapter,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VerseActionSheet(
        verse:              verse,
        bookName:           bookName,
        chapter:            chapter,
        translationCode:    translationCode,
        bookNumber:         bookNumber,
        currentColor:       highlights[verse.verseNumber],
        onHighlightChanged: () => ref.invalidate(bibleHighlightsProvider(key)),
      ),
    );
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.verse,
    required this.onTap,
    this.highlight,
  });
  final BibleVerse   verse;
  final String?      highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    if (highlight != null) {
      try {
        bg = Color(
          int.parse('FF${highlight!.replaceFirst('#', '')}', radix: 16),
        ).withAlpha(70);
      } catch (_) {}
    }

    final content = RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          height: 1.75,
          color: AppColors.textPrimary,
        ),
        children: [
          WidgetSpan(
            baseline:  TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.baseline,
            child: Container(
              margin:  const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:        AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${verse.verseNumber}',
                style: const TextStyle(
                  fontFamily:  'Inter',
                  fontSize:    10,
                  fontWeight:  FontWeight.w700,
                  color:       AppColors.primary,
                ),
              ),
            ),
          ),
          TextSpan(text: verse.text),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:    const Duration(milliseconds: 200),
        margin:      const EdgeInsets.only(bottom: 14),
        padding:     bg != null
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : EdgeInsets.zero,
        decoration:  bg != null
            ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8))
            : null,
        child: content,
      ),
    );
  }
}

// ── Verse action sheet ────────────────────────────────────────────────────────

class _VerseActionSheet extends ConsumerWidget {
  const _VerseActionSheet({
    required this.verse,
    required this.bookName,
    required this.chapter,
    required this.translationCode,
    required this.bookNumber,
    required this.currentColor,
    required this.onHighlightChanged,
  });

  final BibleVerse   verse;
  final String       bookName;
  final int          chapter;
  final String       translationCode;
  final int          bookNumber;
  final String?      currentColor;
  final VoidCallback onHighlightChanged;

  static const _colors = [
    '#FFD700', '#4ADE80', '#60A5FA', '#F9A8D4', '#FB923C',
  ];

  String get _verseRef  => '$bookName $chapter:${verse.verseNumber}';
  String get _fullVerse => '$_verseRef — «${verse.text}»';

  Future<void> _setHighlight(
    BuildContext context,
    WidgetRef ref,
    String? colorHex,
  ) async {
    Navigator.pop(context);
    final dao = ref.read(bibleHighlightDaoProvider);
    if (colorHex == null) {
      await dao.clearHighlight(
        translationCode: translationCode,
        bookNumber:      bookNumber,
        chapterNumber:   chapter,
        verseNumber:     verse.verseNumber,
      );
    } else {
      await dao.setHighlight(
        translationCode: translationCode,
        bookNumber:      bookNumber,
        chapterNumber:   chapter,
        verseNumber:     verse.verseNumber,
        colorHex:        colorHex,
      );
    }
    onHighlightChanged();
  }

  Future<void> _share(BuildContext context) async {
    Navigator.pop(context);
    await SharePlus.instance.share(ShareParams(text: _fullVerse));
  }

  Future<void> _compare(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context);
    final dao   = ref.read(bibleDaoProvider);
    final codes = await dao.getDownloadedTranslationCodes();
    final texts = await dao.getVerseAcrossTranslations(
      codes, bookNumber, chapter, verse.verseNumber,
    );
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CompareSheet(verseRef: _verseRef, texts: texts),
    );
  }

  void _insert(BuildContext context, WidgetRef ref) {
    Navigator.pop(context);
    ref.read(bibleVerseToInsertProvider.notifier).set(_fullVerse);
    context.go('/publish/preview');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _verseRef,
              style: const TextStyle(
                fontFamily:  'Poppins',
                fontWeight:  FontWeight.w600,
                fontSize:    14,
                color:       AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              verse.text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize:   13,
                color:      AppColors.textSecondary,
                height:     1.4,
              ),
              maxLines:  3,
              overflow:  TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),

            // Highlight swatches
            Text(
              'Surligner',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Clear swatch
                GestureDetector(
                  onTap: () => _setHighlight(context, ref, null),
                  child: Container(
                    width: 34, height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.border, width: 1.5),
                      color: AppColors.background,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ),
                ..._colors.map((hex) {
                  final isSelected = currentColor == hex;
                  final c = Color(
                    int.parse('FF${hex.replaceFirst('#', '')}', radix: 16),
                  );
                  return GestureDetector(
                    onTap: () => _setHighlight(context, ref, hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34, height: 34,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(
                                color:      c.withAlpha(100),
                                blurRadius: 6,
                              )]
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),

            _ActionRow(
              icon:  Icons.share_rounded,
              label: 'Partager ce verset',
              onTap: () => _share(context),
            ),
            _ActionRow(
              icon:  Icons.compare_arrows_rounded,
              label: 'Comparer les traductions',
              onTap: () => _compare(context, ref),
            ),
            _ActionRow(
              icon:   Icons.edit_note_rounded,
              label:  'Insérer dans un témoignage',
              onTap:  () => _insert(context, ref),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  final bool         isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary, size: 22),
          title: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize:   14,
              color:      AppColors.textPrimary,
            ),
          ),
          onTap:           onTap,
          contentPadding:  EdgeInsets.zero,
          dense:           true,
        ),
        if (!isLast)
          const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _CompareSheet extends StatelessWidget {
  const _CompareSheet({required this.verseRef, required this.texts});
  final String             verseRef;
  final Map<String, String> texts;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              verseRef,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize:   14,
                color:      AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (texts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Téléchargez d\'autres traductions pour les comparer.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize:   13,
                    color:      AppColors.textSecondary,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: texts.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontFamily:  'Inter',
                            fontSize:    11,
                            fontWeight:  FontWeight.w700,
                            color:       AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize:   14,
                            color:      AppColors.textPrimary,
                            height:     1.5,
                          ),
                        ),
                        const Divider(height: 16, color: AppColors.border),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.canPrev,
    required this.canNext,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
  });
  final bool         canPrev;
  final bool         canNext;
  final String       prevLabel;
  final String       nextLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (canPrev)
            Expanded(
              child: GestureDetector(
                onTap: onPrev,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chevron_left_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        prevLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          if (canNext)
            Expanded(
              child: GestureDetector(
                onTap: onNext,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        nextLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary),
                  ],
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
