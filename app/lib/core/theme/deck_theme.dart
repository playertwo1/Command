import 'package:companion/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

/// Como os botões do deck são desenhados.
enum DeckTileStyle {
  /// Bloco preenchido com a cor do botão (o visual original).
  solid('Sólido'),

  /// Fundo escuro com borda na cor do botão.
  outline('Contorno'),

  /// Moldura dupla com canto chanfrado e triângulo na cor do botão.
  frame('Moldura');

  const DeckTileStyle(this.ptLabel);

  /// Rótulo em português (chave de tradução); a tela usa [label].
  final String ptLabel;
  String get label => tr(ptLabel);
}

/// Cores e estilo da grade do deck. Fica no [ThemeData] como extensão, então
/// qualquer widget lê com [DeckTheme.of].
@immutable
class DeckTheme extends ThemeExtension<DeckTheme> {
  const DeckTheme({
    required this.tileStyle,
    required this.background,
    required this.tileColor,
    required this.emptyTileColor,
    required this.outline,
    required this.foreground,
    required this.accent,
    required this.activeColor,
  });

  final DeckTileStyle tileStyle;

  /// Fundo atrás da grade.
  final Color background;

  /// Preenchimento do botão sem cor própria.
  final Color tileColor;

  /// Preenchimento do slot vazio.
  final Color emptyTileColor;

  /// Traço das molduras/contornos.
  final Color outline;

  /// Ícone e texto sobre o botão.
  final Color foreground;

  final Color accent;

  /// Cor de "ligado" quando o botão não define a sua.
  final Color activeColor;

  /// Fora do app (testes com um MaterialApp cru) a extensão não existe: deriva
  /// do esquema de cores para nunca quebrar.
  static DeckTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<DeckTheme>() ??
        DeckTheme.fromScheme(theme.colorScheme);
  }

  factory DeckTheme.fromScheme(
    ColorScheme scheme, {
    DeckTileStyle style = DeckTileStyle.solid,
  }) {
    final dark = scheme.brightness == Brightness.dark;
    return DeckTheme(
      tileStyle: style,
      background: scheme.surface,
      tileColor: dark
          ? const Color(0xFF303030)
          : scheme.surfaceContainerHighest,
      emptyTileColor: scheme.surfaceContainerLow,
      outline: dark ? scheme.onSurface.withValues(alpha: 0.85) : scheme.outline,
      foreground: dark ? Colors.white : scheme.onSurface,
      accent: scheme.primary,
      activeColor: dark ? const Color(0xFFB71C1C) : const Color(0xFFD32F2F),
    );
  }

  @override
  DeckTheme copyWith({
    DeckTileStyle? tileStyle,
    Color? background,
    Color? tileColor,
    Color? emptyTileColor,
    Color? outline,
    Color? foreground,
    Color? accent,
    Color? activeColor,
  }) {
    return DeckTheme(
      tileStyle: tileStyle ?? this.tileStyle,
      background: background ?? this.background,
      tileColor: tileColor ?? this.tileColor,
      emptyTileColor: emptyTileColor ?? this.emptyTileColor,
      outline: outline ?? this.outline,
      foreground: foreground ?? this.foreground,
      accent: accent ?? this.accent,
      activeColor: activeColor ?? this.activeColor,
    );
  }

  @override
  DeckTheme lerp(DeckTheme? other, double t) {
    if (other == null) return this;
    return DeckTheme(
      tileStyle: t < 0.5 ? tileStyle : other.tileStyle,
      background: Color.lerp(background, other.background, t)!,
      tileColor: Color.lerp(tileColor, other.tileColor, t)!,
      emptyTileColor: Color.lerp(emptyTileColor, other.emptyTileColor, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      activeColor: Color.lerp(activeColor, other.activeColor, t)!,
    );
  }
}
