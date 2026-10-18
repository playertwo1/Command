import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';

class _ChatMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final HermesAnalyzeResult? result;

  _ChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.result,
  });
}

/// Console de Chat Assistivo Hermes IA (Onda v0.4 - H3).
class HermesAssistantPage extends StatefulWidget {
  final DroidDeckClient client;
  final String? initialPrompt;
  final String? screenshotId;
  final Future<void> Function(HermesSuggestedAction action)? onExecuteConfirmedAction;

  const HermesAssistantPage({
    super.key,
    required this.client,
    this.initialPrompt,
    this.screenshotId,
    this.onExecuteConfirmedAction,
  });

  @override
  State<HermesAssistantPage> createState() => _HermesAssistantPageState();
}

class _HermesAssistantPageState extends State<HermesAssistantPage> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool _includeTelemetry = true;
  bool _includeTopProcesses = true;

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color darkBackground = Color(0xFF050408);
  static const Color surfaceCard = Color(0xFF161424);
  static const Color bubbleUser = Color(0xFF2D2447);
  static const Color bubbleAssistant = Color(0xFF1E1B2E);

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _promptController.text = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendPrompt(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPrompt(String promptText) async {
    final text = promptText.trim();
    if (text.isEmpty || _isLoading) return;

    _promptController.clear();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _messages.add(_ChatMessage(
        isUser: true,
        text: text,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    try {
      final result = await widget.client.analyzeWithHermes(
        prompt: text,
        includeTelemetry: _includeTelemetry,
        includeTopProcesses: _includeTopProcesses,
        screenshotId: widget.screenshotId,
      );

      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            isUser: false,
            text: result.reply,
            timestamp: DateTime.now(),
            result: result,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro na análise assistiva: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showConfirmationDialog(HermesSuggestedAction action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1829),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar Ação Sugerida',
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

    if (confirmed == true && widget.onExecuteConfirmedAction != null) {
      try {
        await widget.onExecuteConfirmedAction!(action);
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
              content: Text('Erro ao executar: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: amethystAccent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Hermes Assistente',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (widget.screenshotId != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: amethystAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Print Ativo',
                  style: TextStyle(color: amethystAccent, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner de Transparência e Consentimento no topo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceCard,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, color: amethystAccent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Consentimento ativo: apenas métricas sanitizadas (sem IPs/caminhos privados) são enviadas.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Incluir Telemetria', style: TextStyle(fontSize: 11)),
                      selected: _includeTelemetry,
                      selectedColor: amethystAccent.withValues(alpha: 0.3),
                      checkmarkColor: amethystAccent,
                      labelStyle: TextStyle(
                        color: _includeTelemetry ? amethystAccent : Colors.white60,
                      ),
                      onSelected: (val) => setState(() => _includeTelemetry = val),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Incluir Top Processos', style: TextStyle(fontSize: 11)),
                      selected: _includeTopProcesses,
                      selectedColor: amethystAccent.withValues(alpha: 0.3),
                      checkmarkColor: amethystAccent,
                      labelStyle: TextStyle(
                        color: _includeTopProcesses ? amethystAccent : Colors.white60,
                      ),
                      onSelected: (val) => setState(() => _includeTopProcesses = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chips de Diagnóstico Rápido
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.speed, size: 16, color: amethystAccent),
                    label: const Text('Diagnosticar Lentidão'),
                    backgroundColor: surfaceCard,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _sendPrompt('Diagnosticar Lentidão'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.memory, size: 16, color: amethystAccent),
                    label: const Text('Analisar Uso de Memória'),
                    backgroundColor: surfaceCard,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _sendPrompt('Analisar Uso de Memória'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.health_and_safety_outlined, size: 16, color: amethystAccent),
                    label: const Text('Resumo de Saúde'),
                    backgroundColor: surfaceCard,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onPressed: () => _sendPrompt('Resumo de Saúde'),
                  ),
                ],
              ),
            ),
          ),

          // Lista de Mensagens
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Como posso ajudar você no PC hoje?',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageTile(msg);
                    },
                  ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.red.withValues(alpha: 0.2),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: amethystAccent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Analisando telemetria com Hermes...',
                    style: TextStyle(
                      color: amethystAccent.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Campo de Entrada
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceCard,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      style: const TextStyle(color: Colors.white),
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Pergunte sobre telemetria ou ações...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: const Color(0xFF1E1B2E),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (text) => _sendPrompt(text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: amethystAccent),
                    onPressed: _isLoading ? null : () => _sendPrompt(_promptController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(_ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isUser ? bubbleUser : bubbleAssistant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: msg.isUser
                ? amethystAccent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  msg.isUser ? Icons.person : Icons.psychology,
                  color: amethystAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  msg.isUser ? 'Você' : 'Hermes',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            if (msg.result != null && msg.result!.sanitizedContextSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Contexto: ${msg.result!.sanitizedContextSummary}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (msg.result != null && msg.result!.suggestedActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
              const Text(
                'Ações Sugeridas:',
                style: TextStyle(
                  color: amethystAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              ...msg.result!.suggestedActions.map(_buildActionCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(HermesSuggestedAction action) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: amethystAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_circle_outline, color: amethystAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.reason,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirmar e Executar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: amethystAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => _showConfirmationDialog(action),
            ),
          ),
        ],
      ),
    );
  }
}
