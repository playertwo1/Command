import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/desktop_stream/desktop_stream_controller.dart';
import 'package:droiddeck/src/desktop_stream/desktop_live_stream_viewer.dart';
import 'package:droiddeck/src/desktop_stream/screen_coordinate_mapper.dart';

class MockStreamHttpClient extends http.BaseClient {
  final int statusCode;
  final Stream<List<int>> responseStream;

  MockStreamHttpClient({
    this.statusCode = 200,
    required this.responseStream,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      responseStream,
      statusCode,
      headers: {'content-type': 'multipart/x-mixed-replace; boundary=frame'},
    );
  }
}

class MockRemoteInputClient extends DroidDeckClient {
  MockRemoteInputClient({super.baseUrl = 'https://test.deck'});

  final List<String> calls = [];
  final List<Map<String, dynamic>> clickCalls = [];

  bool throwOnStart = false;
  Exception? startException;

  bool throwOnClick = false;
  Exception? clickException;

  @override
  Future<RemoteControlSessionInfo> startRemoteInputSession({String? deviceId}) async {
    calls.add('startRemoteInputSession');
    if (throwOnStart && startException != null) {
      throw startException!;
    }
    return RemoteControlSessionInfo(
      sessionId: 'sess-test',
      deviceId: deviceId ?? 'dev-test',
      timeoutSeconds: 60,
      isActive: true,
    );
  }

  @override
  Future<void> endRemoteInputSession({String? deviceId}) async {
    calls.add('endRemoteInputSession');
  }

  @override
  Future<void> sendMouseClick(
    String button, {
    String action = 'click',
    double? normalizedX,
    double? normalizedY,
    String? deviceId,
  }) async {
    calls.add('sendMouseClick');
    if (throwOnClick && clickException != null) {
      throw clickException!;
    }
    clickCalls.add({
      'button': button,
      'action': action,
      'normalizedX': normalizedX,
      'normalizedY': normalizedY,
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Frame JPEG 1x1 válido codificado em Base64
  final dummyJpeg = base64Decode(
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD8qqKKKAP/2Q==',
  );

  group('ScreenCoordinateMapper Tests', () {
    test('extractJpegDimensions returns dimensions for valid JPEG', () {
      final dims = ScreenCoordinateMapper.extractJpegDimensions(dummyJpeg);
      expect(dims, isNotNull);
      expect(dims?.width, equals(1));
      expect(dims?.height, equals(1));
      expect(dims?.aspectRatio, equals(1.0));
    });

    test('extractJpegDimensions returns null for invalid bytes', () {
      expect(ScreenCoordinateMapper.extractJpegDimensions(Uint8List(0)), isNull);
      expect(ScreenCoordinateMapper.extractJpegDimensions(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('mapContainerToNormalized with exact aspect ratio', () {
      final norm = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(80, 45),
        containerSize: const Size(160, 90),
        imageAspectRatio: 16 / 9,
      );
      expect(norm, isNotNull);
      expect(norm!.dx, closeTo(0.5, 0.001));
      expect(norm.dy, closeTo(0.5, 0.001));
    });

    test('mapContainerToNormalized with pillarbox (black bars on left and right)', () {
      // Container 400x100, imagem 1:1 -> imagem fica 100x100 centralizada de X=150 a X=250
      final blackBarLeft = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(50, 50),
        containerSize: const Size(400, 100),
        imageAspectRatio: 1.0,
      );
      expect(blackBarLeft, isNull);

      final blackBarRight = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(350, 50),
        containerSize: const Size(400, 100),
        imageAspectRatio: 1.0,
      );
      expect(blackBarRight, isNull);

      final center = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(200, 50),
        containerSize: const Size(400, 100),
        imageAspectRatio: 1.0,
      );
      expect(center, isNotNull);
      expect(center!.dx, closeTo(0.5, 0.001));
      expect(center.dy, closeTo(0.5, 0.001));
    });

    test('mapContainerToNormalized with letterbox (black bars on top and bottom)', () {
      // Container 100x400, imagem 1:1 -> imagem fica 100x100 centralizada de Y=150 a Y=250
      final blackBarTop = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(50, 50),
        containerSize: const Size(100, 400),
        imageAspectRatio: 1.0,
      );
      expect(blackBarTop, isNull);

      final blackBarBottom = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(50, 350),
        containerSize: const Size(100, 400),
        imageAspectRatio: 1.0,
      );
      expect(blackBarBottom, isNull);

      final center = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(50, 200),
        containerSize: const Size(100, 400),
        imageAspectRatio: 1.0,
      );
      expect(center, isNotNull);
      expect(center!.dx, closeTo(0.5, 0.001));
      expect(center.dy, closeTo(0.5, 0.001));
    });

    test('mapContainerToNormalized returns null on invalid dimensions', () {
      final result = ScreenCoordinateMapper.mapContainerToNormalized(
        localPosition: const Offset(10, 10),
        containerSize: Size.zero,
        imageAspectRatio: 1.0,
      );
      expect(result, isNull);
    });
  });

  group('DesktopStreamController Tests', () {
    test('Initial state is idle with medium preset', () {
      final controller = DesktopStreamController();
      expect(controller.isPlaying, isFalse);
      expect(controller.preset, equals(StreamQualityPreset.medium));
      expect(controller.latestFrame, isNull);
      expect(controller.fps, equals(0));
      expect(controller.errorMessage, isNull);
      controller.dispose();
    });

    test('Changes preset and updates stream parameters', () {
      final controller = DesktopStreamController();
      controller.setPreset(StreamQualityPreset.high);
      expect(controller.preset, equals(StreamQualityPreset.high));
      expect(controller.preset.fps, equals(15));
      controller.dispose();
    });

    test('Parses MJPEG stream chunks and updates latestFrame and FPS', () async {
      final controller = DesktopStreamController();
      final streamController = StreamController<List<int>>();

      final mockClient = MockStreamHttpClient(
        statusCode: 200,
        responseStream: streamController.stream,
      );

      await controller.start(
        baseUrl: 'http://127.0.0.1:5000',
        apiKey: 'test-api-key',
        clientOverride: mockClient,
      );

      expect(controller.isPlaying, isTrue);

      // Simula envio de chunks contendo frame JPEG
      streamController.add([0xFF, 0xD8, 0x00, 0x01]);
      streamController.add([0x02, 0xFF, 0xD9]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.latestFrame, isNotNull);
      expect(controller.latestFrame!.length, equals(7));
      expect(controller.fps, equals(1));

      await controller.stop();
      expect(controller.isPlaying, isFalse);
      await streamController.close();
      controller.dispose();
    });

    test('Handles 409 conflict when another client is streaming', () async {
      final controller = DesktopStreamController();
      final mockClient = MockStreamHttpClient(
        statusCode: 409,
        responseStream: const Stream<List<int>>.empty(),
      );

      await controller.start(
        baseUrl: 'http://127.0.0.1:5000',
        clientOverride: mockClient,
      );

      expect(controller.isPlaying, isFalse);
      expect(controller.errorMessage, contains('Ocupado'));
      controller.dispose();
    });
  });

  group('DesktopLiveStreamViewer Widget Tests', () {
    testWidgets('Renders live stream card with play button and quality menu', (tester) async {
      final controller = DesktopStreamController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLiveStreamViewer(
              controller: controller,
              baseUrl: 'http://192.168.1.100:5000',
            ),
          ),
        ),
      );

      expect(find.text('Tela ao Vivo'), findsOneWidget);
      expect(find.text('Assistir Tela ao Vivo'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Shows FPS badge and pause button when playing', (tester) async {
      final controller = DesktopStreamController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLiveStreamViewer(
              controller: controller,
              baseUrl: 'http://192.168.1.100:5000',
            ),
          ),
        ),
      );

      // Simula estado ativo com frame e 10 FPS
      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
      );
      await tester.pump();

      expect(find.text('Pausar Transmissão'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.text('10 FPS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Tapping on fullscreen button navigates to DesktopFullScreenViewerPage', (tester) async {
      final controller = DesktopStreamController();
      final mockClient = MockRemoteInputClient();

      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopLiveStreamViewer(
              controller: controller,
              baseUrl: 'http://192.168.1.100:5000',
              client: mockClient,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopFullScreenViewerPage), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  group('DesktopFullScreenViewerPage Tap-to-Click Tests', () {
    testWidgets('Tapping on preview sends click with normalized coordinates', (tester) async {
      final controller = DesktopStreamController();
      final mockClient = MockRemoteInputClient();

      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
        aspectRatio: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopFullScreenViewerPage(
            controller: controller,
            baseUrl: 'http://192.168.1.100:5000',
            client: mockClient,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(mockClient.calls, contains('startRemoteInputSession'));

      // Toca no centro da tela
      final detector = find.byKey(const ValueKey('desktop_preview_gesture_detector'));
      expect(detector, findsOneWidget);
      final center = tester.getCenter(detector);
      await tester.tapAt(center);
      await tester.pump();

      expect(mockClient.calls, contains('sendMouseClick'));
      expect(mockClient.clickCalls, isNotEmpty);
      final lastClick = mockClient.clickCalls.last;
      expect(lastClick['button'], equals('left'));
      expect(lastClick['normalizedX'], closeTo(0.5, 0.05));
      expect(lastClick['normalizedY'], closeTo(0.5, 0.05));

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Long press sends right click with normalized coordinates', (tester) async {
      final controller = DesktopStreamController();
      final mockClient = MockRemoteInputClient();

      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
        aspectRatio: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopFullScreenViewerPage(
            controller: controller,
            baseUrl: 'http://192.168.1.100:5000',
            client: mockClient,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final detector = find.byKey(const ValueKey('desktop_preview_gesture_detector'));
      expect(detector, findsOneWidget);
      final center = tester.getCenter(detector);
      await tester.longPressAt(center);
      await tester.pump();

      expect(mockClient.calls, contains('sendMouseClick'));
      final lastClick = mockClient.clickCalls.last;
      expect(lastClick['button'], equals('right'));

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Toggling mode switches between touch-to-click and zoom', (tester) async {
      final controller = DesktopStreamController();
      final mockClient = MockRemoteInputClient();

      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
        aspectRatio: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopFullScreenViewerPage(
            controller: controller,
            baseUrl: 'http://192.168.1.100:5000',
            client: mockClient,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop_preview_gesture_detector')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);

      // Alterna para modo Zoom/Navegação
      await tester.tap(find.byKey(const ValueKey('desktop_mode_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Shows lock message banner when remote input is locked', (tester) async {
      final controller = DesktopStreamController();
      final mockClient = MockRemoteInputClient()
        ..throwOnClick = true
        ..clickException = const RemoteInputLockedException('Sessão bloqueada ou UAC.');

      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
        aspectRatio: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopFullScreenViewerPage(
            controller: controller,
            baseUrl: 'http://192.168.1.100:5000',
            client: mockClient,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final detector = find.byKey(const ValueKey('desktop_preview_gesture_detector'));
      expect(detector, findsOneWidget);
      final center = tester.getCenter(detector);
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(find.text('Sessão bloqueada ou UAC.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('Exiting DesktopFullScreenViewerPage stops controller stream and ends session', (tester) async {
      final controller = DesktopStreamController();
      final mockClient = MockRemoteInputClient();

      controller.setStreamStateForTesting(
        isPlaying: true,
        frame: dummyJpeg,
        fps: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopFullScreenViewerPage(
            controller: controller,
            baseUrl: 'http://192.168.1.100:5000',
            client: mockClient,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.isPlaying, isTrue);

      // Destrói o widget da página (simulando pop/saída da tela)
      await tester.pumpWidget(const SizedBox());

      expect(controller.isPlaying, isFalse);
      expect(mockClient.calls, contains('endRemoteInputSession'));
      controller.dispose();
    });
  });
}
