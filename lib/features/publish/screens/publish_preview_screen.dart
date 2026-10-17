import 'dart:async' show Timer;
import 'dart:io' show File;

import 'package:video_player/video_player.dart'
    show VideoPlayerController;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/media/youtube.dart';
import '../../../../core/providers/categories_provider.dart';
import '../../../../core/router/app_routes.dart' show AppPaths;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../bible/providers/bible_providers.dart'
    show
        bibleVerseToInsertProvider,
        bibleVerseRefProvider,
        bibleVerseTextProvider;
import '../models/publish_models.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/mention_text.dart' show MentionText;
import '../../../../shared/widgets/mention_text_field.dart';
import '../providers/publish_provider.dart';
import 'video_camera_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../conversion/data/conversion_repository.dart' show conversionMinYear, isValidConversionYear;
import '../../conversion/widgets/conversion_widgets.dart' show conversionIcon;

// =============================================================================
// PublishPreviewScreen — 3-step stepper for text / audio / video testimony
// =============================================================================
//
// Widget tree (top level):
//
// Scaffold
//   Column
//     _StepperHeader            ← step indicator (1/3 … 3/3) + back arrow
//     _StatusBarRow             ← workflow chips
//     Expanded
//       AnimatedSwitcher
//         _Step1Details         ← title, category, cover image
//         _Step2Text / _Step2Audio / _Step2Video
//         _Step3Preview         ← preview card + visibility + publish CTA
//     _BottomNavButtons         ← Précédent / Suivant|Publier

class PublishPreviewScreen extends ConsumerWidget {
  const PublishPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(publishProvider);
    final step = ref.watch(publishStepProvider);
    final format = draft.format ?? TestimonyFormat.text;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _StepperHeader(step: step, format: format),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: _stepWidget(step, format, ref),
                ),
              ),
            ),
            _BottomNavButtons(step: step),
          ],
        ),
      ),
    );
  }

  Widget _stepWidget(int step, TestimonyFormat format, WidgetRef ref) {
    switch (step) {
      case 1:
        return const _Step1Details();
      case 2:
        switch (format) {
          case TestimonyFormat.text:
            return const _Step2Text();
          case TestimonyFormat.audio:
            return const _Step2Audio();
          case TestimonyFormat.video:
            return const _Step2Video();
        }
      case 3:
        return const _Step3Visibility();
      default:
        return const _Step1Details();
    }
  }
}

// =============================================================================
// Stepper header
// =============================================================================

class _StepperHeader extends StatelessWidget {
  const _StepperHeader({required this.step, required this.format});

  final int step;
  final TestimonyFormat format;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.commonBack,
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.publishStepOf(
                    step,
                    [
                      context.l10n.publishStepDetails,
                      context.l10n.publishStepContent,
                      context.l10n.publishStepPublication,
                    ][(step - 1).clamp(0, 2)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Progress dots
          Row(
            children: List.generate(3, (i) {
              final active = i + 1 == step;
              final done = i + 1 < step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.secondary
                      : done
                          ? AppColors.primary
                          : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 1 — Détails (maquette : Titre (optionnel) · Description · Catégorie)
// =============================================================================

class _Step1Details extends ConsumerStatefulWidget {
  const _Step1Details();

  @override
  ConsumerState<_Step1Details> createState() => _Step1DetailsState();
}

class _Step1DetailsState extends ConsumerState<_Step1Details> {
  late final TextEditingController _titleCtrl;

  /// Description / transcription avec mentions « @ » (prévenues à la publication).
  late final MentionEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(publishProvider);
    _titleCtrl = TextEditingController(text: draft.title);
    _descCtrl = MentionEditingController(
      text: draft.format == TestimonyFormat.audio
          ? draft.audioTranscript
          : draft.bodyText,
    );
    draft.mentions.forEach(_descCtrl.remember);
    // Saisie, mention choisie ou barre de mise en forme : le brouillon suit le champ.
    _descCtrl.addListener(_syncDescription);
  }

  void _syncDescription() {
    final draft = ref.read(publishProvider);
    final notifier = ref.read(publishProvider.notifier);
    final text = _descCtrl.text;
    if (draft.format == TestimonyFormat.audio) {
      if (draft.audioTranscript != text) notifier.updateAudioTranscript(text);
    } else if (draft.bodyText != text) {
      notifier.updateBodyText(text);
    }
    final mentions = _descCtrl.mentions;
    final current = draft.mentions;
    if (mentions.length != current.length ||
        mentions.any((m) => !current.contains(m))) {
      notifier.updateMentions(mentions);
    }
  }

  @override
  void dispose() {
    _descCtrl.removeListener(_syncDescription);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(publishProvider);
    final notifier = ref.read(publishProvider.notifier);
    final format = draft.format ?? TestimonyFormat.text;
    final isText = format == TestimonyFormat.text;
    final isAudio = format == TestimonyFormat.audio;
    final isPrivate = draft.visibility == TestimonyVisibility.private;
    final descLength =
        isAudio ? draft.audioTranscript.length : draft.bodyText.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Témoignage de conversion : année, lieu, verset (facultatifs) ──
          if (ref.watch(publishConversionProvider) != null) ...[
            const _SectionCard(children: [ConversionFieldsForm()]),
            const SizedBox(height: AppSpacing.lg),
          ],
          _SectionCard(
            children: [
              // ── Title (facultatif : repli sur la description) ─────────────
              _FieldLabel(label: context.l10n.publishTitleOptional, required: false),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                maxLength: 80,
                onChanged: notifier.updateTitle,
                decoration: _inputDecoration(
                  hint: context.l10n.publishTitleHint,
                  counterText: '${draft.title.length}/80',
                ),
                style: _inputTextStyle,
              ),
              const SizedBox(height: 12),

              // ── Description ───────────────────────────────────────────────
              // Texte : corps du témoignage (obligatoire). Audio : transcription.
              // Vidéo : description facultative.
              _FieldLabel(
                label: isText ? context.l10n.publishDescription : context.l10n.publishDescriptionOptional,
                required: isText,
              ),
              if (isAudio) ...[
                const SizedBox(height: 2),
                Text(
                  context.l10n.publishTranscriptHint,
                  style: AppTextStyles.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              if (isText) ...[
                _TextFormatToolbar(controller: _descCtrl),
                const SizedBox(height: 8),
              ],
              // « @ » : mentionner quelqu'un (prévenu quand le témoignage sera publié).
              MentionTextField(
                controller: _descCtrl,
                maxLength: 5000,
                minLines: isText ? 6 : 4,
                maxLines: isText ? 14 : 8,
                keyboardType: TextInputType.multiline,
                decoration: _inputDecoration(
                  hint: context.l10n.publishBodyHint,
                  counterText: '$descLength/5000',
                  contentPadding: const EdgeInsets.all(14),
                ),
                style: _inputTextStyle,
              ),
              const SizedBox(height: 12),

              // ── Category ──────────────────────────────────────────────────
              // Carnet privé : catégorie facultative.
              _FieldLabel(
                label: isPrivate ? context.l10n.publishCategoryOptional : context.l10n.journalCategory,
                required: !isPrivate,
              ),
              const SizedBox(height: 8),
              _CategorySelector(
                selectedSlug: draft.category,
                onChanged: notifier.updateCategory,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Cover image ─────────────────────────────────────────────────────
          _SectionCard(
            children: [
              _FieldLabel(
                  label: context.l10n.publishCoverOptional, required: false),
              const SizedBox(height: 8),
              _CoverImagePicker(
                imagePath: draft.coverImagePath,
                onPick: notifier.updateCoverImage,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Preuves (facultatives, publiées seulement avec l'accord de l'auteur) ─
          const _SectionCard(children: [_ProofsSection()]),
        ],
      ),
    );
  }
}

/// Champs du témoignage de conversion (année, lieu, verset), tous facultatifs.
class ConversionFieldsForm extends ConsumerStatefulWidget {
  const ConversionFieldsForm({super.key});

  @override
  ConsumerState<ConversionFieldsForm> createState() => _ConversionFieldsFormState();
}

class _ConversionFieldsFormState extends ConsumerState<ConversionFieldsForm> {
  late final TextEditingController _year;
  late final TextEditingController _place;
  late final TextEditingController _verse;

  @override
  void initState() {
    super.initState();
    final f = ref.read(publishConversionProvider) ?? const ConversionFields();
    _year = TextEditingController(text: f.year?.toString() ?? '');
    _place = TextEditingController(text: f.place);
    _verse = TextEditingController(text: f.verse);
  }

  @override
  void dispose() {
    _year.dispose();
    _place.dispose();
    _verse.dispose();
    super.dispose();
  }

  void _sync() {
    final current = ref.read(publishConversionProvider);
    if (current == null) return;
    ref.read(publishConversionProvider.notifier).update(ConversionFields(
          year: int.tryParse(_year.text.trim()),
          place: _place.text,
          verse: _verse.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final yearText = _year.text.trim();
    final year = int.tryParse(yearText);
    final yearError = yearText.isNotEmpty && (year == null || !isValidConversionYear(year))
        ? l10n.conversionYearInvalid(conversionMinYear, DateTime.now().year)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(conversionIcon, color: AppColors.secondaryDark, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.conversionMyConversion,
                  style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.conversionFieldsHint, style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _year,
          keyboardType: TextInputType.number,
          maxLength: 4,
          onChanged: (_) => setState(_sync),
          decoration: _inputDecoration(hint: l10n.conversionYearHint, counterText: '').copyWith(
            labelText: l10n.conversionYear,
            errorText: yearError,
            prefixIcon: const Icon(Icons.event_rounded),
          ),
          style: _inputTextStyle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _place,
          maxLength: 150,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _sync(),
          decoration: _inputDecoration(hint: l10n.conversionPlaceHint, counterText: '').copyWith(
            labelText: l10n.conversionPlace,
            prefixIcon: const Icon(Icons.place_outlined),
          ),
          style: _inputTextStyle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _verse,
          maxLength: 100,
          onChanged: (_) => _sync(),
          decoration: _inputDecoration(hint: l10n.conversionVerseHint, counterText: '').copyWith(
            labelText: l10n.conversionVerse,
            prefixIcon: const Icon(Icons.menu_book_rounded),
          ),
          style: _inputTextStyle,
        ),
      ],
    );
  }
}

/// Carte blanche de la charte (radius 16, bordure fine, ombre légère).
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// =============================================================================
// Step 2 — Text content
// =============================================================================

class _Step2Text extends ConsumerStatefulWidget {
  const _Step2Text();

  @override
  ConsumerState<_Step2Text> createState() => _Step2TextState();
}

class _Step2TextState extends ConsumerState<_Step2Text> {
  late final TextEditingController _verseCtrl;

  @override
  void initState() {
    super.initState();
    final draft   = ref.read(publishProvider);
    _verseCtrl    = TextEditingController(text: draft.bibleVerse);

    // Pre-fill verse from Bible reader (bibleVerseToInsertProvider)
    final pending = ref.read(bibleVerseToInsertProvider);
    if (pending != null && pending.isNotEmpty) {
      _verseCtrl.text = pending;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(publishProvider.notifier).updateBibleVerse(pending);
        ref.read(bibleVerseToInsertProvider.notifier).clear();
      });
    }
  }

  @override
  void dispose() {
    _verseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(publishProvider);
    final notifier = ref.read(publishProvider.notifier);
    final body = draft.bodyText.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Rappel de la description (saisie à l'étape 1) ────────────────
          _SectionCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _FieldLabel(
                        label: context.l10n.publishYourTestimony, required: false),
                  ),
                  TextButton.icon(
                    onPressed: ref.read(publishStepProvider.notifier).previous,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(context.l10n.commonEdit),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              MentionText(
                body.isEmpty ? context.l10n.publishNoDescription : body,
                mentions: draft.mentions,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: body.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Bible verse ──────────────────────────────────────────────────
          _SectionCard(
            children: [
              _FieldLabel(
                  label: context.l10n.publishVerseOptional, required: false),
              const SizedBox(height: 8),
              TextField(
                controller: _verseCtrl,
                onChanged: (v) {
                  notifier.updateBibleVerse(v);
                  // Si l'utilisateur modifie manuellement, on efface la réf structurée
                  if (ref.read(bibleVerseRefProvider) != null) {
                    ref.read(bibleVerseRefProvider.notifier).clear();
                  }
                },
                decoration: _inputDecoration(
                  hint: context.l10n.publishVerseHint,
                  prefixIcon: const Icon(Icons.menu_book_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                style: _inputTextStyle.copyWith(
                  fontFamily: 'Playfair Display',
                  fontStyle: FontStyle.italic,
                ),
              ),
              // Aperçu du texte du verset (chargé depuis SQLite local)
              const _BibleVersePreview(),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 2 — Audio (enregistrement réel via audio_waveforms)
// =============================================================================

class _Step2Audio extends ConsumerStatefulWidget {
  const _Step2Audio();

  @override
  ConsumerState<_Step2Audio> createState() => _Step2AudioState();
}

class _Step2AudioState extends ConsumerState<_Step2Audio> {
  final _recorder = RecorderController();
  bool  _isRecording = false;
  int   _elapsed     = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) _recorder.stop();
    _recorder.dispose();
    super.dispose();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Démarrer l'enregistrement ─────────────────────────────────────────────

  Future<void> _start() async {
    // audio_waveforms vérifie la permission microphone en interne
    final hasPerm = await _recorder.checkPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.publishMicPermissionDenied,
                style: const TextStyle(fontFamily: AppFonts.family)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final dir  = await getTemporaryDirectory();
    final path =
        '${dir.path}/testi_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.record(path: path);

    setState(() { _isRecording = true; _elapsed = 0; });
    ref.read(audioRecordingProvider.notifier).startRecording();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  // ── Arrêter l'enregistrement ──────────────────────────────────────────────

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;

    setState(() => _isRecording = false);
    ref.read(audioRecordingProvider.notifier).stopRecording();

    if (path != null) {
      final notifier = ref.read(publishProvider.notifier);
      notifier.updateAudioPath(path);
      notifier.updateAudioDuration(_elapsed);
    }
  }

  // ── Importer un fichier audio ─────────────────────────────────────────────

  Future<void> _import() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    final path = file?.path;
    if (path != null && mounted) {
      ref.read(audioRecordingProvider.notifier).stopRecording();
      ref.read(publishProvider.notifier).updateAudioPath(path);
    }
  }

  // ── Remettre à zéro ──────────────────────────────────────────────────────

  void _reset() {
    _timer?.cancel();
    if (_isRecording) _recorder.stop();
    setState(() { _isRecording = false; _elapsed = 0; });
    ref.read(audioRecordingProvider.notifier).reset();
    ref.read(publishProvider.notifier).clearAudio();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final draft    = ref.watch(publishProvider);
    final hasAudio = (draft.audioPath ?? '').isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Carte d'enregistrement (waveform réelle) ───────────────────────
          _RealRecordingCard(
            recorder:    _recorder,
            isRecording: _isRecording,
            elapsed:     _elapsed,
            hasAudio:    hasAudio,
            onStart:     _start,
            onStop:      _stop,
            onReset:     _reset,
            formatTime:  _fmt,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(context.l10n.publishOr,
                    style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),

          const SizedBox(height: 20),

          // ── Import fichier ─────────────────────────────────────────────────
          _UploadButton(
            icon:  Icons.upload_file_rounded,
            label: context.l10n.publishImportFromFiles,
            onTap: _import,
          ),

          // ── Lecteur de prévisualisation ────────────────────────────────────
          if (hasAudio) ...[
            const SizedBox(height: 24),
            _RealPlaybackBar(
              audioPath:       draft.audioPath!,
              durationSeconds: draft.audioDurationSeconds,
              onDelete:        _reset,
            ),
          ],
          // La transcription se saisit à l'étape 1 (champ « Description »).
        ],
      ),
    );
  }
}

// =============================================================================
// Step 2 — Video
// =============================================================================

class _Step2Video extends ConsumerStatefulWidget {
  const _Step2Video();

  @override
  ConsumerState<_Step2Video> createState() => _Step2VideoState();
}

class _Step2VideoState extends ConsumerState<_Step2Video> {
  final _picker = ImagePicker();
  Duration _videoDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final sec = ref.read(publishProvider).videoDurationSeconds;
    if (sec > 0) _videoDuration = Duration(seconds: sec);
  }

  Future<void> _applyVideoPath(String path) async {
    final notifier = ref.read(publishProvider.notifier);

    final ctrl = VideoPlayerController.file(File(path));
    try {
      await ctrl.initialize();
      final dur = ctrl.value.duration;
      if (dur > Duration.zero) {
        notifier.updateVideoDuration(dur.inSeconds);
        notifier.updateVideoTrim(Duration.zero, dur);
        if (mounted) setState(() => _videoDuration = dur);
      }
    } finally {
      ctrl.dispose();
    }

    notifier.updateVideoPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final draft    = ref.watch(publishProvider);
    final notifier = ref.read(publishProvider.notifier);
    final total    = _videoDuration > Duration.zero
        ? _videoDuration
        : const Duration(seconds: 60);
    // Publication par lien YouTube : réservée aux administrateurs (403 sinon).
    final isAdmin    = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final useYouTube = isAdmin && draft.useYouTube;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAdmin) ...[
            _VideoSourceToggle(
              useYouTube: useYouTube,
              onChanged: notifier.setUseYouTube,
            ),
            const SizedBox(height: 16),
          ],
          if (useYouTube)
            _YouTubeLinkField(
              initialValue: draft.youtubeUrl,
              onChanged: notifier.updateYouTubeUrl,
            )
          else ...[
          // ── Camera preview / placeholder ─────────────────────────────────
          _VideoCameraPreview(
            videoPath: draft.videoPath,
            onRecord: () async {
              final String? path = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => const VideoCameraScreen(),
                ),
              );
              if (path != null) await _applyVideoPath(path);
            },
            onImport: () async {
              final XFile? file = await _picker.pickVideo(
                source: ImageSource.gallery,
              );
              if (file != null) await _applyVideoPath(file.path);
            },
          ),
          const SizedBox(height: 24),

          // ── Trim tool ─────────────────────────────────────────────────────
          if (draft.videoPath != null) ...[
            _VideoTrimTool(
              totalDuration: total,
              trimStart: draft.videoTrimStart,
              trimEnd: draft.videoTrimEnd,
              onChanged: notifier.updateVideoTrim,
            ),
            const SizedBox(height: 20),

            // ── Thumbnail selector ──────────────────────────────────────────
            _ThumbnailSelector(
              selectedIndex: draft.videoThumbnailIndex,
              onChanged: notifier.updateThumbnailIndex,
            ),
          ],
          ],
        ],
      ),
    );
  }
}

// ── Vidéo : fichier ou lien YouTube (administrateurs) ─────────────────────────

class _VideoSourceToggle extends StatelessWidget {
  const _VideoSourceToggle({required this.useYouTube, required this.onChanged});

  final bool useYouTube;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(bool value, IconData icon, String label) {
      final selected = useYouTube == value;
      return Expanded(
        child: InkWell(
          onTap: selected ? null : () => onChanged(value),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: AppColors.primary) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          option(false, Icons.videocam_rounded, context.l10n.publishVideoFile),
          const SizedBox(width: 4),
          option(true, Icons.smart_display_rounded, context.l10n.publishYouTubeLink),
        ],
      ),
    );
  }
}

class _YouTubeLinkField extends StatefulWidget {
  const _YouTubeLinkField({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_YouTubeLinkField> createState() => _YouTubeLinkFieldState();
}

class _YouTubeLinkFieldState extends State<_YouTubeLinkField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text.trim();
    final id = extractYouTubeId(text);
    final error = text.isNotEmpty && id == null
        ? context.l10n.publishYouTubeInvalid
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: context.l10n.publishYouTubeLink, required: true),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
          decoration: _inputDecoration(
            hint: 'https://www.youtube.com/watch?v=…',
          ).copyWith(
            errorText: error,
            errorMaxLines: 2,
            prefixIcon: const Icon(Icons.link_rounded,
                color: AppColors.textSecondary),
          ),
          style: _inputTextStyle,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.publishYouTubeNote,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        if (id != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                youTubeThumbnailUrl(id),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.primarySoft,
                  alignment: Alignment.center,
                  child: const Icon(Icons.smart_display_rounded,
                      color: AppColors.primary, size: 40),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Preuves du témoignage (2 emplacements, facultatives) ──────────────────────

class _ProofsSection extends ConsumerWidget {
  const _ProofsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft  = ref.watch(publishProvider);
    final proofs = draft.proofs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: context.l10n.publishProofsLabel, required: false),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.publishProofsHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final position in const [1, 2]) ...[
          _ProofSlot(position: position, file: proofs[position]),
          if (position == 1) const SizedBox(height: 8),
        ],
        if (proofs.isNotEmpty) ...[
          const SizedBox(height: 10),
          // Accord pour montrer les preuves au public (une fois le témoignage publié)
          Material(
            color: draft.proofsPublic ? AppColors.primarySoft : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: draft.proofsPublic ? AppColors.primary : AppColors.border,
              ),
            ),
            child: CheckboxListTile(
              value: draft.proofsPublic,
              onChanged: (v) => ref
                  .read(publishProvider.notifier)
                  .setProofsPublic(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                context.l10n.publishProofsPublic,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                context.l10n.publishProofsPublicHint,
                style: AppTextStyles.bodySmall.copyWith(height: 1.4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProofSlot extends ConsumerWidget {
  const _ProofSlot({required this.position, required this.file});

  final int position;
  final ProofAttachment? file;

  /// « 12 Ko » / « 1,5 Mo » (virgule décimale en français, point en anglais).
  static String _size(int bytes) {
    final l = L10n.current;
    if (bytes < 1024 * 1024) return l.publishSizeKb('${(bytes / 1024).ceil()}');
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return l.publishSizeMb(L10n.languageCode == 'fr' ? mb.replaceAll('.', ',') : mb);
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: Text(ctx.l10n.publishProofFromGallery),
              onTap: () => Navigator.of(ctx).pop('image'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.primary),
              title: Text(ctx.l10n.publishProofFromFiles),
              onTap: () => Navigator.of(ctx).pop('file'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    String? path;
    String? name;
    int size = 0;
    try {
      if (source == 'image') {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img == null) return;
        path = img.path;
        name = img.name;
        size = await img.length();
      } else {
        final f = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: kProofExtensions,
        );
        if (f == null || f.path == null) return;
        path = f.path;
        name = f.name;
        size = f.size;
      }
    } catch (_) {
      return;
    }

    final reason = proofRejectionReason(name: name, size: size);
    if (reason != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(reason)));
      }
      return;
    }
    ref.read(publishProvider.notifier).setProof(
        position, ProofAttachment(path: path!, name: name, size: size));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = file;
    if (f == null) {
      return OutlinedButton.icon(
        onPressed: () => _pick(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.inputBorder),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        icon: const Icon(Icons.attach_file_rounded, size: 18),
        label: Text(context.l10n.publishProofAdd(position),
            style: TextStyle(fontFamily: AppFonts.family, fontSize: 14)),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            f.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  context.l10n.publishProofItem(position, _size(f.size)),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.publishProofRemove(position),
            onPressed: () =>
                ref.read(publishProvider.notifier).removeProof(position),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bottom navigation buttons
// =============================================================================

class _BottomNavButtons extends ConsumerStatefulWidget {
  const _BottomNavButtons({required this.step});
  final int step;

  @override
  ConsumerState<_BottomNavButtons> createState() => _BottomNavButtonsState();
}

class _BottomNavButtonsState extends ConsumerState<_BottomNavButtons> {
  bool _isPublishing = false;

  bool _canProceed(PublishDraft draft, AudioRecordingStatus recordingStatus) {
    // Même repli que l'affichage (PublishPreviewScreen) et la publication
    // (PublishNotifier) : sans format choisi — arrivée depuis le verset du jour
    // ou la Bible —, c'est un témoignage écrit. Sans ce repli, l'étape 2
    // attendait une vidéo et « Suivant » restait désactivé.
    final format = draft.format ?? TestimonyFormat.text;
    switch (widget.step) {
      case 1:
        // Titre facultatif (repli sur la description) ; carnet privé :
        // catégorie facultative. Texte : la description est le témoignage.
        final categoryOk = draft.category != null ||
            draft.visibility == TestimonyVisibility.private;
        final bodyOk = format != TestimonyFormat.text ||
            draft.bodyText.trim().isNotEmpty;
        final conversionYear = ref.read(publishConversionProvider)?.year;
        final conversionOk = conversionYear == null || isValidConversionYear(conversionYear);
        return categoryOk && bodyOk && conversionOk;
      case 2:
        if (format == TestimonyFormat.text) {
          return draft.bodyText.trim().isNotEmpty;
        }
        if (format == TestimonyFormat.audio) {
          return recordingStatus == AudioRecordingStatus.finished ||
              draft.audioPath != null;
        }
        if (draft.useYouTube &&
            (ref.read(currentUserProvider)?.isAdmin ?? false)) {
          return extractYouTubeId(draft.youtubeUrl) != null;
        }
        return draft.videoPath != null;
      case 3:
        if (draft.visibility == TestimonyVisibility.private) return true;
        return draft.consentGiven && draft.category != null;
      default:
        return true;
    }
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    try {
      await ref.read(publishProvider.notifier).publish();
      if (!mounted) return;
      final result = ref.read(publishProvider);
      // Témoignage publié mais preuve refusée / réseau : on le signale sans
      // bloquer (ScaffoldMessenger affiche les messages l'un après l'autre).
      for (final position in result.failedProofPositions) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.publishProofUploadFailed(position)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
      if (result.isAuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? context.l10n.publishSessionExpired,
              style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13),
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: context.l10n.authSignIn,
              textColor: Colors.white,
              onPressed: () => context.go('/login'),
            ),
          ),
        );
      } else if (result.errorMessage != null || result.uploadError != null) {
        // uploadError : échec d'envoi de la vidéo / audio / couverture.
        // Sans ce cas, l'échec tombait dans la branche « succès » et le
        // brouillon était effacé alors que rien n'avait été publié.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? result.uploadError!,
                style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13)),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 6),
          ),
        );
      } else if (result.status == PublishStatus.videoUploading) {
        // Vidéo : compression et envoi suivis sur l'écran dédié (Annuler,
        // Réessayer, message « en cours de traitement » à la fin).
        ref.read(publishProvider.notifier).reset();
        ref.read(publishStepProvider.notifier).goTo(1);
        final router = GoRouter.of(context);
        router.go(AppPaths.homePath);
        router.push(AppPaths.videoUploadPath);
      } else if (result.status == PublishStatus.pendingSync) {
        // Hors ligne — enregistré localement, sera synchronisé plus tard
        ref.read(publishProvider.notifier).reset();
        ref.read(publishStepProvider.notifier).goTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.publishSavedOffline,
              style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13),
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );
        if (context.canPop()) context.pop();
        context.go('/home');
      } else if (result.status == PublishStatus.savedToJournal) {
        ref.read(publishProvider.notifier).reset();
        ref.read(publishStepProvider.notifier).goTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.publishSavedToJournal,
              style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
        if (context.canPop()) context.pop();
        context.go('/journal');
      } else {
        // Succès — réinitialiser le flux et retourner à l'accueil
        ref.read(publishProvider.notifier).reset();
        ref.read(publishStepProvider.notifier).goTo(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.publishSubmitted,
              style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
        if (context.canPop()) context.pop();
        context.go('/home');
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(publishConversionProvider); // année de conversion valide pour « Suivant »
    final draft           = ref.watch(publishProvider);
    final recordingStatus = ref.watch(audioRecordingProvider);
    final stepNotifier    = ref.read(publishStepProvider.notifier);

    final canGo      = _canProceed(draft, recordingStatus);
    final isLastStep = widget.step == 3;
    final canPublish = isLastStep &&
        canGo &&
        draft.status != PublishStatus.submitted &&
        !draft.isUploadingMedia &&
        !_isPublishing;

    final isPrivate = draft.visibility == TestimonyVisibility.private;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (widget.step > 1) ...[
            Expanded(
              child: AppButton(
                label: context.l10n.commonPrevious,
                variant: AppButtonVariant.outline,
                size: isLastStep ? AppButtonSize.large : AppButtonSize.medium,
                fullWidth: true,
                onPressed: _isPublishing ? null : stepNotifier.previous,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            flex: widget.step == 1 ? 1 : 2,
            child: isLastStep
                ? AppButton(
                    label: isPrivate ? context.l10n.commonSave : context.l10n.commonPublish,
                    variant: AppButtonVariant.orange,
                    size: AppButtonSize.large,
                    fullWidth: true,
                    isLoading: _isPublishing,
                    leadingIcon: isPrivate
                        ? Icons.lock_rounded
                        : Icons.send_rounded,
                    onPressed: canPublish ? _publish : null,
                  )
                : AppButton(
                    label: context.l10n.commonNext,
                    fullWidth: true,
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: canGo ? stepNotifier.next : null,
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 3 — Visibility & Consent
// =============================================================================

class _Step3Visibility extends ConsumerWidget {
  const _Step3Visibility();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(publishProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Visibility ─────────────────────────────────────────────────────
          _SectionCard(children: [
          _FieldLabel(label: context.l10n.publishVisibility, required: true),
          const SizedBox(height: 4),
          Text(
            context.l10n.publishWhoCanSee,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),

          _VisibilityOption(
            icon: Icons.public_rounded,
            label: context.l10n.publishVisibilityPublic,
            description: context.l10n.publishVisibilityPublicHint,
            selected: draft.visibility == TestimonyVisibility.public,
            onTap: () => ref
                .read(publishProvider.notifier)
                .setVisibility(TestimonyVisibility.public),
          ),
          const SizedBox(height: 10),
          _VisibilityOption(
            icon: Icons.people_rounded,
            label: context.l10n.publishVisibilityFriends,
            description: context.l10n.publishVisibilityFriendsHint,
            selected: draft.visibility == TestimonyVisibility.friends,
            onTap: () => ref
                .read(publishProvider.notifier)
                .setVisibility(TestimonyVisibility.friends),
          ),
          const SizedBox(height: 10),
          _VisibilityOption(
            icon: Icons.lock_rounded,
            label: context.l10n.publishJournalOption,
            description: context.l10n.publishVisibilityPrivateHint,
            selected: draft.visibility == TestimonyVisibility.private,
            onTap: () => ref
                .read(publishProvider.notifier)
                .setVisibility(TestimonyVisibility.private),
          ),
          ]),

          const SizedBox(height: AppSpacing.lg),

          // Carnet privé : pas de consentement de publication.
          if (draft.visibility == TestimonyVisibility.private)
            const _JournalInfoCard()
          else ...[
          // ── Consent ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: () =>
                ref.read(publishProvider.notifier).toggleConsent(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: draft.consentGiven
                    ? AppColors.primarySoft
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: draft.consentGiven
                      ? AppColors.primary.withAlpha(100)
                      : AppColors.border,
                  width: draft.consentGiven ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: draft.consentGiven,
                      onChanged: (_) =>
                          ref.read(publishProvider.notifier).toggleConsent(),
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      side: BorderSide(
                        color: draft.consentGiven
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.publishCertifyReal,
                          style: TextStyle(
                            fontFamily: AppFonts.family,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: draft.consentGiven
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.publishCertifyBody,
                          style: const TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!draft.consentGiven) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.publishConsentRequired,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          ],
          // Une publication (publique ou abonnés) exige une catégorie.
          if (draft.visibility != TestimonyVisibility.private &&
              draft.category == null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.publishCategoryRequired,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Carnet privé : explication (étape 3) ──────────────────────────────────────

class _JournalInfoCard extends StatelessWidget {
  const _JournalInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.publishJournalInfo,
              style: const TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Visibility option card ────────────────────────────────────────────────────

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final String       description;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primarySoft
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withAlpha(20)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.border,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared sub-widgets
// =============================================================================

// ── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.required});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      style: const TextStyle(
        fontFamily: AppFonts.family,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Category selector ─────────────────────────────────────────────────────────

class _CategorySelector extends ConsumerWidget {
  const _CategorySelector({
    required this.selectedSlug,
    required this.onChanged,
  });

  /// Slug stocké dans le draft (ex: "guerison"). Null si rien sélectionné.
  final String? selectedSlug;
  final ValueChanged<CategoryModel> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesListProvider);
    final selectedCat = selectedSlug != null
        ? categories.where((c) => c.slug == selectedSlug).firstOrNull
        : null;
    final displayName = selectedCat?.name ?? selectedSlug;

    return GestureDetector(
      onTap: () => _showCategorySheet(context, categories),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
        child: Row(
          children: [
            Icon(
              Icons.category_rounded,
              size: 18,
              color: selectedSlug != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayName ?? context.l10n.publishChooseCategory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 14,
                  color: selectedSlug != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCategorySheet(
      BuildContext context, List<CategoryModel> categories) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.88,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.publishChooseCategory,
                    style: const TextStyle(
                      fontFamily: AppFonts.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: categories.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: categories.length,
                        itemBuilder: (_, i) {
                          final cat = categories[i];
                          final isSelected = cat.slug == selectedSlug;
                          return ListTile(
                            title: Text(
                              cat.name,
                              style: TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 14,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary, size: 20)
                                : null,
                            onTap: () {
                              onChanged(cat);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cover image picker ────────────────────────────────────────────────────────

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({required this.imagePath, required this.onPick});

  final String? imagePath;
  final ValueChanged<String> onPick;

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
              ),
              title: Text(context.l10n.editGallery,
                  style: const TextStyle(fontFamily: AppFonts.family)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: Text(context.l10n.editCamera,
                  style: const TextStyle(fontFamily: AppFonts.family)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (file != null) onPick(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: imagePath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // Sur web, image_picker retourne un blob URL → Image.network
                    // Sur mobile, c'est un chemin fichier → Image.file
                    child: kIsWeb
                        ? Image.network(
                            imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder,
                          )
                        : Image.file(
                            File(imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _placeholder,
                          ),
                  ),
                  // Bouton "changer"
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded,
                              color: Colors.white, size: 13),
                          const SizedBox(width: 4),
                          Text(context.l10n.publishChange,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: AppFonts.family)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _placeholder,
      ),
    );
  }

  static Widget get _placeholder => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate_rounded,
            size: 36, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(
          L10n.current.publishTapToAddCover,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

// ── Text format toolbar ───────────────────────────────────────────────────────

class _TextFormatToolbar extends StatelessWidget {
  const _TextFormatToolbar({required this.controller});

  final TextEditingController controller;

  void _wrap(String prefix, String suffix) {
    final sel  = controller.selection;
    final text = controller.text;
    if (!sel.isValid) return;
    final before   = text.substring(0, sel.start);
    final selected = text.substring(sel.start, sel.end);
    final after    = text.substring(sel.end);
    final inserted = '$prefix$selected$suffix';
    controller.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(
        offset: sel.start + inserted.length,
      ),
    );
  }

  void _quote() => _prefixLines((_) => '> ');

  void _heading() => _prefixLines((_) => '# ');

  void _bullets() => _prefixLines((_) => '- ');

  void _numbered() => _prefixLines((i) => '${i + 1}. ');

  /// Préfixe chaque ligne touchée par la sélection (ou la ligne du curseur).
  /// Les préfixes de bloc existants (#, >, -, 1.) sont remplacés, pas cumulés.
  void _prefixLines(String Function(int index) prefix) {
    final sel  = controller.selection;
    final text = controller.text;
    if (!sel.isValid) return;

    final start = text.lastIndexOf('\n', sel.start > 0 ? sel.start - 1 : 0) + 1;
    var end = text.indexOf('\n', sel.end);
    if (end < 0) end = text.length;

    final existing = RegExp(r'^(#{1,3} |> |- |\d{1,3}[.)] )');
    final lines = text.substring(start, end).split('\n');
    final block = [
      for (var i = 0; i < lines.length; i++)
        '${prefix(i)}${lines[i].replaceFirst(existing, '')}',
    ].join('\n');

    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, block),
      selection: TextSelection.collapsed(offset: start + block.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      // Défilable : 7 boutons ne tiennent pas sur les petits écrans.
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ToolbarButton(
              icon: Icons.title_rounded,
              tooltip: context.l10n.publishFormatHeading,
              onTap: _heading),
          _ToolbarButton(
              icon: Icons.format_bold_rounded,
              tooltip: context.l10n.publishFormatBold,
              onTap: () => _wrap('**', '**')),
          _ToolbarButton(
              icon: Icons.format_italic_rounded,
              tooltip: context.l10n.publishFormatItalic,
              onTap: () => _wrap('__', '__')),
          _ToolbarButton(
              icon: Icons.format_strikethrough_rounded,
              tooltip: context.l10n.publishFormatStrike,
              onTap: () => _wrap('~~', '~~')),
          _ToolbarButton(
              icon: Icons.format_quote_rounded,
              tooltip: context.l10n.publishFormatQuote,
              onTap: _quote),
          _ToolbarButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: context.l10n.publishFormatBullets,
              onTap: _bullets),
          _ToolbarButton(
              icon: Icons.format_list_numbered_rounded,
              tooltip: context.l10n.publishFormatNumbered,
              onTap: _numbered),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Carte d'enregistrement réelle ────────────────────────────────────────────

class _RealRecordingCard extends StatelessWidget {
  const _RealRecordingCard({
    required this.recorder,
    required this.isRecording,
    required this.elapsed,
    required this.hasAudio,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.formatTime,
  });

  final RecorderController       recorder;
  final bool                     isRecording;
  final int                      elapsed;
  final bool                     hasAudio;
  final Future<void> Function()  onStart;
  final Future<void> Function()  onStop;
  final VoidCallback             onReset;
  final String Function(int)     formatTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecording ? AppColors.danger : AppColors.border,
          width: isRecording ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Waveform live (audio_waveforms)
          if (isRecording)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 64,
                child: AudioWaveforms(
                  recorderController: recorder,
                  size: Size(MediaQuery.of(context).size.width - 80, 64),
                  waveStyle: WaveStyle(
                    waveColor: AppColors.danger,
                    backgroundColor: AppColors.background,
                    showBottom: true,
                    showTop: true,
                    extendWaveform: true,
                    showMiddleLine: false,
                    waveThickness: 2.5,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(28, (i) => Container(
                  width: 3,
                  height: hasAudio ? (6 + (i % 6) * 7.0) : 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: hasAudio
                        ? AppColors.primary.withAlpha(120)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )),
              ),
            ),
          const SizedBox(height: 14),

          // Timer
          Text(
            formatTime(elapsed),
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Bouton record
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouton reset (visible si audio capturé)
              if (hasAudio && !isRecording)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                    onTap: onReset,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger.withAlpha(15),
                        border: Border.all(
                            color: AppColors.danger.withAlpha(80)),
                      ),
                      child: const Icon(Icons.restart_alt_rounded,
                          color: AppColors.danger, size: 22),
                    ),
                  ),
                ),

              // Bouton record principal
              GestureDetector(
                onTap: isRecording ? onStop : onStart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.danger
                            .withAlpha(isRecording ? 90 : 45),
                        blurRadius: isRecording ? 20 : 10,
                        spreadRadius: isRecording ? 5 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isRecording
                        ? Icons.stop_rounded
                        : (hasAudio
                            ? Icons.fiber_manual_record_rounded
                            : Icons.mic_rounded),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            isRecording
                ? context.l10n.publishTapToStop
                : hasAudio
                    ? context.l10n.publishRecordingDone
                    : context.l10n.publishTapToRecord,
            style: TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 12,
              color: hasAudio && !isRecording
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barre de lecture réelle (just_audio) ─────────────────────────────────────

class _RealPlaybackBar extends StatefulWidget {
  const _RealPlaybackBar({
    required this.audioPath,
    required this.durationSeconds,
    required this.onDelete,
  });
  final String audioPath;
  final int    durationSeconds;
  final VoidCallback onDelete;

  @override
  State<_RealPlaybackBar> createState() => _RealPlaybackBarState();
}

class _RealPlaybackBarState extends State<_RealPlaybackBar> {
  final _player  = AudioPlayer();
  bool _playing  = false;
  double _progress = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.audioPath);
      _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _duration = d);
      });
      _player.positionStream.listen((p) {
        if (mounted) {
          setState(() {
            _position = p;
            _progress = _duration.inMilliseconds > 0
                ? p.inMilliseconds / _duration.inMilliseconds
                : 0;
          });
        }
      });
      _player.playingStream.listen((p) {
        if (mounted) setState(() => _playing = p);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Play / Pause
          IconButton(
            onPressed: () =>
                _playing ? _player.pause() : _player.play(),
            icon: Icon(
              _playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: AppColors.primary,
              size: 36,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),

          // Slider + temps
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 3,
                    thumbShape:
                        RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _progress.clamp(0.0, 1.0),
                    onChanged: (v) async {
                      final target = Duration(
                          milliseconds:
                              (v * _duration.inMilliseconds).round());
                      await _player.seek(target);
                    },
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(_position),
                          style: const TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      Text(_fmt(_duration),
                          style: const TextStyle(
                              fontFamily: AppFonts.family,
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Supprimer
          IconButton(
            onPressed: () {
              _player.stop();
              widget.onDelete();
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Upload button ─────────────────────────────────────────────────────────────

class _UploadButton extends StatelessWidget {
  const _UploadButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: const TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ── Video camera preview ──────────────────────────────────────────────────────

class _VideoCameraPreview extends StatelessWidget {
  const _VideoCameraPreview({
    required this.videoPath,
    required this.onRecord,
    required this.onImport,
  });

  final String? videoPath;
  final Future<void> Function() onRecord;
  final Future<void> Function() onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: videoPath != null
          ? _VideoSelected(path: videoPath!, onReplace: onImport)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      color: Colors.white70, size: 40),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.fiber_manual_record_rounded,
                      color: AppColors.danger, size: 16),
                  label: Text(context.l10n.publishFilmVideo),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.photo_library_rounded,
                      color: Colors.white70, size: 18),
                  label: Text(
                    context.l10n.publishPickFromGallery,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: AppFonts.family,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
    );
  }
}

class _VideoSelected extends StatelessWidget {
  const _VideoSelected({required this.path, required this.onReplace});
  final String path;
  final Future<void> Function() onReplace;

  @override
  Widget build(BuildContext context) {
    final fileName = path.split('/').last.split('\\').last;
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(80),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: AppFonts.family,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 10, right: 10,
          child: GestureDetector(
            onTap: onReplace,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text(context.l10n.publishChange,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontFamily: AppFonts.family)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Video trim tool ───────────────────────────────────────────────────────────

class _VideoTrimTool extends StatelessWidget {
  const _VideoTrimTool({
    required this.totalDuration,
    required this.trimStart,
    required this.trimEnd,
    required this.onChanged,
  });

  final Duration totalDuration;
  final Duration trimStart;
  final Duration trimEnd;
  final void Function(Duration start, Duration end) onChanged;

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalSec = totalDuration.inSeconds.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.publishTrimVideo,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_fmt(trimStart),
                style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 11,
                    color: AppColors.textSecondary)),
            Expanded(
              child: RangeSlider(
                values: RangeValues(
                  trimStart.inSeconds.toDouble(),
                  trimEnd.inSeconds == 0
                      ? totalSec
                      : trimEnd.inSeconds.toDouble(),
                ),
                min: 0,
                max: totalSec,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.border,
                onChanged: (v) => onChanged(
                  Duration(seconds: v.start.round()),
                  Duration(seconds: v.end.round()),
                ),
              ),
            ),
            Text(
              _fmt(trimEnd.inSeconds == 0 ? totalDuration : trimEnd),
              style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 11,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Thumbnail selector ────────────────────────────────────────────────────────

class _ThumbnailSelector extends StatelessWidget {
  const _ThumbnailSelector({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.publishThumbnail,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: Row(
            children: [
              // 3 auto-generated frames
              ...List.generate(3, (i) {
                final selected = i == selectedIndex;
                return GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 56,
                    height: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary, size: 20)
                        : null,
                  ),
                );
              }),
              // Custom thumbnail button
              GestureDetector(
                onTap: () => onChanged(3),
                child: Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selectedIndex == 3
                            ? AppColors.primary
                            : AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.publishThumbnailCustom,
                        style: const TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: 9,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Bible verse preview (résout la référence → texte SQLite local) ────────────

class _BibleVersePreview extends ConsumerWidget {
  const _BibleVersePreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verseRef  = ref.watch(bibleVerseRefProvider);
    if (verseRef == null) return const SizedBox.shrink();

    final textAsync = ref.watch(bibleVerseTextProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  verseRef.displayRef,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            textAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (text) => text != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '«$text»',
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary,
                          height: 1.55,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared helpers
// =============================================================================

InputDecoration _inputDecoration({
  required String hint,
  Widget? prefixIcon,
  String? counterText,
  EdgeInsetsGeometry? contentPadding,
}) {
  const radius = BorderRadius.all(Radius.circular(AppRadius.field));
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      fontFamily: AppFonts.family,
      fontSize: 14,
      color: AppColors.textSecondary,
    ),
    prefixIcon: prefixIcon,
    counterText: counterText ?? '',
    counterStyle: const TextStyle(
      fontFamily: AppFonts.family,
      fontSize: 11,
      color: AppColors.textSecondary,
    ),
    isDense: true,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.inputBorder),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.inputBorder),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    filled: true,
    fillColor: AppColors.surface,
  );
}

const TextStyle _inputTextStyle = TextStyle(
  fontFamily: AppFonts.family,
  fontSize: 14,
  color: AppColors.textPrimary,
);
