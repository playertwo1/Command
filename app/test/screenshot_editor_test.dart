import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/home/screenshot_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPngBytes = Uint8List.fromList([
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

  final testInfo = ScreenshotInfo(
    id: 'sc_test_123',
    requestId: 'req_123',
    width: 1920,
    height: 1080,
    sizeBytes: 153600,
    createdAtUtc: DateTime.utc(2026, 10, 17, 12, 0),
    expiresAtUtc: DateTime.utc(2026, 10, 17, 12, 10),
  );

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

    // Arrasta o dedo sobre a imagem para criar um retângulo de destaque
    final gestureTarget = find.byKey(const Key('annotation_canvas_gesture'));
    expect(gestureTarget, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(gestureTarget));
    await gesture.moveBy(const Offset(80, 60));
    await gesture.up();
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
