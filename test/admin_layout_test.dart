// Vérifie qu'aucune section de l'administration ne déborde sur un petit
// écran, avec une grande taille de police et des textes longs.
// Flutter signale tout débordement (RenderFlex overflowed) comme une erreur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:testi_app/features/admin/models/admin_models.dart';
import 'package:testi_app/features/admin/providers/admin_provider.dart';
import 'package:testi_app/features/admin/screens/admin_dashboard_screen.dart';
import 'package:testi_app/features/moderation/models/moderation_models.dart';
import 'package:testi_app/shared/models/user_model.dart' show UserRole;

const _longName =
    'Ministère International Lumière du Monde pour la Restauration';

final _users = [
  for (final (i, role) in UserRole.values.indexed)
    AdminUser(
      uid: 'u$i',
      displayName: '$_longName $i',
      email: 'une.adresse.tres.longue.$i@ministere-lumiere-du-monde.org',
      role: role,
      status: UserAccountStatus.values[i % 3],
      country: "République démocratique du Congo",
      joinedAt: DateTime(2026, 1, 1),
    ),
];

final _categories = [
  for (var i = 0; i < 4; i++)
    AppCategory(
      id: 'c$i',
      name: 'Protection divine et délivrance spirituelle $i',
      slug: 'protection-$i',
      order: i,
      testimonyCount: 123456 * (i + 1),
      isActive: i.isEven,
    ),
];

final _testimonies = [
  for (final (i, type) in TestimonyType.values.indexed)
    PublishedTestimony(
      id: 't$i',
      title: 'Un très long titre de témoignage pour vérifier le retour à la '
          'ligne dans la carte $i',
      authorName: _longName,
      category: 'Protection divine et délivrance',
      type: type,
      publishedAt: DateTime(2026, 9, 1),
      views: 1234567,
      likes: 987654,
    ),
];

const _metrics = AdminMetrics(
  totalUsers: 1234567,
  newUsersToday: 98765,
  totalTestimonies: 7654321,
  viewsThisMonth: 123456789,
  approvalRate: 99.9,
  pendingTestimonies: 45678,
  avgEngagement: 1234.5,
  commentsThisMonth: 9876543,
);

class _FakeUsers extends AdminUsersNotifier {
  @override
  Future<List<AdminUser>> build() async => _users;
}

class _FakeCategories extends AdminCategoriesNotifier {
  @override
  Future<List<AppCategory>> build() async => _categories;
}

class _FakeSettings extends AppSettingsNotifier {
  @override
  Future<AppSettings> build() async =>
      const AppSettings(maintenanceMode: true);
}

Widget _app({double textScale = 1.0}) => ProviderScope(
      overrides: [
        adminMetricsProvider.overrideWith((ref) async => _metrics),
        adminUsersNotifierProvider.overrideWith(_FakeUsers.new),
        adminCategoriesNotifierProvider.overrideWith(_FakeCategories.new),
        adminTestimoniesProvider.overrideWith((ref) async => _testimonies),
        appSettingsProvider.overrideWith(_FakeSettings.new),
      ],
      child: MaterialApp(
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: c!,
        ),
        home: const AdminDashboardScreen(),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final section in AdminSection.values) {
        testWidgets(
            'administration › ${section.name} sans débordement '
            '($width px, ×$scale)', (tester) async {
          // Écran haut : toute la section est construite, pas seulement le
          // début visible.
          tester.view.physicalSize = Size(width * 2, 6000);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(_app(textScale: scale));
          await tester.pump();
          ProviderScope.containerOf(
                  tester.element(find.byType(AdminDashboardScreen)))
              .read(adminSectionProvider.notifier)
              .select(section);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
