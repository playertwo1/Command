import 'package:flutter/material.dart';

/// Cor de um "#RRGGBB" (ou "#AARRGGBB") salvo no perfil. Inválida ou vazia = null.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  try {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (_) {
    return null;
  }
}

/// "#RRGGBB" de uma cor, no formato que os perfis guardam.
String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
