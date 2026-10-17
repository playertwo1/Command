import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';
import '../connection/pc_store.dart';
import '../services/signalr_service.dart';

/// Aba de Telemetria e Estado do PC (Command)
class StatusPage extends StatefulWidget {
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final SignalRService? signalRService;

  const StatusPage({
    super.key,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.signalRService,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  SavedPc? _currentPc;

  @override
  void initState() {
    super.initState();
    _loadPc();
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
                  ),
                ],
              ),

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
            ],
          ),
        );
      }),
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

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subvalue,
    required this.progress,
    required this.icon,
    required this.theme,
  });

  Color _progressColor(double p) {
    if (p >= 0.9) return const Color(0xFFF87171); // Vermelho
    if (p >= 0.7) return const Color(0xFFF0B65F); // Âmbar
    return const Color(0xFF34D5A0); // Verde
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
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
