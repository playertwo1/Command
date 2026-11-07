import 'dart:typed_data';
import 'package:command/core/core.dart';
import 'package:command/src/home/status_page.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeScreenshotClient extends CommandClient {
  bool shouldThrowLocked = false;
  int captureCalls = 0;
  int getBytesCalls = 0;

  FakeScreenshotClient() : super(baseUrl: 'http://localhost:4787');

  @override
  Future<List<AllowedApp>> getApps() async => [];

  @override
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async => [];

  @override
  Future<ScreenshotInfo> captureScreenshot({
    required String requestId,
    String? deviceId,
  }) async {
    captureCalls++;
    if (shouldThrowLocked) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/screenshots/capture'),
        response: Response(
          statusCode: 423,
          data: {
            'code': 'SESSION_LOCKED',
            'error': 'A área de trabalho está bloqueada ou em tela segura do Windows (UAC).',
          },
          requestOptions: RequestOptions(path: '/api/screenshots/capture'),
        ),
      );
    }

    return ScreenshotInfo(
      id: 'sc_test_1',
      requestId: requestId,
      width: 1920,
      height: 1080,
      sizeBytes: 154320,
      createdAtUtc: DateTime.now().toUtc(),
      expiresAtUtc: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<Uint8List> getScreenshotBytes(
    String screenshotId, {
    String? deviceId,
  }) async {
    getBytesCalls++;
    // Gera 1x1 pixel PNG/JPEG falso para renderizar Image.memory nos testes
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ScreenshotInfo model: serialização e expiração', () {
    final now = DateTime.now().toUtc();
    final info = ScreenshotInfo(
      id: 'sc_123',
      requestId: 'req_123',
      width: 2560,
      height: 1440,
      sizeBytes: 204800,
      createdAtUtc: now,
      expiresAtUtc: now.add(const Duration(minutes: 10)),
    );

    expect(info.isExpired, isFalse);
    final json = info.toJson();
    final fromJson = ScreenshotInfo.fromJson(json);

    expect(fromJson.id, 'sc_123');
    expect(fromJson.width, 2560);
    expect(fromJson.height, 1440);
    expect(fromJson.sizeBytes, 204800);
  });

  testWidgets('StatusPage exibe Card de Captura de Tela e botão Capturar', (tester) async {
    final fakeClient = FakeScreenshotClient();
    final signalR = SignalRService();

    await tester.pumpWidget(
      MaterialApp(
        home: StatusPage(
          isFullscreen: false,
          onToggleFullscreen: () {},
          client: fakeClient,
          signalRService: signalR,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Rola para exibir o card de captura de tela
    await tester.scrollUntilVisible(
      find.text('Captura de Tela'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Captura de Tela'), findsOneWidget);
    expect(find.text('Capturar Tela Agora'), findsOneWidget);

    // Toca no botão para capturar tela
    await tester.tap(find.text('Capturar Tela Agora'));
    await tester.pumpAndSettle();

    expect(fakeClient.captureCalls, 1);
    expect(fakeClient.getBytesCalls, 1);

    // Deve exibir resolução, tamanho e botões de ação
    expect(find.textContaining('1920x1080'), findsOneWidget);
    expect(find.text('Visualizar'), findsOneWidget);
    expect(find.text('Compartilhar'), findsOneWidget);
  });

  testWidgets('StatusPage: erro quando sessão do Windows está bloqueada (SESSION_LOCKED)', (tester) async {
    final fakeClient = FakeScreenshotClient()..shouldThrowLocked = true;
    final signalR = SignalRService();

    await tester.pumpWidget(
      MaterialApp(
        home: StatusPage(
          isFullscreen: false,
          onToggleFullscreen: () {},
          client: fakeClient,
          signalRService: signalR,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Capturar Tela Agora'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Capturar Tela Agora'));
    await tester.pumpAndSettle();

    expect(fakeClient.captureCalls, 1);
    expect(find.textContaining('Acesso Bloqueado'), findsOneWidget);
    expect(find.textContaining('UAC'), findsOneWidget);
  });
}
