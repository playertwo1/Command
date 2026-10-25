import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/home/metric_sparkline.dart';
import 'package:droiddeck/src/home/status_page.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDiagnosticsClient extends DroidDeckClient {
  FakeDiagnosticsClient() : super(baseUrl: 'http://localhost:4787');

  List<WindowsServiceItem> mockServices = [
    const WindowsServiceItem(
      name: 'Tailscale',
      displayName: 'Tailscale Service',
      status: 'Running',
      isRunning: true,
    ),
    const WindowsServiceItem(
      name: 'Spooler',
      displayName: 'Print Spooler',
      status: 'Stopped',
      isRunning: false,
    ),
    const WindowsServiceItem(
      name: 'docker',
      displayName: 'Docker Engine',
      status: 'NotFound',
      isRunning: false,
    ),
  ];

  TopProcessesData mockTopProcesses = const TopProcessesData(
    byMemory: [
      TopProcessItem(
        pid: 10420,
        name: 'qemu-system-x86_64',
        memoryMb: 3512.8,
        cpuPercent: 2.1,
      ),
      TopProcessItem(
        pid: 8840,
        name: 'chrome',
        memoryMb: 1240.5,
        cpuPercent: 1.0,
      ),
    ],
    byCpu: [
      TopProcessItem(
        pid: 22100,
        name: 'Antigravity',
        memoryMb: 850.2,
        cpuPercent: 18.5,
      ),
      TopProcessItem(
        pid: 5432,
        name: 'Code',
        memoryMb: 420.0,
        cpuPercent: 5.4,
      ),
    ],
  );

  @override
  Future<List<AllowedApp>> getApps() async => [];

  @override
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async => [];

  @override
  Future<List<TransferItem>> listOutboundTransfers({String? deviceId}) async => [];

  @override
  Future<List<WindowsServiceItem>> getServices({List<String>? names}) async => mockServices;

  @override
  Future<TopProcessesData> getTopProcesses({int count = 5}) async => mockTopProcesses;

  @override
  Future<PingResult> ping() async => PingResult(
        hostName: 'TEST-HOST',
        status: 'ok',
        serverTimeUtc: DateTime.now().toUtc(),
        latencyMs: 15,
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fase S5 — Sparklines 60s, Serviços Windows e Top Processos', () {
    testWidgets('MetricSparkline renderiza sem erros com diferentes quantidades de dados',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MetricSparkline(values: [10.0, 25.0, 50.0, 75.0, 40.0]),
                MetricSparkline(values: [55.0]),
                MetricSparkline(values: []),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(MetricSparkline), findsNWidgets(3));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('StatusPage renderiza Histórico de Carga (60s) quando history não está vazio',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final signalR = SignalRService();
      signalR.connectionStatus.value = 'Connected';
      signalR.systemStats.value = SystemStats(
        cpuUsage: 32.5,
        ramUsage: 64.0,
        ramTotal: 16384,
        ramAvailable: 5898,
        history: [
          MetricSample(
            timestampUtc: DateTime.now().subtract(const Duration(seconds: 2)),
            cpu: 28.0,
            ram: 63.0,
          ),
          MetricSample(
            timestampUtc: DateTime.now().subtract(const Duration(seconds: 1)),
            cpu: 32.5,
            ram: 64.0,
          ),
        ],
      );

      final client = FakeDiagnosticsClient();

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
            client: client,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card de Histórico 60s
      expect(find.text('Histórico de Carga (60s)'), findsOneWidget);
      expect(find.byType(MetricSparkline), findsNWidgets(2)); // CPU e RAM
    });

    testWidgets('StatusPage exibe card Serviços do Windows com badges Ativo, Parado e Ausente',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final signalR = SignalRService();
      signalR.connectionStatus.value = 'Connected';
      signalR.systemStats.value = SystemStats(cpuUsage: 20.0);

      final client = FakeDiagnosticsClient();

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
            client: client,
          ),
        ),
      );

      await tester.pump();

      // Rola para exibir o Card de Serviços
      await tester.scrollUntilVisible(
        find.text('Serviços do Windows'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Card de Serviços
      expect(find.text('Serviços do Windows'), findsOneWidget);
      expect(find.text('Tailscale Service'), findsOneWidget);
      expect(find.text('Ativo'), findsOneWidget);

      expect(find.text('Print Spooler'), findsOneWidget);
      expect(find.text('Parado'), findsOneWidget);

      expect(find.text('Docker Engine'), findsOneWidget);
      expect(find.text('Ausente'), findsOneWidget);
    });

    testWidgets('StatusPage exibe card Top Processos e alterna entre Memória e CPU',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final signalR = SignalRService();
      signalR.connectionStatus.value = 'Connected';
      signalR.systemStats.value = SystemStats(cpuUsage: 20.0);

      final client = FakeDiagnosticsClient();

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
            client: client,
          ),
        ),
      );

      await tester.pump();

      // Rola para exibir o Card de Top Processos
      await tester.scrollUntilVisible(
        find.text('Top Processos'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Card de Top Processos inicial em "Por Memória (RAM)"
      expect(find.text('Top Processos'), findsOneWidget);
      expect(find.text('Por Memória (RAM)'), findsOneWidget);
      expect(find.text('Por CPU'), findsOneWidget);

      expect(find.text('qemu-system-x86_64'), findsOneWidget);
      expect(find.text('3512.8 MB'), findsOneWidget);
      expect(find.text('PID 10420'), findsOneWidget);

      expect(find.text('chrome'), findsOneWidget);
      expect(find.text('1240.5 MB'), findsOneWidget);

      // Garante visibilidade e alterna para "Por CPU"
      await tester.ensureVisible(find.text('Por CPU'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por CPU'));
      await tester.pumpAndSettle();

      expect(find.text('Antigravity'), findsOneWidget);
      expect(find.text('18.5%'), findsOneWidget);
      expect(find.text('PID 22100'), findsOneWidget);

      expect(find.text('Code'), findsOneWidget);
      expect(find.text('5.4%'), findsOneWidget);
    });
  });
}
