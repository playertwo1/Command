import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:droiddeck/core/core.dart';

/// Modal BottomSheet para Exportação e Restauração de Backups Criptografados (Onda P1).
class EncryptedBackupSheet extends StatefulWidget {
  final DroidDeckClient client;

  const EncryptedBackupSheet({
    super.key,
    required this.client,
  });

  static Future<void> show(BuildContext context, DroidDeckClient client) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EncryptedBackupSheet(client: client),
    );
  }

  @override
  State<EncryptedBackupSheet> createState() => _EncryptedBackupSheetState();
}

class _EncryptedBackupSheetState extends State<EncryptedBackupSheet> {
  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color sheetBg = Color(0xFF161424);
  static const Color surfaceBg = Color(0xFF1E1B2E);
  static const Color borderColor = Color(0xFF2E2A4A);

  final TextEditingController _exportPassphraseCtrl = TextEditingController();
  final TextEditingController _restoreEnvelopeCtrl = TextEditingController();
  final TextEditingController _restorePassphraseCtrl = TextEditingController();

  bool _isProcessing = false;
  String? _exportJsonResult;
  String? _exportError;
  String? _restoreStatus;
  String? _restoreError;

  @override
  void dispose() {
    _exportPassphraseCtrl.dispose();
    _restoreEnvelopeCtrl.dispose();
    _restorePassphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final passphrase = _exportPassphraseCtrl.text.trim();
    if (passphrase.length < 6) {
      setState(() {
        _exportError = 'A senha mestra deve conter ao menos 6 caracteres.';
        _exportJsonResult = null;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _exportError = null;
      _exportJsonResult = null;
    });

    try {
      final envelope = await widget.client.exportEncryptedBackup(passphrase);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(envelope.toJson());
      if (mounted) {
        setState(() {
          _exportJsonResult = jsonStr;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportError = 'Erro ao exportar backup: $e';
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    final rawJson = _restoreEnvelopeCtrl.text.trim();
    final passphrase = _restorePassphraseCtrl.text.trim();

    if (rawJson.isEmpty) {
      setState(() {
        _restoreError = 'Insira o JSON do envelope criptografado.';
        _restoreStatus = null;
      });
      return;
    }

    if (passphrase.isEmpty) {
      setState(() {
        _restoreError = 'Digite a senha do backup.';
        _restoreStatus = null;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _restoreError = null;
      _restoreStatus = null;
    });

    try {
      final Map<String, dynamic> parsed = jsonDecode(rawJson) as Map<String, dynamic>;
      final envelope = EncryptedBackupEnvelopeModel.fromJson(parsed);

      final result = await widget.client.restoreEncryptedBackup(envelope, passphrase);
      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (result.success) {
            _restoreStatus = 'Restauração concluída com sucesso!\n'
                '• Rotinas restauradas: ${result.restoredRoutinesCount}\n'
                '• Permissões restauradas: ${result.restoredPermissionsCount}';
          } else {
            _restoreError = result.errorMessage ?? 'Falha na restauração do backup.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _restoreError = 'Formato inválido ou erro de decodificação: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: borderColor, width: 1.5),
          left: BorderSide(color: borderColor, width: 1.5),
          right: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: amethystAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: amethystAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Backup Criptografado (AES-256)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TabBar(
              indicatorColor: amethystAccent,
              labelColor: amethystAccent,
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(
                  icon: Icon(Icons.security, size: 20),
                  text: 'Exportar Backup',
                ),
                Tab(
                  icon: Icon(Icons.verified_user_outlined, size: 20),
                  text: 'Restaurar Backup',
                ),
              ],
            ),
            Flexible(
              child: TabBarView(
                children: [
                  _buildExportTab(),
                  _buildRestoreTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Proteja rotinas, configurações e perfis com AES-256-GCM. '
            'A chave é derivada da senha por PBKDF2/Argon2.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _exportPassphraseCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Senha Mestra (mínimo 6 caracteres)',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: surfaceBg,
              prefixIcon: const Icon(Icons.lock_outline, color: amethystAccent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: amethystAccent, width: 2),
              ),
            ),
          ),
          if (_exportError != null) ...[
            const SizedBox(height: 10),
            Text(
              _exportError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_generate_encrypted_backup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: amethystAccent,
              foregroundColor: sheetBg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isProcessing ? null : _handleExport,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shield_outlined),
            label: Text(
              _isProcessing ? 'Gerando Cifra...' : 'Gerar Envelope Criptografado',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_exportJsonResult != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Envelope Gerado (JSON):',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  key: const Key('btn_copy_backup_json'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _exportJsonResult!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Envelope copiado para a área de transferência!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16, color: amethystAccent),
                  label: const Text(
                    'Copiar JSON',
                    style: TextStyle(color: amethystAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                _exportJsonResult!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cole o envelope criptografado abaixo e digite a mesma senha utilizada no momento da exportação.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('input_restore_envelope_json'),
            controller: _restoreEnvelopeCtrl,
            maxLines: 4,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            decoration: InputDecoration(
              labelText: 'JSON do Envelope Criptografado',
              labelStyle: const TextStyle(color: Colors.white70),
              alignLabelWithHint: true,
              filled: true,
              fillColor: surfaceBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: amethystAccent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('input_restore_passphrase'),
            controller: _restorePassphraseCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Senha Mestra de Descriptografia',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: surfaceBg,
              prefixIcon: const Icon(Icons.lock_outline, color: amethystAccent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: amethystAccent, width: 2),
              ),
            ),
          ),
          if (_restoreError != null) ...[
            const SizedBox(height: 10),
            Text(
              _restoreError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (_restoreStatus != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Text(
                _restoreStatus!,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const Key('btn_execute_encrypted_restore'),
            style: ElevatedButton.styleFrom(
              backgroundColor: amethystAccent,
              foregroundColor: sheetBg,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isProcessing ? null : _handleRestore,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _isProcessing ? 'Validando Integridade...' : 'Restaurar Dados Seguros',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
