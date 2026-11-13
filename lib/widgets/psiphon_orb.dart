import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tunnel_status.dart';
import '../theme/psiphon_theme.dart';

class PsiphonOrb extends StatefulWidget {
  final ConnectionPhase phase;
  final VoidCallback onTap;

  const PsiphonOrb({
    super.key,
    required this.phase,
    required this.onTap,
  });

  @override
  State<PsiphonOrb> createState() => _PsiphonOrbState();
}

class _PsiphonOrbState extends State<PsiphonOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _baseDiameter {
    switch (widget.phase) {
      case ConnectionPhase.disconnected:
        return 134.0;
      case ConnectionPhase.connecting:
      case ConnectionPhase.disconnecting:
        return 192.0;
      case ConnectionPhase.connected:
        return 222.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransitioning = widget.phase == ConnectionPhase.connecting ||
        widget.phase == ConnectionPhase.disconnecting;
    final isConnected = widget.phase == ConnectionPhase.connected;

    return Semantics(
      button: true,
      label: isConnected
          ? 'Disconnect Psiphon VPN'
          : isTransitioning
              ? 'Cancel connection'
              : 'Connect Psiphon VPN',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: SizedBox(
          width: 270,
          height: 270,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final t = _pulseController.value;
                final breath = isTransitioning
                    ? 1.0 + 0.055 * math.sin(t * 2 * math.pi)
                    : isConnected
                        ? 1.0 + 0.018 * math.sin(t * 2 * math.pi)
                        : 1.0 + 0.010 * math.sin(t * 2 * math.pi);
                final pressScale = _pressed ? 0.94 : 1.0;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  width: _baseDiameter * breath * pressScale,
                  height: _baseDiameter * breath * pressScale,
                  child: CustomPaint(
                    painter: _OrbPainter(
                      phase: widget.phase,
                      animationPhase: t,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final ConnectionPhase phase;
  final double animationPhase;

  const _OrbPainter({
    required this.phase,
    required this.animationPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final angle = animationPhase * 2 * math.pi;

    // Ambient outer halo proportional to connection state
    final haloAlpha = switch (phase) {
      ConnectionPhase.connected => 107,
      ConnectionPhase.connecting || ConnectionPhase.disconnecting => 76,
      ConnectionPhase.disconnected => 41,
    };

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (phase == ConnectionPhase.connected
                  ? PsiphonPalette.connectedEmerald
                  : PsiphonPalette.orbCoral)
              .withAlpha(haloAlpha),
          PsiphonPalette.orbPeriwinkle.withAlpha((haloAlpha * 0.45).round()),
          Colors.transparent,
        ],
        stops: const [0.45, 0.72, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.28))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);

    canvas.drawCircle(center, radius * 1.15, haloPaint);

    // Subtle expanding radar ring while connecting
    if (phase == ConnectionPhase.connecting ||
        phase == ConnectionPhase.disconnecting) {
      final ringProgress = animationPhase;
      final ringRadius = radius * (1.0 + 0.24 * ringProgress);
      final ringAlpha = ((1.0 - ringProgress) * 122).round().clamp(0, 255);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = PsiphonPalette.orbGold.withAlpha(ringAlpha);
      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Core diagonal radial gradient matching Default/Connecting/Connected-Orb.svg
    final driftX = phase == ConnectionPhase.disconnected
        ? 0.0
        : 0.08 * math.cos(angle);
    final driftY = phase == ConnectionPhase.disconnected
        ? 0.0
        : 0.08 * math.sin(angle);

    final stops = switch (phase) {
      ConnectionPhase.disconnected => const [0.02, 0.16, 0.42, 1.0],
      ConnectionPhase.connecting ||
      ConnectionPhase.disconnecting =>
        const [0.09, 0.38, 0.72, 1.0],
      ConnectionPhase.connected => const [0.10, 0.36, 0.62, 1.0],
    };

    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.56 + driftX, 0.64 + driftY),
        focal: Alignment(-0.72 + driftX, 0.76 + driftY),
        radius: 1.52,
        colors: const [
          PsiphonPalette.orbCoral,
          PsiphonPalette.orbGold,
          PsiphonPalette.orbPeach,
          PsiphonPalette.orbPeriwinkle,
        ],
        stops: stops,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, orbPaint);

    // Soft glass highlight rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = phase == ConnectionPhase.connected ? 1.5 : 1.0
      ..color = Colors.white.withAlpha(
          phase == ConnectionPhase.connected ? 82 : 41);
    canvas.drawCircle(center, radius - 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.animationPhase != animationPhase;
  }
}
