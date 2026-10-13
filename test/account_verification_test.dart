// Vérification des comptes personnels : modèle, validation du formulaire,
// envoi, états de l'écran et mise en page (320 / 390 px, ×1,3) sans débordement.
// Voir docs/fonctionnalites/verification-des-comptes.md (dépôt Laravel).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/admin/screens/admin_verifications_screen.dart';
import 'package:testi_app/features/auth/providers/auth_notifier.dart';
import 'package:testi_app/features/notifications/models/notification_models.dart';
import 'package:testi_app/features/notifications/providers/notifications_provider.dart';
import 'package:testi_app/features/profile/models/account_verification.dart';
import 'package:testi_app/features/profile/providers/account_verification_provider.dart';
import 'package:testi_app/features/profile/screens/account_verification_screen.dart';
import 'package:testi_app/shared/models/user_model.dart';
import 'package:testi_app/shared/widgets/organization_badge.dart';

const _longChurch = 'Église Évangélique Internationale de la Restauration et du Réveil de Cotonou';

Map<String, dynamic> _json(String status, {bool canRequest = false, String? reason, String? block}) => {
      'status': status,
      'isVerified': status == 'verified',
      'canRequest': canRequest,
      'blockReason': block,
      'reason': reason,
      'request': status == 'none'
          ? null
          : {
              'id': 'r1',
              'status': status == 'verified' ? 'approved' : status,
              'fullName': 'Jean-Baptiste Kossivi Adjovi de la Grâce Éternelle',
              'role': 'ministry_leader',
              'roleLabel': 'Responsable de ministère',
              'church': _longChurch,
              'links': ['https://youtube.com/@pasteur'],
              'documentCount': 2,
              'createdAt': '2026-10-07T10:00:00+00:00',
            },
      'roles': [
        {'value': 'pastor', 'label': 'Pasteur'},
        {'value': 'evangelist', 'label': 'Évangéliste'},
        {'value': 'singer', 'label': 'Chantre'},
        {'value': 'ministry_leader', 'label': 'Responsable de ministère'},
        {'value': 'public_figure', 'label': 'Personnalité publique'},
        {'value': 'other', 'label': 'Autre'},
      ],
      'limits': {'maxDocuments': 3, 'maxDocumentKb': 8192, 'maxLinks': 3},
    };

AccountVerificationState _state(String status, {bool canRequest = false, String? reason, String? block}) =>
    AccountVerificationState.fromJson(_json(status, canRequest: canRequest, reason: reason, block: block));

final _doc = VerificationDocument(name: 'piece-identite.jpg', size: 120000, bytes: Uint8List(4));

class _FakeRepo implements AccountVerificationRepository {
  final calls = <Map<String, Object?>>[];

  @override
  Future<AccountVerificationState> fetch() async => _state('none', canRequest: true);

  @override
  Future<AccountVerificationState> submit({
    required String fullName,
    required String role,
    String? roleOther,
    required String church,
    List<String> links = const [],
    String? message,
    required List<VerificationDocument> documents,
  }) async {
    calls.add({'fullName': fullName, 'role': role, 'church': church, 'links': links, 'documents': documents.length});
    return _state('pending');
  }
}

Widget _screen(AccountVerificationState state, {double textScale = 1.0, UserModel? user}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserProvider.overrideWithValue(user),
        accountVerificationProvider.overrideWith((ref) async => state),
      ],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: const AccountVerificationScreen(),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('modèle', () {
    test('état renvoyé par l\'API', () {
      final s = _state('rejected', reason: 'Pièce illisible', block: 'Vous pourrez…');
      expect(s.status, AccountVerificationStatus.rejected);
      expect(s.reason, 'Pièce illisible');
      expect(s.canRequest, isFalse);
      expect(s.request?.documentCount, 2);
      expect(s.roles, hasLength(6));
      expect(AccountVerificationStatus.fromJson('inconnu'), AccountVerificationStatus.none);
    });

    test('validation du formulaire', () {
      final errors = validateVerificationForm(
        fullName: ' ',
        role: null,
        roleOther: '',
        church: '',
        links: ['pas-un-lien', ''],
        documents: const [],
      );
      expect(errors.keys, containsAll(['full_name', 'role', 'church', 'links.0', 'documents']));
      expect(errors.containsKey('links.1'), isFalse);

      expect(
        validateVerificationForm(
            fullName: 'Jean Adjovi', role: 'other', roleOther: '', church: 'Église', links: const [], documents: [_doc]),
        {'role_other': 'Précisez votre fonction.'},
      );
      expect(
        validateVerificationForm(
            fullName: 'Jean Adjovi',
            role: 'pastor',
            roleOther: '',
            church: 'Église',
            links: ['https://eglise.org'],
            documents: [_doc]),
        isEmpty,
      );
    });

    test('pièces refusées avant l\'envoi', () {
      expect(verificationDocumentRejection(const VerificationDocument(name: 'a.exe', size: 10)), isNotNull);
      expect(verificationDocumentRejection(const VerificationDocument(name: 'a.PDF', size: 10)), isNull);
      expect(verificationDocumentRejection(const VerificationDocument(name: 'a.jpg', size: 9 * 1024 * 1024)), isNotNull);
    });

    test('notifications de vérification du compte', () {
      final ok = notificationFromJson({
        'id': 'n1',
        'type': 'account_verified',
        'message': 'Votre compte est vérifié.',
        'createdAt': '2026-10-07T10:00:00+00:00',
      })!;
      expect(ok.type, NotificationType.accountVerified);
      expect(ok.title, 'Compte vérifié');
      expect(ok.isSystemType, isTrue);
      final ko = notificationFromJson({
        'id': 'n2',
        'type': 'account_verification_rejected',
        'message': 'Votre demande de vérification a été refusée : pièce illisible.',
        'createdAt': '2026-10-07T10:00:00+00:00',
      })!;
      expect(ko.type, NotificationType.accountVerificationRejected);
      expect(ko.body, contains('pièce illisible'));
    });
  });

  testWidgets('badge : « Compte vérifié » pour une personne, « Organisation vérifiée » sinon', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Row(children: [
        OrganizationBadge(isOrganization: false, isVerified: true),
        OrganizationBadge(isOrganization: true, isVerified: true),
      ]),
    ));
    expect(find.byTooltip('Compte vérifié'), findsOneWidget);
    expect(find.byTooltip('Organisation vérifiée'), findsOneWidget);
  });

  group('écran', () {
    testWidgets('organisation : renvoyée vers son profil', (tester) async {
      await tester.pumpWidget(_screen(_state('none', canRequest: true),
          user: const UserModel(id: 'o', accountType: AccountType.organization)));
      await tester.pumpAndSettle();
      expect(find.text('Compte organisation'), findsOneWidget);
      expect(find.byKey(const ValueKey('verification-submit')), findsNothing);
    });

    testWidgets('états : en attente, vérifié, refusé avec motif', (tester) async {
      await tester.pumpWidget(_screen(_state('pending')));
      await tester.pumpAndSettle();
      expect(find.text('Demande en cours d’examen'), findsOneWidget);
      expect(find.text('Votre demande'), findsOneWidget);
      expect(find.byKey(const ValueKey('verification-submit')), findsNothing);

      await tester.pumpWidget(_screen(_state('verified')));
      await tester.pumpAndSettle();
      expect(find.text('Votre compte est vérifié'), findsOneWidget);

      await tester.pumpWidget(_screen(_state('rejected', canRequest: true, reason: 'Pièce illisible')));
      await tester.pumpAndSettle();
      expect(find.text('Demande refusée'), findsOneWidget);
      expect(find.textContaining('Motif : Pièce illisible'), findsOneWidget);
      expect(find.byKey(const ValueKey('verification-submit')), findsOneWidget);
    });

    testWidgets('validation : champs obligatoires signalés, rien n\'est envoyé', (tester) async {
      final repo = _FakeRepo();
      tester.view.physicalSize = const Size(390 * 2, 5000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          accountVerificationProvider.overrideWith((ref) async => _state('none', canRequest: true)),
          accountVerificationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AccountVerificationScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('verification-submit')));
      await tester.pump();
      expect(find.text('Indiquez votre nom complet.'), findsOneWidget);
      expect(find.text('Choisissez votre fonction.'), findsOneWidget);
      expect(find.text('Indiquez votre église ou votre ministère.'), findsOneWidget);
      expect(find.text('Ajoutez au moins une pièce justificative.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('envoi : demande transmise avec ses pièces', (tester) async {
      final repo = _FakeRepo();
      tester.view.physicalSize = const Size(390 * 2, 5000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          accountVerificationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VerificationRequestForm(
                state: _state('none', canRequest: true),
                initialName: 'Jean Adjovi',
                initialDocuments: [_doc],
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('role-singer')));
      await tester.enterText(find.widgetWithText(TextField, 'Église de la Grâce, Cotonou'), 'Église de la Grâce');
      await tester.enterText(find.widgetWithText(TextField, 'https://'), 'https://youtube.com/@jean');
      await tester.tap(find.byKey(const ValueKey('verification-submit')));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single['fullName'], 'Jean Adjovi');
      expect(repo.calls.single['role'], 'singer');
      expect(repo.calls.single['church'], 'Église de la Grâce');
      expect(repo.calls.single['documents'], 1);
      expect(find.text('Demande envoyée. Vous serez prévenu dans vos notifications.'), findsOneWidget);
    });
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final status in ['none', 'pending', 'verified', 'rejected']) {
        testWidgets('mise en page « $status » sans débordement ($width px, ×$scale)', (tester) async {
          tester.view.physicalSize = Size(width * 2, 7000);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_screen(
            _state(status, canRequest: status == 'none' || status == 'rejected', reason: 'Pièce illisible : $_longChurch'),
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          if (status == 'none') {
            // Erreurs affichées : la mise en page doit tenir aussi.
            await tester.tap(find.byKey(const ValueKey('verification-submit')));
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('pièce choisie : nom long sans débordement (320 px, ×1,3)', (tester) async {
    tester.view.physicalSize = const Size(640, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: c!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerificationRequestForm(
              state: _state('none', canRequest: true),
              initialDocuments: [
                VerificationDocument(name: 'lettre-de-recommandation-$_longChurch.pdf', size: 7900000, bytes: Uint8List(1)),
                _doc,
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets("administration : détail d'une demande sans débordement ($width px, ×1.3)", (tester) async {
      tester.view.physicalSize = Size(width * 2, 6000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final request = AdminVerificationRequest.fromJson({
        'id': 'r1',
        'status': 'pending',
        'statusLabel': 'En attente',
        'fullName': 'Jean-Baptiste Kossivi Adjovi de la Grâce Éternelle',
        'roleLabel': 'Responsable de ministère',
        'church': _longChurch,
        'links': ['https://www.youtube.com/@une-chaine-au-nom-tres-long-pour-le-test'],
        'message': 'Merci.',
        'user': {'id': 'u1', 'displayName': 'Jean', 'email': 'jean.adjovi.tres.long@ministere-lumiere.org'},
        'documents': [
          {'index': 0, 'name': 'identite.jpg', 'isImage': true},
          {'index': 1, 'name': 'lettre-$_longChurch.pdf', 'isImage': false},
        ],
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          adminVerificationProvider('r1').overrideWith((ref) async => request),
          adminVerificationDocumentProvider(('r1', 0)).overrideWith((ref) async => Uint8List(0)),
        ],
        child: MaterialApp(
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: c!,
          ),
          home: const AdminVerificationDetailScreen(requestId: 'r1'),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Approuver'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
      // Image vide : l'erreur de décodage est attendue, seul le débordement compte.
      final error = tester.takeException();
      expect(error == null || '$error'.contains('image') || '$error'.contains('Image'), isTrue, reason: '$error');
    });
  }
}
