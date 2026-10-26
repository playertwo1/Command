import 'dart:typed_data';
import 'dart:ui';

/// Dimensões extraídas do cabeçalho JPEG.
class JpegDimensions {
  final int width;
  final int height;

  const JpegDimensions(this.width, this.height);

  double get aspectRatio => width / (height > 0 ? height : 1);
}

/// Utilitário para extração de cabeçalhos e mapeamento matemático de toques na tela.
class ScreenCoordinateMapper {
  /// Extrai dimensões (largura e altura) de um cabeçalho JPEG binário.
  /// Suporta marcadores SOF0 (0xC0 Baseline), SOF1 (0xC1 Extended) e SOF2 (0xC2 Progressive).
  static JpegDimensions? extractJpegDimensions(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
      return null;
    }

    int offset = 2;
    while (offset + 4 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final marker = bytes[offset + 1];

      // Marcadores sem payload de comprimento: SOI (0xD8), EOI (0xD9), RST (0xD0-0xD7)
      if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
        offset += 2;
        continue;
      }

      if (offset + 4 > bytes.length) break;
      final length = (bytes[offset + 2] << 8) | bytes[offset + 3];

      // SOF0 (Baseline), SOF1 (Extended Sequential), SOF2 (Progressive)
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        if (offset + 9 <= bytes.length) {
          final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
          final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
          if (width > 0 && height > 0) {
            return JpegDimensions(width, height);
          }
        }
        break;
      }

      offset += 2 + length;
    }

    return null;
  }

  /// Mapeia uma coordenada local dentro de um container renderizado com BoxFit.contain
  /// para coordenadas normalizadas entre [0.0, 1.0] relativas à imagem real.
  /// Retorna `null` se o toque ocorreu nas barras pretas laterais ou verticais (pillarbox/letterbox).
  static Offset? mapContainerToNormalized({
    required Offset localPosition,
    required Size containerSize,
    required double imageAspectRatio,
  }) {
    if (containerSize.width <= 0 || containerSize.height <= 0 || imageAspectRatio <= 0) {
      return null;
    }

    final containerAspect = containerSize.width / containerSize.height;
    double renderWidth;
    double renderHeight;
    double offsetX;
    double offsetY;

    if (containerAspect > imageAspectRatio) {
      // Container mais largo que a imagem -> barras pretas nas laterais (pillarbox)
      renderHeight = containerSize.height;
      renderWidth = containerSize.height * imageAspectRatio;
      offsetX = (containerSize.width - renderWidth) / 2;
      offsetY = 0;
    } else {
      // Container mais alto que a imagem -> barras pretas no topo e na base (letterbox)
      renderWidth = containerSize.width;
      renderHeight = containerSize.width / imageAspectRatio;
      offsetX = 0;
      offsetY = (containerSize.height - renderHeight) / 2;
    }

    final imgX = localPosition.dx - offsetX;
    final imgY = localPosition.dy - offsetY;

    // Se tocou fora da imagem renderizada (na barra preta), ignora
    if (imgX < 0 || imgX > renderWidth || imgY < 0 || imgY > renderHeight) {
      return null;
    }

    final normX = (imgX / renderWidth).clamp(0.0, 1.0);
    final normY = (imgY / renderHeight).clamp(0.0, 1.0);

    return Offset(normX, normY);
  }
}
