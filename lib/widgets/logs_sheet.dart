import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vpn_controller.dart';
import '../theme/psiphon_theme.dart';

class LogsSheet extends StatelessWidget {
  final VpnController controller;

  const LogsSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final entries = controller.logs;

            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Diagnostic Logs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: PsiphonPalette.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy all logs',
                        icon: const Icon(
                          Icons.copy_all_rounded,
                          color: PsiphonPalette.textSecondary,
                        ),
                        onPressed: entries.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: entries.join('\n')),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied diagnostic logs to clipboard'),
                                  ),
                                );
                              },
                      ),
                      IconButton(
                        tooltip: 'Clear logs',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: PsiphonPalette.textSecondary,
                        ),
                        onPressed: entries.isEmpty
                            ? null
                            : () => controller.clearLogs(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: PsiphonPalette.border),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            'No tunnel log messages yet.\nConnect to stream Psiphon core diagnostics.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PsiphonPalette.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final line = entries[entries.length - 1 - index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: SelectableText(
                                line,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: Color(0xFFD1D1D6),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
