import 'package:droiddeck/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import 'deck_theme.dart';

/// Tema nomeado: define o visual escuro inteiro (fundo, superfícies, destaque e
/// estilo dos botões). O claro deriva da cor de destaque.
@immutable
class ThemePreset {
  const ThemePreset({
    required this.id,
    required String name,
    required this.accent,
    required this.background,
    required this.surface,
    required this.tile,
    required this.outline,
    required this.tileStyle,
  }) : ptName = name;

  final String id;
  /// Nome em português (chave de tradução); a tela usa [name].
  final String ptName;
  String get name => tr(ptName);
  final Color accent;
  final Color background;
  final Color surface;
  final Color tile;
  final Color outline;
  final DeckTileStyle tileStyle;
}

const kThemePresets = <ThemePreset>[
  ThemePreset(
    id: 'classico',
    name: 'Clássico',
    accent: Color(0xFF42A5F5),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    tile: Color(0xFF303030),
    outline: Color(0xFFE0E0E0),
    tileStyle: DeckTileStyle.solid,
  ),
  ThemePreset(
    id: 'neon',
    name: 'Neon',
    accent: Color(0xFF4FC3F7),
    background: Color(0xFF0B1020),
    surface: Color(0xFF141A2E),
    tile: Color(0xFF111729),
    outline: Color(0xFFDCE6FF),
    tileStyle: DeckTileStyle.frame,
  ),
  ThemePreset(
    id: 'oled',
    name: 'OLED',
    accent: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    tile: Color(0xFF000000),
    outline: Color(0xFF8A8A8A),
    tileStyle: DeckTileStyle.outline,
  ),
  ThemePreset(
    id: 'ambar',
    name: 'Âmbar',
    accent: Color(0xFFFFB300),
    background: Color(0xFF15120B),
    surface: Color(0xFF221D13),
    tile: Color(0xFF2E2719),
    outline: Color(0xFFFFE0A3),
    tileStyle: DeckTileStyle.solid,
  ),
  ThemePreset(
    id: 'synthwave',
    name: 'Synthwave',
    accent: Color(0xFFE040FB),
    background: Color(0xFF140A24),
    surface: Color(0xFF211338),
    tile: Color(0xFF1A0F2E),
    outline: Color(0xFFF3C6FF),
    tileStyle: DeckTileStyle.frame,
  ),
];

/// Cores oferecidas para trocar o destaque do tema.
const kAccentChoices = <Color>[
  Color(0xFF42A5F5), // azul
  Color(0xFF4FC3F7), // ciano
  Color(0xFF26A69A), // verde-água
  Color(0xFF66BB6A), // verde
  Color(0xFFFFB300), // âmbar
  Color(0xFFFF7043), // laranja
  Color(0xFFEF5350), // vermelho
  Color(0xFFEC407A), // rosa
  Color(0xFFAB47BC), // roxo
  Color(0xFF7E57C2), // violeta
];

ThemePreset presetById(String? id) => kThemePresets.firstWhere(
  (p) => p.id == id,
  orElse: () => kThemePresets.first,
);

/// Escolhas do usuário. Destaque e estilo nulos seguem o tema escolhido.
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.presetId = 'classico',
    this.mode = ThemeMode.system,
    this.accent,
    this.tileStyle,
  });

  final String presetId;
  final ThemeMode mode;
  final Color? accent;
  final DeckTileStyle? tileStyle;

  ThemePreset get preset => presetById(presetId);
  Color get effectiveAccent => accent ?? preset.accent;
  DeckTileStyle get effectiveTileStyle => tileStyle ?? preset.tileStyle;

  ThemeSettings copyWith({
    String? presetId,
    ThemeMode? mode,
    Color? Function()? accent,
    DeckTileStyle? Function()? tileStyle,
  }) {
    return ThemeSettings(
      presetId: presetId ?? this.presetId,
      mode: mode ?? this.mode,
      accent: accent != null ? accent() : this.accent,
      tileStyle: tileStyle != null ? tileStyle() : this.tileStyle,
    );
  }
}

Color _onColor(Color c) =>
    c.computeLuminance() > 0.45 ? Colors.black : Colors.white;

ThemeData buildAppTheme(ThemeSettings s, Brightness brightness) {
  final preset = s.preset;
  final accent = s.effectiveAccent;
  final style = s.effectiveTileStyle;
  final dark = brightness == Brightness.dark;

  var scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(primary: accent, onPrimary: _onColor(accent));

  DeckTheme deck;
  Color scaffold;
  if (dark) {
    // Superfícies do tema, em degraus a partir do fundo.
    Color step(double t) => Color.lerp(preset.background, preset.outline, t)!;
    scheme = scheme.copyWith(
      surface: preset.surface,
      surfaceContainerLowest: preset.background,
      surfaceContainerLow: step(0.04),
      surfaceContainer: step(0.07),
      surfaceContainerHigh: step(0.10),
      surfaceContainerHighest: step(0.14),
      outlineVariant: preset.outline.withValues(alpha: 0.16),
    );
    scaffold = preset.background;
    deck = DeckTheme(
      tileStyle: style,
      background: preset.background,
      tileColor: preset.tile,
      emptyTileColor: Color.lerp(preset.background, preset.tile, 0.6)!,
      outline: preset.outline,
      foreground: Colors.white,
      accent: accent,
      activeColor: const Color(0xFFB71C1C),
    );
  } else {
    scaffold = scheme.surface;
    deck = DeckTheme.fromScheme(scheme, style: style);
  }

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      surfaceTintColor: Colors.transparent,
    ),
    extensions: [deck],
  );
}
