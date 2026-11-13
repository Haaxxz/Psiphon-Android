import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/region.dart';
import '../models/tunnel_status.dart';
import '../services/vpn_controller.dart';
import '../theme/psiphon_theme.dart';
import '../widgets/country_picker_sheet.dart';
import '../widgets/logs_sheet.dart';
import '../widgets/psiphon_orb.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/slide_to_connect.dart';
import '../widgets/stats_sheet.dart';

class HomeScreen extends StatelessWidget {
  final VpnController controller;

  const HomeScreen({super.key, required this.controller});

  void _openRegions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CountryPickerSheet(
        selectedCode: controller.selectedRegion,
        availableServerRegions: controller.snapshot.availableRegions,
        onSelect: (code) => controller.selectRegion(code),
      ),
    );
  }

  void _openStats(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatsSheet(controller: controller),
    );
  }

  void _openLogs(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogsSheet(controller: controller),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final snap = controller.snapshot;
        final chosenRegion = resolveRegion(controller.selectedRegion);
        final activeExitRegion = snap.connectedRegion.isNotEmpty
            ? resolveRegion(snap.connectedRegion)
            : chosenRegion;

        final (headline, subline) = _statusCopy(snap, chosenRegion, activeExitRegion);

        return Scaffold(
          backgroundColor: PsiphonPalette.background,
          body: SafeArea(
            child: Column(
              children: [
                _HeaderBar(
                  onStatsTap: () => _openStats(context),
                  onLogsTap: () => _openLogs(context),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PsiphonOrb(
                        phase: snap.phase,
                        onTap: () => _handleToggle(context),
                      ),
                      const SizedBox(height: 16),
                      _LiveTelemetryBadge(
                        snapshot: snap,
                        activeExitRegion: activeExitRegion,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RegionSelectorPill(
                        region: chosenRegion,
                        onTap: () => _openRegions(context),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        headline,
                        style: const TextStyle(
                          color: PsiphonPalette.textPrimary,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subline,
                        style: const TextStyle(
                          color: PsiphonPalette.textSecondary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: SlideToConnect(
                              phase: snap.phase,
                              onTrigger: () => _handleToggle(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _CircularActionButton(
                            tooltip: 'Settings',
                            onTap: () => _openSettings(context),
                            child: SvgPicture.asset(
                              'assets/icons/settings.svg',
                              width: 22,
                              height: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleToggle(BuildContext context) async {
    final ok = await controller.toggleConnection();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Android VPN permission is required to start the tunnel'),
        ),
      );
    }
  }

  (String, String) _statusCopy(
    TunnelSnapshot snap,
    VpnRegion chosen,
    VpnRegion activeExit,
  ) {
    switch (snap.phase) {
      case ConnectionPhase.connected:
        final dur = formatDuration(controller.connectedDuration);
        final totalDown = formatBytes(snap.bytesReceived);
        final totalUp = formatBytes(snap.bytesSent);
        return (
          'Protected in ${activeExit.name}',
          'Connected $dur • ↓ $totalDown  ↑ $totalUp',
        );
      case ConnectionPhase.connecting:
        final target = chosen.isAuto ? 'fastest server' : chosen.name;
        return (
          'Connecting…',
          'Establishing encrypted tunnel to $target',
        );
      case ConnectionPhase.disconnecting:
        return (
          'Disconnecting…',
          'Closing local VPN interface cleanly',
        );
      case ConnectionPhase.disconnected:
        return (
          'Start your connection',
          snap.lastError?.isNotEmpty == true
              ? snap.lastError!
              : 'All 49 countries unlocked • Tap orb or slide',
        );
    }
  }
}

class _HeaderBar extends StatelessWidget {
  final VoidCallback onStatsTap;
  final VoidCallback onLogsTap;

  const _HeaderBar({
    required this.onStatsTap,
    required this.onLogsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 16, 4),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/psiphon_mark_white.svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 9),
          const Text(
            'Psiphon',
            style: TextStyle(
              color: PsiphonPalette.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Telemetry & Stats',
            onPressed: onStatsTap,
            icon: SvgPicture.asset(
              'assets/icons/stats.svg',
              width: 21,
              height: 21,
            ),
          ),
          IconButton(
            tooltip: 'Diagnostic Logs',
            onPressed: onLogsTap,
            icon: const Icon(
              Icons.terminal_rounded,
              color: PsiphonPalette.textPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionSelectorPill extends StatelessWidget {
  final VpnRegion region;
  final VoidCallback onTap;

  const _RegionSelectorPill({
    required this.region,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PsiphonPalette.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PsiphonPalette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RegionFlagIcon(region: region, size: 19),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  region.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PsiphonPalette.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: PsiphonPalette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTelemetryBadge extends StatelessWidget {
  final TunnelSnapshot snapshot;
  final VpnRegion activeExitRegion;

  const _LiveTelemetryBadge({
    required this.snapshot,
    required this.activeExitRegion,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.phase == ConnectionPhase.connected) {
      final proto = snapshot.activeProtocol.isNotEmpty
          ? '${snapshot.activeProtocol} • '
          : '';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: PsiphonPalette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PsiphonPalette.connectedEmerald.withAlpha(110),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: PsiphonPalette.connectedEmerald,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$proto↓ ${formatSpeed(snapshot.downSpeedBps)}  ↑ ${formatSpeed(snapshot.upSpeedBps)}',
              style: const TextStyle(
                color: PsiphonPalette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (snapshot.phase == ConnectionPhase.connecting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: PsiphonPalette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PsiphonPalette.connectingAmber.withAlpha(105),
          ),
        ),
        child: const Text(
          'Searching fastest circumvention path…',
          style: TextStyle(
            color: PsiphonPalette.connectingAmber,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return const SizedBox(height: 31);
  }
}

class _CircularActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  const _CircularActionButton({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PsiphonPalette.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: PsiphonPalette.border),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
