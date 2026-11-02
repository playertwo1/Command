import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/wake_on_lan_service.dart';
import 'package:flutter/material.dart';

/// Card interativo para controle seguro de energia, sessão e Wake-on-LAN (Onda v0.6 - W0/W1).
class PowerControlCard extends StatefulWidget {
  final DroidDeckClient? client;
  final String? targetPcName;
  final String? savedMacAddress;
  final VoidCallback? onOpenDockMode;

  const PowerControlCard({
    super.key,
    this.client,
    this.targetPcName,
    this.savedMacAddress,
    this.onOpenDockMode,
  });

  @override
  State<PowerControlCard> createState() => _PowerControlCardState();
}

class _PowerControlCardState extends State<PowerControlCard> {
  bool _isProcessing = false;

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color cardBackground = Color(0xFF161424);
  static const Color buttonBg = Color(0xFF1E1B2E);

  Future<void> _handlePowerAction(String action, String actionName) async {
    final endsSession = action == 'shutdown' || action == 'restart';
    final pcName = widget.targetPcName ?? 'PC selecionado';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1829),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          endsSession ? actionName : 'Confirmar Controle de Sessão',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PC-alvo: $pcName\nDeseja realmente executar "$actionName"?',
              style: const TextStyle(color: amethystAccent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              endsSession
                  ? 'A sessão será encerrada. A conexão com este PC cai e o trabalho não salvo pode ser perdido.'
                  : 'Atenção: Ao bloquear ou suspender o PC, a captura de tela ficará indisponível até o desbloqueio local.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: amethystAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              endsSession
                  ? (action == 'restart' ? 'Reiniciar agora' : 'Desligar agora')
                  : 'Confirmar Agora',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.client != null) {
      setState(() => _isProcessing = true);
      try {
        final result = await widget.client!.executePowerAction(
          action: action,
          confirmed: true,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.success
                  ? 'Ação "$actionName" executada com sucesso!'
                  : 'Falha: ${result.errorMessage ?? result.status}'),
              backgroundColor: result.success ? const Color(0xFF2E7D32) : Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao executar ação: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _handleWakeOnLan() async {
    final mac = widget.savedMacAddress;
    if (mac == null || mac.isEmpty) {
      final macController = TextEditingController();
      final enteredMac = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1829),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Wake-on-LAN', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: macController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'MAC Address (ex: AA:BB:CC:DD:EE:FF)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: amethystAccent, foregroundColor: Colors.black),
              onPressed: () => Navigator.of(ctx).pop(macController.text.trim()),
              child: const Text('Enviar Pacote'),
            ),
          ],
        ),
      );

      if (enteredMac != null && enteredMac.isNotEmpty) {
        await _sendWol(enteredMac);
      }
    } else {
      await _sendWol(mac);
    }
  }

  Future<void> _sendWol(String mac) async {
    setState(() => _isProcessing = true);
    try {
      final success = await WakeOnLanService.sendWakeOnLan(macAddress: mac);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Magic Packet enviado com sucesso para $mac!'
                : 'Falha ao enviar pacote Wake-on-LAN.'),
            backgroundColor: success ? const Color(0xFF2E7D32) : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar WoL: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: amethystAccent.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.power_settings_new, color: amethystAccent, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Controle de Energia & Sessão',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Bloquear, suspender, desligar e reiniciar com confirmação',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Bloquear PC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _handlePowerAction('lock', 'Bloquear PC'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bedtime_outlined, size: 18),
                    label: const Text('Suspender PC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _handlePowerAction('sleep', 'Suspender PC'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.power_settings_new, size: 18, color: amethystAccent),
                    label: const Text('Desligar PC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: amethystAccent.withValues(alpha: 0.45)),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _handlePowerAction('shutdown', 'Desligar PC'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 18, color: amethystAccent),
                    label: const Text('Reiniciar PC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: amethystAccent.withValues(alpha: 0.45)),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _handlePowerAction('restart', 'Reiniciar PC'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.wifi_tethering, size: 18, color: amethystAccent),
                    label: const Text('Wake-on-LAN (Ligar PC)', style: TextStyle(color: amethystAccent, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: amethystAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing ? null : _handleWakeOnLan,
                  ),
                ),
                if (widget.onOpenDockMode != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.dock_outlined, size: 18, color: amethystAccent),
                      label: const Text('Modo Dock (Mesa)', style: TextStyle(color: amethystAccent, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: amethystAccent.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: widget.onOpenDockMode,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
