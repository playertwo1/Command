import 'package:command/core/core.dart';
import 'package:command/src/connection/pc_store.dart';
import 'package:command/src/home/status_page.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSignalRService extends SignalRService {
  @override
  Future<void> updateUrl(String baseUrl, {String? apiKey}) async {
    currentUrl.value = baseUrl;
  }
}

class FakeLatencyClient extends CommandClient {
  int nextLatencyMs = 20;
  String mockHostName = 'DESKTOP-COMMAND';
  int pingCallCount = 0;

  FakeLatencyClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<PingResult> ping() async {
    pingCallCount++;
    return PingResult(
      hostName: mockHostName,
      status: 'ok',
      serverTimeUtc: DateTime.now().toUtc(),
      latencyMs: nextLatencyMs,
    );
  }

  @override
  Future<List<AllowedApp>> getApps() async => [];

  @override
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async => [];

  @override
  Future<List<TransferItem>> listOutboundTransfers({String? deviceId}) async => [];

  @override
  Future<List<WindowsServiceItem>> getServices({List<String>? names}) async => [];

  @override
  Future<TopProcessesData> getTopProcesses({int count = 5}) async =>
      const TopProcessesData();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PcStore.currentId = null;
  });

  group('PingResult Model Tests (Fase S8)', () {
    test('PingResult deserializa JSON e armazena latencyMs corretamente', () {
      final now = DateTime.now().toUtc();
      final json = {
        'status': 'ok',
        'hostName': 'GAMING-RIG',
        'serverTimeUtc': now.toIso8601String(),
      };

      final result = PingResult.fromJson(json, 32);

      expect(result.status, 'ok');
      expect(result.hostName, 'GAMING-RIG');
      expect(result.latencyMs, 32);
      expect(result.serverTimeUtc.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
    });

    test('PingResult aceita chaves PascalCase do backend ASP.NET', () {
      final json = {
        'Status': 'ok',
        'HostName': 'SERVER-NODE',
        'ServerTimeUtc': '2026-10-17T20:00:00.000Z',
      };

      final result = PingResult.fromJson(json, 15);

      expect(result.status, 'ok');
      expect(result.hostName, 'SERVER-NODE');
      expect(result.latencyMs, 15);
    });
  });

  group('StatusPage Latency Badge Widget Tests (Fase S8)', () {
    testWidgets('exibe badge de latência verde para RTT <= 50ms',
        (tester) async {
      final fakeClient = FakeLatencyClient()..nextLatencyMs = 28;
      final fakeSignalR = FakeSignalRService();
      fakeSignalR.connectionStatus.value = 'Connected';

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            client: fakeClient,
            signalRService: fakeSignalR,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final latencyFinder = find.byKey(const ValueKey('latency_badge'));
      expect(latencyFinder, findsOneWidget);
      expect(find.text('28 ms'), findsOneWidget);

      final container = tester.widget<Container>(latencyFinder);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0xFF10B981).withValues(alpha: 0.4));
    });

    testWidgets('calcula jitter e exibe cor âmbar para RTT entre 51ms e 150ms',
        (tester) async {
      final fakeClient = FakeLatencyClient()..nextLatencyMs = 40;
      final fakeSignalR = FakeSignalRService();
      fakeSignalR.connectionStatus.value = 'Connected';

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            client: fakeClient,
            signalRService: fakeSignalR,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('40 ms'), findsOneWidget);

      // Simula segunda medição com variação de latência (RTT = 85ms, jitter = |85 - 40| = 45ms)
      fakeClient.nextLatencyMs = 85;
      await tester.tap(find.byKey(const ValueKey('latency_badge')));
      await tester.pumpAndSettle();

      expect(find.text('85 ms (±45)'), findsOneWidget);

      final container = tester.widget<Container>(find.byKey(const ValueKey('latency_badge')));
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0xFFF59E0B).withValues(alpha: 0.4));
    });

    testWidgets('exibe cor vermelha para RTT > 150ms', (tester) async {
      final fakeClient = FakeLatencyClient()..nextLatencyMs = 220;
      final fakeSignalR = FakeSignalRService();
      fakeSignalR.connectionStatus.value = 'Connected';

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            client: fakeClient,
            signalRService: fakeSignalR,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final latencyFinder = find.byKey(const ValueKey('latency_badge'));
      expect(latencyFinder, findsOneWidget);
      expect(find.text('220 ms'), findsOneWidget);

      final container = tester.widget<Container>(latencyFinder);
      final decoration = decorationOf(container);
      final border = decoration.border as Border;
      expect(border.top.color, const Color(0xFFEF4444).withValues(alpha: 0.4));
    });

    testWidgets('não exibe badge de latência quando desconectado (Offline)',
        (tester) async {
      final fakeClient = FakeLatencyClient()..nextLatencyMs = 25;
      final fakeSignalR = FakeSignalRService();
      fakeSignalR.connectionStatus.value = 'Disconnected';

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            client: fakeClient,
            signalRService: fakeSignalR,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('latency_badge')), findsNothing);
      expect(find.text('Offline'), findsOneWidget);
    });
  });
}

BoxDecoration decorationOf(Container container) =>
    container.decoration as BoxDecoration;
