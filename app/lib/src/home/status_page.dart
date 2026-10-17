import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../connection/pc_store.dart';
import '../services/signalr_service.dart';
import 'metric_sparkline.dart';
import 'screenshot_viewer.dart';

/// Aba de Telemetria e Estado do PC (Command)
class StatusPage extends StatefulWidget {
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final SignalRService? signalRService;
  final DroidDeckClient? client;

  const StatusPage({
    super.key,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.signalRService,
    this.client,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  SavedPc? _currentPc;
  List<AllowedApp> _apps = [];
  List<CommandJob> _jobs = [];
  bool _loadingApps = false;
  bool _loadingJobs = false;
  final Set<String> _pendingActions = {};

  ScreenshotInfo? _lastScreenshot;
  Uint8List? _lastScreenshotBytes;
  bool _capturingScreenshot = false;
  String? _screenshotError;

  List<TransferItem> _outboundFiles = [];
  bool _loadingTransfers = false;
  String? _transferError;
  final Set<String> _pendingDownloads = {};
  bool _uploadingInbound = false;

  List<WindowsServiceItem> _services = [];
  bool _loadingServices = false;
  String? _servicesError;

  TopProcessesData? _topProcesses;
  bool _loadingProcesses = false;
  String? _processesError;
  int _processSortIndex = 0;

  DroidDeckClient? get _client {
    if (widget.client != null) return widget.client;
    try {
      return Injector.get<DroidDeckClient>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPc();
    _loadAppsAndJobs();
  }

  Future<void> _loadPc() async {
    try {
      final pcs = await PcStore.load();
      if (mounted) {
        setState(() {
          _currentPc = pcs.where((p) => p.id == PcStore.currentId).firstOrNull ??
              (pcs.isNotEmpty ? pcs.first : null);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAppsAndJobs() async {
    await Future.wait([
      _fetchApps(),
      _fetchJobs(),
      _fetchTransfers(),
      _fetchServices(),
      _fetchTopProcesses(),
    ]);
  }

  Future<void> _fetchApps() async {
    final client = _client;
    if (client == null || _loadingApps) return;
    if (mounted) setState(() => _loadingApps = true);
    try {
      final apps = await client.getApps();
      if (mounted) {
        setState(() => _apps = apps);
      }
    } catch (_) {
      // Ignora erro de rede quando offline
    } finally {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _fetchJobs() async {
    final client = _client;
    if (client == null || _loadingJobs) return;
    if (mounted) setState(() => _loadingJobs = true);
    try {
      final jobs = await client.getJobs();
      if (mounted) {
        setState(() => _jobs = jobs);
      }
    } catch (_) {
      // Ignora erro de rede quando offline
    } finally {
      if (mounted) setState(() => _loadingJobs = false);
    }
  }

  Future<void> _captureScreenshot() async {
    final client = _client;
    if (client == null || _capturingScreenshot) return;

    setState(() {
      _capturingScreenshot = true;
      _screenshotError = null;
    });

    final reqId = 'sc_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final info = await client.captureScreenshot(
        requestId: reqId,
        deviceId: _currentPc?.id,
      );

      final bytes = await client.getScreenshotBytes(
        info.id,
        deviceId: _currentPc?.id,
      );

      if (mounted) {
        setState(() {
          _lastScreenshot = info;
          _lastScreenshotBytes = bytes;
          _screenshotError = null;
        });
        _fetchJobs();
      }
    } catch (e) {
      if (mounted) {
        String errStr = e.toString();
        if (e is DioException) {
          final data = e.response?.data;
          final code = (data is Map) ? data['code']?.toString() : null;
          final status = e.response?.statusCode;
          if (status == 423 || code == 'SESSION_LOCKED' || code == 'SECURE_DESKTOP') {
            errStr = 'Acesso Bloqueado: A área de trabalho está bloqueada ou em tela segura do Windows (UAC). Desbloqueie o PC para capturar a tela.';
          } else if (status == 503 || code == 'NOT_INTERACTIVE') {
            errStr = 'Sessão do Windows não interativa ou monitor indisponível.';
          } else if (data is Map && data['error'] != null) {
            errStr = data['error'].toString();
          }
        } else if (errStr.contains('423') || errStr.contains('SESSION_LOCKED')) {
          errStr = 'Acesso Bloqueado: A área de trabalho está bloqueada ou em tela segura do Windows (UAC). Desbloqueie o PC para capturar a tela.';
        }
        setState(() {
          _screenshotError = errStr;
        });
        _fetchJobs();
      }
    } finally {
      if (mounted) {
        setState(() => _capturingScreenshot = false);
      }
    }
  }

  Future<void> _launchApp(AllowedApp app) async {
    final client = _client;
    if (client == null || _pendingActions.contains(app.id)) return;
    setState(() => _pendingActions.add(app.id));

    final reqId = '${DateTime.now().microsecondsSinceEpoch}_${app.id}';
    try {
      final job = await client.launchApp(app.id, requestId: reqId);
      if (mounted) {
        if (job.status == 'succeeded') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('"{name}" iniciado com sucesso.', {'name': app.name}))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('Falha ao iniciar "{name}": {err}', {
                'name': app.name,
                'err': job.errorMessage ?? tr('Erro desconhecido'),
              })),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      await _fetchApps();
      await _fetchJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Erro ao executar ação (sem retry automático): {e}. Verifique a lista de Atividade.', {'e': e.toString()})),
            backgroundColor: const Color(0xFFF87171),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingActions.remove(app.id));
      }
    }
  }

  Future<void> _confirmAndKillApp(AllowedApp app) async {
    if (_pendingActions.contains(app.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Encerrar Aplicativo')),
        content: Text(
          tr('Deseja realmente encerrar a instância de "{name}"?\nEsta ação interrompe o processo imediatamente.', {'name': app.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF87171)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Encerrar')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final client = _client;
    if (client == null) return;

    setState(() => _pendingActions.add(app.id));
    final reqId = '${DateTime.now().microsecondsSinceEpoch}_kill_${app.id}';

    try {
      final job = await client.killApp(
        app.id,
        requestId: reqId,
        confirmed: true,
        processId: app.processId,
        startTimeUtc: app.startTimeUtc,
      );
      if (mounted) {
        if (job.status == 'succeeded') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('Processo de "{name}" encerrado.', {'name': app.name}))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('Falha ao encerrar "{name}": {err}', {
                'name': app.name,
                'err': job.errorMessage ?? tr('Erro desconhecido'),
              })),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      await _fetchApps();
      await _fetchJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Erro ao encerrar processo (sem retry automático): {e}. Verifique a lista de Atividade.', {'e': e.toString()})),
            backgroundColor: const Color(0xFFF87171),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingActions.remove(app.id));
      }
    }
  }

  Future<void> _clearJobs() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.clearJobs();
      if (mounted) {
        setState(() => _jobs = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Histórico de atividades limpo.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Erro ao limpar histórico: {e}', {'e': e.toString()}))),
        );
      }
    }
  }

  Future<void> _fetchTransfers() async {
    final client = _client;
    if (client == null || _loadingTransfers) return;
    if (mounted) {
      setState(() {
        _loadingTransfers = true;
        _transferError = null;
      });
    }
    try {
      final files = await client.listOutboundTransfers(deviceId: _currentPc?.id);
      if (mounted) {
        setState(() {
          _outboundFiles = files;
          _transferError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transferError = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loadingTransfers = false);
    }
  }

  Future<void> _downloadFile(TransferItem file) async {
    final client = _client;
    if (client == null || _pendingDownloads.contains(file.fileName)) return;

    setState(() => _pendingDownloads.add(file.fileName));

    try {
      final downloadData = await client.downloadOutboundFile(
        file.fileName,
        deviceId: _currentPc?.id,
      );

      final calculatedHash = sha256.convert(downloadData.bytes).toString();
      final expectedHash = downloadData.checksumSha256;

      final isValid = expectedHash.isNotEmpty &&
          calculatedHash.toLowerCase() == expectedHash.toLowerCase();

      if (mounted) {
        if (isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${file.fileName}: Download concluído! SHA-256 verificado (${calculatedHash.substring(0, 8)}...)',
              ),
              backgroundColor: const Color(0xFF34D5A0),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'AVISO DE SEGURANÇA: Divergência de checksum SHA-256 no arquivo ${file.fileName}!',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      await _fetchJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao baixar arquivo (sem retry automático): $e'),
            backgroundColor: const Color(0xFFF87171),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingDownloads.remove(file.fileName));
      }
    }
  }

  Future<void> _uploadTestFile() async {
    final client = _client;
    if (client == null || _uploadingInbound) return;

    setState(() => _uploadingInbound = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'mobile_report_$timestamp.csv';
      final content = 'id,timestamp,source,status\n1,$timestamp,AndroidEmulator,OK\n';
      final bytes = Uint8List.fromList(utf8.encode(content));
      final expectedSha256 = sha256.convert(bytes).toString();

      final result = await client.uploadInboundFile(
        fileName: fileName,
        bytes: bytes,
        expectedSha256: expectedSha256,
        deviceId: _currentPc?.id,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Arquivo "$fileName" enviado com sucesso para o PC! (SHA-256 verificado)'),
              backgroundColor: const Color(0xFF34D5A0),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha no upload (sem retry automático): ${result.message}'),
              backgroundColor: const Color(0xFFF87171),
            ),
          );
        }
      }
      await _fetchJobs();
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (e is DioException && e.response?.statusCode == 409) {
          msg = 'Conflito (409): O arquivo já existe na pasta inbound do PC.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar arquivo (sem retry automático): $msg'),
            backgroundColor: const Color(0xFFF87171),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingInbound = false);
      }
    }
  }

  Future<void> _fetchServices() async {
    final client = _client;
    if (client == null || _loadingServices) return;
    if (mounted) setState(() => _loadingServices = true);
    try {
      final services = await client.getServices();
      if (mounted) {
        setState(() {
          _services = services;
          _servicesError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _servicesError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _fetchTopProcesses() async {
    final client = _client;
    if (client == null || _loadingProcesses) return;
    if (mounted) setState(() => _loadingProcesses = true);
    try {
      final procs = await client.getTopProcesses();
      if (mounted) {
        setState(() {
          _topProcesses = procs;
          _processesError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _processesError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingProcesses = false);
    }
  }

  Widget _buildServiceStatusBadge(String status) {
    final lower = status.toLowerCase();
    final Color color;
    final String label;

    if (lower == 'running') {
      color = const Color(0xFF10B981);
      label = tr('Ativo');
    } else if (lower == 'stopped') {
      color = const Color(0xFFF59E0B);
      label = tr('Parado');
    } else if (lower == 'notfound') {
      color = const Color(0xFF9CA3AF);
      label = tr('Ausente');
    } else {
      color = const Color(0xFF9CA3AF);
      label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProcessRow(TopProcessItem proc, ThemeData theme, {required bool isMemory}) {
    final valStr = isMemory
        ? '${proc.memoryMb.toStringAsFixed(1)} MB'
        : (proc.cpuPercent != null ? '${proc.cpuPercent!.toStringAsFixed(1)}%' : 'N/D');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PID ${proc.pid}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                proc.name,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            valStr,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: isMemory ? const Color(0xFF38BDF8) : const Color(0xFFA78BFA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySparklineCard(SystemStats stats, ThemeData theme) {
    final cpuValues = stats.history.map((s) => s.cpu).toList();
    final ramValues = stats.history.map((s) => s.ram).toList();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 20, color: Color(0xFFA78BFA)),
                const SizedBox(width: 8),
                Text(
                  tr('Histórico de Carga (60s)'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.memory, size: 14, color: Color(0xFFA78BFA)),
                              const SizedBox(width: 4),
                              Text(
                                'CPU',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${stats.cpuUsage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFFA78BFA),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      MetricSparkline(
                        values: cpuValues,
                        lineColor: const Color(0xFFA78BFA),
                        height: 38,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storage, size: 14, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 4),
                              Text(
                                'RAM',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${stats.ramUsedPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      MetricSparkline(
                        values: ramValues,
                        lineColor: const Color(0xFF38BDF8),
                        height: 38,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsServicesCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.miscellaneous_services_outlined, size: 20, color: Color(0xFFA78BFA)),
                    const SizedBox(width: 8),
                    Text(
                      tr('Serviços do Windows'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: tr('Atualizar serviços'),
                  onPressed: _loadingServices ? null : _fetchServices,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingServices && _services.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_services.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _servicesError != null
                      ? '${tr('Erro ao carregar serviços:')} $_servicesError'
                      : tr('Nenhum serviço retornado pelo PC.'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final svc in _services) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  svc.displayName.isNotEmpty ? svc.displayName : svc.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  svc.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildServiceStatusBadge(svc.status),
                        ],
                      ),
                    ),
                    if (svc != _services.last)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProcessesCard(ThemeData theme) {
    final procs = _processSortIndex == 0
        ? (_topProcesses?.byMemory ?? const <TopProcessItem>[])
        : (_topProcesses?.byCpu ?? const <TopProcessItem>[]);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 20, color: Color(0xFFA78BFA)),
                    const SizedBox(width: 8),
                    Text(
                      tr('Top Processos'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: tr('Atualizar processos'),
                  onPressed: _loadingProcesses ? null : _fetchTopProcesses,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _processSortIndex = 0),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _processSortIndex == 0
                              ? const Color(0xFFA78BFA).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _processSortIndex == 0
                              ? Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.6))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            tr('Por Memória (RAM)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _processSortIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              color: _processSortIndex == 0
                                  ? const Color(0xFFA78BFA)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _processSortIndex = 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _processSortIndex == 1
                              ? const Color(0xFFA78BFA).withValues(alpha: 0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: _processSortIndex == 1
                              ? Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.6))
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            tr('Por CPU'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _processSortIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              color: _processSortIndex == 1
                                  ? const Color(0xFFA78BFA)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingProcesses && _topProcesses == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_topProcesses == null || procs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _processesError != null
                      ? '${tr('Erro ao carregar processos:')} $_processesError'
                      : tr('Nenhum processo retornado pelo PC.'),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              for (final proc in procs) ...[
                _buildTopProcessRow(proc, theme, isMemory: _processSortIndex == 0),
                if (proc != procs.last)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForApp(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'description':
      case 'note':
        return Icons.description_outlined;
      case 'terminal':
      case 'code':
        return Icons.code_rounded;
      case 'edit_note':
      case 'edit':
        return Icons.edit_note_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signalR = widget.signalRService ?? Injector.get<SignalRService>();
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onToggleFullscreen,
        mini: true,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        foregroundColor: theme.colorScheme.onSurface,
        child: Icon(
          widget.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
        ),
      ),
      appBar: widget.isFullscreen
          ? null
          : AppBar(
              title: Row(
                children: [
                  const Icon(Icons.monitor_heart_outlined, size: 22),
                  const SizedBox(width: 8),
                  Text(tr('Status')),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: tr('Configurações'),
                  onPressed: () => Navigator.of(context).pushNamed('/config'),
                ),
              ],
            ),
      body: Watch((context) {
        final stats = signalR.systemStats.value;
        final status = signalR.connectionStatus.value;
        final isConnected = status == 'Connected';
        final activePc = _currentPc;

        return RefreshIndicator(
          onRefresh: () async {
            await _loadPc();
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isConnected) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF87171).withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Color(0xFFF87171), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('Command Bridge Desconectado'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFF87171),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tr('Verifique se o aplicativo está aberto no PC. Sem retry automático.'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFA78BFA),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () async {
                          final activePc = _currentPc;
                          if (activePc != null) {
                            await signalR.updateUrl('http://${activePc.ip}:${activePc.port}', apiKey: activePc.apiKey);
                          }
                          await _loadAppsAndJobs();
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(tr('Reconectar')),
                      ),
                    ],
                  ),
                ),
              ],

              // Card do PC e Estado da Conexão
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isConnected
                        ? const Color(0xFF34D5A0).withValues(alpha: 0.6)
                        : const Color(0xFFF87171).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? const Color(0xFF34D5A0).withValues(alpha: 0.15)
                              : const Color(0xFFF87171).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.computer,
                          color: isConnected
                              ? const Color(0xFF34D5A0)
                              : const Color(0xFFF87171),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activePc?.name ?? tr('PC Conectado'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activePc != null
                                  ? '${activePc.ip}:${activePc.port}'
                                  : (signalR.currentUrl.value.isNotEmpty &&
                                          signalR.currentUrl.value != 'Not Initialized')
                                      ? signalR.currentUrl.value
                                      : '127.0.0.1:4787',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? const Color(0xFF34D5A0).withValues(alpha: 0.2)
                              : const Color(0xFFF87171).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? const Color(0xFF34D5A0)
                                    : const Color(0xFFF87171),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnected ? tr('Online') : tr('Offline'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isConnected
                                    ? const Color(0xFF34D5A0)
                                    : const Color(0xFFF87171),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stats.hasBattery && stats.batteryPercent != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (stats.isCharging == true
                                    ? const Color(0xFF34D5A0)
                                    : const Color(0xFFA78BFA))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (stats.isCharging == true
                                      ? const Color(0xFF34D5A0)
                                      : const Color(0xFFA78BFA))
                                  .withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                stats.isCharging == true
                                    ? Icons.bolt
                                    : (stats.batteryPercent! <= 20
                                        ? Icons.battery_alert
                                        : Icons.battery_std),
                                size: 13,
                                color: stats.isCharging == true
                                    ? const Color(0xFF34D5A0)
                                    : (stats.batteryPercent! <= 20
                                        ? const Color(0xFFF87171)
                                        : const Color(0xFFA78BFA)),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${stats.batteryPercent}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: stats.isCharging == true
                                      ? const Color(0xFF34D5A0)
                                      : (stats.batteryPercent! <= 20
                                          ? const Color(0xFFF87171)
                                          : const Color(0xFFA78BFA)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Grid de métricas de Hardware
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _MetricCard(
                    title: 'CPU',
                    value: '${stats.cpuUsage.toStringAsFixed(1)}%',
                    subvalue: tr('Uso do processador'),
                    progress: (stats.cpuUsage / 100.0).clamp(0.0, 1.0),
                    icon: Icons.memory,
                    theme: theme,
                    tempC: stats.cpuTempC,
                    showTempBadge: true,
                  ),
                  _MetricCard(
                    title: 'RAM',
                    value: '${stats.ramUsedPercent.toStringAsFixed(1)}%',
                    subvalue: '${stats.ramUsedGb.toStringAsFixed(1)} / ${stats.ramTotalGb.toStringAsFixed(1)} GB',
                    progress: (stats.ramUsedPercent / 100.0).clamp(0.0, 1.0),
                    icon: Icons.storage,
                    theme: theme,
                  ),
                  _MetricCard(
                    title: tr('Disco'),
                    value: '${stats.diskUsage.toStringAsFixed(1)}%',
                    subvalue: '${(stats.diskTotalGb - stats.diskAvailableGb).toStringAsFixed(0)} / ${stats.diskTotalGb.toStringAsFixed(0)} GB',
                    progress: (stats.diskUsage / 100.0).clamp(0.0, 1.0),
                    icon: Icons.disc_full_outlined,
                    theme: theme,
                  ),
                  _MetricCard(
                    title: 'GPU',
                    value: '${stats.gpuUsage.toStringAsFixed(1)}%',
                    subvalue: tr('Vídeo / 3D Engine'),
                    progress: (stats.gpuUsage / 100.0).clamp(0.0, 1.0),
                    icon: Icons.videogame_asset_outlined,
                    theme: theme,
                    tempC: stats.gpuTempC,
                    showTempBadge: true,
                  ),
                ],
              ),

              // Histórico Recente de Carga - 60s (Command v0.2 - S5)
              if (stats.history.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildHistorySparklineCard(stats, theme),
              ],

              // Múltiplos Volumes de Disco (Command v0.2 - S4)
              if (stats.disks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns_outlined, size: 20, color: Color(0xFFA78BFA)),
                            const SizedBox(width: 8),
                            Text(
                              tr('Volumes de Disco'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (final disk in stats.disks) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      disk.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: Color(0xFFA78BFA),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    disk.label.isNotEmpty ? disk.label : disk.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                              Text(
                                '${disk.usagePercent.toStringAsFixed(1)}% (${(disk.totalGb - disk.availableGb).toStringAsFixed(0)}/${disk.totalGb.toStringAsFixed(0)} GB)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (disk.usagePercent / 100.0).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                disk.usagePercent >= 90
                                    ? const Color(0xFFEF4444)
                                    : (disk.usagePercent >= 75
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF10B981)),
                              ),
                            ),
                          ),
                          if (disk != stats.disks.last) const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Cartão de Throughput de Rede
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('Rede'),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF34D5A0)),
                              const SizedBox(width: 4),
                              Text(
                                '${stats.netDown.toStringAsFixed(1)} KB/s',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.arrow_upward, size: 14, color: Color(0xFF42A5F5)),
                              const SizedBox(width: 4),
                              Text(
                                '${stats.netUp.toStringAsFixed(1)} KB/s',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Cartão de Uptime
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('Tempo ligado'),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        stats.formattedUptime,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Módulo Hermes (Opcional - MVP)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 20, color: Color(0xFFA78BFA)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hermes IA',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              tr('Módulo de inteligência opcional'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tr('Não configurado'),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Card de Ações Autorizadas (Allowlist F4)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFFA78BFA)),
                              const SizedBox(width: 8),
                              Text(
                                tr('Ações Autorizadas'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: tr('Atualizar lista'),
                            onPressed: _loadingApps ? null : _fetchApps,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_loadingApps && _apps.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_apps.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            tr('Nenhum aplicativo retornado pelo PC. Conecte ao Bridge para carregar.'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _apps.length,
                          separatorBuilder: (_, __) => const Divider(height: 12, thickness: 0.5),
                          itemBuilder: (context, index) {
                            final app = _apps[index];
                            final isPending = _pendingActions.contains(app.id);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                                child: Icon(_iconForApp(app.icon), color: const Color(0xFFA78BFA), size: 20),
                              ),
                              title: Text(
                                app.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                app.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (app.canKill) ...[
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFF87171),
                                        side: const BorderSide(color: Color(0xFFF87171)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: isPending ? null : () => _confirmAndKillApp(app),
                                      child: isPending
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Text(tr('Encerrar'), style: const TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFA78BFA),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: isPending ? null : () => _launchApp(app),
                                    child: isPending
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                          )
                                        : Text(tr('Abrir'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Card de Captura de Tela Manual (F5)
              _buildScreenshotCard(theme),

              const SizedBox(height: 12),

              // Card de Transferência Restrita de Arquivos (F6)
              _buildTransferCard(theme),

              const SizedBox(height: 12),

              // Card de Serviços do Windows (Command v0.2 - S5)
              _buildWindowsServicesCard(theme),

              const SizedBox(height: 12),

              // Card de Top Processos (Command v0.2 - S5)
              _buildTopProcessesCard(theme),

              const SizedBox(height: 12),

              // Card de Histórico de Atividades (Jobs F4-04)
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, size: 20, color: Color(0xFFA78BFA)),
                              const SizedBox(width: 8),
                              Text(
                                tr('Atividade Recente'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: tr('Atualizar'),
                                onPressed: _loadingJobs ? null : _fetchJobs,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                tooltip: tr('Limpar histórico'),
                                onPressed: _jobs.isEmpty ? null : _clearJobs,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_loadingJobs && _jobs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_jobs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            tr('Nenhuma atividade registrada.'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _jobs.take(10).length,
                          separatorBuilder: (_, __) => const Divider(height: 8, thickness: 0.3),
                          itemBuilder: (context, index) {
                            final job = _jobs[index];
                            final isSuccess = job.status == 'succeeded';
                            final isFailed = job.status == 'failed';
                            final color = isSuccess
                                ? const Color(0xFF34D5A0)
                                : isFailed
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFFF0B65F);
                            final icon = isSuccess
                                ? Icons.check_circle_outline
                                : isFailed
                                    ? Icons.error_outline
                                    : Icons.hourglass_top_rounded;

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(icon, color: color, size: 18),
                              title: Text(
                                '${job.actionType} (${job.targetId})',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.errorMessage != null
                                        ? job.errorMessage!
                                        : 'Estado: ${job.status} · ${job.createdAtUtc.toLocal().toString().length >= 19 ? job.createdAtUtc.toLocal().toString().substring(11, 19) : ""}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isFailed ? const Color(0xFFF87171) : theme.colorScheme.onSurfaceVariant,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  if (job.status == 'unknown')
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Estado indeterminado: verifique o PC antes de reenviar (sem retry automático).',
                                        style: TextStyle(color: Color(0xFFF0B65F), fontSize: 10),
                                      ),
                                    )
                                  else if (isFailed)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Falha: confira a conexão e o alvo antes de tentar novamente.',
                                        style: TextStyle(color: Color(0xFFF87171), fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  job.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScreenshotCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_outlined, size: 20, color: Color(0xFFA78BFA)),
                    const SizedBox(width: 8),
                    Text(
                      tr('Captura de Tela'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_lastScreenshot != null && !_capturingScreenshot)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: tr('Nova Captura'),
                    onPressed: _captureScreenshot,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tr('Captura sob demanda do monitor principal · expira em 10 min'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            if (_screenshotError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Color(0xFFF87171), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _screenshotError!,
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (_lastScreenshot != null && _lastScreenshotBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Image.memory(
                    _lastScreenshotBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_lastScreenshot!.width}x${_lastScreenshot!.height} · ${(_lastScreenshot!.sizeBytes / 1024).toStringAsFixed(1)} KB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    _lastScreenshot!.isExpired ? tr('Expirado') : tr('Válido por 10 min'),
                    style: TextStyle(
                      color: _lastScreenshot!.isExpired ? const Color(0xFFF87171) : const Color(0xFF34D5A0),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.zoom_in, size: 16),
                      label: Text(tr('Visualizar')),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ScreenshotViewerPage(
                              info: _lastScreenshot!,
                              imageBytes: _lastScreenshotBytes!,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: Text(tr('Compartilhar')),
                      onPressed: () async {
                        await SharePlus.instance.share(ShareParams(
                          files: [
                            XFile.fromData(
                              _lastScreenshotBytes!,
                              name: 'command_screenshot_${_lastScreenshot!.id}.jpg',
                              mimeType: 'image/jpeg',
                            ),
                          ],
                          fileNameOverrides: ['command_screenshot_${_lastScreenshot!.id}.jpg'],
                          subject: 'Command Screenshot (${_lastScreenshot!.width}x${_lastScreenshot!.height})',
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA78BFA),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _capturingScreenshot
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.camera_alt, size: 18),
                  label: Text(
                    _capturingScreenshot ? tr('Capturando tela...') : tr('Capturar Tela Agora'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _capturingScreenshot ? null : _captureScreenshot,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTransferCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert_rounded, size: 20, color: Color(0xFFA78BFA)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('Transferência de Arquivos'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: tr('Atualizar lista'),
                  onPressed: _loadingTransfers ? null : _fetchTransfers,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('Pastas restritas: outbound (PC ➔ Celular) & inbound (Celular ➔ PC)'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            if (_transferError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _transferError!,
                        style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            Text(
              tr('Disponíveis para Download (PC Outbound)'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFFA78BFA),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            if (_loadingTransfers && _outboundFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_outboundFiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tr('Nenhum arquivo disponível na pasta outbound do PC.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _outboundFiles.length,
                separatorBuilder: (_, __) => const Divider(height: 8, thickness: 0.3),
                itemBuilder: (context, index) {
                  final file = _outboundFiles[index];
                  final isDownloading = _pendingDownloads.contains(file.fileName);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insert_drive_file_outlined, size: 20, color: Color(0xFFA78BFA)),
                    ),
                    title: Text(
                      file.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      '${file.formattedSize} · SHA: ${file.checksumSha256.length > 8 ? file.checksumSha256.substring(0, 8) : file.checksumSha256}...',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isDownloading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download, size: 16),
                        label: Text(isDownloading ? tr('Baixando...') : tr('Baixar')),
                        onPressed: isDownloading ? null : () => _downloadFile(file),
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA78BFA).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFFA78BFA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFA78BFA), width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _uploadingInbound
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA78BFA)),
                      )
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(
                  _uploadingInbound ? tr('Enviando para o PC...') : tr('Enviar Arquivo para o PC (Inbound)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _uploadingInbound ? null : _uploadTestFile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subvalue;
  final double progress;
  final IconData icon;
  final ThemeData theme;
  final double? tempC;
  final bool showTempBadge;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subvalue,
    required this.progress,
    required this.icon,
    required this.theme,
    this.tempC,
    this.showTempBadge = false,
  });

  Color _progressColor(double p) {
    if (p >= 0.9) return const Color(0xFFF87171); // Vermelho
    if (p >= 0.7) return const Color(0xFFF0B65F); // Âmbar
    return const Color(0xFF34D5A0); // Verde
  }

  Widget _buildTempBadge(double? temp) {
    final String text = temp != null ? '${temp.toStringAsFixed(0)}°C' : 'N/D';
    final Color color;
    if (temp == null) {
      color = const Color(0xFF9CA3AF);
    } else if (temp <= 65) {
      color = const Color(0xFF10B981);
    } else if (temp <= 80) {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thermostat, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (showTempBadge) ...[
                      const SizedBox(width: 6),
                      _buildTempBadge(tempC),
                    ],
                  ],
                ),
                Icon(icon, size: 18, color: theme.colorScheme.primary),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subvalue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor(progress)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
