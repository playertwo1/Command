import 'package:flutter/material.dart';

class QuickCommandAction {
  final String actionType;
  final String targetId;
  final String title;
  final String reason;
  final bool requiresConfirmation;

  const QuickCommandAction({
    required this.actionType,
    required this.targetId,
    required this.title,
    required this.reason,
    this.requiresConfirmation = true,
  });
}

/// Interpretador determinístico offline dos comandos rápidos locais.
class QuickCommandParser {
  static QuickCommandAction? parseLocalIntent(String input) {
    final clean = input.trim().toLowerCase();

    if (clean == 'abrir obsidian') {
      return const QuickCommandAction(
        actionType: 'app.launch',
        targetId: 'obsidian',
        title: 'Abrir Obsidian',
        reason: 'Comando rápido local',
        requiresConfirmation: true,
      );
    }

    if (clean == 'abrir orbit') {
      return const QuickCommandAction(
        actionType: 'app.launch',
        targetId: 'orbit',
        title: 'Abrir Orbit',
        reason: 'Comando rápido local',
        requiresConfirmation: true,
      );
    }

    if (clean == 'abrir bloco de notas' || clean == 'abrir notepad') {
      return const QuickCommandAction(
        actionType: 'app.launch',
        targetId: 'test_notepad',
        title: 'Abrir Bloco de Notas',
        reason: 'Comando rápido local',
        requiresConfirmation: true,
      );
    }

    if (clean == 'fechar bloco de notas' ||
        clean == 'encerrar notepad' ||
        clean == 'fechar notepad' ||
        clean == 'encerrar bloco de notas') {
      return const QuickCommandAction(
        actionType: 'app.kill',
        targetId: 'test_notepad',
        title: 'Encerrar Bloco de Notas',
        reason: 'Comando rápido local',
        requiresConfirmation: true,
      );
    }

    if (clean == 'capturar tela' || clean == 'print' || clean == 'tirar print') {
      return const QuickCommandAction(
        actionType: 'screenshot.capture',
        targetId: 'primary_monitor',
        title: 'Capturar Tela',
        reason: 'Comando rápido local',
        requiresConfirmation: true,
      );
    }

    return null;
  }
}

/// Barra de comandos locais com ações tipadas e confirmação explícita.
class LocalQuickCommandBar extends StatefulWidget {
  final String targetPcName;
  final Future<void> Function(QuickCommandAction action)? onTriggerAction;

  const LocalQuickCommandBar({
    super.key,
    required this.targetPcName,
    this.onTriggerAction,
  });

  @override
  State<LocalQuickCommandBar> createState() => _LocalQuickCommandBarState();
}

class _LocalQuickCommandBarState extends State<LocalQuickCommandBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color barBackground = Color(0xFF161424);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCommand(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _isProcessing) return;

    final action = QuickCommandParser.parseLocalIntent(text);

    if (action != null) {
      _controller.clear();
      await _confirmAndExecute(action);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comando não reconhecido localmente: "$text"'),
            backgroundColor: const Color(0xFF2E2A40),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndExecute(QuickCommandAction action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1829),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar Ação Rápida',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action.title,
              style: const TextStyle(
                color: amethystAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.reason,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'PC-alvo: ${widget.targetPcName}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ação: ${action.actionType} | Alvo: ${action.targetId}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
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
            child: const Text('Executar Agora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onTriggerAction != null) {
      setState(() => _isProcessing = true);
      try {
        await widget.onTriggerAction!(action);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ação "${action.title}" executada com sucesso!'),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao executar ação: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: barBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amethystAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on_outlined, color: amethystAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Comando rápido (ex: abrir obsidian, capturar tela)...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: _handleCommand,
            ),
          ),
          if (_isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: amethystAccent),
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded, color: amethystAccent, size: 20),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _handleCommand(_controller.text),
            ),
        ],
      ),
    );
  }
}
