import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/transfers/share_receiver_sheet.dart';
import 'package:droiddeck/src/connection/pc_store.dart';

class MockDroidDeckClient extends Mock implements DroidDeckClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDroidDeckClient mockClient;

  setUp(() {
    mockClient = MockDroidDeckClient();
  });

  final testBytes = Uint8List.fromList(utf8.encode('arquivo de teste enviado do celular'));
  final testSha = sha256.convert(testBytes).toString();

  testWidgets('Renders file details and SHA-256 in ShareReceiverSheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareReceiverSheet(
            fileName: 'documento.pdf',
            fileBytes: testBytes,
            client: mockClient,
            targetPc: const SavedPc(
              id: 'pc-1',
              name: 'Meu Desktop',
              ip: '192.168.1.50',
              port: '5000',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Enviar Arquivo para o PC'), findsOneWidget);
    expect(find.text('documento.pdf'), findsOneWidget);
    expect(find.text('Destino: Meu Desktop (pasta inbound)'), findsOneWidget);
    expect(find.textContaining('SHA-256: ${testSha.substring(0, 16)}'), findsOneWidget);
    expect(find.text('Confirmar e Enviar para o PC'), findsOneWidget);
  });

  testWidgets('Blocks upload if file size exceeds 100 MiB limit', (tester) async {
    // Simula buffer de 105 MiB
    final largeBytes = Uint8List(105 * 1024 * 1024);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareReceiverSheet(
            fileName: 'video_gigante.mp4',
            fileBytes: largeBytes,
            client: mockClient,
          ),
        ),
      ),
    );

    expect(find.text('Arquivo excede o limite máximo permitido de 100 MiB.'), findsOneWidget);
    final buttonFinder = find.byType(ElevatedButton);
    final button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull); // Botão desabilitado
  });

  testWidgets('Uploads file successfully to inbound root with SHA-256', (tester) async {
    when(() => mockClient.uploadInboundFile(
          fileName: 'foto.jpg',
          bytes: testBytes,
          expectedSha256: any(named: 'expectedSha256'),
          deviceId: any(named: 'deviceId'),
          rootId: any(named: 'rootId'),
          conflictPolicy: any(named: 'conflictPolicy'),
        )).thenAnswer((_) async => UploadTransferResult(
          success: true,
          item: TransferItem(
            name: 'foto.jpg',
            sizeBytes: testBytes.length,
            sha256: testSha,
            modifiedAtUtc: DateTime.now().toUtc(),
          ),
        ));

    bool completedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareReceiverSheet(
            fileName: 'foto.jpg',
            fileBytes: testBytes,
            client: mockClient,
            onCompleted: () => completedCalled = true,
          ),
        ),
      ),
    );

    // Clica para enviar
    await tester.tap(find.text('Confirmar e Enviar para o PC'));
    await tester.pumpAndSettle();

    verify(() => mockClient.uploadInboundFile(
          fileName: 'foto.jpg',
          bytes: testBytes,
          expectedSha256: testSha,
          deviceId: any(named: 'deviceId'),
          rootId: any(named: 'rootId'),
          conflictPolicy: any(named: 'conflictPolicy'),
        )).called(1);

    expect(find.text('Arquivo enviado com sucesso para a pasta inbound do PC!'), findsOneWidget);
    expect(find.text('Concluído'), findsOneWidget);
    expect(completedCalled, isTrue);
  });
  testWidgets('Sends to the chosen destination folder and keeps both on conflict', (tester) async {
    SharedPreferences.setMockInitialValues({});
    when(() => mockClient.listDestinations()).thenAnswer((_) async => const [
          DestinationFolder(id: 'abc', name: 'Séries', icon: 'tv'),
          DestinationFolder(id: 'def', name: 'PDFs', icon: 'doc'),
        ]);
    var calls = 0;
    when(() => mockClient.uploadInboundFile(
          fileName: 'ep.mkv',
          bytes: testBytes,
          expectedSha256: any(named: 'expectedSha256'),
          deviceId: any(named: 'deviceId'),
          rootId: any(named: 'rootId'),
          conflictPolicy: any(named: 'conflictPolicy'),
        )).thenAnswer((inv) async {
      if (calls++ == 0) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/transfers/upload'),
          response: Response(statusCode: 409, requestOptions: RequestOptions(path: '/api/transfers/upload')),
        );
      }
      return UploadTransferResult(
        success: true,
        item: TransferItem(name: 'ep.mkv', sizeBytes: 1, sha256: 'x', modifiedAtUtc: DateTime.now().toUtc()),
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShareReceiverSheet(fileName: 'ep.mkv', fileBytes: testBytes, client: mockClient),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Séries'));
    await tester.pump();
    await tester.tap(find.text('Confirmar e Enviar para o PC'));
    await tester.pumpAndSettle();

    expect(find.text('Arquivo já existe'), findsOneWidget);
    await tester.tap(find.text('Manter os dois'));
    await tester.pumpAndSettle();

    verify(() => mockClient.uploadInboundFile(
          fileName: 'ep.mkv',
          bytes: testBytes,
          expectedSha256: testSha,
          deviceId: any(named: 'deviceId'),
          rootId: 'abc',
          conflictPolicy: 'keepBoth',
        )).called(1);
    expect(find.text('Arquivo enviado com sucesso para "Séries" no PC!'), findsOneWidget);
  });
}
