import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:droiddeck/src/desktop_stream/desktop_stream_controller.dart';
import 'package:droiddeck/src/desktop_stream/desktop_live_stream_viewer.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Frame JPEG 1x1 válido codificado em Base64
  final dummyJpeg = base64Decode(
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD8qqKKKAP/2Q==',
  );

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
  });
}
