import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'app_theme.dart';
import 'deck_theme.dart';

/// Guarda a aparência escolhida e a persiste no aparelho. O MaterialApp observa
/// [settings], então qualquer mudança vale na hora.
class ThemeController {
  ThemeController._();
  static final instance = ThemeController._();

  static const _presetKey = 'theme_preset';
  static const _modeKey = 'theme_mode';
  static const _accentKey = 'theme_accent';
  static const _tileStyleKey = 'theme_tile_style';
  static const _deckOnlyKey = 'deck_only';

  final settings = signal(const ThemeSettings());

  /// Esconde a aba de áudio: o app abre direto no deck, em tela cheia.
  final deckOnly = signal(false);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accent = prefs.getInt(_accentKey);
      settings.value = ThemeSettings(
        presetId: presetById(prefs.getString(_presetKey)).id,
        mode:
            ThemeMode.values.asNameMap()[prefs.getString(_modeKey)] ??
            ThemeMode.system,
        accent: accent != null ? Color(accent) : null,
        tileStyle: DeckTileStyle.values
            .asNameMap()[prefs.getString(_tileStyleKey)],
      );
      deckOnly.value = prefs.getBool(_deckOnlyKey) ?? false;
    } catch (_) {
      // Preferências ilegíveis: fica no padrão em vez de travar o startup.
    }
  }

  Future<void> setDeckOnly(bool value) async {
    deckOnly.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deckOnlyKey, value);
  }

  Future<void> update(ThemeSettings next) async {
    settings.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_presetKey, next.presetId);
    await prefs.setString(_modeKey, next.mode.name);
    if (next.accent != null) {
      await prefs.setInt(_accentKey, next.accent!.toARGB32());
    } else {
      await prefs.remove(_accentKey);
    }
    if (next.tileStyle != null) {
      await prefs.setString(_tileStyleKey, next.tileStyle!.name);
    } else {
      await prefs.remove(_tileStyleKey);
    }
  }
}
