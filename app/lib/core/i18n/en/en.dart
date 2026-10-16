import 'config.dart';
import 'core.dart';
import 'deck.dart';
import 'editors.dart';

/// Traduções para inglês, por área do app (não é const: a mesma chave pode aparecer em
/// mais de um arquivo; vale a última). Chave = texto em português, exatamente como
/// aparece no código (com os placeholders {nome}).
final Map<String, String> enStrings = {
  ...enCore,
  ...enDeck,
  ...enEditors,
  ...enConfig,
};
