import 'package:command/src/dock/dock_dashboard_page.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DockDashboardPage Widget Tests', () {
    testWidgets('renderiza telemetria em alto contraste e botões de ação', (tester) async {
      int lockCalls = 0;
      int captureCalls = 0;

      final stats = SystemStats(
        cpuUsage: 42.5,
        ramUsage: 68.2,
        gpuUsage: 25.0,
        cpuTempC: 58.0,
        uptimeSeconds: 7320, // 2h 2m
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DockDashboardPage(
            stats: stats,
            pcName: 'DESKTOP-ULTRA',
            onLockPc: () => lockCalls++,
            onCaptureScreen: () => captureCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cabeçalho e Uptime
      expect(find.text('DESKTOP-ULTRA'), findsOneWidget);
      expect(find.text('Uptime: 2h 2m'), findsOneWidget);

      // Gauges de telemetria
      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('42.5%'), findsOneWidget);
      expect(find.text('RAM'), findsOneWidget);
      expect(find.text('68.2%'), findsOneWidget);
      expect(find.text('GPU'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('TEMP'), findsOneWidget);
      expect(find.text('58°C'), findsOneWidget);

      // Botões rápidos
      expect(find.text('Bloquear PC'), findsOneWidget);
      expect(find.text('Capturar Tela'), findsOneWidget);
      expect(find.text('Sair do Dock'), findsOneWidget);

      // Toca em Bloquear PC
      await tester.tap(find.text('Bloquear PC'));
      await tester.pumpAndSettle();
      expect(lockCalls, 1);

      // Toca em Capturar Tela
      await tester.tap(find.text('Capturar Tela'));
      await tester.pumpAndSettle();
      expect(captureCalls, 1);

    });
  });
}
