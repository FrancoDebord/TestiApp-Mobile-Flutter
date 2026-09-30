// Mise en page des écrans d'authentification (onboarding, connexion,
// inscription, mot de passe oublié) : aucun débordement sur petit écran avec
// une grande taille de police. Flutter signale tout débordement
// (RenderFlex overflowed) comme une exception.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/auth/screens/forgot_password_screen.dart';
import 'package:testi_app/features/auth/screens/login_screen.dart';
import 'package:testi_app/features/auth/screens/onboarding_screen.dart';
import 'package:testi_app/features/auth/screens/register_screen.dart';
import 'package:testi_app/shared/widgets/guest_gate.dart';

Widget _app(Widget child, {double textScale = 1.0}) => ProviderScope(
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: child,
      ),
    );

Future<void> _setPhone(WidgetTester tester, double width,
    {double height = 640}) async {
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      final tag = '($width px, ×$scale)';

      testWidgets('onboarding : toutes les diapositives $tag', (tester) async {
        await _setPhone(tester, width, height: 568);
        await tester.pumpWidget(_app(const OnboardingScreen(), textScale: scale));
        await tester.pump();
        expect(find.text('Suivant'), findsOneWidget);
        expect(find.text('Passer'), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Suivant'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Commencer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('connexion : choix et formulaire e-mail $tag',
          (tester) async {
        await _setPhone(tester, width, height: 568);
        await tester.pumpWidget(_app(const LoginScreen(), textScale: scale));
        await tester.pump();
        expect(find.text('Se connecter avec numéro'), findsOneWidget);
        expect(find.text('Se connecter avec Google'), findsOneWidget);
        expect(find.text('Mode invité'), findsOneWidget);
        expect(find.text('Continuer avec Facebook'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Se connecter avec Email'));
        await tester.tap(find.text('Se connecter avec Email'));
        await tester.pumpAndSettle();
        expect(find.text('Mot de passe oublié ?'), findsOneWidget);
        // Validation conservée.
        await tester.ensureVisible(find.text('Se connecter'));
        await tester.tap(find.text('Se connecter'));
        await tester.pump();
        expect(find.text('Veuillez saisir votre adresse e-mail'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('inscription : personne et organisation $tag',
          (tester) async {
        await _setPhone(tester, width);
        await tester.pumpWidget(_app(const RegisterScreen(), textScale: scale));
        await tester.pump();
        expect(find.text('Créer un compte'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final orgCard = find.textContaining('organisation').first;
        await tester.ensureVisible(orgCard);
        await tester.tap(orgCard);
        await tester.pumpAndSettle();
        expect(find.text("Nom de l'organisation"), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Faire défiler jusqu'en bas (bouton S'inscrire, Google, lien).
        await tester.drag(
            find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('mot de passe oublié $tag', (tester) async {
        await _setPhone(tester, width, height: 568);
        await tester.pumpWidget(
            _app(const ForgotPasswordScreen(), textScale: scale));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('feuille « compte requis » $tag', (tester) async {
        await _setPhone(tester, width, height: 568);
        await tester.pumpWidget(_app(
          const Scaffold(
            body: AccountRequiredSheet(
                reason: 'publier votre témoignage et réagir aux autres'),
          ),
          textScale: scale,
        ));
        await tester.pump();
        expect(find.text('Se connecter'), findsOneWidget);
        expect(find.text('Plus tard'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
