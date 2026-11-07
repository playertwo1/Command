import 'package:command/core/core.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

/// Status claro da conexão no configurador, sem expor detalhes técnicos do SignalR.
class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key});

  @override
  Widget build(BuildContext context) {
    final status = Injector.get<SignalRService>().connectionStatus.watch(
      context,
    );
    final connected = status == 'Connected';
    final connecting =
        status == 'Connecting...' || status.startsWith('Reconnecting');
    final failed = status == 'Build Error' || status.startsWith('Conn Error');

    final label = switch (status) {
      'Connected' => tr('Conectado ao PC'),
      'Connecting...' => tr('Conectando…'),
      _ when status.startsWith('Reconnecting') => tr('Reconectando…'),
      'URL Empty' => tr('PC não configurado'),
      'Build Error' => tr('Falha ao iniciar conexão'),
      _ when status.startsWith('Conn Error') => tr('Erro de conexão'),
      'Suspended' => tr('Conexão suspensa'),
      _ => tr('Sem conexão com o PC'),
    };
    final color = connected
        ? const Color(0xFF34D5A0)
        : connecting
        ? const Color(0xFFF0B65F)
        : failed
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = connected
        ? Icons.link
        : connecting
        ? Icons.sync
        : Icons.link_off;

    return Semantics(
      label: label,
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
