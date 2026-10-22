import 'dart:convert';

import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/routines/routine_builder_page.dart';
import 'package:flutter/material.dart';
import '../services/signalr_service.dart';

class RoutinePcTarget {
  const RoutinePcTarget({
    required this.pcId,
    required this.pcName,
    required this.client,
    required this.connection,
  });

  final String pcId;
  final String pcName;
  final DroidDeckClient client;
  final SignalRService connection;
}

/// Card interativo para Modos de Ambiente e Rotinas Encadeadas (Onda v0.5 - M1).
class WorkspaceRoutinesCard extends StatefulWidget {
  final DroidDeckClient? client;
  final VoidCallback? onRoutineExecuted;
  final String? targetPcName;
  final String? deviceId;
  final List<RoutinePcTarget> dualTargets;

  const WorkspaceRoutinesCard({
    super.key,
    this.client,
    this.onRoutineExecuted,
    this.targetPcName,
    this.deviceId,
    this.dualTargets = const [],
  });

  @override
  State<WorkspaceRoutinesCard> createState() => _WorkspaceRoutinesCardState();
}

class _WorkspaceRoutinesCardState extends State<WorkspaceRoutinesCard> {
  List<RoutineDefinitionData> _routines = List.from(_defaultPresets);
  Map<String, List<RoutineDefinitionData>> _dualRoutinesByPc = {};
  bool _isLoading = false;
  bool _dualRoutinesLoading = false;
  bool _dualRoutinesFailed = false;
  String? _executingRoutineId;
  int _dualRoutineLoadGeneration = 0;

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color cardBackground = Color(0xFF161424);
  static const Color itemBackground = Color(0xFF1E1B2E);

  // 3 Presets locais padrão para resiliência offline e testes
  static final List<RoutineDefinitionData> _defaultPresets = [
    const RoutineDefinitionData(
      id: 'study_vault',
      name: 'Modo Estudo & Vault',
      description: 'Abre Obsidian e minimiza distrações no PC',
      icon: 'auto_mode',
      isPreset: true,
      requiresConfirmation: true,
      steps: [
        RoutineStepData(
          stepId: 's1',
          actionType: 'app.launch',
          targetId: 'obsidian',
          delayMs: 1000,
        ),
      ],
    ),
    const RoutineDefinitionData(
      id: 'dev_orbit',
      name: 'Modo Dev Orbit',
      description: 'Inicia ambiente de desenvolvimento e monitor',
      icon: 'playlist_play',
      isPreset: true,
      requiresConfirmation: true,
      steps: [
        RoutineStepData(
          stepId: 's1',
          actionType: 'app.launch',
          targetId: 'orbit',
          delayMs: 500,
        ),
      ],
    ),
    const RoutineDefinitionData(
      id: 'focus_clean',
      name: 'Limpeza de Foco',
      description: 'Encerra processos de teste e captura tela de auditoria',
      icon: 'workspaces_outline',
      isPreset: true,
      requiresConfirmation: true,
      steps: [
        RoutineStepData(
          stepId: 's1',
          actionType: 'app.kill',
          targetId: 'test_notepad',
        ),
        RoutineStepData(
          stepId: 's2',
          actionType: 'screenshot.capture',
          targetId: 'primary',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
    _loadDualRoutines();
  }

  @override
  void didUpdateWidget(covariant WorkspaceRoutinesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) _loadRoutines();
    if (!_sameDualTargets(oldWidget.dualTargets, widget.dualTargets)) {
      _loadDualRoutines();
    }
  }

  bool _sameDualTargets(List<RoutinePcTarget> left, List<RoutinePcTarget> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].pcId != right[i].pcId ||
          left[i].pcName != right[i].pcName ||
          left[i].client != right[i].client ||
          left[i].connection != right[i].connection) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadDualRoutines() async {
    final generation = ++_dualRoutineLoadGeneration;
    final targets = List<RoutinePcTarget>.from(widget.dualTargets);
    if (targets.length != 2) {
      if (mounted) {
        setState(() {
          _dualRoutinesByPc = {};
          _dualRoutinesLoading = false;
          _dualRoutinesFailed = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _dualRoutinesByPc = {};
        _dualRoutinesLoading = true;
        _dualRoutinesFailed = false;
      });
    }
    final results = await Future.wait(targets.map((target) async {
      try {
        return MapEntry(target.pcId, await target.client.getRoutines());
      } catch (_) {
        return null;
      }
    }));
    if (!mounted || generation != _dualRoutineLoadGeneration) return;
    setState(() {
      _dualRoutinesByPc = {
        for (final result in results)
          if (result != null) result.key: result.value,
      };
      _dualRoutinesFailed = results.any((result) => result == null);
      _dualRoutinesLoading = false;
    });
  }

  String? _dualExecutionProblem(RoutineDefinitionData routine, {required bool connected}) {
    if (!connected) return 'Os dois PCs precisam estar conectados.';
    if (_dualRoutinesLoading) return 'Verificando as rotinas nos dois PCs…';
    if (_dualRoutinesFailed) return 'Não foi possível ler as rotinas dos dois PCs.';
    final definitions = widget.dualTargets.map((target) =>
      _dualRoutinesByPc[target.pcId]?.where((item) => item.id == routine.id).firstOrNull,
    ).toList();
    for (var i = 0; i < definitions.length; i++) {
      if (definitions[i] == null) return 'Rotina ausente em ${widget.dualTargets[i].pcName}.';
    }
    if (jsonEncode(definitions.first!.toJson()) != jsonEncode(definitions.last!.toJson())) {
      return 'As definições diferem entre ${widget.dualTargets[0].pcName} e ${widget.dualTargets[1].pcName}.';
    }
    return null;
  }

  Future<void> _loadRoutines() async {
    final client = widget.client;
    if (client == null) {
      if (mounted) {
        setState(() {
          _routines = List.from(_defaultPresets);
          _isLoading = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final remote = await client.getRoutines();
      if (mounted) {
        setState(() {
          _routines = remote.isNotEmpty ? remote : List.from(_defaultPresets);
        });
      }
    } catch (_) {
      // Fallback gracioso para presets locais
      if (mounted) {
        setState(() {
          _routines = List.from(_defaultPresets);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openBuilder([RoutineDefinitionData? routine]) async {
    final effectiveClient = widget.client ?? DroidDeckClient(baseUrl: 'http://10.0.2.2:4787');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => RoutineBuilderPage(
          client: effectiveClient,
          initialRoutine: routine,
          onSaved: (saved) {
            _loadRoutines();
          },
        ),
      ),
    );
    _loadRoutines();
    _loadDualRoutines();
  }

  Future<void> _confirmAndExecuteRoutine(RoutineDefinitionData routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1829),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmar Execução de Rotina',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              routine.name,
              style: const TextStyle(
                color: amethystAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (widget.targetPcName != null) ...[
              const SizedBox(height: 4),
              Text('PC-alvo: ${widget.targetPcName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            const SizedBox(height: 6),
            Text(
              routine.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Passos sequenciais que serão executados:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  children: routine.steps.map((step) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_right, color: amethystAccent, size: 18),
                          Expanded(
                            child: Text(
                              '${step.actionType} -> ${step.targetId}${step.delayMs > 0 ? " (delay ${step.delayMs}ms)" : ""}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
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
            child: const Text('Executar Rotina', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _executingRoutineId = routine.id);
      try {
        final effectiveClient = widget.client ?? DroidDeckClient(baseUrl: 'http://10.0.2.2:4787');
        final result = await effectiveClient.executeRoutine(
          routine.id,
          confirmed: true,
          deviceId: widget.deviceId,
        );
        if (mounted) {
          _showExecutionResultSheet(result);
          widget.onRoutineExecuted?.call();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha de comunicação com o PC-alvo. Confira a conexão e o pareamento.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _executingRoutineId = null);
        }
      }
    }
  }

  Future<void> _confirmAndExecuteBoth(RoutineDefinitionData routine) async {
    final targets = List<RoutinePcTarget>.from(widget.dualTargets);
    final connected = targets.length == 2 && targets.every(
      (target) => target.connection.connectionStatus.value == 'Connected',
    );
    final problem = _dualExecutionProblem(routine, connected: connected);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1829),
        title: const Text('Confirmar nos dois PCs'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routine.name, style: const TextStyle(color: amethystAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final target in targets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(target.pcName, style: const TextStyle(color: Colors.white)),
                ),
              const SizedBox(height: 8),
              Text(routine.description, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              for (final step in routine.steps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${step.actionType} -> ${step.targetId}${step.delayMs > 0 ? ' (delay ${step.delayMs}ms)' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar nos dois')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (targets.any((target) => target.connection.connectionStatus.value != 'Connected')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A conexão de um dos PCs caiu. Nenhuma execução pareada foi iniciada.')),
      );
      return;
    }

    setState(() => _executingRoutineId = routine.id);
    try {
      final results = await Future.wait<(RoutinePcTarget, RoutineExecutionResult?)>(
        targets.map((target) async {
          try {
            return (
              target,
              await target.client.executeRoutine(routine.id, confirmed: true, deviceId: target.pcId),
            );
          } catch (_) {
            return (target, null);
          }
        }),
      );
      if (mounted) {
        _showDualExecutionResults(routine, results);
        widget.onRoutineExecuted?.call();
      }
    } finally {
      if (mounted) setState(() => _executingRoutineId = null);
    }
  }

  void _showDualExecutionResults(
    RoutineDefinitionData routine,
    List<(RoutinePcTarget, RoutineExecutionResult?)> results,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardBackground,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(routine.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (final (target, result) in results)
                  Card(
                    color: itemBackground,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(target.pcName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            result == null ? 'Falha de comunicação. Confira o PC e o pareamento.' : 'Status: ${result.overallStatus}',
                            style: TextStyle(color: result == null ? Colors.redAccent : Colors.white70),
                          ),
                          if (result != null)
                            for (final step in result.stepResults)
                              Text('${step.actionType} (${step.targetId}): ${step.status}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExecutionResultSheet(RoutineExecutionResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161424),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    result.overallStatus == 'succeeded'
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: result.overallStatus == 'succeeded'
                        ? const Color(0xFF4CAF50)
                        : Colors.orangeAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Resultado: ${result.routineName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Status Geral: ${result.overallStatus}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),
              const SizedBox(height: 6),
              ...result.stepResults.map((stepRes) {
                final isOk = stepRes.status == 'succeeded';
                final isSkip = stepRes.status == 'skipped';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOk
                            ? Icons.check
                            : isSkip
                                ? Icons.redo
                                : Icons.close,
                        color: isOk
                            ? const Color(0xFF4CAF50)
                            : isSkip
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${stepRes.actionType} (${stepRes.targetId}): ${stepRes.status}',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      if (stepRes.durationMs > 0)
                        Text(
                          '${stepRes.durationMs}ms',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: amethystAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final dualStatuses = widget.dualTargets
          .map((target) => target.connection.connectionStatus.watch(context))
          .toList();
      final dualConnected =
          dualStatuses.length == 2 &&
          dualStatuses.every((status) => status == 'Connected');
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
              // Cabeçalho do Card
              Row(
                children: [
                  const Icon(
                    Icons.workspaces_outline,
                    color: amethystAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modos de Ambiente & Rotinas',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Automações encadeadas seguras (Regra 3)',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.add,
                      size: 16,
                      color: amethystAccent,
                    ),
                    label: const Text(
                      'Nova Rotina',
                      style: TextStyle(color: amethystAccent, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: amethystAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _openBuilder(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isLoading && _routines.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: amethystAccent),
                  ),
                )
              else
                ...List.generate(_routines.length, (index) {
                  final routine = _routines[index];
                  final isRunning = _executingRoutineId != null;
                  final routineIsRunning = _executingRoutineId == routine.id;
                  final dualProblem = widget.dualTargets.length == 2
                      ? _dualExecutionProblem(routine, connected: dualConnected)
                      : null;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: itemBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: amethystAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.playlist_play_rounded,
                                color: amethystAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    routine.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    routine.description,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${routine.steps.length} passos configurados',
                                    style: const TextStyle(
                                      color: amethystAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: amethystAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: isRunning
                                  ? null
                                  : () => _confirmAndExecuteRoutine(routine),
                              child: routineIsRunning
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text('Executar'),
                            ),
                          ],
                        ),
                        if (widget.dualTargets.length == 2) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.devices, size: 16),
                            label: const Text('Executar nos dois PCs'),
                            onPressed: isRunning || dualProblem != null
                                ? null
                                : () => _confirmAndExecuteBoth(routine),
                          ),
                          if (dualProblem != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                dualProblem,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    });
  }
}
