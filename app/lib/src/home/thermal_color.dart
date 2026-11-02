import 'package:flutter/material.dart';

/// Até 60°C verde, até 80°C âmbar, acima disso vermelho.
Color thermalColor(double? celsius) {
  if (celsius == null) return const Color(0xFF9CA3AF);
  if (celsius <= 60) return const Color(0xFF34D5A0);
  if (celsius <= 80) return const Color(0xFFF0B65F);
  return const Color(0xFFF87171);
}
