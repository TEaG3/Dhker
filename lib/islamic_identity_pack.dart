import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Offline decorative layer for Dhker.
/// It overlays the existing route without replacing screens or intercepting input.
class DhkerIdentityWrapper extends StatelessWidget {
  const DhkerIdentityWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep decorative geometry behind all screen content. Painting it
        // above the child reduced contrast over Quran text and could obscure
        // ayat on the Mushaf reader.
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _DhkerOrnamentPainter(
                  gold: const Color(0xFFC6A76A),
                  accent: colors.primary,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DhkerOrnamentPainter extends CustomPainter {
  const _DhkerOrnamentPainter({
    required this.gold,
    required this.accent,
    required this.isDark,
  });

  final Color gold;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = isDark ? 0.20 : 0.13;
    _drawShamsa(canvas, Offset(size.width * .10, size.height * .19),
        size.shortestSide * .19, opacity);
    _drawShamsa(canvas, Offset(size.width * .91, size.height * .73),
        size.shortestSide * .13, opacity * .65);
    _drawLantern(canvas, Offset(size.width * .12, 0), size.height * .17);
    _drawLantern(canvas, Offset(size.width * .88, 0), size.height * .17);
    _drawEightPointGrid(canvas, size);
  }

  void _drawShamsa(Canvas canvas, Offset center, double radius, double alpha) {
    final paint = Paint()
      ..color = gold.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var ring = 0; ring < 2; ring++) {
      final r = radius * (ring == 0 ? .72 : 1);
      final path = Path();
      for (var i = 0; i < 16; i++) {
        final angle = -math.pi / 2 + i * math.pi / 8;
        final point = Offset(center.dx + math.cos(angle) * r,
            center.dy + math.sin(angle) * r);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(center, radius * .32, paint);
  }

  void _drawLantern(Canvas canvas, Offset anchor, double height) {
    final width = height * .25;
    final centerX = anchor.dx;
    final top = anchor.dy;
    final paint = Paint()
      ..color = gold.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(centerX, top), Offset(centerX, top + height * .22), paint);
    final body = Path()
      ..moveTo(centerX - width * .34, top + height * .25)
      ..lineTo(centerX - width * .50, top + height * .66)
      ..quadraticBezierTo(centerX, top + height * .92,
          centerX + width * .50, top + height * .66)
      ..lineTo(centerX + width * .34, top + height * .25)
      ..close();
    canvas.drawPath(body, paint);
    canvas.drawLine(Offset(centerX - width * .36, top + height * .25),
        Offset(centerX + width * .36, top + height * .25), paint);
    canvas.drawLine(Offset(centerX - width * .43, top + height * .52),
        Offset(centerX + width * .43, top + height * .52), paint);
    final glow = Paint()
      ..color = accent.withValues(alpha: .20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, top + height * .56),
          width: width * .65, height: height * .34),
      glow,
    );
  }

  void _drawEightPointGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gold.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    const cell = 44.0;
    for (double x = 0; x < size.width + cell; x += cell) {
      for (double y = 0; y < size.height + cell; y += cell) {
        final c = Offset(x, y);
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final a = -math.pi / 2 + i * math.pi / 4;
          final p = Offset(c.dx + math.cos(a) * 12, c.dy + math.sin(a) * 12);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DhkerOrnamentPainter oldDelegate) =>
      oldDelegate.gold != gold ||
      oldDelegate.accent != accent ||
      oldDelegate.isDark != isDark;
}
