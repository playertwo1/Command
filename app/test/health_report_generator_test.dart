import 'package:command/core/core.dart';
import 'package:command/src/connection/pc_store.dart';
import 'package:command/src/home/status_page.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:command/src/services/health_report_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSignalRService extends SignalRService {
  @override
  Future<void> updateUrl(String baseUrl, {String? apiKey}) async {
    currentUrl.value = baseUrl;
  }
}

class FakeReportClient extends CommandClient {
  FakeReportClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<PingResult> ping() async => PingResult(
        hostName: 'DESKTOP-TEST',
        status: 'ok',
        serverTimeUtc: DateTime.now().toUtc(),
        latencyMs: 14,
      );

  @override
  Future<List<AllowedApp>> getApps() async => [];

  @override
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async => [];

  @override
  Future<List<TransferItem>> listOutboundTransfers({String? deviceId}) async => [];

  @override
  Future<List<WindowsServiceItem>> getServices({List<String>? names}) async => [
        const WindowsServiceItem(
          name: 'Tailscale',
          displayName: 'Tailscale Service',
          status: 'Running',
          isRunning: true,
        ),
      ];

  @override
  Future<TopProcessesData> getTopProcesses({int count = 5}) async =>
      const TopProcessesData(
        byMemory: [
          TopProcessItem(
            pid: 1010,
            name: 'chrome',
            memoryMb: 800.0,
            cpuPercent: 1.5,
          ),
        ],
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PcStore.currentId = null;
  });

  group('HealthReportGenerator Unit Tests (Fase S9)', () {
    const pc = SavedPc(
      id: 'pc-123',
      name: 'Workstation Extreme',
      ip: '192.168.1.100',
      port: '4787',
      apiKey: 'SUPER-SECRET-TOKEN-DO-NOT-LEAK-XYZ',
    );

    final stats = SystemStats(
      cpuUsage: 45.2,
      cpuTempC: 62.5,
      ramUsage: 70.0,
      ramTotal: 32768,
      ramAvailable: 9830,
      gpuUsage: 18.0,
      gpuTempC: 54.0,
      batteryPercent: 88,
      isCharging: true,
      hasBattery: true,
      uptimeSeconds: 51720, // 14h 22m
      disks: [
        DiskVolume(
          name: 'C:',
          label: 'System OS',
          totalGb: 931.3,
          availableGb: 372.5,
          usagePercent: 60.0,
        ),
      ],
    );

    final services = [
      const WindowsServiceItem(
        name: 'Tailscale',
        displayName: 'Tailscale IPN',
        status: 'Running',
        isRunning: true,
      ),
      const WindowsServiceItem(
        name: 'Spooler',
        displayName: 'Print Spooler',
        status: 'Stopped',
        isRunning: false,
      ),
    ];

    const topProcesses = TopProcessesData(
      byMemory: [
        TopProcessItem(
          pid: 1234,
          name: 'chrome',
          memoryMb: 1450.5,
          cpuPercent: 1.2,
        ),
      ],
      byCpu: [
        TopProcessItem(
          pid: 5678,
          name: 'code',
          memoryMb: 620.0,
          cpuPercent: 12.4,
        ),
      ],
    );

    test('maskIp mascara adequadamente o último octeto de endereços IPv4', () {
      expect(HealthReportGenerator.maskIp('192.168.1.100'), '192.168.*.***');
      expect(HealthReportGenerator.maskIp('10.0.2.15'), '10.0.*.***');
      expect(HealthReportGenerator.maskIp(null), 'N/A');
      expect(HealthReportGenerator.maskIp(''), 'N/A');
    });

    test('generateJsonMap gera estrutura completa e NUNCA inclui apiKey ou tokens', () {
      final input = HealthReportInput(
        pc: pc,
        stats: stats,
        services: services,
        topProcesses: topProcesses,
        latencyMs: 18,
        jitterMs: 3,
        sanitize: true,
      );

      final jsonMap = HealthReportGenerator.generateJsonMap(input);
      final jsonString = HealthReportGenerator.generateJson(input);

      // Verificação de Sanitização Estrita (Regra 4 do Roadmap v0.2)
      expect(jsonString.contains('SUPER-SECRET-TOKEN-DO-NOT-LEAK-XYZ'), isFalse);
      expect(jsonString.contains('apiKey'), isFalse);
      expect(jsonMap['pc']['host'], '192.168.*.***');

      // Verificação da estrutura técnica
      expect(jsonMap['version'], '0.2.0');
      expect(jsonMap['pc']['name'], 'Workstation Extreme');
      expect(jsonMap['pc']['latencyMs'], 18);
      expect(jsonMap['pc']['jitterMs'], 3);

      final telemetry = jsonMap['telemetry'] as Map<String, dynamic>;
      expect(telemetry['cpuUsagePercent'], 45.2);
      expect(telemetry['cpuTempC'], 62.5);
      expect(telemetry['ramUsagePercent'], 70.0);
      expect(telemetry['gpuTempC'], 54.0);
      expect(telemetry['batteryPercent'], 88);
      expect(telemetry['isCharging'], true);
      expect(telemetry['uptime'], '14h 22m');

      final disks = jsonMap['disks'] as List;
      expect(disks.length, 1);
      expect(disks[0]['name'], 'C:');
      expect(disks[0]['usagePercent'], 60.0);

      final servicesList = jsonMap['services'] as List;
      expect(servicesList.length, 2);
      expect(servicesList[0]['name'], 'Tailscale');
      expect(servicesList[0]['status'], 'Running');

      final procs = jsonMap['topProcesses'] as Map<String, dynamic>;
      expect((procs['byMemory'] as List).first['name'], 'chrome');
      expect((procs['byCpu'] as List).first['name'], 'code');
    });

    test('generateJson preserva IP completo quando sanitize = false sem expor apiKey', () {
      final input = HealthReportInput(
        pc: pc,
        stats: stats,
        sanitize: false,
      );

      final jsonMap = HealthReportGenerator.generateJsonMap(input);
      final jsonString = HealthReportGenerator.generateJson(input);

      expect(jsonMap['pc']['host'], '192.168.1.100');
      expect(jsonString.contains('SUPER-SECRET-TOKEN-DO-NOT-LEAK-XYZ'), isFalse);
    });

    test('generateMarkdown formata relatório legível com tabelas e sem credenciais', () {
      final input = HealthReportInput(
        pc: pc,
        stats: stats,
        services: services,
        topProcesses: topProcesses,
        latencyMs: 24,
        jitterMs: 5,
        sanitize: true,
      );

      final md = HealthReportGenerator.generateMarkdown(input);

      expect(md.contains('# Relatório de Saúde do Sistema — Command'), isTrue);
      expect(md.contains('192.168.*.***'), isTrue);
      expect(md.contains('SUPER-SECRET-TOKEN-DO-NOT-LEAK-XYZ'), isFalse);
      expect(md.contains('45.2%'), isTrue);
      expect(md.contains('62.5 °C'), isTrue);
      expect(md.contains('54.0 °C'), isTrue);
      expect(md.contains('88% (Carregando)'), isTrue);
      expect(md.contains('`C:`'), isTrue);
      expect(md.contains('`Tailscale`'), isTrue);
      expect(md.contains('`chrome`'), isTrue);
      expect(md.contains('`code`'), isTrue);
      expect(md.contains('24 ms (±5 ms)'), isTrue);
      expect(md.contains('100% IA-Independente'), isTrue);
    });

    test('generateMarkdown tolera dados nulos/vazios com degradação graciosa', () {
      final input = HealthReportInput(
        pc: null,
        stats: null,
        services: const [],
        topProcesses: null,
        sanitize: true,
      );

      final md = HealthReportGenerator.generateMarkdown(input);
      expect(md.contains('Desconhecido'), isTrue);
      expect(md.contains('N/A'), isTrue);
      expect(md.contains('_Nenhum disco detectado ou telemetria indisponível._'), isTrue);
      expect(md.contains('_Nenhum serviço monitorado na allowlist._'), isTrue);
    });
  });

  group('StatusPage Health Report Export Widget Tests (Fase S9)', () {
    testWidgets('exibe botão de exportar na AppBar e abre modal de diagnóstico com preview',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeClient = FakeReportClient();
      final fakeSignalR = FakeSignalRService();
      fakeSignalR.connectionStatus.value = 'Connected';
      fakeSignalR.systemStats.value = SystemStats(
        cpuUsage: 35.0,
        cpuTempC: 58.0,
        disks: [
          DiskVolume(name: 'C:', label: 'Windows', totalGb: 500, availableGb: 200, usagePercent: 60),
        ],
      );

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

      // Botão de exportação no AppBar
      expect(find.byKey(const ValueKey('export_health_report_button')), findsOneWidget);

      // Clicar no botão da AppBar para abrir o modal
      await tester.tap(find.byKey(const ValueKey('export_health_report_button')));
      await tester.pumpAndSettle();

      // Modal aberto com título e preview
      expect(find.text('Diagnóstico do PC'), findsOneWidget);
      expect(find.text('Sanitizar dados sensíveis'), findsOneWidget);
      expect(find.byKey(const ValueKey('report_preview_text')), findsOneWidget);
      expect(find.byKey(const ValueKey('export_dialog_copy_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('export_dialog_share_button')), findsOneWidget);

      // Clicar em Copiar
      await tester.tap(find.byKey(const ValueKey('export_dialog_copy_button')));
      await tester.pumpAndSettle();

      expect(find.text('Relatório copiado para a área de transferência!'), findsOneWidget);
    });
  });
}
