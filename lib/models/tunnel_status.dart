enum ConnectionPhase {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

ConnectionPhase parsePhase(String? value) {
  switch (value) {
    case 'connecting':
      return ConnectionPhase.connecting;
    case 'connected':
      return ConnectionPhase.connected;
    case 'disconnecting':
      return ConnectionPhase.disconnecting;
    default:
      return ConnectionPhase.disconnected;
  }
}

class TunnelSnapshot {
  final ConnectionPhase phase;
  final String selectedRegion;
  final String connectedRegion;
  final String clientRegion;
  final List<String> availableRegions;
  final String activeProtocol;
  final String preferredProtocol;
  final String upstreamProxyUrl;
  final int bytesSent;
  final int bytesReceived;
  final int upSpeedBps;
  final int downSpeedBps;
  final int connectedSinceMs;
  final String? lastError;

  const TunnelSnapshot({
    this.phase = ConnectionPhase.disconnected,
    this.selectedRegion = '',
    this.connectedRegion = '',
    this.clientRegion = '',
    this.availableRegions = const [],
    this.activeProtocol = '',
    this.preferredProtocol = 'AUTO',
    this.upstreamProxyUrl = '',
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.upSpeedBps = 0,
    this.downSpeedBps = 0,
    this.connectedSinceMs = 0,
    this.lastError,
  });

  factory TunnelSnapshot.fromMap(Map<Object?, Object?> map) {
    final availRaw = map['availableRegions'];
    final available = availRaw is List
        ? availRaw.map((e) => e.toString().toUpperCase()).toList()
        : const <String>[];

    return TunnelSnapshot(
      phase: parsePhase(map['status'] as String?),
      selectedRegion: (map['selectedRegion'] as String?) ?? '',
      connectedRegion: (map['connectedRegion'] as String?) ?? '',
      clientRegion: (map['clientRegion'] as String?) ?? '',
      availableRegions: available,
      activeProtocol: (map['activeProtocol'] as String?) ?? '',
      preferredProtocol: (map['preferredProtocol'] as String?) ?? 'AUTO',
      upstreamProxyUrl: (map['upstreamProxyUrl'] as String?) ?? '',
      bytesSent: (map['bytesSent'] as num?)?.toInt() ?? 0,
      bytesReceived: (map['bytesReceived'] as num?)?.toInt() ?? 0,
      upSpeedBps: (map['upSpeedBps'] as num?)?.toInt() ?? 0,
      downSpeedBps: (map['downSpeedBps'] as num?)?.toInt() ?? 0,
      connectedSinceMs: (map['connectedSinceMs'] as num?)?.toInt() ?? 0,
      lastError: map['lastError'] as String?,
    );
  }

  TunnelSnapshot copyWith({
    ConnectionPhase? phase,
    String? selectedRegion,
    String? connectedRegion,
    String? clientRegion,
    List<String>? availableRegions,
    String? activeProtocol,
    String? preferredProtocol,
    String? upstreamProxyUrl,
    int? bytesSent,
    int? bytesReceived,
    int? upSpeedBps,
    int? downSpeedBps,
    int? connectedSinceMs,
    String? lastError,
  }) {
    return TunnelSnapshot(
      phase: phase ?? this.phase,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      connectedRegion: connectedRegion ?? this.connectedRegion,
      clientRegion: clientRegion ?? this.clientRegion,
      availableRegions: availableRegions ?? this.availableRegions,
      activeProtocol: activeProtocol ?? this.activeProtocol,
      preferredProtocol: preferredProtocol ?? this.preferredProtocol,
      upstreamProxyUrl: upstreamProxyUrl ?? this.upstreamProxyUrl,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      upSpeedBps: upSpeedBps ?? this.upSpeedBps,
      downSpeedBps: downSpeedBps ?? this.downSpeedBps,
      connectedSinceMs: connectedSinceMs ?? this.connectedSinceMs,
      lastError: lastError ?? this.lastError,
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatSpeed(int bytesPerSecond) {
  return '${formatBytes(bytesPerSecond)}/s';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}
