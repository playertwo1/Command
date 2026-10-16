import 'package:droiddeck/core/i18n/en/en.dart';
import 'package:droiddeck/core/i18n/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppLanguage.choice.value = 'pt');

  test('português devolve a chave; inglês devolve a tradução', () {
    AppLanguage.choice.value = 'pt';
    expect(tr('Salvar'), 'Salvar');
    AppLanguage.choice.value = 'en';
    expect(tr('Salvar'), 'Save');
  });

  test('placeholders e texto sem tradução', () {
    AppLanguage.choice.value = 'en';
    expect(tr('Texto que não existe {x}', {'x': 1}), 'Texto que não existe 1');
  });

  test('toda tradução mantém os mesmos placeholders da chave', () {
    final re = RegExp(r'\{(\w+)\}');
    for (final e in enStrings.entries) {
      final a = re.allMatches(e.key).map((m) => m[1]).toSet();
      final b = re.allMatches(e.value).map((m) => m[1]).toSet();
      expect(b, a, reason: 'placeholders diferentes em "${e.key}"');
    }
  });
}
