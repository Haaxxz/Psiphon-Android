import 'package:flutter/material.dart';
import '../models/tunnel_status.dart';
import '../theme/psiphon_theme.dart';

class SlideToConnect extends StatefulWidget {
  final ConnectionPhase phase;
  final VoidCallback onTrigger;

  const SlideToConnect({
    super.key,
    required this.phase,
    required this.onTrigger,
  });

  @override
  State<SlideToConnect> createState() => _SlideToConnectState();
}

class _SlideToConnectState extends State<SlideToConnect> {
  static const double _trackHeight = 58.0;
  static const double _puckSize = 48.0;
  static const double _margin = 5.0;

  double _dragOffset = 0.0;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant SlideToConnect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _dragOffset = 0.0;
      _dragging = false;
    }
  }

  String get _labelText {
    switch (widget.phase) {
      case ConnectionPhase.connected:
        return 'Slide to stop';
      case ConnectionPhase.connecting:
        return 'Connecting… tap to cancel';
      case ConnectionPhase.disconnecting:
        return 'Stopping…';
      case ConnectionPhase.disconnected:
        return 'Slide to turn on';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.phase == ConnectionPhase.connected;
    final isConnecting = widget.phase == ConnectionPhase.connecting;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTravel =
            (constraints.maxWidth - _puckSize - (_margin * 2)).clamp(1.0, 600.0);
        final progress = (_dragOffset / maxTravel).clamp(0.0, 1.0);

        return GestureDetector(
          onTap: widget.onTrigger,
          onHorizontalDragStart: (_) {
            setState(() => _dragging = true);
          },
          onHorizontalDragUpdate: (details) {
            if (!_dragging) return;
            setState(() {
              _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, maxTravel);
            });
          },
          onHorizontalDragEnd: (_) {
            final shouldTrigger = _dragOffset >= maxTravel * 0.58;
            setState(() {
              _dragging = false;
              _dragOffset = 0.0;
            });
            if (shouldTrigger) {
              widget.onTrigger();
            }
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: _dragging ? 0 : 240),
            curve: Curves.easeOutCubic,
            height: _trackHeight,
            decoration: BoxDecoration(
              color: isConnected
                  ? const Color(0xFF28191A)
                  : isConnecting
                      ? const Color(0xFF222226)
                      : PsiphonPalette.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isConnected
                    ? PsiphonPalette.stopRed.withAlpha(90)
                    : PsiphonPalette.border,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  opacity: (1.0 - progress * 1.4).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 120),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 28, right: 16),
                    child: Text(
                      _labelText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PsiphonPalette.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: Duration(milliseconds: _dragging ? 0 : 240),
                  curve: Curves.easeOutCubic,
                  left: _margin + _dragOffset,
                  top: _margin,
                  child: Container(
                    width: _puckSize,
                    height: _puckSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isConnected
                          ? Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: PsiphonPalette.stopRed,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )
                          : isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: Color(0xFF141418),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
