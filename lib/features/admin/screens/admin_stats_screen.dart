import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';

// =============================================================================
// AdminStatsScreen — Charts and analytics
//
// Widget tree:
//   ListView
//     _ChartCard("Témoignages par semaine")  → _BarChartPlaceholder
//     _ChartCard("Croissance mensuelle")      → _LineChartPlaceholder
//     _ChartCard("Répartition par catégorie") → _PieChartPlaceholder
//     _TopCategoriesList
// =============================================================================

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(adminCategoriesProvider);
    final sorted = [...categories]
      ..sort((a, b) => b.testimonyCount.compareTo(a.testimonyCount));
    final top5 = sorted.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Weekly bar chart ─────────────────────────────────────────────────
        _ChartCard(
          title: 'Témoignages cette semaine',
          subtitle: 'Soumis vs approuvés',
          child: _BarChartPlaceholder(
            bars: const [
              _Bar('Lun', 8, 6),
              _Bar('Mar', 12, 10),
              _Bar('Mer', 7, 5),
              _Bar('Jeu', 15, 13),
              _Bar('Ven', 11, 9),
              _Bar('Sam', 6, 4),
              _Bar('Dim', 4, 4),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Monthly line chart ───────────────────────────────────────────────
        _ChartCard(
          title: 'Croissance mensuelle',
          subtitle: 'Nouveaux utilisateurs — 6 derniers mois',
          child: _LineChartPlaceholder(
            points: const [320, 410, 375, 490, 520, 620],
            labels: const ['Déc', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai'],
          ),
        ),
        const SizedBox(height: 16),
        // ── Pie chart ────────────────────────────────────────────────────────
        _ChartCard(
          title: 'Répartition par catégorie',
          subtitle: 'Top 5 catégories les plus actives',
          child: _PieChartPlaceholder(top5: top5),
        ),
        const SizedBox(height: 16),
        // ── Top categories list ──────────────────────────────────────────────
        _TopCategoriesTable(categories: top5),
      ],
    );
  }
}

// ─── Chart card wrapper ───────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Bar chart placeholder ────────────────────────────────────────────────────

class _Bar {
  const _Bar(this.label, this.submitted, this.approved);
  final String label;
  final int submitted;
  final int approved;
}

class _BarChartPlaceholder extends StatelessWidget {
  const _BarChartPlaceholder({required this.bars});
  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    final maxVal = bars
        .map((b) => b.submitted)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.map((bar) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Stacked bars
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Submitted (background)
                      Container(
                        height: 110 * (bar.submitted / maxVal),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8).withAlpha(25),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      // Approved (foreground)
                      Container(
                        height: 110 * (bar.approved / maxVal),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B21A8),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bar.label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Line chart placeholder ───────────────────────────────────────────────────

class _LineChartPlaceholder extends StatelessWidget {
  const _LineChartPlaceholder({
    required this.points,
    required this.labels,
  });

  final List<double> points;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final h = 110.0;

    return SizedBox(
      height: 140,
      child: Column(
        children: [
          SizedBox(
            height: h,
            child: CustomPaint(
              painter: _LineChartPainter(points: points, maxVal: maxVal),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: labels
                .map((l) => Text(l,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFF64748B))))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.points, required this.maxVal});
  final List<double> points;
  final double maxVal;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF6B21A8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF6B21A8).withAlpha(60),
          const Color(0xFF6B21A8).withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final step = size.width / (points.length - 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - (points[i] / maxVal) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo((points.length - 1) * step, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw dots
    final dotPaint = Paint()
      ..color = const Color(0xFF6B21A8)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - (points[i] / maxVal) * size.height;
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Pie chart placeholder ────────────────────────────────────────────────────

class _PieChartPlaceholder extends StatelessWidget {
  const _PieChartPlaceholder({required this.top5});
  final List<dynamic> top5;

  static const _colors = [
    Color(0xFF6B21A8),
    Color(0xFFA855F7),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
  ];

  @override
  Widget build(BuildContext context) {
    final total = top5.fold<int>(
        0, (sum, c) => sum + (c.testimonyCount as int));

    return SizedBox(
      height: 120,
      child: Row(
        children: [
          // Pie visual
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _PiePainter(
                values: top5
                    .map<double>(
                        (c) => (c.testimonyCount as int) / total)
                    .toList(),
                colors: _colors,
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                top5.length,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colors[i % _colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          top5[i].name as String,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${((top5[i].testimonyCount as int) / total * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    var startAngle = -3.14159 / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep;
    }

    // Donut hole
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Top categories table ─────────────────────────────────────────────────────

class _TopCategoriesTable extends StatelessWidget {
  const _TopCategoriesTable({required this.categories});
  final List<dynamic> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(
        0, (sum, c) => sum + (c.testimonyCount as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top catégories',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(categories.length, (i) {
            final cat = categories[i];
            final pct = (cat.testimonyCount as int) / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.name as String,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        '${cat.testimonyCount} témoignages',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6B21A8)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
