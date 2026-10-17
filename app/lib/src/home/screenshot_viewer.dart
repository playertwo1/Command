import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:droiddeck/core/droiddeck_client/models/screenshot_models.dart';

class ScreenshotViewerPage extends StatelessWidget {
  final ScreenshotInfo info;
  final Uint8List imageBytes;

  const ScreenshotViewerPage({
    super.key,
    required this.info,
    required this.imageBytes,
  });

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(
          imageBytes,
          name: 'command_screenshot_${info.id}.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
      fileNameOverrides: ['command_screenshot_${info.id}.jpg'],
      subject: 'Command Screenshot (${info.width}x${info.height})',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.85),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Captura de Tela',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${info.width}x${info.height} · ${(info.sizeBytes / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartilhar',
            onPressed: _share,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
