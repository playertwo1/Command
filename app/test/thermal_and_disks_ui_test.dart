import 'package:command/src/home/status_page.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fase S4 - Telemetria Térmica, Bateria e Múltiplos Discos', () {
    test('SystemStats.fromJson realiza parse completo de métricas v0.2', () {
      final json = {
        'cpuUsage': 35.5,
        'ramUsage': 48.2,
        'ramTotal': 16384.0,
        'ramAvailable': 8487.0,
        'gpuUsage': 20.0,
        'cpuTempC': 62.4,
        'gpuTempC': 74.8,
        'hasBattery': true,
        'batteryPercent': 88,
        'isCharging': true,
        'uptimeSeconds': 3600,
        'disks': [
          {
            'name': 'C:',
            'label': 'Windows',
            'totalGB': 919.0,
            'availableGB': 436.5,
            'usagePercent': 52.5,
          },
          {
            'name': 'D:',
            'label': 'Backup',
            'totalGB': 1863.0,
            'availableGB': 1200.0,
            'usagePercent': 35.6,
          }
        ],
        'history': [
          {
            'timestampUtc': '2026-10-17T19:00:00Z',
            'cpu': 30.0,
            'ram': 48.0,
            'gpu': 15.0,
            'cpuTempC': 61.0,
            'gpuTempC': 73.0,
          }
        ]
      };

      final stats = SystemStats.fromJson(json);

      expect(stats.cpuUsage, 35.5);
      expect(stats.cpuTempC, 62.4);
      expect(stats.gpuTempC, 74.8);
      expect(stats.hasBattery, isTrue);
      expect(stats.batteryPercent, 88);
      expect(stats.isCharging, isTrue);
      expect(stats.disks.length, 2);
      expect(stats.disks[0].name, 'C:');
      expect(stats.disks[0].label, 'Windows');
      expect(stats.disks[0].usagePercent, 52.5);
      expect(stats.disks[1].name, 'D:');
      expect(stats.history.length, 1);
      expect(stats.history[0].cpuTempC, 61.0);
    });

    testWidgets('StatusPage exibe badges de temperatura na CPU e GPU e pill de bateria',
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
        cpuUsage: 45.0,
        ramUsage: 55.0,
        gpuUsage: 30.0,
        cpuTempC: 58.0,
        gpuTempC: 76.5,
        hasBattery: true,
        batteryPercent: 92,
        isCharging: true,
        disks: [
          DiskVolume(
            name: 'C:',
            label: 'Sistema',
            totalGb: 500.0,
            availableGb: 200.0,
            usagePercent: 60.0,
          ),
          DiskVolume(
            name: 'D:',
            label: 'Projetos',
            totalGb: 1000.0,
            availableGb: 800.0,
            usagePercent: 20.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
          ),
        ),
      );

      // Verifica temperaturas
      expect(find.text('58°C'), findsOneWidget); // CPU badge
      expect(find.text('77°C'), findsOneWidget); // GPU badge arredondada

      // Verifica pill de bateria no header
      expect(find.text('92%'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);

      // Verifica card de volumes de disco
      expect(find.text('Volumes de Disco'), findsOneWidget);
      expect(find.text('C:'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('D:'), findsOneWidget);
      expect(find.text('Projetos'), findsOneWidget);
    });

    testWidgets('StatusPage não exibe bateria quando hasBattery é falso',
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
        cpuUsage: 10.0,
        hasBattery: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatusPage(
            isFullscreen: false,
            onToggleFullscreen: () {},
            signalRService: signalR,
          ),
        ),
      );

      expect(find.byIcon(Icons.battery_charging_full), findsNothing);
      expect(find.byIcon(Icons.bolt), findsNothing);
    });
  });
}
