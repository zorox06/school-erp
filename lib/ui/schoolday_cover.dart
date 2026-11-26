import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'components.dart';

class SchooldayCover extends StatelessWidget {
  const SchooldayCover({
    super.key,
    required this.title,
    this.label,
    this.caption,
  });

  final String title;
  final String? label;
  final String? caption;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: ColoredBox(
      color: Palette.forest,
      child: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _SchoolArch())),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: textStyle(
                      12,
                      color: Palette.brass,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  style: textStyle(
                    34,
                    color: Palette.paper,
                    weight: FontWeight.w800,
                    height: 1.12,
                  ).copyWith(letterSpacing: -1.25),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    caption!,
                    style: textStyle(13, color: const Color(0xFFDBE7DD)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SchoolArch extends CustomPainter {
  const _SchoolArch();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width - 30, size.height * .77);
    final paint = Paint()
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..color = const Color(0x406DB094);
    for (var i = 0; i < 6; i++) {
      final radius = 30.0 + i * 12;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(
            center.dx - radius,
            center.dy - radius,
            center.dx + radius,
            size.height + 3,
          ),
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        paint,
      );
    }
    canvas.drawCircle(
      Offset(center.dx, center.dy - 31),
      3.5,
      Paint()..color = Palette.brass,
    );
  }

  @override
  bool shouldRepaint(_SchoolArch oldDelegate) => false;
}
