import 'package:flutter/material.dart';

/// The official multicolor Google "G" mark drawn with the four brand colors:
/// blue (#4285F4), red (#EA4335), yellow (#FBBC05) and green (#34A853).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  // Source view box is 18x18 (official Google "G" mark geometry).
  static const double _viewBox = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..style = PaintingStyle.fill;

    // Blue.
    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(
      Path()
        ..moveTo(17.64, 9.205)
        ..cubicTo(17.64, 8.567, 17.583, 7.953, 17.476, 7.364)
        ..lineTo(9, 7.364)
        ..lineTo(9, 10.845)
        ..cubicTo(11.81, 10.845, 14.035, 11.683, 15.561, 13.168)
        ..lineTo(18.484, 10.399)
        ..cubicTo(17.723, 9.37, 17.64, 9.205, 17.64, 9.205)
        ..close(),
      paint,
    );

    // Green.
    paint.color = const Color(0xFF34A853);
    canvas.drawPath(
      Path()
        ..moveTo(9, 18)
        ..cubicTo(11.43, 18, 13.467, 17.194, 14.956, 15.819)
        ..lineTo(12.033, 13.05)
        ..cubicTo(11.227, 13.59, 10.197, 13.909, 9, 13.909)
        ..cubicTo(6.668, 13.909, 4.694, 12.334, 3.989, 10.216)
        ..lineTo(1.033, 13.115)
        ..cubicTo(2.407, 16.516, 5.505, 18, 9, 18)
        ..close(),
      paint,
    );

    // Yellow.
    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(
      Path()
        ..moveTo(3.989, 10.216)
        ..cubicTo(3.841, 9.649, 3.769, 9.05, 3.769, 8.428)
        ..cubicTo(3.769, 7.807, 3.841, 7.207, 3.989, 6.64)
        ..lineTo(1.033, 4.009)
        ..cubicTo(0.377, 5.224, 0, 6.676, 0, 8.197)
        ..cubicTo(0, 9.719, 0.377, 11.17, 1.033, 12.385)
        ..close(),
      paint,
    );

    // Red.
    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(
      Path()
        ..moveTo(9, 3.58)
        ..cubicTo(10.322, 3.58, 11.508, 4.034, 12.441, 4.926)
        ..lineTo(15.022, 2.345)
        ..cubicTo(13.463, 0.892, 11.426, 0, 9, 0)
        ..cubicTo(5.505, 0, 2.407, 1.484, 1.034, 4.009)
        ..lineTo(3.989, 6.64)
        ..cubicTo(4.694, 4.522, 6.668, 3.58, 9, 3.58)
        ..close(),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
