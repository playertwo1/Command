import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:droiddeck/core/droiddeck_client/models/screenshot_models.dart';

enum AnnotationMode { none, pen, rectangle }

class AnnotationItem {
  final AnnotationMode mode;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final Rect? rect;

  const AnnotationItem({
    required this.mode,
    required this.color,
    required this.strokeWidth,
    required this.points,
    this.rect,
  });
}

class AnnotationPainter extends CustomPainter {
  final List<AnnotationItem> items;
  final AnnotationItem? currentItem;

  const AnnotationPainter({
    required this.items,
    this.currentItem,
  });

  @override
  void paint(Canvas canvas, Size size) {
    void drawItem(AnnotationItem item) {
      final paint = Paint()
        ..color = item.color
        ..strokeWidth = item.strokeWidth
        ..style = item.mode == AnnotationMode.rectangle ? PaintingStyle.stroke : PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (item.mode == AnnotationMode.rectangle && item.rect != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(item.rect!, const Radius.circular(6)),
          paint,
        );
      } else if (item.mode == AnnotationMode.pen && item.points.length > 1) {
        final path = Path()..moveTo(item.points.first.dx, item.points.first.dy);
        for (int i = 1; i < item.points.length; i++) {
          path.lineTo(item.points[i].dx, item.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    for (final item in items) {
      drawItem(item);
    }
    if (currentItem != null) {
      drawItem(currentItem!);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) => true;
}

class ScreenshotViewerPage extends StatefulWidget {
  final ScreenshotInfo info;
  final Uint8List imageBytes;
  final VoidCallback? onAskHermes;

  const ScreenshotViewerPage({
    super.key,
    required this.info,
    required this.imageBytes,
    this.onAskHermes,
  });

  @override
  State<ScreenshotViewerPage> createState() => _ScreenshotViewerPageState();
}

class _ScreenshotViewerPageState extends State<ScreenshotViewerPage> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  AnnotationMode _activeMode = AnnotationMode.none;
  Color _selectedColor = const Color(0xFFA78BFA); // Amethyst padrão
  final List<AnnotationItem> _annotations = [];
  Offset? _dragStart;
  Offset? _dragCurrent;
  final List<Offset> _penPoints = [];
  bool _isExporting = false;

  void _undo() {
    if (_annotations.isNotEmpty) {
      setState(() {
        _annotations.removeLast();
      });
    }
  }

  void _clearAll() {
    setState(() {
      _annotations.clear();
      _activeMode = AnnotationMode.none;
    });
  }

  Future<void> _shareOriginal() async {
    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(
          widget.imageBytes,
          name: 'command_screenshot_${widget.info.id}.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
      fileNameOverrides: ['command_screenshot_${widget.info.id}.jpg'],
      subject: 'Command Screenshot (${widget.info.width}x${widget.info.height})',
    ));
  }

  Future<void> _shareAnnotated() async {
    if (_annotations.isEmpty) {
      await _shareOriginal();
      return;
    }

    setState(() => _isExporting = true);

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await _shareOriginal();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(
              pngBytes,
              name: 'command_screenshot_${widget.info.id}_annotated.png',
              mimeType: 'image/png',
            ),
          ],
          fileNameOverrides: ['command_screenshot_${widget.info.id}_annotated.png'],
          subject: 'Command Screenshot Anotado (${widget.info.width}x${widget.info.height})',
        ));
      }
    } catch (_) {
      await _shareOriginal();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnnotations = _annotations.isNotEmpty;

    AnnotationItem? liveItem;
    if (_activeMode == AnnotationMode.rectangle && _dragStart != null && _dragCurrent != null) {
      liveItem = AnnotationItem(
        mode: AnnotationMode.rectangle,
        color: _selectedColor,
        strokeWidth: 3.5,
        points: const [],
        rect: Rect.fromPoints(_dragStart!, _dragCurrent!),
      );
    } else if (_activeMode == AnnotationMode.pen && _penPoints.length > 1) {
      liveItem = AnnotationItem(
        mode: AnnotationMode.pen,
        color: _selectedColor,
        strokeWidth: 3.0,
        points: List.from(_penPoints),
      );
    }

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
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.info.width}x${widget.info.height} · ${(widget.info.sizeBytes / 1024).toStringAsFixed(1)} KB',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (widget.onAskHermes != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Color(0xFFA78BFA)),
              tooltip: 'Analisar com Hermes IA',
              onPressed: widget.onAskHermes,
            ),
          if (hasAnnotations) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Desfazer Anotação',
              onPressed: _undo,
            ),
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Limpar Todas',
              onPressed: _clearAll,
            ),
          ],
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.share_outlined),
            tooltip: hasAnnotations ? 'Compartilhar Anotado' : 'Compartilhar',
            onPressed: _isExporting ? null : _shareAnnotated,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _activeMode == AnnotationMode.none
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Image.memory(
                        widget.imageBytes,
                        fit: BoxFit.contain,
                      ),
                    )
                  : GestureDetector(
                      key: const Key('annotation_canvas_gesture'),
                      onPanStart: (details) {
                        final localPos = details.localPosition;
                        if (_activeMode == AnnotationMode.rectangle) {
                          setState(() {
                            _dragStart = localPos;
                            _dragCurrent = localPos;
                          });
                        } else if (_activeMode == AnnotationMode.pen) {
                          setState(() {
                            _penPoints.clear();
                            _penPoints.add(localPos);
                          });
                        }
                      },
                      onPanUpdate: (details) {
                        final localPos = details.localPosition;
                        if (_activeMode == AnnotationMode.rectangle) {
                          setState(() {
                            _dragCurrent = localPos;
                          });
                        } else if (_activeMode == AnnotationMode.pen) {
                          setState(() {
                            _penPoints.add(localPos);
                          });
                        }
                      },
                      onPanEnd: (_) {
                        if (_activeMode == AnnotationMode.rectangle &&
                            _dragStart != null &&
                            _dragCurrent != null) {
                          final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
                          if (rect.width > 5 && rect.height > 5) {
                            setState(() {
                              _annotations.add(AnnotationItem(
                                mode: AnnotationMode.rectangle,
                                color: _selectedColor,
                                strokeWidth: 3.5,
                                points: const [],
                                rect: rect,
                              ));
                              _dragStart = null;
                              _dragCurrent = null;
                            });
                          }
                        } else if (_activeMode == AnnotationMode.pen && _penPoints.length > 1) {
                          setState(() {
                            _annotations.add(AnnotationItem(
                              mode: AnnotationMode.pen,
                              color: _selectedColor,
                              strokeWidth: 3.0,
                              points: List.from(_penPoints),
                            ));
                            _penPoints.clear();
                          });
                        }
                      },
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: CustomPaint(
                          foregroundPainter: AnnotationPainter(
                            items: _annotations,
                            currentItem: liveItem,
                          ),
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          // Barra de Ferramentas de Edição e Anotação
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.pan_tool_outlined),
                  color: _activeMode == AnnotationMode.none ? const Color(0xFFA78BFA) : Colors.white60,
                  tooltip: 'Modo Zoom & Pan',
                  onPressed: () => setState(() => _activeMode = AnnotationMode.none),
                ),
                IconButton(
                  icon: const Icon(Icons.crop_square),
                  color: _activeMode == AnnotationMode.rectangle ? const Color(0xFFA78BFA) : Colors.white60,
                  tooltip: 'Destaque Retangular',
                  onPressed: () => setState(() => _activeMode = AnnotationMode.rectangle),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: _activeMode == AnnotationMode.pen ? const Color(0xFFA78BFA) : Colors.white60,
                  tooltip: 'Caneta Livre',
                  onPressed: () => setState(() => _activeMode = AnnotationMode.pen),
                ),
                const SizedBox(width: 8),
                // Seletor de Cores
                for (final color in const [
                  Color(0xFFA78BFA), // Amethyst
                  Color(0xFFFBBF24), // Amarelo
                  Color(0xFF34D5A0), // Verde
                  Color(0xFFF87171), // Vermelho
                ])
                  InkWell(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
