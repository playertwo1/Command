import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command/core/core.dart';
import 'package:command/src/security/security_center_card.dart';
import 'package:command/src/services/biometric_guard_service.dart';

class FakeSecurityClient extends CommandClient {
  int updateStatusCalls = 0;
  int systemStabilityCalls = 0;
  int exportBackupCalls = 0;

  FakeSecurityClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<UpdateStatusModel> getUpdateStatus() async {
    updateStatusCalls++;
    return const UpdateStatusModel(
      currentVersion: '1.0.0',
      channel: 'stable',
      updateAvailable: false,
      isVelopackReady: true,
      checkedAtUtc: '2026-10-18T16:00:00Z',
    );
  }

  @override
  Future<SystemStabilityModel> getSystemStability() async {
    systemStabilityCalls++;
    return const SystemStabilityModel(
      workingSetMb: 128.5,
      handleCount: 1024,
      threadCount: 32,
      bridgeUptimeSeconds: 7200.0,
      healthStatus: 'Healthy',
      timestampUtc: '2026-10-18T16:00:00Z',
    );
  }

  @override
  Future<EncryptedBackupEnvelopeModel> exportEncryptedBackup(String passphrase) async {
    exportBackupCalls++;
    return const EncryptedBackupEnvelopeModel(
      createdAtUtc: '2026-10-18T16:00:00Z',
      saltBase64: 'c2FsdA==',
      nonceBase64: 'bm9uY2U=',
      tagBase64: 'dGFn',
      ciphertextBase64: 'Y2lwaGVy',
      plaintextSha256: 'sha256',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricGuardService', () {
    late BiometricGuardService service;

    setUp(() {
      service = BiometricGuardService();
    });

    test('Permite ação direta se o guard estiver desabilitado', () async {
      expect(service.isGuardEnabled, isFalse);
    });

    testWidgets('Solicita e valida PIN quando o guard estiver ativado', (tester) async {
      service.isGuardEnabled = true;

      bool? authorized;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  authorized = await service.confirmCriticalAction(
                    context,
                    actionTitle: 'Teste Crítico',
                  );
                },
                child: const Text('Disparar Ação'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disparar Ação'));
      await tester.pumpAndSettle();

      expect(find.text('Guardião de Segurança'), findsOneWidget);
      expect(find.text('Ação protegida: Teste Crítico'), findsOneWidget);

      // Digita PIN incorreto
      await tester.enterText(find.byType(TextField), '9999');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(find.text('PIN incorreto. Tente novamente.'), findsOneWidget);

      // Digita PIN correto
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Autorizar'));
      await tester.pumpAndSettle();

      expect(authorized, isTrue);
    });

    testWidgets('Cancela autorização de PIN', (tester) async {
      service.isGuardEnabled = true;

      bool? authorized;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  authorized = await service.confirmCriticalAction(
                    context,
                    actionTitle: 'Cancelar Ação',
                  );
                },
                child: const Text('Disparar Ação'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disparar Ação'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(authorized, isFalse);
    });
  });

  group('SecurityCenterCard Widget Tests', () {
    late FakeSecurityClient fakeClient;
    late BiometricGuardService guardService;

    setUp(() {
      fakeClient = FakeSecurityClient();
      guardService = BiometricGuardService();
    });

    testWidgets('Renderiza cabeçalho e não executa chamadas de rede no initState', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecurityCenterCard(
                client: fakeClient,
                guardService: guardService,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Centro de Segurança e Integridade'), findsOneWidget);
      expect(find.text('Command v1.0.0 (Stable)'), findsOneWidget);
      expect(fakeClient.updateStatusCalls, 0);
      expect(fakeClient.systemStabilityCalls, 0);
    });

    testWidgets('Alterna o switch de PIN', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecurityCenterCard(
                client: fakeClient,
                guardService: guardService,
              ),
            ),
          ),
        ),
      );

      final switchFinder = find.byKey(const Key('switch_biometric_guard'));
      expect(switchFinder, findsOneWidget);
      expect(guardService.isGuardEnabled, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(guardService.isGuardEnabled, isTrue);
    });

    testWidgets('Consulta estabilidade e atualizações sob demanda', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecurityCenterCard(
                client: fakeClient,
                guardService: guardService,
              ),
            ),
          ),
        ),
      );

      final checkBtn = find.byKey(const Key('btn_check_system_stability'));
      expect(checkBtn, findsOneWidget);

      await tester.tap(checkBtn);
      await tester.pumpAndSettle();

      expect(fakeClient.updateStatusCalls, 1);
      expect(fakeClient.systemStabilityCalls, 1);
      expect(find.textContaining('Bridge atualizada: 1.0.0 (stable)'), findsOneWidget);
      expect(find.textContaining('Status: Healthy'), findsOneWidget);
      expect(find.textContaining('Mem: 128.5 MB'), findsOneWidget);
    });

    testWidgets('Abre Backup Criptografado quando acionado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecurityCenterCard(
                client: fakeClient,
                guardService: guardService,
              ),
            ),
          ),
        ),
      );

      final backupBtn = find.byKey(const Key('btn_open_encrypted_backup'));
      await tester.tap(backupBtn);
      await tester.pumpAndSettle();

      expect(find.text('Backup Criptografado (AES-256)'), findsWidgets);
      expect(find.text('Exportar Backup'), findsOneWidget);
      expect(find.text('Restaurar Backup'), findsOneWidget);
    });
  });
}
