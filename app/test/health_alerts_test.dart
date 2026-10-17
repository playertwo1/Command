import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droiddeck/src/services/health_alert_service.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:droiddeck/src/config/health_alert_settings_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HealthAlertService Unit Tests', () {
    test('dispara alerta crítico de CPU quando usage >= threshold', () {
      final service = HealthAlertService();
      service.clearAll();

      final stats = SystemStats(
        cpuUsage: 95.0,
        ramUsage: 40.0,
        diskUsage: 50.0,
      );

      service.evaluate(stats);

      expect(service.activeAlerts.length, 1);
      final alert = service.activeAlerts.first;
      expect(alert.id, 'cpu');
      expect(alert.severity, AlertSeverity.critical);
      expect(alert.title, contains('CPU'));
    });

    test('limpa alerta de CPU quando métrica retorna ao normal', () {
      final service = HealthAlertService();
      service.clearAll();

      final highCpu = SystemStats(
        cpuUsage: 95.0,
        ramUsage: 40.0,
        diskUsage: 50.0,
      );
      service.evaluate(highCpu);
      expect(service.activeAlerts.length, 1);

      final normalCpu = SystemStats(
        cpuUsage: 35.0,
        ramUsage: 40.0,
        diskUsage: 50.0,
      );
      service.evaluate(normalCpu);
      expect(service.activeAlerts.isEmpty, isTrue);
    });

    test('cooldown previne múltiplos alertas duplicados dentro da janela', () {
      final service = HealthAlertService();
      service.clearAll();
      service.thresholds.cooldownSeconds = 60;

      final stats = SystemStats(
        cpuUsage: 92.0,
        ramUsage: 92.0,
        diskUsage: 50.0,
      );

      service.evaluate(stats);
      expect(service.activeAlerts.length, 2); // CPU e RAM

      // Avaliação imediata subsequente não duplica
      service.evaluate(stats);
      expect(service.activeAlerts.length, 2);
    });

    test('dismissAlert remove alerta da lista ativa', () {
      final service = HealthAlertService();
      service.clearAll();

      final stats = SystemStats(
        cpuUsage: 95.0,
        ramUsage: 40.0,
        diskUsage: 50.0,
      );

      service.evaluate(stats);
      expect(service.activeAlerts.length, 1);

      service.dismissAlert('cpu');
      expect(service.activeAlerts.isEmpty, isTrue);

      // Avaliação subsequente dentro do cooldown não reativa
      service.evaluate(stats);
      expect(service.activeAlerts.isEmpty, isTrue);
    });

    test('detecta superaquecimento e bateria fraca no PC', () {
      final service = HealthAlertService();
      service.clearAll();

      final stats = SystemStats(
        cpuUsage: 10.0,
        ramUsage: 20.0,
        diskUsage: 30.0,
        cpuTempC: 89.0,
        hasBattery: true,
        isCharging: false,
        batteryPercent: 10,
      );

      service.evaluate(stats);

      expect(service.activeAlerts.length, 2);
      expect(service.activeAlerts.any((a) => a.id == 'temp' && a.severity == AlertSeverity.critical), isTrue);
      expect(service.activeAlerts.any((a) => a.id == 'battery' && a.severity == AlertSeverity.warning), isTrue);
    });
  });

  group('HealthAlertSettingsPage Widget Tests', () {
    testWidgets('renderiza sliders de configuração e botão salvar', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = HealthAlertService();

      await tester.pumpWidget(
        MaterialApp(
          home: HealthAlertSettingsPage(service: service),
        ),
      );

      expect(find.text('Limiares de Alerta'), findsOneWidget);
      expect(find.text('Uso de CPU'), findsOneWidget);
      expect(find.text('Uso de Memória RAM'), findsOneWidget);
      expect(find.text('Temperatura Máxima (CPU/GPU)'), findsOneWidget);
      expect(find.text('Uso de Armazenamento'), findsOneWidget);
      expect(find.text('Bateria Restante Baixa'), findsOneWidget);
      expect(find.text('Tempo de Cooldown'), findsOneWidget);
      expect(find.text('Salvar Limiares'), findsOneWidget);

      // Toca em Restaurar Padrões
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pumpAndSettle();

      expect(find.text('90%'), findsNWidgets(2)); // CPU e RAM defaults
    });
  });
}
