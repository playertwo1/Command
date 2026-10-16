import 'package:companion/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _hapticsKey = 'haptics';
  static const _autoProfileKey = 'auto_profile';

  final settings = signal(const ThemeSettings());

  /// Esconde a aba de áudio: o app abre direto no deck, em tela cheia.
  final deckOnly = signal(false);

  /// Vibração ao tocar num botão do deck.
  final haptics = signal(Haptics.light);

  /// Seguir o perfil do app em foco no PC.
  final autoProfile = signal(true);

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
      autoProfile.value = prefs.getBool(_autoProfileKey) ?? true;
      haptics.value =
          Haptics.values.asNameMap()[prefs.getString(_hapticsKey)] ??
          Haptics.light;
    } catch (_) {
      // Preferências ilegíveis: fica no padrão em vez de travar o startup.
    }
  }

  Future<void> setDeckOnly(bool value) async {
    deckOnly.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deckOnlyKey, value);
  }

  Future<void> setAutoProfile(bool value) async {
    autoProfile.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoProfileKey, value);
  }

  Future<void> setHaptics(Haptics value) async {
    haptics.value = value;
    value.play();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hapticsKey, value.name);
  }

  /// Vibra no toque de um botão, conforme a preferência.
  void tapFeedback() => haptics.value.play();

  /// Vibração forte, independente da intensidade escolhida (fim de um timer). Só não
  /// vibra com a vibração desligada.
  void alertFeedback() {
    if (haptics.value != Haptics.off) HapticFeedback.heavyImpact();
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

enum Haptics {
  off('Desligada'),
  light('Leve'),
  medium('Média'),
  heavy('Forte');

  const Haptics(this.ptLabel);

  /// Rótulo em português (chave de tradução); a tela usa [label].
  final String ptLabel;
  String get label => tr(ptLabel);

  void play() {
    switch (this) {
      case Haptics.off:
        return;
      case Haptics.light:
        HapticFeedback.lightImpact();
      case Haptics.medium:
        HapticFeedback.mediumImpact();
      case Haptics.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}
