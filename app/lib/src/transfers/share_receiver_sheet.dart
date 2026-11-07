import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:command/core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../connection/pc_store.dart';

class ShareReceiverSheet extends StatefulWidget {
  final String fileName;
  final Uint8List fileBytes;
  final CommandClient client;
  final SavedPc? targetPc;
  final VoidCallback? onCompleted;

  const ShareReceiverSheet({
    super.key,
    required this.fileName,
    required this.fileBytes,
    required this.client,
    this.targetPc,
    this.onCompleted,
  });

  @override
  State<ShareReceiverSheet> createState() => _ShareReceiverSheetState();
}

class _ShareReceiverSheetState extends State<ShareReceiverSheet> {
  bool _isUploading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  late final String _sha256Hash;
  List<DestinationFolder> _destinations = [];
  String _selectedId = 'inbound';
  static const int maxFileSizeBytes = 100 * 1024 * 1024; // 100 MiB

  @override
  void initState() {
    super.initState();
    _sha256Hash = sha256.convert(widget.fileBytes).toString();
    _loadDestinations();
  }

  String get _lastDestinationKey => 'share_last_destination_${widget.targetPc?.id ?? 'default'}';

  DestinationFolder? get _selected {
    for (final d in _destinations) {
      if (d.id == _selectedId) return d;
    }
    return null;
  }

  // Sem pastas cadastradas (ou PC antigo sem o endpoint) o envio segue para a inbound.
  Future<void> _loadDestinations() async {
    try {
      final list = await widget.client.listDestinations();
      String last = 'inbound';
      try {
        last = (await SharedPreferences.getInstance()).getString(_lastDestinationKey) ?? 'inbound';
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _destinations = list;
        if (list.any((d) => d.id == last)) _selectedId = last;
      });
    } catch (_) {}
  }

  Future<void> _selectDestination(String id) async {
    setState(() => _selectedId = id);
    try {
      await (await SharedPreferences.getInstance()).setString(_lastDestinationKey, id);
    } catch (_) {}
  }

  static IconData _iconFor(String icon) => switch (icon) {
        'tv' => Icons.tv,
        'movie' => Icons.movie,
        'doc' => Icons.description,
        'music' => Icons.music_note,
        'image' => Icons.image,
        _ => Icons.folder,
      };

  Future<String?> _askConflictPolicy() => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Arquivo já existe'),
          content: Text('"${widget.fileName}" já está nessa pasta do PC.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keepBoth'), child: const Text('Manter os dois')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'replace'), child: const Text('Substituir')),
          ],
        ),
      );

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startUpload({String? conflictPolicy}) async {
    if (widget.fileBytes.length > maxFileSizeBytes) {
      setState(() {
        _errorMessage = 'Arquivo excede o limite máximo permitido de 100 MiB.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.client.uploadInboundFile(
        fileName: widget.fileName,
        bytes: widget.fileBytes,
        expectedSha256: _sha256Hash,
        deviceId: 'android_share_sender',
        rootId: _selectedId,
        conflictPolicy: conflictPolicy,
      );

      if (mounted) {
        if (result.success) {
          setState(() {
            _isUploading = false;
            _isSuccess = true;
          });
          widget.onCompleted?.call();
        } else {
          setState(() {
            _isUploading = false;
            _errorMessage = result.message ?? 'Falha ao enviar arquivo para o PC.';
          });
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && mounted) {
        setState(() => _isUploading = false);
        final policy = await _askConflictPolicy();
        if (policy != null) await _startUpload(conflictPolicy: policy);
        return;
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Erro de envio: $e';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Erro de envio: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pcName = widget.targetPc?.name ?? 'PC Pareado (Command)';
    final isTooLarge = widget.fileBytes.length > maxFileSizeBytes;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_to_mobile, color: Color(0xFFA78BFA), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enviar Arquivo para o PC',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Destino: $pcName (${_selected?.name ?? 'pasta inbound'})',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Card de Detalhes do Arquivo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Color(0xFFA78BFA), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatSize(widget.fileBytes.length),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'SHA-256: ${_sha256Hash.substring(0, 16)}...',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_destinations.isNotEmpty) ...[
            Text('Enviar para', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.inbox, size: 16),
                  label: const Text('Padrão'),
                  selected: _selectedId == 'inbound',
                  onSelected: _isUploading ? null : (_) => _selectDestination('inbound'),
                ),
                for (final d in _destinations)
                  ChoiceChip(
                    avatar: Icon(_iconFor(d.icon), size: 16),
                    label: Text(d.name),
                    selected: _selectedId == d.id,
                    onSelected: _isUploading ? null : (_) => _selectDestination(d.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (isTooLarge) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arquivo excede o limite máximo permitido de 100 MiB.',
                      style: TextStyle(color: Color(0xFFF87171), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isSuccess) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF34D5A0).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF34D5A0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selected == null
                          ? 'Arquivo enviado com sucesso para a pasta inbound do PC!'
                          : 'Arquivo enviado com sucesso para "${_selected!.name}" no PC!',
                      style: const TextStyle(color: Color(0xFF34D5A0), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSuccess ? const Color(0xFF34D5A0) : const Color(0xFFA78BFA),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Icon(_isSuccess ? Icons.check : Icons.upload_rounded),
              label: Text(
                _isUploading
                    ? 'Enviando...'
                    : _isSuccess
                        ? 'Concluído'
                        : 'Confirmar e Enviar para o PC',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isUploading || isTooLarge
                  ? null
                  : _isSuccess
                      ? () => Navigator.of(context).pop()
                      : _startUpload,
            ),
          ),
        ],
      ),
    );
  }
}
