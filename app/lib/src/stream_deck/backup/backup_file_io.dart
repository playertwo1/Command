import 'dart:typed_data';

import 'package:companion/core/i18n/i18n.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilha o backup (Drive, e-mail, "Salvar em arquivos"...).
Future<void> saveBackupFile(List<int> bytes, String name) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: 'application/zip')],
    fileNameOverrides: [name],
    subject: tr('Backup do DroidDeck'),
  ));
}

/// Escolher arquivo só existe no configurador do PC.
Future<List<int>?> pickBackupFile() async => null;

const bool canPickBackup = false;
