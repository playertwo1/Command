import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:command/core/core.dart';
import 'package:command/src/security/encrypted_backup_sheet.dart';

class FakeBackupClient extends CommandClient {
  String? lastExportPassphrase;
  EncryptedBackupEnvelopeModel? lastRestoreEnvelope;
  String? lastRestorePassphrase;

  FakeBackupClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<EncryptedBackupEnvelopeModel> exportEncryptedBackup(String passphrase) async {
    lastExportPassphrase = passphrase;
    return const EncryptedBackupEnvelopeModel(
      formatVersion: 1,
      app: 'Command',
      version: '1.0.0',
      createdAtUtc: '2026-10-18T16:00:00Z',
      saltBase64: 'c2FsdA==',
      nonceBase64: 'bm9uY2U=',
      tagBase64: 'dGFn',
      ciphertextBase64: 'Y2lwaGVy',
      plaintextSha256: 'a1b2c3d4e5f6',
    );
  }

  @override
  Future<EncryptedBackupRestoreResultModel> restoreEncryptedBackup(
    EncryptedBackupEnvelopeModel envelope,
    String passphrase,
  ) async {
    lastRestoreEnvelope = envelope;
    lastRestorePassphrase = passphrase;

    if (passphrase == 'wrong_pass') {
      return const EncryptedBackupRestoreResultModel(
        success: false,
        errorCode: 'DECRYPTION_FAILED',
        errorMessage: 'Senha incorreta ou tag de autenticação corrompida.',
      );
    }

    return const EncryptedBackupRestoreResultModel(
      success: true,
      restoredRoutinesCount: 4,
      restoredPermissionsCount: 2,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modelos de Segurança e Backup (Unit Tests)', () {
    test('DevicePermissionModel: serialização e parsing camelCase e PascalCase', () {
      const model = DevicePermissionModel(
        deviceId: 'dev_123',
        role: 'admin',
        updatedAtUtc: '2026-10-18T12:00:00Z',
      );

      final json = model.toJson();
      expect(json['deviceId'], 'dev_123');
      expect(json['role'], 'admin');

      final fromCamel = DevicePermissionModel.fromJson(json);
      expect(fromCamel.deviceId, 'dev_123');
      expect(fromCamel.role, 'admin');

      final fromPascal = DevicePermissionModel.fromJson({
        'DeviceId': 'dev_456',
        'Role': 'operator',
        'UpdatedAtUtc': '2026-10-18T13:00:00Z',
      });
      expect(fromPascal.deviceId, 'dev_456');
      expect(fromPascal.role, 'operator');
    });

    test('SecurityAuditEntryModel: serialização e parsing', () {
      const entry = SecurityAuditEntryModel(
        id: 'audit_1',
        deviceId: 'dev_123',
        actionType: 'power.sleep',
        allowed: true,
        reason: 'Authorized operator',
        timestampUtc: '2026-10-18T14:00:00Z',
      );

      final json = entry.toJson();
      expect(json['allowed'], isTrue);
      expect(json['reason'], 'Authorized operator');

      final parsed = SecurityAuditEntryModel.fromJson(json);
      expect(parsed.id, 'audit_1');
      expect(parsed.actionType, 'power.sleep');
      expect(parsed.allowed, isTrue);

      final pascal = SecurityAuditEntryModel.fromJson({
        'Id': 'audit_2',
        'DeviceId': 'dev_999',
        'ActionType': 'transfer.download',
        'Allowed': false,
        'Reason': 'Blocked path traversal',
        'TimestampUtc': '2026-10-18T15:00:00Z',
      });
      expect(pascal.allowed, isFalse);
      expect(pascal.reason, 'Blocked path traversal');
    });

    test('EncryptedBackupEnvelopeModel: integridade do envelope', () {
      const envelope = EncryptedBackupEnvelopeModel(
        formatVersion: 1,
        app: 'Command',
        version: '1.0.0',
        createdAtUtc: '2026-10-18T16:00:00Z',
        saltBase64: 'c2FsdA==',
        nonceBase64: 'bm9uY2U=',
        tagBase64: 'dGFn',
        ciphertextBase64: 'Y2lwaGVy',
        plaintextSha256: 'abcdef',
      );

      final json = envelope.toJson();
      final parsed = EncryptedBackupEnvelopeModel.fromJson(json);

      expect(parsed.formatVersion, 1);
      expect(parsed.app, 'Command');
      expect(parsed.ciphertextBase64, 'Y2lwaGVy');
      expect(parsed.plaintextSha256, 'abcdef');
    });

    test('EncryptedBackupRestoreResultModel: parsing de sucesso e erro', () {
      const successResult = EncryptedBackupRestoreResultModel(
        success: true,
        restoredRoutinesCount: 5,
        restoredPermissionsCount: 3,
      );
      final jsonSuccess = successResult.toJson();
      final parsedSuccess = EncryptedBackupRestoreResultModel.fromJson(jsonSuccess);
      expect(parsedSuccess.success, isTrue);
      expect(parsedSuccess.restoredRoutinesCount, 5);
      expect(parsedSuccess.restoredPermissionsCount, 3);

      final parsedError = EncryptedBackupRestoreResultModel.fromJson({
        'Success': false,
        'ErrorCode': 'INVALID_TAG',
        'ErrorMessage': 'Falha de autenticação',
      });
      expect(parsedError.success, isFalse);
      expect(parsedError.errorCode, 'INVALID_TAG');
    });

    test('UpdateStatusModel e SystemStabilityModel: parsing correto', () {
      final update = UpdateStatusModel.fromJson({
        'CurrentVersion': '1.0.0',
        'Channel': 'stable',
        'UpdateAvailable': true,
        'LatestVersion': '1.1.0',
        'IsVelopackReady': true,
        'BinarySha256': 'hash123',
        'CheckedAtUtc': '2026-10-18T17:00:00Z',
      });
      expect(update.updateAvailable, isTrue);
      expect(update.latestVersion, '1.1.0');
      expect(update.isVelopackReady, isTrue);

      final stability = SystemStabilityModel.fromJson({
        'WorkingSetMb': 95.5,
        'HandleCount': 420,
        'ThreadCount': 18,
        'BridgeUptimeSeconds': 3600.0,
        'HealthStatus': 'Degraded',
        'TimestampUtc': '2026-10-18T17:00:00Z',
      });
      expect(stability.workingSetMb, 95.5);
      expect(stability.healthStatus, 'Degraded');
    });
  });

  group('EncryptedBackupSheet Widget Tests', () {
    late FakeBackupClient fakeClient;

    setUp(() {
      fakeClient = FakeBackupClient();
    });

    testWidgets('Valida senha mínima na aba de exportação', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EncryptedBackupSheet(client: fakeClient),
          ),
        ),
      );

      // Tenta exportar com senha curta (< 6 caracteres)
      final input = find.byType(TextField).first;
      await tester.enterText(input, '123');
      final exportBtn = find.byKey(const Key('btn_generate_encrypted_backup'));
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.text('A senha mestra deve conter ao menos 6 caracteres.'), findsOneWidget);
      expect(fakeClient.lastExportPassphrase, isNull);
    });

    testWidgets('Exporta envelope com senha válida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EncryptedBackupSheet(client: fakeClient),
          ),
        ),
      );

      final input = find.byType(TextField).first;
      await tester.enterText(input, 'minha_senha_super_segura');
      final exportBtn = find.byKey(const Key('btn_generate_encrypted_backup'));
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(fakeClient.lastExportPassphrase, 'minha_senha_super_segura');
      expect(find.text('Envelope Gerado (JSON):'), findsOneWidget);
      expect(find.byKey(const Key('btn_copy_backup_json')), findsOneWidget);
    });

    testWidgets('Restaura envelope criptografado na aba de restauração', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EncryptedBackupSheet(client: fakeClient),
          ),
        ),
      );

      // Clica na aba Restaurar Backup
      await tester.tap(find.text('Restaurar Backup'));
      await tester.pumpAndSettle();

      const sampleEnvelope = EncryptedBackupEnvelopeModel(
        createdAtUtc: '2026-10-18T16:00:00Z',
        saltBase64: 'c2FsdA==',
        nonceBase64: 'bm9uY2U=',
        tagBase64: 'dGFn',
        ciphertextBase64: 'Y2lwaGVy',
        plaintextSha256: 'sha256',
      );
      final jsonStr = jsonEncode(sampleEnvelope.toJson());

      await tester.enterText(find.byKey(const Key('input_restore_envelope_json')), jsonStr);
      await tester.enterText(find.byKey(const Key('input_restore_passphrase')), 'senha_correta');

      final restoreBtn = find.byKey(const Key('btn_execute_encrypted_restore'));
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      expect(fakeClient.lastRestorePassphrase, 'senha_correta');
      expect(find.textContaining('Restauração concluída com sucesso!'), findsOneWidget);
      expect(find.textContaining('Rotinas restauradas: 4'), findsOneWidget);
      expect(find.textContaining('Permissões restauradas: 2'), findsOneWidget);
    });
  });
}
