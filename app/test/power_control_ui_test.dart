import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/power/power_control_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePowerClient extends DroidDeckClient {
  int executeCalls = 0;
  String? lastAction;
  bool? lastConfirmed;

  FakePowerClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<NetworkWakeInfo> getWakeInfo() async {
    return const NetworkWakeInfo(
      hostName: 'DESKTOP-COMMAND',
      macAddress: 'AA:BB:CC:DD:EE:FF',
      localIp: '192.168.1.100',
      wolPort: 9,
      supportsWakeOnLan: true,
    );
  }

  @override
  Future<PowerActionResult> executePowerAction({
    required String action,
    required bool confirmed,
    String? requestId,
    String? deviceId,
  }) async {
    executeCalls++;
    lastAction = action;
    lastConfirmed = confirmed;
    return PowerActionResult(
      success: true,
      action: action,
      status: 'executed',
      jobId: 'job_power_1',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Power Models Serialization', () {
    test('NetworkWakeInfo: serialização e parsing', () {
      const info = NetworkWakeInfo(
        hostName: 'PC-TEST',
        macAddress: '11:22:33:44:55:66',
        localIp: '192.168.0.50',
        wolPort: 9,
        supportsWakeOnLan: true,
      );

      final json = info.toJson();
      final fromJson = NetworkWakeInfo.fromJson(json);

      expect(fromJson.hostName, 'PC-TEST');
      expect(fromJson.macAddress, '11:22:33:44:55:66');
      expect(fromJson.localIp, '192.168.0.50');
      expect(fromJson.wolPort, 9);
      expect(fromJson.supportsWakeOnLan, isTrue);

      final pascalJson = {
        'HostName': 'PC-PASCAL',
        'MacAddress': 'AA-BB-CC-DD-EE-FF',
        'LocalIp': '10.0.0.5',
        'WolPort': 7,
        'SupportsWakeOnLan': false,
      };
      final fromPascal = NetworkWakeInfo.fromJson(pascalJson);
      expect(fromPascal.hostName, 'PC-PASCAL');
      expect(fromPascal.supportsWakeOnLan, isFalse);
    });

    test('PowerActionResult: parsing de sucesso e erro', () {
      final json = {
        'success': true,
        'action': 'lock',
        'status': 'executed',
        'jobId': 'job_123',
      };
      final res = PowerActionResult.fromJson(json);
      expect(res.success, isTrue);
      expect(res.action, 'lock');
      expect(res.jobId, 'job_123');
    });
  });

  group('PowerControlCard Widget Tests', () {
    testWidgets('renderiza botões e exige confirmação para bloquear PC', (tester) async {
      final client = FakePowerClient();
      int dockModeCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerControlCard(
              client: client,
              savedMacAddress: 'AA:BB:CC:DD:EE:FF',
              targetPcName: 'PC Sala',
              onOpenDockMode: () => dockModeCalls++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Controle de Energia & Sessão'), findsOneWidget);
      expect(find.text('Bloquear PC'), findsOneWidget);
      expect(find.text('Suspender PC'), findsOneWidget);
      expect(find.text('Wake-on-LAN (Ligar PC)'), findsOneWidget);
      expect(find.text('Modo Dock (Mesa)'), findsOneWidget);

      // Toca em Bloquear PC
      await tester.tap(find.text('Bloquear PC'));
      await tester.pumpAndSettle();

      // Diálogo de confirmação obrigatória
      expect(find.text('Confirmar Controle de Sessão'), findsOneWidget);
      expect(find.textContaining('PC-alvo: PC Sala'), findsOneWidget);
      expect(
        find.text('Atenção: Ao bloquear ou suspender o PC, a captura de tela ficará indisponível até o desbloqueio local.'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Confirmar Agora'), findsOneWidget);

      // Cancela
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(client.executeCalls, 0);

      // Clica novamente e agora confirma
      await tester.tap(find.text('Bloquear PC'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar Agora'));
      await tester.pumpAndSettle();

      expect(client.executeCalls, 1);
      expect(client.lastAction, 'lock');
      expect(client.lastConfirmed, isTrue);
      expect(find.textContaining('executada com sucesso'), findsOneWidget);

      // Testa Modo Dock
      await tester.tap(find.text('Modo Dock (Mesa)'));
      await tester.pumpAndSettle();
      expect(dockModeCalls, 1);
    });

    testWidgets('confirmação para suspender PC chama ação sleep', (tester) async {
      final client = FakePowerClient();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerControlCard(
              client: client,
              savedMacAddress: 'AA:BB:CC:DD:EE:FF',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Suspender PC'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar Controle de Sessão'), findsOneWidget);
      await tester.tap(find.text('Confirmar Agora'));
      await tester.pumpAndSettle();

      expect(client.executeCalls, 1);
      expect(client.lastAction, 'sleep');
      expect(client.lastConfirmed, isTrue);
    });
  });
}
