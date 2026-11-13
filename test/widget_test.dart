import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psiphon_flutter/main.dart';
import 'package:psiphon_flutter/models/region.dart';
import 'package:psiphon_flutter/services/vpn_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVpnBridge implements VpnBridge {
  final _events = StreamController<dynamic>.broadcast();
  String? lastStartedRegion;
  String? lastRestartedRegion;
  bool stopped = false;

  @override
  Future<void> clearLogs() async {}

  @override
  Stream<dynamic> events() => _events.stream;

  @override
  Future<Map<Object?, Object?>> getState() async => const {'status': 'disconnected'};

  @override
  Future<void> restartVpn({
    required String region,
    required String protocol,
    required String upstreamProxyUrl,
  }) async {
    lastRestartedRegion = region;
  }

  @override
  Future<bool> startVpn({
    required String region,
    required String protocol,
    required String upstreamProxyUrl,
  }) async {
    lastStartedRegion = region;
    _events.add({
      'type': 'state',
      'data': {
        'status': 'connected',
        'selectedRegion': region,
        'connectedRegion': region.isEmpty ? 'US' : region,
        'availableRegions': ['DE', 'JP', 'US'],
        'activeProtocol': 'OSSH',
        'bytesSent': 2048,
        'bytesReceived': 16384,
      },
    });
    return true;
  }

  @override
  Future<void> stopVpn() async {
    stopped = true;
    _events.add({
      'type': 'state',
      'data': {'status': 'disconnected'},
    });
  }

  Future<void> close() => _events.close();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('all 49 Psiphon countries are present and unlocked alongside auto', () {
    expect(kAllPsiphonRegions.first.isAuto, isTrue);
    expect(kAllPsiphonRegions.length, 50); // Auto + 49 individual countries
    final codes = kAllPsiphonRegions.map((r) => r.code).toSet();
    expect(codes, containsAll(<String>['US', 'DE', 'GB', 'JP', 'SG', 'NL', 'ZA']));
  });

  testWidgets('renders Psiphon 4 orb home screen and opens full region sheet',
      (WidgetTester tester) async {
    final bridge = _FakeVpnBridge();
    final controller = VpnController(bridge: bridge);
    await controller.init();

    await tester.pumpWidget(PsiphonApp(controller: controller));
    await tester.pump();

    expect(find.text('Psiphon'), findsOneWidget);
    expect(find.text('Start your connection'), findsOneWidget);
    expect(find.text('Best performance'), findsOneWidget);

    await tester.tap(find.text('Best performance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Server Region'), findsOneWidget);
    expect(find.text('49 countries'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Germany');
    await tester.pump();
    await tester.tap(find.text('Germany'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.selectedRegion, 'DE');
    expect(find.text('Germany'), findsOneWidget);

    await controller.toggleConnection();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(bridge.lastStartedRegion, 'DE');
    expect(find.text('Protected in Germany'), findsOneWidget);

    await controller.selectRegion('JP');
    await tester.pump();
    expect(bridge.lastRestartedRegion, 'JP');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await bridge.close();
    controller.dispose();
  });
}
