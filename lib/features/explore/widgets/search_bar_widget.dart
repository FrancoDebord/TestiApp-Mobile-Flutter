import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/explore_providers.dart';

/// Animated search bar with real voice-search via speech_to_text.
class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  final SpeechToText _speech = SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();

    _focus.addListener(() {
      ref.read(searchBarActiveProvider.notifier).update(_focus.hasFocus);
    });

    _ctrl.addListener(() {
      ref.read(searchQueryProvider.notifier).update(_ctrl.text);
    });

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone non disponible'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isListening = true);
    _focus.unfocus();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords;
        if (text.isNotEmpty) {
          _ctrl.text = text;
          _ctrl.selection =
              TextSelection.fromPosition(TextPosition(offset: text.length));
          ref.read(searchQueryProvider.notifier).update(text);
        }
        if (result.finalResult) {
          if (mounted) setState(() => _isListening = false);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  void _clear() {
    _ctrl.clear();
    ref.read(searchQueryProvider.notifier).update('');
    _focus.unfocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _isListening
            ? AppColors.primary.withAlpha(10)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isListening
              ? AppColors.primary
              : _focus.hasFocus
                  ? AppColors.primary
                  : AppColors.border,
          width: (_isListening || _focus.hasFocus) ? 1.5 : 1,
        ),
        boxShadow: (_isListening || _focus.hasFocus)
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            _isListening ? Icons.mic_rounded : Icons.search_rounded,
            color: (_isListening || _focus.hasFocus)
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _isListening
                ? _ListeningIndicator()
                : TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    style: AppTextStyles.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un témoignage…',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textInputAction: TextInputAction.search,
                  ),
          ),
          if (!_isListening && query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textSecondary,
              onPressed: _clear,
              tooltip: 'Effacer',
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(),
            ),
          _MicButton(
            isListening: _isListening,
            onTap: _toggleVoice,
          ),
        ],
      ),
    );
  }
}

// ── Mic button ─────────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  const _MicButton({required this.isListening, required this.onTap});
  final bool isListening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isListening ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: 20,
          color: isListening ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── Pulse animation when listening ────────────────────────────────────────────

class _ListeningIndicator extends StatefulWidget {
  @override
  State<_ListeningIndicator> createState() => _ListeningIndicatorState();
}

class _ListeningIndicatorState extends State<_ListeningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: const Text(
        'Parlez maintenant…',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.primary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
