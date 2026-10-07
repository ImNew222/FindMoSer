import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// An animated orbs widget inspired by orbs.jakubantalik.com
///
/// Renders floating, pulsing, glowing orbs using CustomPainter.
/// Each orb moves along organic sinusoidal paths with independent
/// opacity pulsing, creating a mesmerizing "thinking" effect.
class AnimatedOrbs extends StatefulWidget {
  final int orbCount;
  final Color baseColor;
  final double size;
  final double speed;

  const AnimatedOrbs({
    super.key,
    this.orbCount = 7,
    this.baseColor = AppTheme.primary,
    this.size = 280,
    this.speed = 0.8,
  });

  @override
  State<AnimatedOrbs> createState() => _AnimatedOrbsState();
}

class _AnimatedOrbsState extends State<AnimatedOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Orb> _orbs;
  final _random = Random(42);

  @override
  void initState() {
    super.initState();
    _orbs = List.generate(widget.orbCount, (_) => _generateOrb());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  _Orb _generateOrb() {
    final baseHue = HSLColor.fromColor(widget.baseColor).hue;
    return _Orb(
      // Starting position as ratio of center (0.0 = center)
      cx: (_random.nextDouble() - 0.5) * 0.6,
      cy: (_random.nextDouble() - 0.5) * 0.6,
      // Radius as ratio of widget size
      radius: 0.06 + _random.nextDouble() * 0.14,
      // Movement parameters
      xFreq: 0.3 + _random.nextDouble() * 0.7,
      yFreq: 0.3 + _random.nextDouble() * 0.7,
      xAmp: 0.08 + _random.nextDouble() * 0.18,
      yAmp: 0.08 + _random.nextDouble() * 0.18,
      xPhase: _random.nextDouble() * 2 * pi,
      yPhase: _random.nextDouble() * 2 * pi,
      // Opacity pulsing
      opacityBase: 0.15 + _random.nextDouble() * 0.25,
      opacityAmp: 0.08 + _random.nextDouble() * 0.15,
      opacityFreq: 0.5 + _random.nextDouble() * 1.0,
      opacityPhase: _random.nextDouble() * 2 * pi,
      // Color variation
      hue: baseHue + (_random.nextDouble() - 0.5) * 30,
      saturation: 0.3 + _random.nextDouble() * 0.3,
      lightness: 0.5 + _random.nextDouble() * 0.2,
      // Blur/glow
      blurRadius: 15 + _random.nextDouble() * 25,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _OrbsPainter(
          orbs: _orbs,
          time: _controller.value * 20, // map to seconds
          speed: widget.speed,
          size: widget.size,
        ),
      ),
    );
  }
}

class _Orb {
  final double cx, cy;
  final double radius;
  final double xFreq, yFreq, xAmp, yAmp, xPhase, yPhase;
  final double opacityBase, opacityAmp, opacityFreq, opacityPhase;
  final double hue, saturation, lightness;
  final double blurRadius;

  const _Orb({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.xFreq,
    required this.yFreq,
    required this.xAmp,
    required this.yAmp,
    required this.xPhase,
    required this.yPhase,
    required this.opacityBase,
    required this.opacityAmp,
    required this.opacityFreq,
    required this.opacityPhase,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.blurRadius,
  });
}

class _OrbsPainter extends CustomPainter {
  final List<_Orb> orbs;
  final double time;
  final double speed;
  final double size;

  _OrbsPainter({
    required this.orbs,
    required this.time,
    required this.speed,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final t = time * speed;

    for (final orb in orbs) {
      // Calculate position with organic movement
      final x =
          center.dx +
          (orb.cx + orb.xAmp * sin(t * orb.xFreq + orb.xPhase)) *
              canvasSize.width;
      final y =
          center.dy +
          (orb.cy + orb.yAmp * sin(t * orb.yFreq + orb.yPhase)) *
              canvasSize.height;

      // Calculate pulsing opacity
      final opacity =
          (orb.opacityBase +
                  orb.opacityAmp * sin(t * orb.opacityFreq + orb.opacityPhase))
              .clamp(0.05, 0.6);

      // Calculate pulsing radius
      final radiusPulse =
          1.0 + 0.15 * sin(t * orb.opacityFreq * 0.7 + orb.xPhase);
      final r = orb.radius * size * radiusPulse;

      final color = HSLColor.fromAHSL(
        opacity,
        orb.hue % 360,
        orb.saturation,
        orb.lightness,
      ).toColor();

      // Draw glow (outer blur)
      final glowPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, orb.blurRadius);
      canvas.drawCircle(Offset(x, y), r * 1.5, glowPaint);

      // Draw core orb
      final corePaint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3);
      canvas.drawCircle(Offset(x, y), r, corePaint);

      // Draw bright center
      final centerPaint = Paint()
        ..color = color.withValues(alpha: opacity * 1.5 > 1 ? 1 : opacity * 1.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15);
      canvas.drawCircle(Offset(x, y), r * 0.4, centerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter oldDelegate) => true;
}
