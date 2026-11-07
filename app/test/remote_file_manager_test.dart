import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crypto/crypto.dart';
import 'package:command/core/core.dart';
import 'package:command/src/transfers/remote_file_manager_page.dart';

class MockCommandClient extends Mock implements CommandClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCommandClient mockClient;

  setUp(() {
    mockClient = MockCommandClient();
  });

  final testItemsRoot = [
    DirectoryBrowseItem(
      name: 'relatorios',
      relativePath: 'relatorios',
      sizeBytes: 0,
      modifiedAtUtc: DateTime.utc(2026, 10, 17, 12, 0),
      extension: '',
      isDirectory: true,
    ),
    DirectoryBrowseItem(
      name: 'manual.pdf',
      relativePath: 'manual.pdf',
      sizeBytes: 2048,
      modifiedAtUtc: DateTime.utc(2026, 10, 17, 14, 30),
      extension: '.pdf',
      isDirectory: false,
    ),
  ];

  final testItemsSubfolder = [
    DirectoryBrowseItem(
      name: 'dados.csv',
      relativePath: 'relatorios/dados.csv',
      sizeBytes: 1024,
      modifiedAtUtc: DateTime.utc(2026, 10, 17, 15, 0),
      extension: '.csv',
      isDirectory: false,
    ),
  ];

  testWidgets('Renders items and breadcrumbs in RemoteFileManagerPage', (tester) async {
    when(() => mockClient.browseDirectory('outbound', subPath: null, deviceId: any(named: 'deviceId')))
        .thenAnswer((_) async => DirectoryBrowseResult(
              rootId: 'outbound',
              currentPath: '',
              items: testItemsRoot,
            ));

    await tester.pumpWidget(
      MaterialApp(
        home: RemoteFileManagerPage(client: mockClient),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gerenciador de Arquivos'), findsOneWidget);
    expect(find.text('outbound'), findsAtLeast(1));
    expect(find.text('relatorios'), findsOneWidget);
    expect(find.text('manual.pdf'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsOneWidget);
    expect(find.byIcon(Icons.folder), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
  });

  testWidgets('Navigates into folder and returns via breadcrumbs', (tester) async {
    when(() => mockClient.browseDirectory('outbound', subPath: null, deviceId: any(named: 'deviceId')))
        .thenAnswer((_) async => DirectoryBrowseResult(
              rootId: 'outbound',
              currentPath: '',
              items: testItemsRoot,
            ));

    when(() => mockClient.browseDirectory('outbound', subPath: 'relatorios', deviceId: any(named: 'deviceId')))
        .thenAnswer((_) async => DirectoryBrowseResult(
              rootId: 'outbound',
              currentPath: 'relatorios',
              items: testItemsSubfolder,
            ));

    await tester.pumpWidget(
      MaterialApp(
        home: RemoteFileManagerPage(client: mockClient),
      ),
    );
    await tester.pumpAndSettle();

    // Toca na pasta relatorios
    await tester.tap(find.text('relatorios'));
    await tester.pumpAndSettle();

    expect(find.text('dados.csv'), findsOneWidget);
    expect(find.textContaining('1.0 KB'), findsOneWidget);
    expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Toca no crumb 'outbound' para voltar à raiz
    await tester.tap(find.text('outbound').first);
    await tester.pumpAndSettle();

    expect(find.text('manual.pdf'), findsOneWidget);
  });

  testWidgets('Downloads file and verifies SHA-256 integrity', (tester) async {
    final fileBytes = Uint8List.fromList(utf8.encode('conteudo do manual'));
    final expectedSha = sha256.convert(fileBytes).toString();

    when(() => mockClient.browseDirectory('outbound', subPath: null, deviceId: any(named: 'deviceId')))
        .thenAnswer((_) async => DirectoryBrowseResult(
              rootId: 'outbound',
              currentPath: '',
              items: testItemsRoot,
            ));

    when(() => mockClient.downloadNestedFile('manual.pdf', deviceId: any(named: 'deviceId')))
        .thenAnswer((_) async => FileDownloadData(
              fileName: 'manual.pdf',
              bytes: fileBytes,
              checksumSha256: expectedSha,
            ));

    await tester.pumpWidget(
      MaterialApp(
        home: RemoteFileManagerPage(client: mockClient),
      ),
    );
    await tester.pumpAndSettle();

    // Clica no botão de download
    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pumpAndSettle();

    expect(find.text('manual.pdf baixado com sucesso!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
  });
}
