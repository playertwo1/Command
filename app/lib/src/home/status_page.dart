import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../connection/pc_store.dart';
import '../services/signalr_service.dart';
import '../services/health_alert_service.dart';
import '../services/health_report_generator.dart';
import 'metric_sparkline.dart';
import 'screenshot_viewer.dart';
import '../desktop_stream/desktop_stream_controller.dart';
import '../desktop_stream/desktop_live_stream_viewer.dart';
import '../transfers/remote_file_manager_page.dart';
import '../hermes/hermes_config_sheet.dart';
import '../hermes/hermes_assistant_page.dart';
import '../hermes/quick_command_bar.dart';
import '../routines/workspace_routines_card.dart';
import '../power/power_control_card.dart';
import '../security/security_center_card.dart';
import '../dock/dock_dashboard_page.dart';

/// Aba de Telemetria e Estado do PC (Command)
class StatusPage extends StatefulWidget {
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final SignalRService? signalRService;
  final DroidDeckClient? client;
  final HealthAlertService? healthAlertService;

  const StatusPage({
    super.key,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.signalRService,
    this.client,
    this.healthAlertService,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  SavedPc? _currentPc;
  List<SavedPc> _savedPcs = [];
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

  int? _latencyMs;
  int? _jitterMs;
  int? _previousLatencyMs;
  bool _measuringLatency = false;

  HermesConfigData _hermesConfig = const HermesConfigData(
    enabled: false,
    endpointUrl: '',
    modelName: 'gemini-3.8-flash',
    hasApiKey: false,
  );

  final DesktopStreamController _streamController = DesktopStreamController();
  late final HealthAlertService _healthAlertService;

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
    _healthAlertService = widget.healthAlertService ?? HealthAlertService.instance;
    _healthAlertService.loadThresholds();
    _loadPc();
    _loadAppsAndJobs();
  }

  @override
  void dispose() {
    _streamController.dispose();
    super.dispose();
  }

  Future<void> _loadPc() async {
    try {
      final pcs = await PcStore.load();
      if (mounted) {
        setState(() {
          _savedPcs = pcs;
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
      _measureLatency(),
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

  Future<void> _measureLatency() async {
    final client = _client;
    if (client == null || _measuringLatency) return;
    _measuringLatency = true;
    try {
      final res = await client.ping();
      if (mounted) {
        final currentLatency = res.latencyMs;
        int? jitter;
        if (_previousLatencyMs != null) {
          jitter = (currentLatency - _previousLatencyMs!).abs();
        }
        setState(() {
          _latencyMs = currentLatency;
          _jitterMs = jitter;
          _previousLatencyMs = currentLatency;
        });
      }
    } catch (_) {
      // Falha silenciosa de medição quando offline
    } finally {
      if (mounted) {
        _measuringLatency = false;
      }
    }
  }

  Widget _buildLatencyBadge(int latency, int? jitter) {
    final Color badgeColor;
    if (latency <= 50) {
      badgeColor = const Color(0xFF10B981);
    } else if (latency <= 150) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = const Color(0xFFEF4444);
    }

    final jitterText = jitter != null ? ' (±$jitter)' : '';

    return Tooltip(
      message: 'RTT: ${latency}ms | Jitter: ${jitter ?? 0}ms',
      child: InkWell(
        onTap: _measureLatency,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          key: const ValueKey('latency_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi,
                size: 12,
                color: badgeColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$latency ms$jitterText',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportReportDialog(BuildContext context, SystemStats? stats) {
    bool isMarkdown = true;
    bool sanitize = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final input = HealthReportInput(
              pc: _currentPc,
              stats: stats,
              services: _services,
              topProcesses: _topProcesses,
              latencyMs: _latencyMs,
              jitterMs: _jitterMs,
              sanitize: sanitize,
            );
            final reportText = isMarkdown
                ? HealthReportGenerator.generateMarkdown(input)
                : HealthReportGenerator.generateJson(input);

            return Material(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.health_and_safety_outlined, color: Color(0xFFA78BFA), size: 24),
                          const SizedBox(width: 8),
                          Text(
                            tr('Diagnóstico do PC'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('Markdown (.md)'),
                              icon: Icon(Icons.description_outlined, size: 16),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('JSON (.json)'),
                              icon: Icon(Icons.code, size: 16),
                            ),
                          ],
                          selected: {isMarkdown},
                          onSelectionChanged: (val) {
                            setModalState(() => isMarkdown = val.first);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr('Sanitizar dados sensíveis'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      tr('Mascara IP de rede local e omite identificadores privados'),
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    value: sanitize,
                    activeColor: const Color(0xFFA78BFA),
                    onChanged: (val) {
                      setModalState(() => sanitize = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          reportText,
                          key: const ValueKey('report_preview_text'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('export_dialog_copy_button'),
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(tr('Copiar')),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: reportText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('Relatório copiado para a área de transferência!')),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('export_dialog_share_button'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFA78BFA),
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(Icons.share, size: 16),
                          label: Text(tr('Compartilhar')),
                          onPressed: () async {
                            final ext = isMarkdown ? 'md' : 'json';
                            await SharePlus.instance.share(ShareParams(
                              text: reportText,
                              subject: 'Command Diagnostico - ${_currentPc?.name ?? "PC"} ($ext)',
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildDiagnosticsExportCard(BuildContext context, ThemeData theme, SystemStats? stats) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    color: Color(0xFFA78BFA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Diagnóstico do Sistema'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        tr('Exportação e compartilhamento de relatório completo e sanitizado'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('export_diagnostics_card_button'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFFA78BFA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: Text(
                      tr('Exportar Relatório (Markdown / JSON)'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    onPressed: () => _showExportReportDialog(context, stats),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildHealthAlertsBanner(List<HealthAlert> alerts, ThemeData theme) {
    return Column(
      children: [
        for (final alert in alerts) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: alert.severity == AlertSeverity.critical
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: alert.severity == AlertSeverity.critical
                    ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  alert.severity == AlertSeverity.critical
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  color: alert.severity == AlertSeverity.critical
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFF59E0B),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: alert.severity == AlertSeverity.critical
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: tr('Dispensar alerta'),
                  onPressed: () => _healthAlertService.dismissAlert(alert.id),
                ),
              ],
            ),
          ),
        ],
      ],
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

  Future<void> _handleSwitchPc(SavedPc pc) async {
    await PcStore.select(pc);
    final client = _client;
    if (client != null) {
      client.setBaseUrl(pc.baseUrl);
      client.setApiKey(pc.apiKey);
    }
    final signalR = widget.signalRService;
    if (signalR != null) {
      await signalR.updateUrl(pc.baseUrl, apiKey: pc.apiKey);
    } else {
      try {
        await Injector.get<SignalRService>().updateUrl(pc.baseUrl, apiKey: pc.apiKey);
      } catch (_) {}
    }
    await _loadPc();
    await _loadAppsAndJobs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Alternado com sucesso para "{name}".', {'name': pc.name})),
          backgroundColor: const Color(0xFF34D5A0),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPcSwitcherModal(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.computer, color: Color(0xFFA78BFA), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          tr('Computadores Pareados'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final pc in _savedPcs) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      pc.id == _currentPc?.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: pc.id == _currentPc?.id
                          ? const Color(0xFFA78BFA)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      pc.name,
                      style: TextStyle(
                        fontWeight: pc.id == _currentPc?.id ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      '${pc.ip}:${pc.port}' +
                          (pc.lastConnectedAt != null
                              ? ' · Visto às ${pc.lastConnectedAt!.hour.toString().padLeft(2, '0')}:${pc.lastConnectedAt!.minute.toString().padLeft(2, '0')}'
                              : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: pc.id == _currentPc?.id
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA78BFA).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr('Ativo'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFA78BFA),
                              ),
                            ),
                          )
                        : null,
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      if (pc.id != _currentPc?.id) {
                        await _handleSwitchPc(pc);
                      }
                    },
                  ),
                  const Divider(height: 1),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pushNamed('/config');
                    },
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: Text(tr('Gerenciar PCs e Novo Pareamento')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                if (_savedPcs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: tr('Alternar PC ativo'),
                    onPressed: () => _showPcSwitcherModal(context, theme),
                  ),
                IconButton(
                  key: const ValueKey('export_health_report_button'),
                  icon: const Icon(Icons.share_outlined),
                  tooltip: tr('Exportar Diagnóstico'),
                  onPressed: () => _showExportReportDialog(context, signalR.systemStats.value),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: tr('Configurações'),
                  onPressed: () async {
                    await Navigator.of(context).pushNamed('/config');
                    await _loadPc();
                  },
                ),
              ],
            ),
      body: Watch((context) {
        final stats = signalR.systemStats.value;
        final status = signalR.connectionStatus.value;
        final isConnected = status == 'Connected';
        final activePc = _currentPc;

        if (isConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _healthAlertService.evaluate(stats);
          });
        }

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
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _savedPcs.length > 1
                      ? () => _showPcSwitcherModal(context, theme)
                      : null,
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
                              Row(
                                children: [
                                  Text(
                                    activePc?.name ?? tr('PC Conectado'),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_savedPcs.length > 1) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      size: 20,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ],
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                const SizedBox(width: 6),
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
                          if (isConnected && _latencyMs != null) ...[
                            const SizedBox(height: 5),
                            _buildLatencyBadge(_latencyMs!, _jitterMs),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

              // Banner Reativo de Alertas de Saúde (Fase S6)
              ListenableBuilder(
                listenable: _healthAlertService,
                builder: (context, _) {
                  final alerts = _healthAlertService.activeAlerts;
                  if (alerts.isEmpty) return const SizedBox.shrink();
                  return _buildHealthAlertsBanner(alerts, theme);
                },
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

              // Módulo Hermes (Opcional - Onda v0.4)
              _buildHermesCard(context, theme),

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

              // Card de Streaming de Tela ao Vivo (Onda v0.3 - T2)
              _buildLiveStreamCard(theme),

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

              // Card de Diagnóstico do Sistema & Exportação (Fase S9)
              _buildDiagnosticsExportCard(context, theme, stats),

              const SizedBox(height: 12),

              // Perfis de Ambiente e Rotinas Encadeadas (Onda v0.5 - M1/M2)
              WorkspaceRoutinesCard(
                client: _client,
                onRoutineExecuted: () {
                  _fetchApps();
                  _fetchJobs();
                },
              ),

              const SizedBox(height: 12),

              // Controle de Sessão, Wake-on-LAN e Modo Dock (Onda v0.6 - W0/W1/W3)
              PowerControlCard(
                client: _client,
                savedMacAddress: null,
                onOpenDockMode: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DockDashboardPage(
                        stats: stats,
                        pcName: activePc?.name ?? 'Command PC',
                        onCaptureScreen: _captureScreenshot,
                        onOpenHermes: () => _openHermesAssistantPage(context),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Centro de Segurança e Integridade (Onda v1.0 - P0/P1/P2)
              SecurityCenterCard(
                client: _client,
              ),

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

  Future<void> _executeConfirmedHermesAction(HermesSuggestedAction action) async {
    final client = _client;
    if (client == null) return;
    final reqId = 'hermes_${DateTime.now().microsecondsSinceEpoch}';
    if (action.actionType == 'app.launch') {
      await client.launchApp(action.targetId, requestId: reqId);
      await _fetchApps();
      await _fetchJobs();
    } else if (action.actionType == 'app.kill') {
      await client.killApp(action.targetId, requestId: reqId, confirmed: true);
      await _fetchApps();
      await _fetchJobs();
    } else if (action.actionType == 'screenshot.capture') {
      await _captureScreenshot();
    }
  }

  void _openHermesConfigSheet(BuildContext context) {
    final pc = _currentPc;
    final effectiveClient = _client ??
        DroidDeckClient(baseUrl: pc != null ? 'http://${pc.ip}:${pc.port}' : 'http://10.0.2.2:4787');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HermesConfigSheet(
        client: effectiveClient,
        initialConfig: _hermesConfig,
        onSaved: (updated) {
          if (mounted) {
            setState(() => _hermesConfig = updated);
          }
        },
      ),
    );
  }

  void _openHermesAssistantPage(BuildContext context, {String? initialPrompt, String? screenshotId}) {
    final pc = _currentPc;
    final effectiveClient = _client ??
        DroidDeckClient(baseUrl: pc != null ? 'http://${pc.ip}:${pc.port}' : 'http://10.0.2.2:4787');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HermesAssistantPage(
          client: effectiveClient,
          initialPrompt: initialPrompt,
          screenshotId: screenshotId,
          onExecuteConfirmedAction: _executeConfirmedHermesAction,
        ),
      ),
    );
  }

  Widget _buildHermesCard(BuildContext context, ThemeData theme) {
    final pc = _currentPc;
    final effectiveClient = _client ??
        DroidDeckClient(baseUrl: pc != null ? 'http://${pc.ip}:${pc.port}' : 'http://10.0.2.2:4787');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _hermesConfig.enabled
              ? const Color(0xFFA78BFA).withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                    color: _hermesConfig.enabled
                        ? const Color(0xFF34D5A0).withValues(alpha: 0.18)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _hermesConfig.enabled ? tr('Ativo') : tr('Não configurado'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _hermesConfig.enabled ? FontWeight.bold : FontWeight.normal,
                      color: _hermesConfig.enabled
                          ? const Color(0xFF34D5A0)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey('hermes_config_button'),
                  icon: const Icon(Icons.tune, size: 18, color: Color(0xFFA78BFA)),
                  tooltip: tr('Configurar Hermes IA'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openHermesConfigSheet(context),
                ),
                IconButton(
                  key: const ValueKey('hermes_assistant_button'),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFFA78BFA)),
                  tooltip: tr('Abrir Assistente Hermes'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openHermesAssistantPage(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            QuickCommandBar(
              client: effectiveClient,
              onTriggerAction: _executeConfirmedHermesAction,
              onFallbackToHermes: (prompt) {
                _openHermesAssistantPage(context, initialPrompt: prompt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStreamCard(ThemeData theme) {
    final pc = _currentPc;
    final client = _client;
    String baseUrl = '';
    if (pc != null && pc.ip.isNotEmpty) {
      baseUrl = 'http://${pc.ip}:${pc.port}';
    } else if (client != null) {
      try {
        baseUrl = client.baseUrl;
      } catch (_) {
        baseUrl = '';
      }
    }
    String? apiKey = pc?.apiKey;
    if (apiKey == null && client != null) {
      try {
        apiKey = client.apiKey;
      } catch (_) {
        apiKey = null;
      }
    }

    return DesktopLiveStreamViewer(
      controller: _streamController,
      baseUrl: baseUrl,
      apiKey: apiKey,
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
                        final scId = _lastScreenshot!.id;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (viewerCtx) => ScreenshotViewerPage(
                              info: _lastScreenshot!,
                              imageBytes: _lastScreenshotBytes!,
                              onAskHermes: () {
                                _openHermesAssistantPage(
                                  viewerCtx,
                                  initialPrompt: 'Analise esta captura de tela do PC',
                                  screenshotId: scId,
                                );
                              },
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
                  icon: const Icon(Icons.folder_open, size: 20, color: Color(0xFFA78BFA)),
                  tooltip: tr('Explorador de Arquivos Remoto'),
                  onPressed: () {
                    final pc = _currentPc;
                    final effectiveClient = _client ??
                        DroidDeckClient(baseUrl: pc != null ? 'http://${pc.ip}:${pc.port}' : 'http://10.0.2.2:4787');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RemoteFileManagerPage(client: effectiveClient),
                      ),
                    );
                  },
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
