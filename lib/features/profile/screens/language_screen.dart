import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';

/// Écran 11 de la maquette : « Langue » — langue du système (par défaut),
/// Français ou English. Le choix est enregistré sur l'appareil et envoyé au
/// serveur (PUT /me { locale }) ; chaque requête porte Accept-Language.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  AppLanguage? _selected;

  Future<void> _apply() async {
    final AppLanguage current = ref.read(appLanguageProvider);
    final choice = _selected ?? current;
    await ref.read(appLanguageProvider.notifier).choose(choice);
    if (!mounted) return;
    // Message dans la nouvelle langue.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(lookupAppLocalizations(ref.read(localeProvider)).languageChanged),
      behavior: SnackBarBehavior.floating,
    ));
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appLanguageProvider);
    final selected = _selected ?? current;
    final l10n = context.l10n;
    final system = L10n.resolveSystem(ref.watch(systemLocalesProvider));
    final systemName =
        system.languageCode == 'en' ? l10n.languageEnglish : l10n.languageFrench;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsLanguage, style: AppTextStyles.h4.copyWith(fontSize: 18)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LanguageOption(
                          key: const ValueKey('language-system'),
                          flag: const _SystemIcon(),
                          label: l10n.languageSystem,
                          subtitle: l10n.languageSystemCurrent(systemName),
                          selected: selected == AppLanguage.system,
                          onTap: () => setState(() => _selected = AppLanguage.system),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LanguageOption(
                          key: const ValueKey('language-fr'),
                          flag: const _FlagFrance(),
                          label: l10n.languageFrench,
                          selected: selected == AppLanguage.fr,
                          onTap: () => setState(() => _selected = AppLanguage.fr),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LanguageOption(
                          key: const ValueKey('language-en'),
                          flag: const _FlagUk(),
                          label: l10n.languageEnglish,
                          selected: selected == AppLanguage.en,
                          onTap: () => setState(() => _selected = AppLanguage.en),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(l10n.languageHint, style: AppTextStyles.bodySmall),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: l10n.languageChange,
                          fullWidth: true,
                          onPressed: _apply,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: AppSpacing.xxl),
                  // Décor bas de page : logo + vague orange/jaune.
                  const _BottomDecoration(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemIcon extends StatelessWidget {
  const _SystemIcon();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.smartphone_rounded, size: 18, color: AppColors.primary),
      );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final Widget flag;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
            child: Row(
              children: [
                SizedBox(width: 32, height: 32, child: flag),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.inputBorder,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.primary),
            )
          : null,
    );
  }
}

// ── Drapeaux ronds dessinés (pas d'emoji : rendu identique partout) ────────

class _FlagFrance extends StatelessWidget {
  const _FlagFrance();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _FrancePainter(), size: Size.square(32));
}

class _FlagUk extends StatelessWidget {
  const _FlagUk();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _UkPainter(), size: Size.square(32));
}

abstract class _RoundFlagPainter extends CustomPainter {
  const _RoundFlagPainter();

  void paintFlag(Canvas canvas, Size size);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    paintFlag(canvas, size);
    canvas.restore();
    canvas.drawOval(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrancePainter extends _RoundFlagPainter {
  const _FrancePainter();

  @override
  void paintFlag(Canvas canvas, Size size) {
    final w = size.width / 3;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = const Color(0xFF002395));
    canvas.drawRect(Rect.fromLTWH(w, 0, w, size.height), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(2 * w, 0, w + 1, size.height), Paint()..color = const Color(0xFFED2939));
  }
}

class _UkPainter extends _RoundFlagPainter {
  const _UkPainter();

  @override
  void paintFlag(Canvas canvas, Size size) {
    const blue = Color(0xFF012169);
    const red = Color(0xFFC8102E);
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = blue);

    // Diagonales blanches puis rouges (simplifiées).
    final diagWhite = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.2;
    final diagRed = Paint()
      ..color = red
      ..strokeWidth = w * 0.07;
    for (final p in [diagWhite, diagRed]) {
      canvas.drawLine(Offset.zero, Offset(w, h), p);
      canvas.drawLine(Offset(w, 0), Offset(0, h), p);
    }

    // Croix droite blanche puis rouge.
    final white = Paint()..color = Colors.white;
    final redP = Paint()..color = red;
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: h * 0.32), white);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.32, height: h), white);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: h * 0.18), redP);
    canvas.drawRect(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.18, height: h), redP);
  }
}

// ── Décor : logo + vague orange → jaune ────────────────────────────────────

class _BottomDecoration extends StatelessWidget {
  const _BottomDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _WavePainter())),
          const Positioned(
            top: 0,
            child: ExcludeSemantics(child: AppLogo(markSize: 56, titleSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Vague jaune douce (arrière) puis orange → jaune (avant).
    final back = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.3, h * 0.55, w * 0.6, h * 0.7)
      ..quadraticBezierTo(w * 0.85, h * 0.82, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = AppColors.sunSoft);

    final front = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.35, h * 0.7, w * 0.7, h * 0.86)
      ..quadraticBezierTo(w * 0.88, h * 0.94, w, h * 0.8)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.secondary, AppColors.sun],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
