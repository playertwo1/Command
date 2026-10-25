import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/home/status_page.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTransferClient extends DroidDeckClient {
  List<TransferItem> outboundFiles = [];
  int listCalls = 0;
  int downloadCalls = 0;
  int uploadCalls = 0;
  bool shouldThrowConflictOnUpload = false;

  FakeTransferClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<List<AllowedApp>> getApps() async => [];

  @override
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async => [];

  @override
  Future<List<TransferItem>> listOutboundTransfers({String? deviceId}) async {
    listCalls++;
    return outboundFiles;
  }

  @override
  Future<FileDownloadData> downloadOutboundFile(String fileName, {String? deviceId}) async {
    downloadCalls++;
    final content = utf8.encode('relatorio,pc,sucesso\n1,100,true\n');
    final bytes = Uint8List.fromList(content);
    final hash = sha256.convert(bytes).toString();
    return FileDownloadData(
      fileName: fileName,
      bytes: bytes,
      checksumSha256: hash,
    );
  }

  @override
  Future<UploadTransferResult> uploadInboundFile({
    required String fileName,
    required Uint8List bytes,
    String? expectedSha256,
    String? requestId,
    String? deviceId,
  }) async {
    uploadCalls++;
    if (shouldThrowConflictOnUpload) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/transfers/upload'),
        response: Response(
          statusCode: 409,
          data: {'code': 'FILE_ALREADY_EXISTS', 'message': 'Arquivo existente'},
          requestOptions: RequestOptions(path: '/api/transfers/upload'),
        ),
      );
    }

    return UploadTransferResult(
      success: true,
      item: TransferItem(
        name: fileName,
        sizeBytes: bytes.length,
        sha256: expectedSha256 ?? sha256.convert(bytes).toString(),
        modifiedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F6 - Transfer Models', () {
    test('TransferItem serializes and deserializes correctly', () {
      final json = {
        'name': 'documento.csv',
        'sizeBytes': 2048,
        'sha256': 'abc123def456',
        'modifiedAtUtc': '2026-10-17T12:00:00Z',
      };

      final item = TransferItem.fromJson(json);
      expect(item.name, 'documento.csv');
      expect(item.fileName, 'documento.csv');
      expect(item.sizeBytes, 2048);
      expect(item.sha256, 'abc123def456');
      expect(item.checksumSha256, 'abc123def456');
      expect(item.formattedSize, '2.0 KB');

      final serialized = item.toJson();
      expect(serialized['name'], 'documento.csv');
      expect(serialized['sizeBytes'], 2048);
    });

    test('TransferItem formattedSize handles bytes, KB, and MB', () {
      final b = TransferItem(name: 'a', sizeBytes: 500, sha256: 'h', modifiedAtUtc: DateTime.now());
      expect(b.formattedSize, '500 B');

      final kb = TransferItem(name: 'b', sizeBytes: 15360, sha256: 'h', modifiedAtUtc: DateTime.now());
      expect(kb.formattedSize, '15.0 KB');

      final mb = TransferItem(name: 'c', sizeBytes: 5242880, sha256: 'h', modifiedAtUtc: DateTime.now());
      expect(mb.formattedSize, '5.0 MB');
    });

    test('FileDownloadData and UploadTransferResult hold correct values', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final dl = FileDownloadData(fileName: 'f.txt', bytes: bytes, checksumSha256: 'hash');
      expect(dl.fileName, 'f.txt');
      expect(dl.bytes.length, 3);
      expect(dl.checksumSha256, 'hash');

      final up = UploadTransferResult(success: true, item: null);
      expect(up.success, isTrue);
      expect(up.item, isNull);
    });
  });

  group('F6 - UI Transferência de Arquivos na StatusPage', () {
    late FakeTransferClient client;
    late SignalRService signalRService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      client = FakeTransferClient();
      signalRService = SignalRService();
    });

    tearDown(() {
      signalRService.dispose();
    });

    testWidgets('Renderiza card de transferência e lista arquivos outbound', (tester) async {
      client.outboundFiles = [
        TransferItem(
          name: 'relatorio_vendas.csv',
          sizeBytes: 12450,
          sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          modifiedAtUtc: DateTime.now().toUtc(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusPage(
              isFullscreen: false,
              onToggleFullscreen: () {},
              client: client,
              signalRService: signalRService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Transferência de Arquivos'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Transferência de Arquivos'), findsOneWidget);
      expect(find.text('Disponíveis para Download (PC Outbound)'), findsOneWidget);
      expect(find.text('relatorio_vendas.csv'), findsOneWidget);
      expect(find.textContaining('12.2 KB'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      expect(find.text('Enviar Arquivo para o PC (Inbound)'), findsOneWidget);
    });

    testWidgets('Aciona download e valida integridade SHA-256', (tester) async {
      client.outboundFiles = [
        TransferItem(
          name: 'dados.csv',
          sizeBytes: 100,
          sha256: 'hash123',
          modifiedAtUtc: DateTime.now().toUtc(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusPage(
              isFullscreen: false,
              onToggleFullscreen: () {},
              client: client,
              signalRService: signalRService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Transferência de Arquivos'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final downloadBtn = find.byIcon(Icons.download);
      expect(downloadBtn, findsOneWidget);

      await tester.tap(downloadBtn);
      await tester.pumpAndSettle();

      expect(client.downloadCalls, 1);
      expect(find.textContaining('Download concluído! SHA-256 verificado'), findsOneWidget);
    });

    testWidgets('Aciona upload para o PC (inbound)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusPage(
              isFullscreen: false,
              onToggleFullscreen: () {},
              client: client,
              signalRService: signalRService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Enviar Arquivo para o PC (Inbound)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final uploadBtn = find.text('Enviar Arquivo para o PC (Inbound)');
      expect(uploadBtn, findsOneWidget);

      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      expect(client.uploadCalls, 1);
      expect(find.textContaining('enviado com sucesso para o PC!'), findsOneWidget);
    });
  });
}
