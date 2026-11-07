import 'package:command/core/core.dart';
import 'package:flutter/material.dart';

/// Construtor visual de rotinas seguras e macros encadeadas (v1.6 - Fase R4).
class RoutineBuilderPage extends StatefulWidget {
  final CommandClient client;
  final RoutineDefinitionData? initialRoutine;
  final ValueChanged<RoutineDefinitionData>? onSaved;

  const RoutineBuilderPage({
    super.key,
    required this.client,
    this.initialRoutine,
    this.onSaved,
  });

  @override
  State<RoutineBuilderPage> createState() => _RoutineBuilderPageState();
}

class _RoutineBuilderPageState extends State<RoutineBuilderPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late List<RoutineStepData> _steps;

  bool _isSaving = false;
  String? _errorMessage;
  List<AllowedApp> _availableApps = [];

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color darkBackground = Color(0xFF0F0E17);
  static const Color surfaceCard = Color(0xFF161424);
  static const Color stepCardBackground = Color(0xFF1E1B2E);

  static const List<String> _allowedActionTypes = [
    'app.launch',
    'app.kill',
    'screenshot.capture',
    'system.shortcut',
    'media.control',
    'power.action',
    'delay',
  ];

  static const Map<String, String> _actionTypeLabels = {
    'app.launch': 'Iniciar Aplicativo',
    'app.kill': 'Encerrar Aplicativo',
    'screenshot.capture': 'Captura de Tela',
    'system.shortcut': 'Atalho do Teclado',
    'media.control': 'Controle de Mídia',
    'power.action': 'Energia do PC',
    'delay': 'Pausa / Espera',
  };

  static const List<String> _commonShortcuts = [
    'Win+D',
    'Alt+Tab',
    'Ctrl+C',
    'Ctrl+V',
    'Ctrl+Z',
    'Ctrl+S',
    'Win',
    'Esc',
    'Enter',
    'Space',
    'F5',
    'F11',
    'PRTSC',
  ];

  static const List<Map<String, String>> _mediaCommands = [
    {'id': 'play_pause', 'label': 'Reproduzir / Pausar'},
    {'id': 'next', 'label': 'Próxima Faixa'},
    {'id': 'prev', 'label': 'Faixa Anterior'},
    {'id': 'stop', 'label': 'Parar Reprodução'},
    {'id': 'volume_up', 'label': 'Aumentar Volume'},
    {'id': 'volume_down', 'label': 'Diminuir Volume'},
    {'id': 'mute', 'label': 'Mutar Áudio'},
  ];

  static const List<Map<String, String>> _powerCommands = [
    {'id': 'lock', 'label': 'Bloquear Sessão (Lock)'},
    {'id': 'sleep', 'label': 'Suspender PC (Sleep)'},
  ];

  static const List<String> _fallbackAppIds = [
    'obsidian',
    'orbit',
    'test_notepad',
    'notepad',
    'chrome',
    'spotify',
    'discord',
    'code',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialRoutine;
    _nameController = TextEditingController(text: init?.name ?? '');
    _descController = TextEditingController(text: init?.description ?? '');
    _steps = init != null ? List.from(init.steps) : [];
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await widget.client.getApps();
      if (mounted && apps.isNotEmpty) {
        setState(() {
          _availableApps = apps;
        });
      }
    } catch (_) {
      // Ignora erro em modo offline
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add(
        RoutineStepData(
          stepId: 'step_${DateTime.now().millisecondsSinceEpoch}_${_steps.length}',
          actionType: 'app.launch',
          targetId: _availableApps.isNotEmpty ? _availableApps.first.id : 'obsidian',
          delayMs: 0,
          continueOnError: false,
        ),
      );
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'O nome da rotina é obrigatório.');
      return;
    }

    if (_steps.isEmpty) {
      setState(() => _errorMessage = 'Adicione pelo menos um passo na rotina.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final routineToSave = RoutineDefinitionData(
        id: widget.initialRoutine?.id ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: _descController.text.trim(),
        icon: widget.initialRoutine?.icon ?? 'auto_mode',
        isPreset: widget.initialRoutine?.isPreset ?? false,
        requiresConfirmation: true,
        steps: _steps,
      );

      final saved = await widget.client.saveRoutine(routineToSave);

      if (mounted) {
        widget.onSaved?.call(saved);
        Navigator.of(context).maybePop(saved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Falha ao salvar rotina: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
            const Icon(Icons.auto_mode, color: amethystAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              widget.initialRoutine == null ? 'Nova Rotina' : 'Editar Rotina',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: amethystAccent),
                  )
                : const Icon(Icons.check, color: amethystAccent),
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campo Nome da Rotina
            TextField(
              controller: _nameController,
              enabled: !_isSaving,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome da Rotina',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'ex: Modo Estudo & Vault',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: surfaceCard,
                prefixIcon: const Icon(Icons.playlist_play, color: amethystAccent),
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

            // Campo Descrição
            TextField(
              controller: _descController,
              enabled: !_isSaving,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Descrição',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'ex: Abre apps de anotação e organiza foco',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: surfaceCard,
                prefixIcon: const Icon(Icons.description_outlined, color: amethystAccent),
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
            const SizedBox(height: 20),

            // Cabeçalho dos Passos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Passos da Sequência (${_steps.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar Passo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amethystAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _isSaving ? null : _addStep,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_steps.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.playlist_add, size: 40, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum passo adicionado ainda.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _buildStepCard(step, index);
                },
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
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
                      'Salvar Rotina',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard(RoutineStepData step, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stepCardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amethystAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: amethystAccent,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Passo ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _removeStep(index),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dropdown ActionType
          DropdownButtonFormField<String>(
            value: _allowedActionTypes.contains(step.actionType) ? step.actionType : _allowedActionTypes.first,
            dropdownColor: surfaceCard,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Tipo de Ação',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _allowedActionTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(_actionTypeLabels[type] ?? type),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                String newTarget = step.targetId;
                if (val == 'screenshot.capture') {
                  newTarget = 'primary';
                } else if (val == 'system.shortcut') {
                  newTarget = 'Win+D';
                } else if (val == 'media.control') {
                  newTarget = 'play_pause';
                } else if (val == 'power.action') {
                  newTarget = 'lock';
                } else if (val == 'delay') {
                  newTarget = 'delay';
                } else if (val == 'app.launch' || val == 'app.kill') {
                  newTarget = _availableApps.isNotEmpty ? _availableApps.first.id : 'obsidian';
                }
                setState(() {
                  _steps[index] = step.copyWith(actionType: val, targetId: newTarget);
                });
              }
            },
          ),
          const SizedBox(height: 10),

          // Seletor de Target dinâmico dependendo do ActionType
          _buildTargetSelector(step, index),
          const SizedBox(height: 10),

          // Slider / Input de Delay (ms)
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: amethystAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Delay após ação: ${step.delayMs} ms',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: step.delayMs.toDouble().clamp(0.0, 5000.0),
            min: 0,
            max: 5000,
            divisions: 10,
            label: '${step.delayMs} ms',
            activeColor: amethystAccent,
            onChanged: (val) {
              setState(() {
                _steps[index] = step.copyWith(delayMs: val.toInt());
              });
            },
          ),

          // Switch Continuar se falhar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Continuar se falhar',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              Switch(
                activeColor: amethystAccent,
                value: step.continueOnError,
                onChanged: (val) {
                  setState(() {
                    _steps[index] = step.copyWith(continueOnError: val);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector(RoutineStepData step, int index) {
    if (step.actionType == 'delay') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Text(
          'Pausa temporal (ajuste os milissegundos no controle abaixo)',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      );
    }

    if (step.actionType == 'screenshot.capture') {
      return DropdownButtonFormField<String>(
        value: 'primary',
        dropdownColor: surfaceCard,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Monitor de Captura',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: const [
          DropdownMenuItem(value: 'primary', child: Text('Monitor Principal')),
        ],
        onChanged: (_) {},
      );
    }

    if (step.actionType == 'media.control') {
      final currentTarget = _mediaCommands.any((m) => m['id'] == step.targetId)
          ? step.targetId
          : _mediaCommands.first['id']!;
      return DropdownButtonFormField<String>(
        value: currentTarget,
        dropdownColor: surfaceCard,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Comando de Mídia',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: _mediaCommands.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['label']!),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _steps[index] = step.copyWith(targetId: val);
            });
          }
        },
      );
    }

    if (step.actionType == 'power.action') {
      final currentTarget = _powerCommands.any((p) => p['id'] == step.targetId)
          ? step.targetId
          : _powerCommands.first['id']!;
      return DropdownButtonFormField<String>(
        value: currentTarget,
        dropdownColor: surfaceCard,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: 'Ação de Energia',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: _powerCommands.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'],
            child: Text(item['label']!),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _steps[index] = step.copyWith(targetId: val);
            });
          }
        },
      );
    }

    if (step.actionType == 'system.shortcut') {
      final isCommon = _commonShortcuts.contains(step.targetId);
      final currentTarget = isCommon ? step.targetId : _commonShortcuts.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: currentTarget,
            dropdownColor: surfaceCard,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Atalhos Predefinidos',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _commonShortcuts.map((sc) {
              return DropdownMenuItem<String>(
                value: sc,
                child: Text(sc),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _steps[index] = step.copyWith(targetId: val);
                });
              }
            },
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: step.targetId,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Ou digite tecla/atalho personalizado (ex: Ctrl+Shift+Esc)',
              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
              filled: true,
              fillColor: surfaceCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) {
              if (val.trim().isNotEmpty) {
                _steps[index] = step.copyWith(targetId: val.trim());
              }
            },
          ),
        ],
      );
    }

    // Caso padrão: app.launch ou app.kill
    final appOptions = _availableApps.isNotEmpty
        ? _availableApps.map((a) => a.id).toList()
        : _fallbackAppIds;
    final currentApp = appOptions.contains(step.targetId) ? step.targetId : appOptions.first;

    return DropdownButtonFormField<String>(
      value: currentApp,
      dropdownColor: surfaceCard,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: step.actionType == 'app.kill' ? 'Aplicativo a Encerrar' : 'Aplicativo a Iniciar',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: appOptions.map((target) {
        final appMatch = _availableApps.where((a) => a.id == target).firstOrNull;
        final label = appMatch != null ? '${appMatch.name} ($target)' : target;
        return DropdownMenuItem<String>(
          value: target,
          child: Text(label),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _steps[index] = step.copyWith(targetId: val);
          });
        }
      },
    );
  }
}
