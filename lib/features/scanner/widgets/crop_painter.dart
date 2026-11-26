part of '../screen.dart';

class _CropPainter extends CustomPainter {
  final Rect crop;
  _CropPainter(this.crop);
  @override
  void paint(Canvas canvas, Size size) {
    final selected = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(selected)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    canvas.drawRect(
      selected,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.crop != crop;
}
