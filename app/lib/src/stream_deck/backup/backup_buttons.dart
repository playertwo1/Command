import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/backup/backup_file.dart';
import 'package:flutter/material.dart';

/// Exportar e importar os perfis num arquivo .droiddeck.
class BackupButtons extends StatefulWidget {
  /// Chamado depois de importar, para a tela recarregar os perfis.
  final VoidCallback? onImported;

  /// Aparência compacta (barra lateral do configurador) ou em lista (configurações).
  final bool dense;

  const BackupButtons({super.key, this.onImported, this.dense = false});

  @override
  State<BackupButtons> createState() => _BackupButtonsState();
}

class _BackupButtonsState extends State<BackupButtons> {
  bool _busy = false;

  DroidDeckClient get _client => Injector.get<DroidDeckClient>();

  Future<void> _run(Future<String> Function() job) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await job();
      if (message.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _errorText(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) return data['error'] as String;
      if (e.response == null) return tr('O PC não respondeu.');
    }
    return tr('Não deu certo: {error}', {'error': e});
  }

  Future<String> _export() async {
    final bytes = await _client.exportBackup();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    await saveBackupFile(
        bytes, 'DroidDeck-${now.year}-${two(now.month)}-${two(now.day)}.droiddeck');
    return '';
  }

  Future<String> _import() async {
    final bytes = await pickBackupFile();
    if (bytes == null || !mounted) return '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Importar backup?')),
        content: Text(tr(
          'Os perfis do arquivo entram no deck. Um perfil que já existe aqui (o mesmo '
          'perfil, de um backup anterior) é substituído pela versão do arquivo.',
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancelar'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Importar'))),
        ],
      ),
    );
    if (ok != true) return '';
    final count = await _client.importBackup(bytes);
    widget.onImported?.call();
    return count == 1
        ? tr('1 perfil importado.')
        : tr('{n} perfis importados.', {'n': count});
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (widget.dense) {
      Widget button(IconData icon, String label, VoidCallback onTap) => Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: TextButton.icon(
              onPressed: _busy ? null : onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
                foregroundColor: muted,
              ),
            ),
          );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.download, tr('Exportar backup'), () => _run(_export)),
          if (canPickBackup)
            button(Icons.upload, tr('Importar backup'), () => _run(_import)),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.save_alt),
          title: Text(tr('Exportar backup do deck')),
          subtitle: Text(tr(
              'Salva todos os perfis num arquivo .droiddeck. Para importar, use o configurador no PC.')),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: _busy ? null : () => _run(_export),
        ),
        if (canPickBackup)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: Text(tr('Importar backup')),
            onTap: _busy ? null : () => _run(_import),
          ),
      ],
    );
  }
}
