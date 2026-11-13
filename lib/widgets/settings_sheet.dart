import 'package:flutter/material.dart';
import '../services/vpn_controller.dart';
import '../theme/psiphon_theme.dart';

const List<({String id, String label, String subtitle})> kProtocolChoices = [
  (id: 'AUTO', label: 'Automatic (Recommended)', subtitle: 'Psiphon selects the fastest circumvention transport'),
  (id: 'OSSH', label: 'OSSH', subtitle: 'Obfuscated SSH over TCP'),
  (id: 'SSH', label: 'SSH', subtitle: 'Direct SSH tunnel'),
  (id: 'UNFRONTED-MEEK-OSSH', label: 'Unfronted Meek', subtitle: 'HTTPS CDN-compatible meek transport'),
  (id: 'FRONTED-MEEK-OSSH', label: 'Fronted Meek', subtitle: 'Domain-fronted HTTPS meek transport'),
  (id: 'QUIC-OSSH', label: 'QUIC OSSH', subtitle: 'Obfuscated QUIC UDP transport'),
  (id: 'INPROXY-WEBRTC-OSSH', label: 'Conduit / Inproxy WebRTC', subtitle: 'Peer-relayed WebRTC tunnel'),
];

class SettingsSheet extends StatefulWidget {
  final VpnController controller;

  const SettingsSheet({super.key, required this.controller});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late String _protocol;
  late final TextEditingController _proxyController;
  String? _proxyError;

  @override
  void initState() {
    super.initState();
    _protocol = widget.controller.preferredProtocol;
    _proxyController = TextEditingController(
      text: widget.controller.upstreamProxyUrl,
    );
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
  }

  bool _isValidUpstreamProxy(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || !uri.hasPort) return false;
    return const {'http', 'https', 'socks4', 'socks4a', 'socks5'}.contains(
      uri.scheme.toLowerCase(),
    );
  }

  Future<void> _save() async {
    final raw = _proxyController.text.trim();
    if (!_isValidUpstreamProxy(raw)) {
      setState(() {
        _proxyError = 'Use http://host:port or socks5://host:port (or leave empty)';
      });
      return;
    }

    await widget.controller.updateSettings(
      preferredProtocol: _protocol,
      upstreamProxyUrl: raw,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: SingleChildScrollView(
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
              const Text(
                'Tunnel Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: PsiphonPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure circumvention transport and upstream proxy chaining',
                style: TextStyle(
                  fontSize: 12,
                  color: PsiphonPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tunnel Protocol',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PsiphonPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              ...kProtocolChoices.map((choice) {
                final selected = _protocol == choice.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? PsiphonPalette.surfaceElevated
                        : PsiphonPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _protocol = choice.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    choice.label,
                                    style: const TextStyle(
                                      color: PsiphonPalette.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    choice.subtitle,
                                    style: const TextStyle(
                                      color: PsiphonPalette.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: selected
                                  ? PsiphonPalette.orbCoral
                                  : Colors.white24,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              const Text(
                'Upstream Proxy (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PsiphonPalette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _proxyController,
                style: const TextStyle(color: PsiphonPalette.textPrimary, fontSize: 14),
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:8080 or socks5://127.0.0.1:1080',
                  hintStyle: const TextStyle(
                    color: PsiphonPalette.textSecondary,
                    fontSize: 13,
                  ),
                  errorText: _proxyError,
                  filled: true,
                  fillColor: PsiphonPalette.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PsiphonPalette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PsiphonPalette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: PsiphonPalette.orbCoral),
                  ),
                ),
                onChanged: (_) {
                  if (_proxyError != null) setState(() => _proxyError = null);
                },
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: PsiphonPalette.orbCoral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save & Apply',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
