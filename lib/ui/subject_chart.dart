import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/school_features.dart';
import '../core/theme.dart';
import 'components.dart';

class SubjectChart extends StatelessWidget {
  final String subject;
  final List<SchoolRow> marks;
  const SubjectChart({super.key, required this.subject, required this.marks});
  @override
  Widget build(BuildContext context) {
    final sorted = [...marks]
      ..sort(
        (a, b) => (a['exam_at'] as String? ?? '').compareTo(
          b['exam_at'] as String? ?? '',
        ),
      );
    final series = sorted
        .where(
          (g) =>
              g['score'] is num &&
              g['max_score'] is num &&
              (g['max_score'] as num) > 0,
        )
        .toList();
    if (series.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: textStyle(17, weight: FontWeight.w800)),
            const SizedBox(height: 14),
            Semantics(
              label:
                  '$subject marks over time: ${series.map((g) => '${g['title'] ?? 'Assessment'} ${g['score']} out of ${g['max_score']} on ${g['exam_at'] ?? 'unpublished date'}').join('; ')}',
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _MarksPainter(
                      series
                          .map(
                            (g) =>
                                (g['score'] as num).toDouble() /
                                (g['max_score'] as num).toDouble(),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: series.map((g) {
                final d = DateTime.tryParse(g['exam_at'] as String? ?? '');
                return Text(
                  '${d == null ? '—' : DateFormat('d MMM').format(d.toLocal())}: ${g['score']}/${g['max_score']}',
                  style: textStyle(11),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  final List<double> values;
  _MarksPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    for (final f in [0.0, .5, 1.0]) {
      canvas.drawLine(
        Offset(5, size.height * (1 - f) - 4),
        Offset(size.width - 5, size.height * (1 - f) - 4),
        grid,
      );
    }
    final stroke = Paint()
      ..color = Palette.teal
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : 8 + i * (size.width - 16) / (values.length - 1);
      final y = 4 + (1 - values[i].clamp(0, 1)) * (size.height - 12);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Palette.teal);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_MarksPainter old) => true;
}
