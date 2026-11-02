import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';
import '../connection/pc_store.dart';
import '../services/signalr_service.dart';
import 'thermal_color.dart';

class PcDashboardCard extends StatelessWidget {
  const PcDashboardCard({
    super.key,
    required this.primaryPc,
    required this.secondaryPc,
    required this.primaryConnection,
    required this.secondaryConnection,
    required this.targetPcId,
    required this.onTargetSelected,
  });

  final SavedPc? primaryPc;
  final SavedPc? secondaryPc;
  final SignalRService? primaryConnection;
  final SignalRService? secondaryConnection;
  final String? targetPcId;
  final ValueChanged<SavedPc> onTargetSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetName = [primaryPc, secondaryPc]
        .whereType<SavedPc>()
        .where((pc) => pc.id == targetPcId)
        .map((pc) => pc.name)
        .firstOrNull;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meus 2 PCs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              targetName == null
                  ? 'Escolha um PC-alvo'
                  : 'PC-alvo: $targetName',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _pcCard(context, primaryPc, primaryConnection)),
                const SizedBox(width: 8),
                Expanded(
                  child: _pcCard(context, secondaryPc, secondaryConnection),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _critical(double? celsius) => celsius != null && celsius > 85;

  Widget _tempChip(String label, double? celsius) {
    final color = thermalColor(celsius);
    final text = celsius == null ? 'N/D' : '${celsius.toStringAsFixed(0)}°';
    return Text(
      '$label $text',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    );
  }

  Widget _pcCard(
    BuildContext context,
    SavedPc? pc,
    SignalRService? connection,
  ) {
    if (pc == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('Segundo PC'), Text('Desconectado')],
          ),
        ),
      );
    }
    return Watch((context) {
      final status = connection?.connectionStatus.watch(context);
      final revoked = connection?.isRevoked.watch(context) == true;
      final stats = connection?.systemStats.watch(context);
      final online = status == 'Connected';
      final theme = Theme.of(context);
      final selected = pc.id == targetPcId;
      return Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? const Color(0xFFA78BFA)
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 0.7,
          ),
        ),
        child: InkWell(
          key: ValueKey('pc-target-${pc.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTargetSelected(pc),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  online
                      ? 'Online'
                      : revoked
                      ? 'Revogado'
                      : 'Offline',
                  style: TextStyle(
                    color: online
                        ? const Color(0xFF34D5A0)
                        : const Color(0xFFF87171),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (online && stats != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${stats.cpuUsage.toStringAsFixed(0)}% CPU · ${stats.ramUsage.toStringAsFixed(0)}% RAM',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      _tempChip('CPU', stats.cpuTempC),
                      _tempChip('GPU', stats.gpuTempC),
                    ],
                  ),
                  if (_critical(stats.cpuTempC) || _critical(stats.gpuTempC))
                    const Text(
                      'Temperatura crítica',
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
                if (selected)
                  const Text(
                    'Alvo',
                    style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
