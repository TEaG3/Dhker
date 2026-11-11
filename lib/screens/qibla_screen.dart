import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCompass();
  }

  @override
  void dispose() {
    FlutterQiblah().dispose();
    super.dispose();
  }

  Future<void> _initializeCompass() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final sensorAvailable = await FlutterQiblah.androidDeviceSensorSupport();
      if (sensorAvailable == false) {
        throw Exception('هذا الجهاز لا يحتوي على مستشعر بوصلة مناسب.');
      }

      var status = await FlutterQiblah.checkLocationStatus();
      if (status.status.toString().toLowerCase().contains('denied')) {
        await FlutterQiblah.requestPermissions();
        status = await FlutterQiblah.checkLocationStatus();
      }

      if (!status.enabled) {
        throw Exception('يرجى تشغيل خدمة الموقع (GPS) ثم المحاولة مجدداً.');
      }
      if (status.status.toString().toLowerCase().contains('denied')) {
        throw Exception('يلزم السماح للتطبيق بالوصول إلى الموقع لحساب اتجاه القبلة.');
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اتجاه القبلة'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.compass, size: 54, color: colors.primary),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _initializeCompass,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    )
                  : StreamBuilder<QiblahDirection>(
                      stream: FlutterQiblah.qiblahStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'تعذر قراءة مستشعر البوصلة: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          );
                        }
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }

                        final direction = snapshot.data!;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'وجّه السهم نحو الكعبة المشرفة',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 26),
                            AnimatedRotation(
                              turns: direction.offset / 360,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              child: CustomPaint(
                                size: const Size(280, 280),
                                painter: _CompassFacePainter(
                                  primary: colors.primary,
                                  secondary: colors.secondary,
                                  surface: colors.surface,
                                  outline: colors.outline,
                                ),
                                child: const SizedBox(
                                  width: 280,
                                  height: 280,
                                  child: Center(
                                    child: Icon(
                                      LucideIcons.navigation,
                                      size: 74,
                                      color: Color(0xFFC6A76A),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Text(
                              'زاوية القبلة: ${direction.qiblah.toStringAsFixed(0)}°',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'الشمال: ${direction.direction.toStringAsFixed(0)}°',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'لأفضل دقة، أبعد الهاتف عن المعادن ومكبرات الصوت، وحرّكه برفق على شكل رقم 8 عند الحاجة إلى معايرة البوصلة.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _CompassFacePainter extends CustomPainter {
  const _CompassFacePainter({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.outline,
  });

  final Color primary;
  final Color secondary;
  final Color surface;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [surface, primary.withValues(alpha: 0.16), surface],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = outline.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30;
      final major = i % 5 == 0;
      final start = radius - (major ? 18 : 9);
      final end = radius - 4;
      final p1 = center + Offset(math.sin(angle) * start, -math.cos(angle) * start);
      final p2 = center + Offset(math.sin(angle) * end, -math.cos(angle) * end);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = major ? secondary : outline.withValues(alpha: 0.65)
          ..strokeWidth = major ? 2.4 : 1,
      );
    }

    const labels = ['ش', 'ش ق', 'ق', 'ج ق', 'ج', 'ج غ', 'غ', 'ش غ'];
    for (var i = 0; i < labels.length; i++) {
      final angle = i * math.pi / 4;
      final position = center +
          Offset(math.sin(angle) * (radius - 34), -math.cos(angle) * (radius - 34));
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: i == 0 ? secondary : primary,
            fontSize: i % 2 == 0 ? 13 : 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      painter.paint(canvas, position - Offset(painter.width / 2, painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _CompassFacePainter oldDelegate) {
    return primary != oldDelegate.primary ||
        secondary != oldDelegate.secondary ||
        surface != oldDelegate.surface ||
        outline != oldDelegate.outline;
  }
}
