import 'package:droiddeck/src/home/status_page.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatusPage exibe métricas de telemetria e estado de conexão',
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
      cpuUsage: 25.4,
      ramUsage: 60.0,
      ramTotal: 16384,
      ramAvailable: 6553.6,
      diskUsage: 42.1,
      diskTotalGb: 500.0,
      diskAvailableGb: 289.5,
      netDown: 1250.5,
      netUp: 85.0,
      gpuUsage: 18.0,
      uptimeSeconds: 7320, // 2h 2m
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

    // Header e status
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);

    // Métricas de Hardware
    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('25.4%'), findsOneWidget);

    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('60.0%'), findsOneWidget);

    expect(find.text('Disco'), findsOneWidget);
    expect(find.text('42.1%'), findsOneWidget);

    expect(find.text('GPU'), findsOneWidget);
    expect(find.text('18.0%'), findsOneWidget);

    // Rede e Uptime
    expect(find.text('Rede'), findsOneWidget);
    expect(find.text('1250.5 KB/s'), findsOneWidget);
    expect(find.text('85.0 KB/s'), findsOneWidget);

    expect(find.text('Tempo ligado'), findsOneWidget);
    expect(find.text('2h 2m'), findsOneWidget);

    // Hermes IA
    expect(find.text('Hermes IA'), findsOneWidget);
    expect(find.text('Não configurado'), findsOneWidget);
  });
}
