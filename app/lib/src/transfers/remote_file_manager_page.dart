import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:droiddeck/core/core.dart';

class RemoteFileManagerPage extends StatefulWidget {
  final DroidDeckClient client;
  final String initialRootId;
  final String? deviceId;
  final String? targetPcName;

  const RemoteFileManagerPage({
    super.key,
    required this.client,
    this.initialRootId = 'outbound',
    this.deviceId,
    this.targetPcName,
  });

  @override
  State<RemoteFileManagerPage> createState() => _RemoteFileManagerPageState();
}

class _RemoteFileManagerPageState extends State<RemoteFileManagerPage> {
  late String _rootId;
  String _currentPath = '';
  List<DirectoryBrowseItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _downloadingPaths = {};
  final Map<String, Uint8List> _downloadedFiles = {};

  @override
  void initState() {
    super.initState();
    _rootId = widget.initialRootId;
    _fetchDirectory();
  }

  Future<void> _fetchDirectory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.client.browseDirectory(
        _rootId,
        subPath: _currentPath.isEmpty ? null : _currentPath,
        deviceId: widget.deviceId,
      );

      if (mounted) {
        setState(() {
          _items = result.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao listar pasta: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSubfolder(String relativePath) {
    setState(() {
      _currentPath = relativePath;
    });
    _fetchDirectory();
  }

  void _navigateUp() {
    if (_currentPath.isEmpty) return;
    final parts = _currentPath.split('/');
    if (parts.length <= 1) {
      setState(() => _currentPath = '');
    } else {
      parts.removeLast();
      setState(() => _currentPath = parts.join('/'));
    }
    _fetchDirectory();
  }

  void _navigateToCrumbIndex(int index) {
    if (index < 0) {
      setState(() => _currentPath = '');
    } else {
      final parts = _currentPath.split('/');
      setState(() => _currentPath = parts.take(index + 1).join('/'));
    }
    _fetchDirectory();
  }

  Future<void> _downloadFile(DirectoryBrowseItem item) async {
    if (_downloadingPaths.contains(item.relativePath)) return;

    setState(() {
      _downloadingPaths.add(item.relativePath);
    });

    try {
      final downloadData = await widget.client.downloadNestedFile(
        item.relativePath,
        deviceId: widget.deviceId,
      );

      // Validação de integridade SHA-256 no cliente
      final clientSha = sha256.convert(downloadData.bytes).toString().toLowerCase();
      if (downloadData.checksumSha256.isNotEmpty &&
          clientSha != downloadData.checksumSha256.toLowerCase()) {
        throw Exception('Inconsistência de integridade SHA-256 no arquivo baixado.');
      }

      if (mounted) {
        setState(() {
          _downloadedFiles[item.relativePath] = downloadData.bytes;
          _downloadingPaths.remove(item.relativePath);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} baixado com sucesso!'),
            backgroundColor: const Color(0xFF34D5A0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingPaths.remove(item.relativePath);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no download: $e'),
            backgroundColor: const Color(0xFFF87171),
          ),
        );
      }
    }
  }

  Future<void> _shareFile(DirectoryBrowseItem item) async {
    final bytes = _downloadedFiles[item.relativePath];
    if (bytes == null) return;

    await SharePlus.instance.share(ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: item.name,
        ),
      ],
      fileNameOverrides: [item.name],
      subject: 'Arquivo baixado do PC: ${item.name}',
    ));
  }

  IconData _getFileIcon(String ext) {
    return switch (ext.toLowerCase()) {
      '.pdf' => Icons.picture_as_pdf,
      '.csv' || '.xlsx' => Icons.table_chart_outlined,
      '.png' || '.jpg' || '.jpeg' || '.webp' => Icons.image_outlined,
      '.txt' || '.md' || '.json' => Icons.description_outlined,
      '.mp3' || '.wav' => Icons.audio_file_outlined,
      '.mp4' => Icons.video_file_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
  }

  Color _getFileColor(String ext) {
    return switch (ext.toLowerCase()) {
      '.pdf' => const Color(0xFFF87171),
      '.csv' || '.xlsx' => const Color(0xFF34D5A0),
      '.png' || '.jpg' || '.jpeg' || '.webp' => const Color(0xFF38BDF8),
      '.txt' || '.md' || '.json' => const Color(0xFFA78BFA),
      '.mp3' || '.wav' => const Color(0xFFFB923C),
      '.mp4' => const Color(0xFFF472B6),
      _ => Colors.white70,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = _currentPath.isEmpty ? <String>[] : _currentPath.split('/');
    final location = '$_rootId${_currentPath.isNotEmpty ? '/$_currentPath' : ''}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gerenciador de Arquivos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.targetPcName == null
                  ? location
                  : '${widget.targetPcName} · $location',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Alterar Raiz',
            icon: const Icon(Icons.folder_shared_outlined),
            onSelected: (newRoot) {
              if (_rootId == newRoot) return;
              setState(() {
                _rootId = newRoot;
                _currentPath = '';
              });
              _fetchDirectory();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'outbound',
                child: Text('Pastas de Saída (outbound)'),
              ),
              PopupMenuItem(
                value: 'inbound',
                child: Text('Pastas de Entrada (inbound)'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _fetchDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Breadcrumbs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Row(
              children: [
                if (_currentPath.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    tooltip: 'Subir Nível',
                    onPressed: _navigateUp,
                  ),
                InkWell(
                  onTap: () => _navigateToCrumbIndex(-1),
                  child: Text(
                    _rootId,
                    style: const TextStyle(
                      color: Color(0xFFA78BFA),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                for (int i = 0; i < crumbs.length; i++) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('/', style: TextStyle(color: Colors.white38)),
                  ),
                  InkWell(
                    onTap: () => _navigateToCrumbIndex(i),
                    child: Text(
                      crumbs[i],
                      style: TextStyle(
                        color: i == crumbs.length - 1 ? Colors.white : const Color(0xFFA78BFA),
                        fontWeight: i == crumbs.length - 1 ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Área de Conteúdo
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFA78BFA)))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Color(0xFFF87171)),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFF87171)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchDirectory,
                                child: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 48, color: Colors.white24),
                                SizedBox(height: 12),
                                Text(
                                  'Esta pasta está vazia',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final isDownloaded = _downloadedFiles.containsKey(item.relativePath);
                              final isDownloading = _downloadingPaths.contains(item.relativePath);

                              if (item.isDirectory) {
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0x22A78BFA),
                                    child: Icon(Icons.folder, color: Color(0xFFA78BFA)),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: const Text('Pasta de arquivos', style: TextStyle(fontSize: 11)),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                                  onTap: () => _navigateToSubfolder(item.relativePath),
                                );
                              }

                              final iconData = _getFileIcon(item.extension);
                              final iconColor = _getFileColor(item.extension);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: iconColor.withValues(alpha: 0.15),
                                  child: Icon(iconData, color: iconColor),
                                ),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  '${item.formattedSize} · ${item.modifiedAtUtc.toLocal().toString().substring(0, 16)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                                ),
                                trailing: _rootId == 'outbound'
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isDownloading)
                                            const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFA78BFA),
                                              ),
                                            )
                                          else if (isDownloaded) ...[
                                            IconButton(
                                              icon: const Icon(Icons.share_outlined, color: Color(0xFFA78BFA)),
                                              tooltip: 'Compartilhar',
                                              onPressed: () => _shareFile(item),
                                            ),
                                            const Icon(Icons.check_circle, color: Color(0xFF34D5A0), size: 20),
                                          ] else
                                            IconButton(
                                              icon: const Icon(Icons.download_outlined),
                                              tooltip: 'Baixar',
                                              onPressed: () => _downloadFile(item),
                                            ),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
