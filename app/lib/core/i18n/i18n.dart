import 'dart:ui' show PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'en/en.dart';

/// Idioma da interface: o texto-fonte é português e [tr] devolve a tradução quando o
/// idioma é inglês. Texto sem tradução aparece em português (nunca some).
///
/// Placeholders entre chaves: `tr('Conectado — {account}', {'account': nome})`.
class AppLanguage {
  AppLanguage._();

  static const _prefKey = 'app_language';

  /// Escolha do usuário: 'auto' (idioma do aparelho), 'pt' ou 'en'.
  static final choice = signal('auto');

  /// Idioma em uso: 'pt' ou 'en'.
  static final current = computed(() => resolve(choice.value));

  static String resolve(String choice) {
    if (choice == 'pt' || choice == 'en') return choice;
    final device = PlatformDispatcher.instance.locale.languageCode;
    return device == 'pt' ? 'pt' : 'en';
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      choice.value = prefs.getString(_prefKey) ?? 'auto';
    } catch (_) {}
  }

  static Future<void> set(String value) async {
    choice.value = value;
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, value);
    } catch (_) {}
  }

  /// Valor do cabeçalho Accept-Language para o PC traduzir o que manda (schema, erros).
  static String get header => current.value == 'en' ? 'en' : 'pt-BR';
}

String tr(String pt, [Map<String, Object?> args = const {}]) {
  var s = AppLanguage.current.value == 'en' ? (enStrings[pt] ?? pt) : pt;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  return s;
}
