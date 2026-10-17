import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Baixa o backup pelo navegador.
Future<void> saveBackupFile(List<int> bytes, String name) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: 'application/zip'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

/// Abre o seletor de arquivos do navegador. Null se o usuário cancelar.
Future<List<int>?> pickBackupFile() {
  final completer = Completer<List<int>?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.droiddeck,.zip';
  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      completer.complete(null);
      return;
    }
    file.arrayBuffer().toDart.then(
          (buffer) => completer.complete(buffer.toDart.asUint8List()),
          onError: (_) => completer.complete(null),
        );
  }.toJS;
  // Cancelar não dispara change em todo navegador: o futuro fica pendente, sem custo.
  input.click();
  return completer.future;
}

const bool canPickBackup = true;
