// Temps de prière immersif : « Je prie » sur une requête de prière ou sur un
// témoignage ouvre cet écran plein écran (sujet, compte à rebours de 5 minutes
// lancé d'office). Le serveur est prévenu du début (POST …/pray/start) et
// refuse « Je prie » avant la fin (docs serveur fonctionnalites/temps-de-priere.md).
// La prière ne peut être validée — « J'ai prié pour… » coché —
// qu'une fois les 5 minutes écoulées. Le temps ne court que lorsque l'écran
// est affiché (application au premier plan) ; l'écran reste allumé.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/mention_text.dart';
import '../models/prayer_models.dart';

/// Durée du temps de prière avant de pouvoir valider.
const Duration kPrayerFocusDuration = Duration(minutes: 5);

/// Ce pour quoi on prie : une requête de prière ou un témoignage.
class PrayerFocusSubject {
  const PrayerFocusSubject({
    required this.body,
    required this.authorName,
    required this.label,
    required this.confirmLabel,
    this.title,
    this.subtitle,
    this.mentions = const [],
    this.onStart,
  });

  /// Requête de prière : son texte.
  factory PrayerFocusSubject.request(PrayerRequest r, {Future<void> Function()? onStart}) => PrayerFocusSubject(
        body: r.body,
        mentions: r.mentions,
        authorName: r.authorName,
        label: L10n.current.prayerFocusSubject,
        confirmLabel: L10n.current.prayerFocusConfirm,
        onStart: onStart,
      );

  final String? title;

  /// Sous le titre de l'écran ; par défaut « Avec {auteur}, présentez ce besoin à Dieu ».
  final String? subtitle;
  final String body;
  final List<MentionRef> mentions;
  final String authorName;

  /// « Sujet de prière » / « Témoignage ».
  final String label;

  /// « J'ai prié pour cette requête » / « … pour ce témoignage ».
  final String confirmLabel;

  /// Début du temps de prière signalé au serveur (erreurs ignorées : le serveur
  /// redira son refus à la validation).
  final Future<void> Function()? onStart;
}

/// Ouvre le temps de prière ; `true` si la personne a prié jusqu'au bout et validé.
Future<bool> openPrayerFocusFor(BuildContext context, PrayerFocusSubject subject) async {
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PrayerFocusScreen(subject: subject),
    ),
  );
  return ok ?? false;
}

/// Temps de prière pour une requête de prière.
Future<bool> openPrayerFocus(BuildContext context, PrayerRequest request, {Future<void> Function()? onStart}) =>
    openPrayerFocusFor(context, PrayerFocusSubject.request(request, onStart: onStart));

class PrayerFocusScreen extends StatefulWidget {
  PrayerFocusScreen({
    PrayerFocusSubject? subject,
    PrayerRequest? request,
    this.duration = kPrayerFocusDuration,
    this.keepScreenOn = true,
    super.key,
  })  : assert(subject != null || request != null),
        subject = subject ?? PrayerFocusSubject.request(request!);

  final PrayerFocusSubject subject;
  final Duration duration;

  /// Désactivé dans les tests (pas de plugin).
  final bool keepScreenOn;

  @override
  State<PrayerFocusScreen> createState() => _PrayerFocusScreenState();
}

class _PrayerFocusScreenState extends State<PrayerFocusScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Temps de prière déjà passé (hors périodes en arrière-plan).
  Duration _elapsed = Duration.zero;
  DateTime? _runningSince;
  Timer? _ticker;
  bool _confirmed = false;
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);

  Duration get _total {
    final since = _runningSince;
    return since == null ? _elapsed : _elapsed + clock.now().difference(since);
  }

  bool get _done => _total >= widget.duration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final onStart = widget.subject.onStart;
    if (onStart != null) unawaited(onStart().catchError((Object _) {}));
    _start();
    if (widget.keepScreenOn) unawaited(WakelockPlus.enable().catchError((_) {}));
  }

  void _start() {
    _runningSince ??= clock.now();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _pause() {
    final since = _runningSince;
    if (since != null) _elapsed += clock.now().difference(since);
    _runningSince = null;
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    if (!mounted) return;
    if (_done) {
      _pause();
      _elapsed = widget.duration;
      unawaited(HapticFeedback.mediumImpact());
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_done) return;
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _breath.dispose();
    if (widget.keepScreenOn) unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }

  /// « 04:59 » : secondes arrondies au-dessus (le décompte affiche 05:00 au départ).
  String _format(Duration d) {
    final s = ((d.inMilliseconds + 999) ~/ 1000).clamp(0, 359999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.subject;
    final remaining = widget.duration - _total;
    final progress = (_total.inMilliseconds / widget.duration.inMilliseconds).clamp(0.0, 1.0);
    final done = _done;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1B3F), AppColors.primaryDark, Color(0xFF241A4A)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: l10n.prayerFocusLeave,
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      children: [
                        Text(
                          l10n.prayerFocusTitle,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.subtitle ?? l10n.prayerFocusFor(r.authorName),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        // Compte à rebours, cercle qui « respire ».
                        AnimatedBuilder(
                          animation: _breath,
                          builder: (context, child) => Transform.scale(
                            scale: done ? 1 : 0.96 + 0.04 * Curves.easeInOut.transform(_breath.value),
                            child: child,
                          ),
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 7,
                                  backgroundColor: Colors.white12,
                                  color: done ? AppColors.sun : AppColors.secondary,
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(done ? Icons.check_circle_rounded : Icons.volunteer_activism_rounded,
                                          color: done ? AppColors.sun : Colors.white70, size: 28),
                                      const SizedBox(height: 6),
                                      Semantics(
                                        liveRegion: true,
                                        label: done
                                            ? l10n.prayerFocusDone
                                            : l10n.prayerFocusRemaining(_format(remaining)),
                                        excludeSemantics: true,
                                        child: Text(
                                          _format(done ? Duration.zero : remaining),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Sujet de prière.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(18),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.label,
                                  style: AppTextStyles.labelMedium.copyWith(
                                      color: AppColors.sun, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              if (r.title != null && r.title!.trim().isNotEmpty) ...[
                                Text(r.title!,
                                    style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                              ],
                              MentionText(
                                r.body,
                                mentions: r.mentions,
                                mentionStyle: const TextStyle(color: AppColors.sun, fontWeight: FontWeight.w700),
                                style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.prayerVerseJames,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white60, fontStyle: FontStyle.italic, height: 1.5),
                        ),
                        const SizedBox(height: 4),
                        Text(l10n.prayerFocusVerseRef, // Jacques 5:16
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white38)),
                      ],
                    ),
                  ),
                ),
                // Validation : seulement après les 5 minutes.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!done)
                        Text(
                          l10n.prayerFocusWait,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
                        )
                      else
                        Theme(
                          data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white70),
                          child: CheckboxListTile(
                            value: _confirmed,
                            onChanged: (v) => setState(() => _confirmed = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.sun,
                            checkColor: AppColors.primaryDark,
                            side: const BorderSide(color: Colors.white70, width: 1.5),
                            contentPadding: EdgeInsets.zero,
                            title: Text(r.confirmLabel,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: done && _confirmed ? () => Navigator.of(context).pop(true) : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.sun,
                          foregroundColor: AppColors.primaryDark,
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white38,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: Icon(done ? Icons.check_rounded : Icons.hourglass_top_rounded),
                        label: Text(l10n.prayerFocusValidate),
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
