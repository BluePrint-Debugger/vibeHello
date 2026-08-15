import 'package:flutter/material.dart';

/// Visual shape applied to every occupied/empty seat in a room. Chosen
/// room-wide by an admin (stored as a plain string on the room doc so it
/// doesn't need a migration if we add more designs later).
enum SeatDesign { circle, squircle, hexagon }

SeatDesign seatDesignFromString(String? value) {
  switch (value) {
    case 'squircle':
      return SeatDesign.squircle;
    case 'hexagon':
      return SeatDesign.hexagon;
    case 'circle':
    default:
      return SeatDesign.circle;
  }
}

extension SeatDesignLabel on SeatDesign {
  String get label {
    switch (this) {
      case SeatDesign.circle:
        return 'Circle';
      case SeatDesign.squircle:
        return 'Squircle';
      case SeatDesign.hexagon:
        return 'Hexagon';
    }
  }

  String get storageValue {
    switch (this) {
      case SeatDesign.circle:
        return 'circle';
      case SeatDesign.squircle:
        return 'squircle';
      case SeatDesign.hexagon:
        return 'hexagon';
    }
  }

  IconData get previewIcon {
    switch (this) {
      case SeatDesign.circle:
        return Icons.circle_outlined;
      case SeatDesign.squircle:
        return Icons.crop_square_rounded;
      case SeatDesign.hexagon:
        return Icons.hexagon_outlined;
    }
  }
}

/// Wraps [child] (typically an avatar Stack) with the chosen seat shape's
/// clip and border, so every seat card in the room renders consistently
/// without every call site needing to know the shape-specific details.
class SeatFrame extends StatelessWidget {
  final SeatDesign design;
  final Widget child;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;

  const SeatFrame({
    super.key,
    required this.design,
    required this.child,
    required this.borderColor,
    this.borderWidth = 2,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    switch (design) {
      case SeatDesign.circle:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: ClipOval(child: child),
        );

      case SeatDesign.squircle:
        final radius = BorderRadius.circular(18);
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: ClipRRect(borderRadius: radius, child: child),
        );

      case SeatDesign.hexagon:
        return Container(
          decoration: BoxDecoration(boxShadow: shadows),
          child: ClipPath(
            clipper: _HexagonClipper(),
            child: CustomPaint(
              foregroundPainter: _HexagonBorderPainter(
                color: borderColor,
                width: borderWidth,
              ),
              child: child,
            ),
          ),
        );
    }
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    // Flat-top hexagon, points at 0°, 60°, 120°, 180°, 240°, 300° around
    // the center - reads clearly as "hexagon" even at small avatar sizes.
    path.moveTo(w * 0.25, 0);
    path.lineTo(w * 0.75, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.25, h);
    path.lineTo(0, h * 0.5);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _HexagonBorderPainter extends CustomPainter {
  final Color color;
  final double width;

  _HexagonBorderPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexagonBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.width != width;
  }
}
