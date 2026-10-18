import 'package:droiddeck/core/core.dart';
import 'package:flutter/material.dart';

/// Modal para gerenciar a configuração do módulo Hermes IA (Onda v0.4 - H2).
class HermesConfigSheet extends StatefulWidget {
  final DroidDeckClient client;
  final HermesConfigData initialConfig;
  final ValueChanged<HermesConfigData>? onSaved;

  const HermesConfigSheet({
    super.key,
    required this.client,
    required this.initialConfig,
    this.onSaved,
  });

  @override
  State<HermesConfigSheet> createState() => _HermesConfigSheetState();
}

class _HermesConfigSheetState extends State<HermesConfigSheet> {
  late bool _enabled;
  late TextEditingController _endpointController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;

  bool _isSaving = false;
  String? _errorMessage;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialConfig.enabled;
    _endpointController = TextEditingController(text: widget.initialConfig.endpointUrl);
    _modelController = TextEditingController(text: widget.initialConfig.modelName);
    _apiKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.client.updateHermesConfig(
        enabled: _enabled,
        endpointUrl: _endpointController.text.trim(),
        modelName: _modelController.text.trim(),
        apiKey: _apiKeyController.text.isNotEmpty ? _apiKeyController.text.trim() : null,
      );

      if (mounted) {
        widget.onSaved?.call(updated);
        Navigator.of(context).maybePop(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao salvar configuração: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const amethystAccent = Color(0xFFA78BFA);
    const darkBackground = Color(0xFF0F0E17);
    const surfaceColor = Color(0xFF1A1829);

    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: darkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, color: amethystAccent, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Configuração Hermes IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Switch Ativar Módulo Hermes IA (Opcional)
            Material(
              color: surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _enabled
                      ? amethystAccent.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Ativar Módulo Hermes IA (Opcional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Diagnóstico assistido e sugestões inteligentes no PC',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                activeColor: amethystAccent,
                value: _enabled,
                onChanged: (val) {
                  setState(() => _enabled = val);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Campo Endpoint / Gateway URL
            TextField(
              controller: _endpointController,
              enabled: !_isSaving,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Endpoint / Gateway URL',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'https://generativelanguage.googleapis.com ou local',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: surfaceColor,
                prefixIcon: const Icon(Icons.link, color: amethystAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: amethystAccent),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Campo Modelo (ex: gemini-3.8-flash)
            TextField(
              controller: _modelController,
              enabled: !_isSaving,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Modelo (ex: gemini-3.8-flash)',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'gemini-3.8-flash',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: surfaceColor,
                prefixIcon: const Icon(Icons.model_training, color: amethystAccent),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: amethystAccent),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Campo Chave de API (opcional, protegida no PC)
            TextField(
              controller: _apiKeyController,
              enabled: !_isSaving,
              obscureText: _obscureApiKey,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Chave de API (opcional, protegida no PC)',
                labelStyle: const TextStyle(color: Colors.white70),
                helperText: widget.initialConfig.hasApiKey
                    ? 'Chave já cadastrada no PC (preencha apenas para alterar)'
                    : 'Armazenada com segurança via DPAPI no Windows',
                helperStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                filled: true,
                fillColor: surfaceColor,
                prefixIcon: const Icon(Icons.key, color: amethystAccent),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white60,
                  ),
                  onPressed: () {
                    setState(() => _obscureApiKey = !_obscureApiKey);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: amethystAccent),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Aviso de Privacidade
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: amethystAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: amethystAccent, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Dados são sanitizados antes do envio. O controle do PC funciona 100% sem IA.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],

            // Botão Salvar Configuração
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: amethystAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'Salvar Configuração',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
