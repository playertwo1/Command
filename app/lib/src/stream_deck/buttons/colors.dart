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

/// "#RRGGBB", ou "#AARRGGBB" quando a cor não é opaca.
String colorToHex(Color color) {
  final argb = color.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  final alpha = (argb >> 24) & 0xFF;
  if (alpha == 0xFF) return '#$rgb';
  final aa = alpha.toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#$aa$rgb';
}
