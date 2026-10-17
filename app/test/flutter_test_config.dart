import 'dart:async';

import 'package:droiddeck/core/i18n/i18n.dart';

/// Os testes procuram os textos em português: fixa o idioma, senão valeria o do sistema.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppLanguage.choice.value = 'pt';
  await testMain();
}
