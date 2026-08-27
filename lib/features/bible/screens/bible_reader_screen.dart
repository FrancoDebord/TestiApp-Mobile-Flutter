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
          // Translation switcher chip
          GestureDetector(
            onTap: () => _showTranslationPicker(context),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.translationCode.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
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

  void _showTranslationPicker(BuildContext context) {
    final allTranslations =
        ref.read(bibleTranslationsProvider).value ?? [];
    final downloaded =
        allTranslations.where((t) => t.isDownloaded).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TranslationPickerSheet(
        translations: downloaded,
        currentCode: widget.translationCode,
        onSelect: (newCode) {
          // Carry current position over to the new translation
          ref.read(bibleReaderPositionProvider.notifier).setPosition(
            newCode,
            _currentBook.bookNumber,
            _chapter,
          );
          context.go('/bible/$newCode');
        },
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

class _VerseList extends ConsumerStatefulWidget {
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
  ConsumerState<_VerseList> createState() => _VerseListState();
}

class _VerseListState extends ConsumerState<_VerseList> {
  // Multi-selection state
  final Set<int> _selected = {};
  bool get _isSelectionMode => _selected.isNotEmpty;

  void _toggleSelection(int verseNumber) {
    setState(() {
      if (_selected.contains(verseNumber)) {
        _selected.remove(verseNumber);
      } else {
        _selected.add(verseNumber);
      }
    });
  }

  void _selectRange(List<BibleVerse> verses, int verseNumber) {
    if (_selected.isEmpty) {
      setState(() => _selected.add(verseNumber));
      return;
    }
    // Sélectionner la plage entre le min actuel et ce verset
    final allNums = verses.map((v) => v.verseNumber).toList();
    final touched = verseNumber;
    final minSel  = _selected.reduce((a, b) => a < b ? a : b);
    final maxSel  = _selected.reduce((a, b) => a > b ? a : b);
    final lo = touched < minSel ? touched : minSel;
    final hi = touched > maxSel ? touched : maxSel;
    setState(() {
      for (final n in allNums) {
        if (n >= lo && n <= hi) _selected.add(n);
      }
    });
  }

  void _clearSelection() => setState(() => _selected.clear());

  @override
  void didUpdateWidget(_VerseList old) {
    super.didUpdateWidget(old);
    // Réinitialiser la sélection lors d'un changement de chapitre
    if (old.chapter != widget.chapter ||
        old.bookNumber != widget.bookNumber ||
        old.translationCode != widget.translationCode) {
      _selected.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      translationCode: widget.translationCode,
      bookNumber:      widget.bookNumber,
      chapter:         widget.chapter,
    );
    final versesAsync = ref.watch(bibleVerseListProvider(key));
    final highlights  = ref.watch(bibleHighlightsProvider(key)).value ?? {};

    return Column(
      children: [
        Expanded(
          child: versesAsync.when(
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
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, _isSelectionMode ? 4 : 24),
                itemCount: verses.length,
                itemBuilder: (_, i) {
                  final v = verses[i];
                  return _VerseRow(
                    verse:            v,
                    highlight:        highlights[v.verseNumber],
                    isSelected:       _selected.contains(v.verseNumber),
                    isSelectionMode:  _isSelectionMode,
                    onTap: _isSelectionMode
                        ? () => _toggleSelection(v.verseNumber)
                        : () => _showVerseActions(context, v, highlights),
                    onLongPress: () {
                      if (_isSelectionMode) {
                        _selectRange(verses, v.verseNumber);
                      } else {
                        setState(() => _selected.add(v.verseNumber));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),

        // ── Selection action bar ───────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _isSelectionMode
              ? _SelectionBar(
                  selectedCount: _selected.length,
                  onClear: _clearSelection,
                  onShare: () => _shareSelection(versesAsync.value ?? []),
                  onInsert: () => _insertSelection(versesAsync.value ?? []),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showVerseActions(
    BuildContext context,
    BibleVerse verse,
    Map<int, String> highlights,
  ) {
    final key = (
      translationCode: widget.translationCode,
      bookNumber:      widget.bookNumber,
      chapter:         widget.chapter,
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
        bookName:           widget.bookName,
        chapter:            widget.chapter,
        translationCode:    widget.translationCode,
        bookNumber:         widget.bookNumber,
        currentColor:       highlights[verse.verseNumber],
        onHighlightChanged: () => ref.invalidate(bibleHighlightsProvider(key)),
      ),
    );
  }

  void _shareSelection(List<BibleVerse> allVerses) {
    final sorted = allVerses
        .where((v) => _selected.contains(v.verseNumber))
        .toList()
      ..sort((a, b) => a.verseNumber.compareTo(b.verseNumber));
    if (sorted.isEmpty) return;
    final text = sorted
        .map((v) => '${v.verseNumber}. ${v.text}')
        .join('\n');
    final ref2 = '${widget.bookName} ${widget.chapter}';
    _clearSelection();
    // Réutilise le SharePlus ou passe via la feuille d'actions
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MultiVerseShareSheet(
        verseText: text,
        reference: ref2,
        versNumbers: sorted.map((v) => v.verseNumber).toList(),
      ),
    );
  }

  void _insertSelection(List<BibleVerse> allVerses) {
    final sorted = allVerses
        .where((v) => _selected.contains(v.verseNumber))
        .toList()
      ..sort((a, b) => a.verseNumber.compareTo(b.verseNumber));
    if (sorted.isEmpty) return;

    // Construire la référence structurée — on ne stocke PAS le texte intégral
    final verseRef = BibleVerseRef(
      translationCode: widget.translationCode,
      bookNumber:      widget.bookNumber,
      bookName:        widget.bookName,
      chapter:         widget.chapter,
      verseNumbers:    sorted.map((v) => v.verseNumber).toList(),
    );

    // bibleVerseToInsertProvider ← courte référence (ex : "Jean 3:16-18")
    ref.read(bibleVerseToInsertProvider.notifier).set(verseRef.displayRef);
    // bibleVerseRefProvider ← données structurées pour l'aperçu dans le formulaire
    ref.read(bibleVerseRefProvider.notifier).set(verseRef);

    _clearSelection();
    context.go('/publish/preview');
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.verse,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    required this.isSelectionMode,
    this.highlight,
  });
  final BibleVerse   verse;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool         isSelected;
  final bool         isSelectionMode;
  final String?      highlight;

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

    // In selection mode, selected verses get a primary-tinted background
    if (isSelected) {
      bg = AppColors.primary.withAlpha(40);
    }

    final numColor = isSelected ? AppColors.primary : AppColors.primary;

    final content = RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          height: 1.75,
          color: isSelected
              ? AppColors.textPrimary
              : AppColors.textPrimary,
        ),
        children: [
          WidgetSpan(
            baseline:  TextBaseline.alphabetic,
            alignment: PlaceholderAlignment.baseline,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin:  const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(60)
                    : AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${verse.verseNumber}',
                style: TextStyle(
                  fontFamily:  'Inter',
                  fontSize:    10,
                  fontWeight:  FontWeight.w700,
                  color:       numColor,
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
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:   const EdgeInsets.only(bottom: 14),
        padding:  bg != null
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : EdgeInsets.zero,
        decoration: bg != null
            ? BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8))
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white)
                      : null,
                ),
              ),
            ],
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

// ── Selection action bar ──────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.onClear,
    required this.onShare,
    required this.onInsert,
  });
  final int          selectedCount;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            // Count chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$selectedCount verset${selectedCount > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const Spacer(),
            // Insert
            _BarAction(
              icon: Icons.add_circle_outline_rounded,
              label: 'Insérer',
              onTap: onInsert,
            ),
            const SizedBox(width: 8),
            // Share
            _BarAction(
              icon: Icons.share_rounded,
              label: 'Partager',
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Multi-verse share sheet ───────────────────────────────────────────────────

class _MultiVerseShareSheet extends StatelessWidget {
  const _MultiVerseShareSheet({
    required this.verseText,
    required this.reference,
    required this.versNumbers,
  });
  final String    verseText;
  final String    reference;
  final List<int> versNumbers;

  String get _versLabel {
    if (versNumbers.isEmpty) return '';
    // Détecte plage contiguë vs éparse
    versNumbers.sort();
    bool isRange = true;
    for (var i = 1; i < versNumbers.length; i++) {
      if (versNumbers[i] != versNumbers[i - 1] + 1) { isRange = false; break; }
    }
    if (isRange && versNumbers.length > 1) {
      return '$reference:${versNumbers.first}-${versNumbers.last}';
    }
    return '$reference:${versNumbers.join(',')}';
  }

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
            Text(_versLabel,
                style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
            const SizedBox(height: 10),
            Text(
              verseText,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 15,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      SharePlus.instance.share(
                        ShareParams(text: '$_versLabel\n$verseText'),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Partager'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

// ── Language helpers ──────────────────────────────────────────────────────────

String _languageLabel(String lang) => switch (lang.toLowerCase()) {
      'fr' => 'Français',
      'en' => 'English',
      'es' => 'Español',
      'pt' => 'Português',
      'de' => 'Deutsch',
      'it' => 'Italiano',
      'ar' => 'العربية',
      'sw' => 'Kiswahili',
      'ln' => 'Lingala',
      'yo' => 'Yoruba',
      'ha' => 'Hausa',
      'ig' => 'Igbo',
      'am' => 'Amharique',
      'rw' => 'Kinyarwanda',
      'wo' => 'Wolof',
      _    => lang.toUpperCase(),
    };

List<String> _sortedLanguages(Iterable<String> langs) {
  const priority = ['fr', 'en', 'es', 'pt'];
  final result = langs.toList()
    ..sort((a, b) {
      final ai = priority.indexOf(a);
      final bi = priority.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return _languageLabel(a).compareTo(_languageLabel(b));
    });
  return result;
}

// ── Translation picker sheet ──────────────────────────────────────────────────

class _TranslationPickerSheet extends StatelessWidget {
  const _TranslationPickerSheet({
    required this.translations,
    required this.currentCode,
    required this.onSelect,
  });

  final List<BibleTranslation> translations;
  final String                 currentCode;
  final ValueChanged<String>   onSelect;

  @override
  Widget build(BuildContext context) {
    // Group by language
    final grouped = <String, List<BibleTranslation>>{};
    for (final t in translations) {
      grouped.putIfAbsent(t.language, () => []).add(t);
    }
    final langs = _sortedLanguages(grouped.keys);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
            Text('Choisir une traduction', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text(
              'Traductions téléchargées',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),

            if (translations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucune traduction disponible.\n'
                    'Téléchargez-en depuis l\'onglet Bible.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var li = 0; li < langs.length; li++) ...[
                        Padding(
                          padding: EdgeInsets.only(
                            top: li == 0 ? 12 : 10,
                            bottom: 2,
                          ),
                          child: Row(
                            children: [
                              Text(
                                _languageLabel(langs[li]).toUpperCase(),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Divider(
                                  color: AppColors.border,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final t in grouped[langs[li]]!)
                          _buildTile(context, t),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, BibleTranslation t) {
    final isActive = t.code == currentCode;
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        onSelect(t.code);
      },
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(20)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          t.abbreviation.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
      title: Text(
        t.name,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        _languageLabel(t.language),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 20)
          : const Icon(Icons.chevron_right_rounded,
              color: AppColors.border, size: 20),
    );
  }
}
