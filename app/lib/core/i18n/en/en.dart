import 'config.dart';
import 'core.dart';
import 'deck.dart';
import 'editors.dart';

/// Traduções para inglês, por área do app. Chave = texto em português, exatamente como
/// aparece no código (com os placeholders {nome}).
const Map<String, String> enStrings = {
  ...enCore,
  ...enDeck,
  ...enEditors,
  ...enConfig,
};
