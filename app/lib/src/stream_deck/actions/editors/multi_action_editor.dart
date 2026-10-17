import 'dart:async';
import 'dart:convert';

import 'package:droiddeck/core/core.dart';

import 'package:droiddeck/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

/// Multi-ação: passos em sequência, cada um com uma espera antes.
///
/// Passo no editor: {type: hotkey|launch_app|mute, param, delayMs, _k (chave estável)}.
/// No botão vira o JSON [{type, parameters, delayMs}] que o PC executa.
class MultiActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const MultiActionEditor({super.key, required this.args});

  @override
  State<MultiActionEditor> createState() => _MultiActionEditorState();
}

class _MultiActionEditorState extends State<MultiActionEditor> {
  List<Map<String, dynamic>> _steps = [];
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _steps = _decode(widget.args.initial['steps']);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() => widget.args.onChanged({'steps': _encode(_steps)});

  void _update(VoidCallback change) {
    setState(change);
    _emit();
  }

  List<Map<String, dynamic>> _decode(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map<Map<String, dynamic>>((e) {
        final m = e as Map<String, dynamic>;
        final t = m['type'] as String? ?? 'hotkey';
        final p = (m['parameters'] as Map?)?.cast<String, dynamic>() ?? {};
        String editorType = t;
        String param = '';
        if (t == 'hotkey') {
          param = p['keys']?.toString() ?? '';
        } else if (t == 'launch_app') {
          param = p['path']?.toString() ?? '';
        } else if (t == 'mixer') {
          editorType = 'mute';
          param = p['processName']?.toString() ?? '';
        }
        return {
          'type': editorType,
          'param': param,
          'delayMs': (m['delayMs'] as num?)?.toInt() ?? 0,
          '_k': _seq++,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _encode(List<Map<String, dynamic>> steps) {
    final out = steps.map((s) {
      final type = s['type'] as String? ?? 'hotkey';
      final param = (s['param'] as String? ?? '').trim();
      final delayMs = (s['delayMs'] as int?) ?? 0;
      if (type == 'mute') {
        return {
          'type': 'mixer',
          'parameters': {'operation': 'toggleMute', 'processName': param},
          'delayMs': delayMs,
        };
      } else if (type == 'launch_app') {
        return {
          'type': 'launch_app',
          'parameters': {'path': param},
          'delayMs': delayMs,
        };
      }
      return {
        'type': 'hotkey',
        'parameters': {'keys': param},
        'delayMs': delayMs,
      };
    }).toList();
    return jsonEncode(out);
  }

  String _paramLabel(String type) {
    switch (type) {
      case 'launch_app':
        return tr('Caminho do app (.exe)');
      case 'mute':
        return tr('Nome do app (processo)');
      default:
        return tr('Teclas (ex.: ^C = Ctrl+C)');
    }
  }

  /// Grava o que for digitado no PC e acrescenta os passos.
  Future<void> _record() async {
    final client = Injector.get<DroidDeckClient>();
    try {
      await client.postJson('/api/macro/start');
    } catch (_) {
      _snack(tr('Não foi possível gravar (só funciona no configurador do PC).'));
      return;
    }
    if (!mounted) return;
    final stepsJson = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RecordingDialog(),
    );
    if (stepsJson == null || !mounted) return;
    final recorded = _decode(stepsJson);
    if (recorded.isEmpty) {
      _snack(tr('Nenhuma tecla gravada.'));
      return;
    }
    _update(() => _steps.addAll(recorded));
    _snack(tr('{n} passo(s) gravado(s).', {'n': recorded.length}));
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final remote = widget.args.remote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Passos (executados em sequência):'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._steps.map((step) {
          final k = step['_k'];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: step['type'] as String,
                          isDense: true,
                          decoration: InputDecoration(
                              labelText: tr('Tipo'), border: const OutlineInputBorder()),
                          items: [
                            if (!remote) ...[
                              DropdownMenuItem(
                                  value: 'hotkey', child: Text(tr('Atalho'))),
                              DropdownMenuItem(
                                  value: 'launch_app', child: Text(tr('Abrir app'))),
                            ],
                            DropdownMenuItem(
                                value: 'mute', child: Text(tr('Mutar app'))),
                          ],
                          onChanged: (v) =>
                              _update(() => step['type'] = v ?? 'hotkey'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _update(() => _steps.remove(step)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('p$k'),
                    initialValue: step['param'] as String? ?? '',
                    decoration: InputDecoration(
                      labelText: _paramLabel(step['type'] as String),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      step['param'] = v;
                      _emit();
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('d$k'),
                    initialValue: (step['delayMs'] as int).toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('Esperar antes (ms)'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      step['delayMs'] = int.tryParse(v) ?? 0;
                      _emit();
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _update(() => _steps.add({
                    'type': remote ? 'mute' : 'hotkey',
                    'param': '',
                    'delayMs': 0,
                    '_k': _seq++,
                  })),
              icon: const Icon(Icons.add),
              label: Text(tr('Adicionar passo')),
            ),
            // Gravar lê o teclado do PC: só no configurador, no próprio PC.
            if (!remote)
              TextButton.icon(
                onPressed: _record,
                icon: const Icon(Icons.fiber_manual_record, color: Colors.redAccent),
                label: Text(tr('Gravar do teclado')),
              ),
          ],
        ),
      ],
    );
  }
}

/// Enquanto grava: mostra quantas teclas já vieram e para no botão (ou sozinho no tempo máximo).
class _RecordingDialog extends StatefulWidget {
  const _RecordingDialog();

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog> {
  final _client = Injector.get<DroidDeckClient>();
  Timer? _poll;
  int _keys = 0;
  int _seconds = 0;
  int _max = 60;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      try {
        final s = Map<String, dynamic>.from(await _client.getJson('/api/macro') as Map);
        if (!mounted) return;
        setState(() {
          _keys = (s['keys'] as num?)?.toInt() ?? 0;
          _seconds = (s['seconds'] as num?)?.toInt() ?? 0;
          _max = (s['maxSeconds'] as num?)?.toInt() ?? 60;
        });
        if (s['recording'] != true) _stop();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    if (_stopping) return;
    _stopping = true;
    _poll?.cancel();
    String? steps;
    try {
      final r = Map<String, dynamic>.from(await _client.postJson('/api/macro/stop') as Map);
      steps = r['steps'] as String?;
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(steps);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.fiber_manual_record, color: Colors.redAccent),
        const SizedBox(width: 8),
        Text(tr('Gravando')),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Vá para o programa e digite a sequência no teclado do PC. '
              'Pausas de mais de meio segundo viram espera entre os passos.')),
          const SizedBox(height: 16),
          Text(tr('{keys} tecla(s) · {seconds}s de {max} s', {'keys': _keys, 'seconds': _seconds, 'max': _max}),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        FilledButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: Text(tr('Parar')),
        ),
      ],
    );
  }
}
