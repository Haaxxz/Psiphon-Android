import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tunnel_status.dart';

abstract class VpnBridge {
  Future<bool> startVpn({
    required String region,
    required String protocol,
    required String upstreamProxyUrl,
  });

  Future<void> restartVpn({
    required String region,
    required String protocol,
    required String upstreamProxyUrl,
  });

  Future<void> stopVpn();

  Future<Map<Object?, Object?>> getState();

  Future<void> clearLogs();

  Stream<dynamic> events();
}

class MethodChannelVpnBridge implements VpnBridge {
  static const MethodChannel _method = MethodChannel('ca.psiphon.flutter/vpn');
  static const EventChannel _events = EventChannel('ca.psiphon.flutter/events');

  @override
  Future<bool> startVpn({
    required String region,
    required String protocol,
    required String upstreamProxyUrl,
  }) async {
    final ok = await _method.invokeMethod<bool>('startVpn', {
      'region': region,
      'protocol': protocol,
      'upstreamProxyUrl': upstreamProxyUrl,
    });
    return ok ?? false;
  }

  @override
  Future<void> restartVpn({
    required String region,
    required String protocol,
    required String upstreamProxyUrl,
  }) async {
    await _method.invokeMethod<void>('restartVpn', {
      'region': region,
      'protocol': protocol,
      'upstreamProxyUrl': upstreamProxyUrl,
    });
  }

  @override
  Future<void> stopVpn() async {
    await _method.invokeMethod<void>('stopVpn');
  }

  @override
  Future<Map<Object?, Object?>> getState() async {
    final res = await _method.invokeMethod<Map<Object?, Object?>>('getState');
    return res ?? const {};
  }

  @override
  Future<void> clearLogs() async {
    await _method.invokeMethod<void>('clearLogs');
  }

  @override
  Stream<dynamic> events() => _events.receiveBroadcastStream();
}

class VpnController extends ChangeNotifier {
  static const _prefRegion = 'selected_region';
  static const _prefProtocol = 'preferred_protocol';
  static const _prefUpstream = 'upstream_proxy_url';
  static const int _maxHistory = 45;
  static const int _maxLogs = 300;

  final VpnBridge _bridge;

  TunnelSnapshot _snapshot = const TunnelSnapshot();
  final List<String> _logs = [];
  final List<double> _downHistory = List<double>.filled(_maxHistory, 0.0, growable: true);
  final List<double> _upHistory = List<double>.filled(_maxHistory, 0.0, growable: true);

  String _selectedRegion = '';
  String _preferredProtocol = 'AUTO';
  String _upstreamProxyUrl = '';
  bool _initialized = false;

  StreamSubscription<dynamic>? _eventSub;
  Timer? _clockTimer;

  VpnController({VpnBridge? bridge}) : _bridge = bridge ?? MethodChannelVpnBridge();

  TunnelSnapshot get snapshot => _snapshot;
  List<String> get logs => List.unmodifiable(_logs);
  List<double> get downHistory => List.unmodifiable(_downHistory);
  List<double> get upHistory => List.unmodifiable(_upHistory);
  String get selectedRegion => _selectedRegion;
  String get preferredProtocol => _preferredProtocol;
  String get upstreamProxyUrl => _upstreamProxyUrl;
  bool get initialized => _initialized;

  Duration get connectedDuration {
    if (_snapshot.phase != ConnectionPhase.connected || _snapshot.connectedSinceMs <= 0) {
      return Duration.zero;
    }
    final diff = DateTime.now().millisecondsSinceEpoch - _snapshot.connectedSinceMs;
    return diff > 0 ? Duration(milliseconds: diff) : Duration.zero;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedRegion = (prefs.getString(_prefRegion) ?? '').toUpperCase();
    _preferredProtocol = prefs.getString(_prefProtocol) ?? 'AUTO';
    _upstreamProxyUrl = prefs.getString(_prefUpstream) ?? '';

    try {
      final state = await _bridge.getState();
      _applySnapshot(state);
    } catch (_) {
      // Initial platform query can be absent in widget tests.
    }

    _eventSub = _bridge.events().listen(
      _onEvent,
      onError: (_) {},
    );

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_snapshot.phase == ConnectionPhase.connected) {
        notifyListeners();
      }
    });

    _initialized = true;
    notifyListeners();
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'];
    if (type == 'log') {
      final line = event['line']?.toString();
      if (line != null && line.isNotEmpty) {
        if (_logs.length >= _maxLogs) _logs.removeAt(0);
        _logs.add(line);
        notifyListeners();
      }
      return;
    }

    final data = event['data'];
    if (data is Map) {
      _applySnapshot(data);
      notifyListeners();
    }
  }

  void _applySnapshot(Map<Object?, Object?> data) {
    final next = TunnelSnapshot.fromMap(data);

    // Preserve user's saved selection when tunnel is idle.
    final effectiveSelected = next.phase == ConnectionPhase.disconnected
        ? _selectedRegion
        : next.selectedRegion;

    _snapshot = next.copyWith(selectedRegion: effectiveSelected);

    if (next.phase == ConnectionPhase.connected || next.phase == ConnectionPhase.connecting) {
      _downHistory.add(next.downSpeedBps.toDouble());
      if (_downHistory.length > _maxHistory) _downHistory.removeAt(0);
      _upHistory.add(next.upSpeedBps.toDouble());
      if (_upHistory.length > _maxHistory) _upHistory.removeAt(0);
    } else if (next.phase == ConnectionPhase.disconnected) {
      _downHistory.fillRange(0, _downHistory.length, 0.0);
      _upHistory.fillRange(0, _upHistory.length, 0.0);
    }

    final rawLogs = data['logs'];
    if (rawLogs is List) {
      _logs
        ..clear()
        ..addAll(rawLogs.map((e) => e.toString()));
    }
  }

  Future<bool> toggleConnection() async {
    if (_snapshot.phase == ConnectionPhase.connected ||
        _snapshot.phase == ConnectionPhase.connecting) {
      await _bridge.stopVpn();
      return true;
    }

    _snapshot = _snapshot.copyWith(phase: ConnectionPhase.connecting);
    notifyListeners();

    final authorized = await _bridge.startVpn(
      region: _selectedRegion,
      protocol: _preferredProtocol,
      upstreamProxyUrl: _upstreamProxyUrl,
    );

    if (!authorized) {
      _snapshot = _snapshot.copyWith(phase: ConnectionPhase.disconnected);
      notifyListeners();
    }
    return authorized;
  }

  Future<void> selectRegion(String code) async {
    final normalized = code.trim().toUpperCase();
    if (_selectedRegion == normalized &&
        _snapshot.selectedRegion == normalized) {
      return;
    }
    _selectedRegion = normalized;
    _snapshot = _snapshot.copyWith(selectedRegion: normalized);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefRegion, normalized);

    if (_snapshot.phase == ConnectionPhase.connected ||
        _snapshot.phase == ConnectionPhase.connecting) {
      await _bridge.restartVpn(
        region: _selectedRegion,
        protocol: _preferredProtocol,
        upstreamProxyUrl: _upstreamProxyUrl,
      );
    }
  }

  Future<void> updateSettings({
    required String preferredProtocol,
    required String upstreamProxyUrl,
  }) async {
    final trimmedProxy = upstreamProxyUrl.trim();
    final changed =
        preferredProtocol != _preferredProtocol || trimmedProxy != _upstreamProxyUrl;
    _preferredProtocol = preferredProtocol;
    _upstreamProxyUrl = trimmedProxy;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefProtocol, preferredProtocol);
    await prefs.setString(_prefUpstream, trimmedProxy);

    if (changed &&
        (_snapshot.phase == ConnectionPhase.connected ||
            _snapshot.phase == ConnectionPhase.connecting)) {
      await _bridge.restartVpn(
        region: _selectedRegion,
        protocol: _preferredProtocol,
        upstreamProxyUrl: _upstreamProxyUrl,
      );
    }
  }

  Future<void> clearLogs() async {
    _logs.clear();
    notifyListeners();
    await _bridge.clearLogs();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }
}
