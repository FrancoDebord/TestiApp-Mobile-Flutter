import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testi_app/core/data/countries.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/widgets/country_picker.dart';

void main() {
  test('liste identique au site : 204 pays, noms et indicatifs', () {
    expect(kCountries.length, 204);
    expect(countryByName("Côte d'Ivoire")?.dial, '225');
    expect(countryByName('Congo (RDC)')?.code, 'cd');
    expect(countryByCode('BJ')?.name, 'Bénin');
    expect(countryByName('Atlantide'), isNull);
    expect(kCountries.map((c) => c.code).toSet().length, 204, reason: 'codes uniques');
  });

  test('drapeau formé à partir du code ISO', () {
    expect(countryByCode('bj')!.flag, '🇧🇯');
    expect(countryByCode('ci')!.dialLabel, '+225');
  });

  test('recherche sans accents, par nom ou indicatif', () {
    expect(searchCountries('cote').first.name, "Côte d'Ivoire");
    expect(searchCountries('benin').first.name, 'Bénin');
    expect(searchCountries('+229').first.name, 'Bénin');
    // Ceux qui commencent par la saisie d'abord.
    final be = searchCountries('be').map((c) => c.name).toList();
    expect(be.take(3), ['Belgique', 'Belize', 'Bénin']);
    expect(searchCountries('xyz'), isEmpty);
    expect(searchCountries(''), hasLength(204));
  });

  test('contrôle du numéro avant envoi', () {
    final bj = countryByCode('bj');
    expect(PhoneNumberField.check(bj, '01 97 12 34 56', required: true), isNull);
    expect(PhoneNumberField.check(bj, '', required: false), isNull);
    expect(PhoneNumberField.check(bj, '', required: true), 'Le numéro de téléphone est obligatoire.');
    expect(PhoneNumberField.check(null, '0197123456', required: false), 'Choisissez l\'indicatif du pays.');
    expect(PhoneNumberField.check(bj, 'abc', required: false), 'Numéro de téléphone invalide.');
    expect(PhoneNumberField.check(bj, '12', required: false), 'Numéro de téléphone invalide.');
  });

  test('numéro enregistré réaffiché sans indicatif', () {
    expect(PhoneNumberField.nationalPart('+2290197123456', countryByCode('bj')), '0197123456');
    expect(PhoneNumberField.nationalPart('+33612345678', countryByCode('bj')), '+33612345678');
  });

  test('UserModel lit indicatif et vérification', () {
    final u = UserModel.fromJson({
      'id': 'u1', 'display_name': 'Awa', 'phone': '+2290197123456',
      'phone_country': 'bj', 'is_phone_verified': true,
    });
    expect(u.phoneCountry, 'bj');
    expect(u.isPhoneVerified, isTrue);
    final back = UserModel.fromJson(u.toJson());
    expect(back.phoneCountry, 'bj');
    expect(back.isPhoneVerified, isTrue);

    // Profil d'une autre personne : coordonnées absentes (null) côté serveur.
    final other = UserModel.fromJson({'id': 'u2', 'display_name': 'X', 'email': null, 'phone': null});
    expect(other.phone, '');
    expect(other.isPhoneVerified, isFalse);
  });

  testWidgets('la liste des pays filtre à la saisie et renvoie le choix', (tester) async {
    Country? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showCountryPicker(context, withDial: true),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cote');
    await tester.pumpAndSettle();
    expect(find.text("Côte d'Ivoire"), findsOneWidget);
    expect(find.text('+225'), findsOneWidget);

    await tester.tap(find.text("Côte d'Ivoire"));
    await tester.pumpAndSettle();
    expect(picked?.code, 'ci');
  });

  testWidgets('champ pays + téléphone : l\'indicatif suit le pays choisi', (tester) async {
    final phone = TextEditingController();
    Country? dial;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ListView(
            children: [
              CountryPickerField(onChanged: (c) => setState(() => dial = c)),
              PhoneNumberField(dial: dial, onDialChanged: (c) => setState(() => dial = c), controller: phone),
            ],
          ),
        ),
      ),
    ));
    expect(find.text('Indicatif'), findsOneWidget);

    await tester.tap(find.text('Sélectionnez votre pays'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'benin');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bénin').last);
    await tester.pumpAndSettle();

    expect(find.text('🇧🇯 +229'), findsOneWidget);
    phone.dispose();
  });
}
