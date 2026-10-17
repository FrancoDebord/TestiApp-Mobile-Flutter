// lib/features/daily_verse/design/verse_style_prefs.dart
//
// Style du verset du jour choisi par l'utilisateur : design, police, taille,
// alignement. Appliqué à la carte de l'accueil et au plein écran.
// shared_preferences pour tous ; synchronisé avec le serveur pour un membre
// connecté (GET · PUT /me/verse-style), voir [VerseStylePrefsNotifier].
//
// Design affiché : celui choisi par l'utilisateur le jour même (ou toujours,
// avec « Toujours utiliser mon design »), sinon le design donné par le serveur
// (effective_design_id / design_of_the_day), sinon le design du jour calculé
// localement (secours hors connexion).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../auth/providers/auth_notifier.dart' show AuthState, AuthStateAuthenticated, AuthStateUnauthenticated, authStateProvider;
import '../../home/providers/home_providers.dart' show dailyVerseProvider;
import 'verse_design.dart';
import 'verse_design_catalog.dart';

/// Police du texte du verset (embarquées : assets/fonts).
enum VerseFont {
  lora('Lora', 'Lora', serif: true), // i18n-ignore : nom de police
  sourceSerif('Source Serif 4', 'Source Serif', serif: true), // i18n-ignore : nom de police
  inter('Inter', 'Inter', serif: false), // i18n-ignore : nom de police
  nunitoSans('Nunito Sans', 'Nunito Sans', serif: false); // i18n-ignore : nom de police

  const VerseFont(this.family, this.label, {required this.serif});

  final String family;
  final String label;
  final bool serif;
}

/// Taille du texte : multiplie la taille calculée (sans passer sous le minimum).
enum VerseTextSize {
  small(0.86),
  medium(1.0),
  large(1.16);

  const VerseTextSize(this.factor);

  final double factor;

  String get label => switch (this) {
        VerseTextSize.small => L10n.current.verseSizeSmall,
        VerseTextSize.medium => L10n.current.verseSizeMedium,
        VerseTextSize.large => L10n.current.verseSizeLarge,
      };
}

enum VerseAlign {
  start(TextAlign.left, Icons.format_align_left_rounded),
  center(TextAlign.center, Icons.format_align_center_rounded);

  const VerseAlign(this.textAlign, this.icon);

  final TextAlign textAlign;
  final IconData icon;

  String get label => switch (this) {
        VerseAlign.start => L10n.current.verseAlignLeft,
        VerseAlign.center => L10n.current.verseAlignCenter,
      };
}

/// Préférences de style du verset.
@immutable
class VerseStylePrefs {
  const VerseStylePrefs({
    this.designId,
    this.chosenOn,
    this.alwaysMine = false,
    this.font = VerseFont.lora,
    this.size = VerseTextSize.medium,
    this.align = VerseAlign.start,
  });

  /// Design choisi (null : design du jour).
  final String? designId;

  /// Jour du choix (aaaa-mm-jj) : le choix vaut jusqu'au lendemain.
  final String? chosenOn;

  /// « Toujours utiliser mon design ».
  final bool alwaysMine;
  final VerseFont font;
  final VerseTextSize size;
  final VerseAlign align;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Le choix de l'utilisateur vaut le jour [today] (aaaa-mm-jj) et le design
  /// fait partie de [available].
  bool isUserChoice(String today, {List<VerseDesign> available = const []}) {
    final mine = verseDesignById(designId);
    if (mine == null) return false;
    if (available.isNotEmpty && !available.contains(mine)) return false;
    return alwaysMine || chosenOn == today;
  }

  /// Design affiché le jour [now] (en local, sans le serveur).
  VerseDesign designFor(DateTime now) => resolveDesign(now: now);

  /// Design affiché : le choix de l'utilisateur s'il vaut aujourd'hui ; sinon le
  /// design indiqué par le serveur ([serverDesignId] : effective_design_id pour
  /// un membre, design_of_the_day pour un visiteur) s'il est connu de
  /// l'application et proposé ; sinon le design du jour calculé localement
  /// (secours hors connexion).
  VerseDesign resolveDesign({
    required DateTime now,
    List<VerseDesign> available = const [],
    String? serverDesignId,
  }) {
    final day = verseDay(now);
    if (isUserChoice(dayKey(day), available: available)) return verseDesignById(designId)!;
    final server = verseDesignById(serverDesignId);
    if (server != null && (available.isEmpty || available.contains(server))) return server;
    return dailyVerseDesign(day);
  }

  /// Valeurs envoyées à PUT /me/verse-style (noms d'enum de l'application).
  Map<String, dynamic> toApiJson() => {
        'design_id': designId,
        'design_chosen_on': designId == null || (chosenOn ?? '').isEmpty ? null : chosenOn,
        'design_always': alwaysMine,
        'font': font.name,
        'text_size': size.name,
        'text_align': align.name,
      };

  /// Lit `user_style` (ressource du verset) ou GET /me/verse-style ; une valeur
  /// inconnue reprend la valeur par défaut.
  factory VerseStylePrefs.fromApiJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    final id = j['design_id'] as String?;
    return VerseStylePrefs(
      designId: id == null || id.isEmpty ? null : id,
      chosenOn: j['design_chosen_on'] as String?,
      alwaysMine: j['design_always'] == true || j['design_always'] == 1,
      font: pick(VerseFont.values, j['font'], VerseFont.lora),
      size: pick(VerseTextSize.values, j['text_size'], VerseTextSize.medium),
      align: pick(VerseAlign.values, j['text_align'], VerseAlign.start),
    );
  }

  VerseStylePrefs copyWith({
    Object? designId = _keep,
    Object? chosenOn = _keep,
    bool? alwaysMine,
    VerseFont? font,
    VerseTextSize? size,
    VerseAlign? align,
  }) =>
      VerseStylePrefs(
        designId: designId == _keep ? this.designId : designId as String?,
        chosenOn: chosenOn == _keep ? this.chosenOn : chosenOn as String?,
        alwaysMine: alwaysMine ?? this.alwaysMine,
        font: font ?? this.font,
        size: size ?? this.size,
        align: align ?? this.align,
      );

  @override
  bool operator ==(Object other) =>
      other is VerseStylePrefs &&
      other.designId == designId &&
      other.chosenOn == chosenOn &&
      other.alwaysMine == alwaysMine &&
      other.font == font &&
      other.size == size &&
      other.align == align;

  @override
  int get hashCode => Object.hash(designId, chosenOn, alwaysMine, font, size, align);
}

const Object _keep = Object();

/// Jour du verset : date à Porto-Novo (UTC+1, sans heure d'été), comme le
/// serveur pour design_of_the_day et design_chosen_on.
DateTime verseDay(DateTime now) {
  final t = now.toUtc().add(const Duration(hours: 1));
  return DateTime(t.year, t.month, t.day);
}

/// Préférences du verset : shared_preferences pour tous ; pour un membre
/// connecté, synchronisées avec le serveur (GET · PUT /me/verse-style).
///
///   • Connexion / démarrage connecté : un changement local pas encore envoyé
///     (hors connexion, échec) part d'abord ; sinon les valeurs du serveur
///     (`user_style` du verset, ou GET /me/verse-style) remplacent le local.
///   • Changement dans le sélecteur : affichage et shared_preferences tout de
///     suite, puis PUT en arrière-plan après 1 s (changements rapides groupés).
///   • Déconnexion : préférences locales du verset effacées.
///   • Visiteur : shared_preferences uniquement.
class VerseStylePrefsNotifier extends Notifier<VerseStylePrefs> {
  static const _kDesign = 'verse_design_id';
  static const _kChosenOn = 'verse_design_chosen_on';
  static const _kAlways = 'verse_design_always';
  static const _kFont = 'verse_font';
  static const _kSize = 'verse_text_size';
  static const _kAlign = 'verse_text_align';

  /// Changement local pas encore accepté par le serveur.
  static const _kPending = 'verse_style_pending_sync';

  /// Délai de regroupement des changements avant PUT /me/verse-style.
  static const syncDelay = Duration(seconds: 1);

  /// Horloge (remplaçable dans les tests).
  DateTime Function() now = DateTime.now;

  late Future<void> _loaded;
  Timer? _debounce;
  bool _pending = false;

  /// Incrémenté à chaque changement local : une réponse du serveur arrivée
  /// après un nouveau changement ne l'écrase pas.
  int _revision = 0;

  bool get _signedIn => ref.read(authStateProvider).value is AuthStateAuthenticated;

  @override
  VerseStylePrefs build() {
    _loaded = Future.microtask(_load);
    ref.onDispose(() => _debounce?.cancel());
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      final was = prev?.value is AuthStateAuthenticated;
      final isNow = next.value is AuthStateAuthenticated;
      if (isNow && !was) unawaited(syncFromServer());
      if (was && next.value is AuthStateUnauthenticated) unawaited(clearLocal());
    }, fireImmediately: true);
    return const VerseStylePrefs();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
          values.firstWhere((v) => v.name == name, orElse: () => fallback);
      _pending = p.getBool(_kPending) ?? false;
      final chosenOn = p.getString(_kChosenOn);
      state = VerseStylePrefs(
        designId: p.getString(_kDesign),
        chosenOn: chosenOn == null || chosenOn.isEmpty ? null : chosenOn,
        alwaysMine: p.getBool(_kAlways) ?? false,
        font: pick(VerseFont.values, p.getString(_kFont), VerseFont.lora),
        size: pick(VerseTextSize.values, p.getString(_kSize), VerseTextSize.medium),
        align: pick(VerseAlign.values, p.getString(_kAlign), VerseAlign.start),
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = state;
      if (s.designId == null) {
        await p.remove(_kDesign);
        await p.remove(_kChosenOn);
      } else {
        await p.setString(_kDesign, s.designId!);
        await p.setString(_kChosenOn, s.chosenOn ?? '');
      }
      await p.setBool(_kAlways, s.alwaysMine);
      await p.setString(_kFont, s.font.name);
      await p.setString(_kSize, s.size.name);
      await p.setString(_kAlign, s.align.name);
    } catch (_) {}
  }

  Future<void> _setPending(bool value) async {
    _pending = value;
    try {
      final p = await SharedPreferences.getInstance();
      value ? await p.setBool(_kPending, true) : await p.remove(_kPending);
    } catch (_) {}
  }

  /// Changement de l'utilisateur : affichage + shared_preferences tout de suite,
  /// puis envoi au serveur (membre connecté) après [syncDelay].
  void _update(VerseStylePrefs next) {
    if (next == state) return;
    state = next;
    _revision++;
    unawaited(_save());
    if (!_signedIn) return;
    unawaited(_setPending(true));
    _debounce?.cancel();
    _debounce = Timer(syncDelay, () => unawaited(_push()));
  }

  /// PUT /me/verse-style avec les valeurs locales. Échec réseau : le changement
  /// reste en attente (envoyé au prochain lancement). 422 : valeur refusée, on
  /// reprend celles du serveur.
  Future<bool> _push() async {
    final revision = _revision;
    try {
      await ref.read(apiServiceProvider).put<dynamic>(AppConstants.myVerseStyle, data: state.toApiJson());
      if (revision == _revision) await _setPending(false);
      return true;
    } on LaravelApiException catch (e) {
      if (e.statusCode == 422) {
        debugPrint('VerseStyle ✗ refusé par le serveur : ${e.displayMessage}');
        await _setPending(false);
        await _pull();
        return true;
      }
      debugPrint('VerseStyle ✗ PUT : $e');
    } catch (e) {
      debugPrint('VerseStyle ✗ PUT : $e');
    }
    return false;
  }

  /// GET /me/verse-style (ou [style] déjà reçu avec le verset) → état local.
  Future<void> _pull([Map<String, dynamic>? style]) async {
    final revision = _revision;
    try {
      style ??= (await ref.read(apiServiceProvider).get<Map<String, dynamic>>(AppConstants.myVerseStyle)).data;
    } catch (e) {
      debugPrint('VerseStyle ✗ GET : $e');
      return;
    }
    // Un changement local fait entre-temps l'emporte (il sera envoyé).
    if (revision != _revision || _pending) return;
    state = VerseStylePrefs.fromApiJson(style);
    await _save();
  }

  /// Démarrage ou connexion d'un membre : envoie d'abord un changement local
  /// en attente, sinon applique les valeurs du serveur (prioritaires).
  Future<void> syncFromServer() async {
    await _loaded;
    if (!_signedIn) return;
    if (_pending) {
      await _push();
      return;
    }
    // user_style du verset : seulement si aucun changement local n'a eu lieu
    // depuis le lancement (le verset a pu être chargé avant ce changement) ;
    // sinon GET /me/verse-style, à jour.
    Map<String, dynamic>? style;
    if (_revision == 0) {
      try {
        style = (await ref.read(dailyVerseProvider.future)).userStyle;
      } catch (_) {}
    }
    await _pull(style);
  }

  /// Déconnexion : préférences locales du verset effacées.
  Future<void> clearLocal() async {
    _debounce?.cancel();
    _revision++;
    state = const VerseStylePrefs();
    _pending = false;
    await clearStored();
  }

  /// Efface les préférences du verset de shared_preferences (appelé aussi par
  /// AuthNotifier.logout, même si ce notifier n'a pas encore été créé).
  static Future<void> clearStored() async {
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in [_kDesign, _kChosenOn, _kAlways, _kFont, _kSize, _kAlign, _kPending]) {
        await p.remove(k);
      }
    } catch (_) {}
  }

  /// Choisit [design] (valable jusqu'au lendemain, ou toujours).
  void chooseDesign(VerseDesign design) => _update(state.copyWith(
        designId: design.id,
        chosenOn: VerseStylePrefs.dayKey(verseDay(now())),
      ));

  /// Design affiché aujourd'hui, calculé ici : lire currentVerseDesignProvider
  /// depuis ce notifier, dont il dépend, lèverait une CircularDependencyError
  /// (l'option « Toujours utiliser mon design » restait alors sans effet).
  VerseDesign _displayedDesign() => state.resolveDesign(
        now: now(),
        available: ref.read(availableVerseDesignsProvider),
        serverDesignId: ref.read(serverVerseDesignIdProvider),
      );

  void setAlwaysMine(bool value) {
    // Activer l'option fige le design affiché aujourd'hui.
    final current = _displayedDesign();
    _update(state.copyWith(
      alwaysMine: value,
      designId: value ? current.id : state.designId,
      chosenOn: value ? VerseStylePrefs.dayKey(verseDay(now())) : state.chosenOn,
    ));
  }

  void setFont(VerseFont f) => _update(state.copyWith(font: f));
  void setSize(VerseTextSize s) => _update(state.copyWith(size: s));
  void setAlign(VerseAlign a) => _update(state.copyWith(align: a));
}

final verseStylePrefsProvider =
    NotifierProvider<VerseStylePrefsNotifier, VerseStylePrefs>(VerseStylePrefsNotifier.new);

/// Design serveur à afficher sans choix du jour : effective_design_id pour un
/// membre, design_of_the_day pour un visiteur (null hors connexion sans cache).
final serverVerseDesignIdProvider = Provider<String?>((ref) {
  final verse = ref.watch(dailyVerseProvider).value;
  if (verse == null) return null;
  final signedIn = ref.watch(authStateProvider).value is AuthStateAuthenticated;
  return signedIn ? (verse.effectiveDesignId ?? verse.designOfTheDay) : verse.designOfTheDay;
});

/// Design du verset affiché aujourd'hui.
final currentVerseDesignProvider = Provider<VerseDesign>((ref) {
  final prefs = ref.watch(verseStylePrefsProvider);
  return prefs.resolveDesign(
    now: ref.read(verseStylePrefsProvider.notifier).now(),
    available: ref.watch(availableVerseDesignsProvider),
    serverDesignId: ref.watch(serverVerseDesignIdProvider),
  );
});

/// Design du jour (serveur, sinon calcul local) : repère « du jour » du sélecteur.
final verseDesignOfTheDayProvider = Provider<VerseDesign>((ref) {
  final server = verseDesignById(ref.watch(dailyVerseProvider).value?.designOfTheDay);
  final available = ref.watch(availableVerseDesignsProvider);
  if (server != null && available.contains(server)) return server;
  return dailyVerseDesign(verseDay(ref.read(verseStylePrefsProvider.notifier).now()));
});
