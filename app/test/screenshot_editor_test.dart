import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/home/screenshot_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List testPngBytes;

  final testInfo = ScreenshotInfo(
    id: 'sc_test_123',
    requestId: 'req_123',
    width: 1920,
    height: 1080,
    sizeBytes: 153600,
    createdAtUtc: DateTime.utc(2026, 10, 17, 12, 0),
    expiresAtUtc: DateTime.utc(2026, 10, 17, 12, 10),
  );

  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 640, 360),
      ui.Paint()..color = const ui.Color(0xFF111111),
    );
    final image = await recorder.endRecording().toImage(640, 360);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    testPngBytes = png!.buffer.asUint8List();
    image.dispose();
  });

  testWidgets('Renders ScreenshotViewerPage with annotation tools', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenshotViewerPage(
          info: testInfo,
          imageBytes: testPngBytes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Captura de Tela'), findsOneWidget);
    expect(find.textContaining('1920x1080'), findsOneWidget);
    expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Draws rectangle highlight annotation and supports undo and clear', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScreenshotViewerPage(
          info: testInfo,
          imageBytes: testPngBytes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Seleciona ferramenta de retângulo
    await tester.tap(find.byIcon(Icons.crop_square));
    await tester.pumpAndSettle();

    // Arrasta o dedo sobre a imagem para criar um retângulo de destaque.
    // Um único moveBy não dispara onPanUpdate no recognizer (o primeiro
    // trecho vira só o slop). drag() quebra o movimento em dois eventos.
    final gestureTarget = find.byKey(const Key('annotation_canvas_gesture'));
    expect(gestureTarget, findsOneWidget);

    await tester.drag(gestureTarget, const Offset(80, 60));
    await tester.pumpAndSettle();

    // Ações de Undo e Clear devem aparecer na AppBar
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.clear_all), findsOneWidget);

    // Toca em Desfazer
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    // Após desfazer a única anotação, ações desaparecem
    expect(find.byIcon(Icons.undo), findsNothing);
    expect(find.byIcon(Icons.clear_all), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
