import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

/// Painel horizontal compacto de alto contraste para uso do celular em dock/mesa (Onda v0.6 - W3).
class DockDashboardPage extends StatelessWidget {
  final SystemStats stats;
  final String pcName;
  final VoidCallback? onLockPc;
  final VoidCallback? onCaptureScreen;
  final VoidCallback? onOpenHermes;

  const DockDashboardPage({
    super.key,
    required this.stats,
    required this.pcName,
    this.onLockPc,
    this.onCaptureScreen,
    this.onOpenHermes,
  });

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color darkBackground = Color(0xFF050408);
  static const Color metricCardBg = Color(0xFF161424);
  static const Color buttonBg = Color(0xFF1E1B2E);

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Superior: Nome do PC, Relógio e Uptime
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: amethystAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.dock_outlined, color: amethystAccent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pcName.isNotEmpty ? pcName : 'Command PC',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Uptime: ${stats.formattedUptime}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: metricCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: amethystAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: amethystAccent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit, color: Colors.white70),
                        tooltip: 'Sair do Dock',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4 Gauges Grandes de Telemetria
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'CPU',
                        value: '${stats.cpuUsage.toStringAsFixed(1)}%',
                        icon: Icons.memory,
                        ratio: (stats.cpuUsage / 100.0).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'RAM',
                        value: '${stats.ramUsedPercent.toStringAsFixed(1)}%',
                        icon: Icons.storage,
                        ratio: (stats.ramUsedPercent / 100.0).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'GPU',
                        value: '${stats.gpuUsage.toStringAsFixed(1)}%',
                        icon: Icons.tv,
                        ratio: (stats.gpuUsage / 100.0).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'TEMP',
                        value: stats.cpuTempC != null
                            ? '${stats.cpuTempC!.toStringAsFixed(0)}°C'
                            : (stats.gpuTempC != null
                                ? '${stats.gpuTempC!.toStringAsFixed(0)}°C'
                                : 'N/A'),
                        icon: Icons.thermostat,
                        ratio: stats.cpuTempC != null
                            ? (stats.cpuTempC! / 100.0).clamp(0.0, 1.0)
                            : 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4 Botões Rápidos de Ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: const Text('Bloquear PC'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: onLockPc,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.screenshot, size: 16),
                      label: const Text('Capturar Tela'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBg,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: onCaptureScreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 16, color: amethystAccent),
                      label: const Text('Hermes IA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonBg,
                        foregroundColor: amethystAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: amethystAccent.withValues(alpha: 0.4)),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: onOpenHermes,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Sair do Dock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E2438),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required double ratio,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metricCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amethystAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: amethystAccent, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: ratio > 0.85
                ? Colors.redAccent
                : ratio > 0.7
                    ? Colors.orangeAccent
                    : amethystAccent,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}
