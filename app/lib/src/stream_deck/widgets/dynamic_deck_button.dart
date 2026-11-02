import 'dart:math' as math;

import 'package:droiddeck/src/stream_deck/widgets/deck_grid_button.dart';
import 'package:droiddeck/src/stream_deck/widgets/mixer_slider_deck_button.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';

import '../buttons/colors.dart';
import 'info_deck_button.dart';

class DynamicDeckButton extends StatelessWidget {
  final DeckButton button;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DynamicDeckButton({
    super.key,
    required this.button,
    required this.onTap,
    required this.onLongPress,
  });


  @override
  Widget build(BuildContext context) {
    // If no dynamic type, render standard button
    if (button.dynamicType == null ||
        button.dynamicType!.isEmpty ||
        button.dynamicType == 'none') {
      return DeckGridButton(
        button: button,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    if (button.dynamicType == 'mixer_slider') {
      final parameters = button.dynamicParameters ?? const <String, String>{};
      return MixerSliderDeckButton(
        key: ValueKey('${PcStore.currentId}:${button.id}:${parameters['deviceKind']}:${parameters['deviceId']}'),
        button: button,
        onTap: onTap,
        onLongPress: onLongPress,
      );
    }

    // Relógio, clima, tocando agora, comando e URL.
    if (infoTypes.contains(button.dynamicType)) {
      return InfoDeckButton(
        button: button,
        onTap: onTap,
        onLongPress: onLongPress,
        color: parseHexColor(button.backgroundColor),
      );
    }

    // Dynamic Rendering
    final signalR = Injector.get<SignalRService>();
    final stats = signalR.systemStats.watch(context);

    return DeckTile(
      color: parseHexColor(button.backgroundColor),
      onTap: onTap,
      onLongPress: onLongPress,
      radius: button.cornerRadius?.toDouble(),
      borderWidth: button.borderWidth?.toDouble(),
      borderColor: parseHexColor(button.borderColor),
      haptic: button.haptic,
      child: _buildDynamicContent(context, stats, button.dynamicType!),
    );
  }

  Widget _buildDynamicContent(
    BuildContext context,
    SystemStats stats,
    String type,
  ) {
    switch (type) {
      case 'cpu_monitor':
        return _buildCpuMonitor(stats);
      case 'memory_monitor':
        return _buildMemoryMonitor(stats);
      case 'gpu_monitor':
        return _buildGpuMonitor(stats);
      case 'network_monitor':
        return _buildNetworkMonitor(stats);
      case 'temp_monitor':
        return _buildTempMonitor(stats);
      default:
        return Center(child: Text(tr('Desconhecido: {type}', {'type': type})));
    }
  }

  Widget _buildCpuMonitor(SystemStats stats) {
    double pct = stats.cpuUsage;
    if (pct.isNaN || pct.isInfinite) pct = 0;
    return _gauge(
      percent: pct,
      icon: Icons.memory,
      value: '${pct.toStringAsFixed(0)}%',
      label: 'CPU',
    );
  }

  Widget _buildMemoryMonitor(SystemStats stats) {
    double pct = stats.ramUsedPercent;
    if (pct.isNaN || pct.isInfinite) pct = 0;
    final detail = stats.ramTotal > 0
        ? '${stats.ramUsedGb.toStringAsFixed(1)}/${stats.ramTotalGb.toStringAsFixed(1)}G'
        : 'RAM';
    return _gauge(
      percent: pct,
      icon: Icons.memory_outlined,
      value: '${pct.toStringAsFixed(0)}%',
      label: detail,
    );
  }

  Widget _buildGpuMonitor(SystemStats stats) {
    double pct = stats.gpuUsage;
    if (pct.isNaN || pct.isInfinite) pct = 0;
    return _gauge(
      percent: pct,
      icon: Icons.videogame_asset,
      value: '${pct.toStringAsFixed(0)}%',
      label: 'GPU',
    );
  }

  Widget _buildNetworkMonitor(SystemStats stats) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.swap_vert, size: 18),
          Text(
            '↓ ${_fmtRate(stats.netDown)}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            '↑ ${_fmtRate(stats.netUp)}',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Opacity(
            opacity: 0.7,
            child: Text('NET', style: TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _buildTempMonitor(SystemStats stats) {
    final cpu = stats.cpuTempC;
    final gpu = stats.gpuTempC;
    final shown = cpu ?? gpu;
    final value = shown == null ? 'N/D' : '${shown.toStringAsFixed(0)}°';
    final label = cpu != null && gpu != null
        ? 'CPU ${cpu.toStringAsFixed(0)} · GPU ${gpu.toStringAsFixed(0)}'
        : (cpu != null ? 'CPU' : 'GPU');
    return _gauge(
      percent: shown == null ? 0 : shown.clamp(0, 100).toDouble(),
      icon: Icons.thermostat,
      value: value,
      label: button.hideLabel ? '' : label,
      heat: true,
    );
  }

  String _fmtRate(double kbps) {
    if (kbps >= 1024) return '${(kbps / 1024).toStringAsFixed(1)}M';
    return '${kbps.toStringAsFixed(0)}K';
  }

  Color _usageColor(double pct, {bool heat = false}) {
    if (heat) {
      if (pct > 80) return const Color(0xFFF87171);
      if (pct > 75) return const Color(0xFFF0B65F);
      if (pct <= 60) return const Color(0xFF34D5A0);
      return const Color(0xFFF0B65F);
    }
    if (pct > 85) return Colors.redAccent;
    if (pct > 60) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  /// Medidor circular: anel colorido pela faixa de uso + ícone/valor/label no centro.
  Widget _gauge({
    required double percent,
    required IconData icon,
    required String value,
    required String label,
    bool heat = false,
  }) {
    final p = (percent / 100).clamp(0.0, 1.0);
    final color = _usageColor(percent, heat: heat);
    return LayoutBuilder(
      builder: (context, c) {
        final fg = DeckTile.foregroundOf(context);
        final side = math.min(c.maxWidth, c.maxHeight);
        final small = side < 70;
        final diameter = math.max(0.0, side - 12).toDouble();
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: diameter,
              child: CircularProgressIndicator(
                  value: p,
                  strokeWidth: small ? 4 : 6,
                  backgroundColor: fg.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            // Encolhe o texto para caber dentro do anel em botões pequenos.
            Padding(
              padding: EdgeInsets.all(small ? 10 : 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: small ? 14 : 18),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: small ? 12 : 15,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.7),
                        fontSize: small ? 8 : 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
