import 'package:flutter/material.dart';

/// Bundled vector illustration: no assets or network needed.
class GroceryArt extends StatelessWidget {
  const GroceryArt({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'A basket of fresh fruit, leafy vegetables, eggs and spices',
    child: SizedBox(height: 150, child: CustomPaint(painter: _BasketPainter())),
  );
}

class _BasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final paint = Paint();
    void oval(Rect rect, Color color) {
      paint.color = color;
      canvas.drawOval(rect, paint);
    }

    oval(
      Rect.fromCenter(center: Offset(x, 133), width: 220, height: 20),
      const Color(0xffe8e9d8),
    );
    oval(
      Rect.fromCenter(center: Offset(x - 65, 60), width: 48, height: 55),
      const Color(0xffef7859),
    );
    oval(
      Rect.fromCenter(center: Offset(x - 30, 50), width: 48, height: 62),
      const Color(0xffefb739),
    );
    for (var i = 0; i < 3; i++) {
      oval(
        Rect.fromCenter(
          center: Offset(x + 5 + i * 15, 43 + i * 6),
          width: 24,
          height: 62,
        ),
        const Color(0xff609b59),
      );
    }
    oval(
      Rect.fromCenter(center: Offset(x + 65, 69), width: 31, height: 43),
      const Color(0xffffe2b9),
    );
    paint.color = const Color(0xffb85c38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 33, 66, 23, 33),
        const Radius.circular(5),
      ),
      paint,
    );
    paint.color = const Color(0xffdfb379);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 95, 83, 190, 48),
        const Radius.circular(14),
      ),
      paint,
    );
    paint
      ..color = const Color(0xffa67b47)
      ..strokeWidth = 3;
    for (var i = 0; i < 8; i++) {
      canvas.drawLine(
        Offset(x - 77 + i * 22, 91),
        Offset(x - 72 + i * 21, 123),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
