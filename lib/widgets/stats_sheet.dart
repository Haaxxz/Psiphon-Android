import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tunnel_status.dart';
import '../services/vpn_controller.dart';
import '../theme/psiphon_theme.dart';

class StatsSheet extends StatelessWidget {
  final VpnController controller;

  const StatsSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final snap = controller.snapshot;
        final isConnected = snap.phase == ConnectionPhase.connected;
        final uptime = isConnected
            ? formatDuration(controller.connectedDuration)
            : 'Not connected';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tunnel Telemetry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: PsiphonPalette.textPrimary,
                        ),
                      ),
                    ),
                    if (snap.activeProtocol.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PsiphonPalette.surfaceElevated,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: PsiphonPalette.border),
                        ),
                        child: Text(
                          snap.activeProtocol,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PsiphonPalette.orbGold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: PsiphonPalette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PsiphonPalette.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: PsiphonPalette.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Connection Time',
                          style: TextStyle(
                            color: PsiphonPalette.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        uptime,
                        style: const TextStyle(
                          color: PsiphonPalette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _TrafficCard(
                  title: '↓ Received',
                  speed: formatSpeed(snap.downSpeedBps),
                  total: 'Total: ${formatBytes(snap.bytesReceived)}',
                  accentColor: PsiphonPalette.connectedEmerald,
                  history: controller.downHistory,
                ),
                const SizedBox(height: 12),
                _TrafficCard(
                  title: '↑ Sent',
                  speed: formatSpeed(snap.upSpeedBps),
                  total: 'Total: ${formatBytes(snap.bytesSent)}',
                  accentColor: PsiphonPalette.uploadCyan,
                  history: controller.upHistory,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrafficCard extends StatelessWidget {
  final String title;
  final String speed;
  final String total;
  final Color accentColor;
  final List<double> history;

  const _TrafficCard({
    required this.title,
    required this.speed,
    required this.total,
    required this.accentColor,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: PsiphonPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PsiphonPalette.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  speed,
                  style: const TextStyle(
                    color: PsiphonPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  color: PsiphonPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 62,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveChartPainter(
                values: history,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _WaveChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withAlpha(31)
      ..strokeWidth = 0.8;

    for (final frac in const [0.25, 0.5, 0.75]) {
      final y = size.height * frac;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final maxVal = math.max(
      values.fold<double>(0.0, math.max),
      10240.0,
    );

    final stepX = size.width / math.max(1, values.length - 1);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final norm = (values[i] / maxVal).clamp(0.0, 1.0);
      final x = i * stepX;
      final y = size.height - (norm * (size.height - 6)) - 2;
      pts.add(Offset(x, y));
    }

    final strokePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      strokePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(strokePath)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withAlpha(82),
          color.withAlpha(5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _WaveChartPainter oldDelegate) => true;
}
