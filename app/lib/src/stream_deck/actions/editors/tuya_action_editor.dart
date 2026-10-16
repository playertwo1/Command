import 'dart:convert';

import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:droiddeck/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

/// Casa inteligente Tuya/Smart Life: o campo de valor se adapta ao tipo de cada
/// função do aparelho (vindo do `specifications` dele).
class TuyaActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const TuyaActionEditor({super.key, required this.args});

  @override
  State<TuyaActionEditor> createState() => _TuyaActionEditorState();
}

class _TuyaActionEditorState extends State<TuyaActionEditor> {
  String _op = 'toggle';
  String? _deviceId;
  String? _code;
  String _value = '';

  SignalRService get _signalR => Injector.get<SignalRService>();

  @override
  void initState() {
    super.initState();
    final p = widget.args.initial;
    _op = p['operation'] ?? 'toggle';
    _deviceId = p['deviceId'];
    _code = p['code'];
    _value = p['value'] ?? '';
    _loadState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    final params = <String, String>{'operation': _op};
    if (_deviceId != null) params['deviceId'] = _deviceId!;
    if (_code != null) params['code'] = _code!;
    if (_op == 'set') {
      params['value'] = _value;
      // O backend precisa do tipo para converter a string no que a Tuya espera
      // (mandar "true" onde ela quer booleano faz a API recusar).
      params['valueType'] = _function()?['type'] ?? 'String';
    }
    widget.args.onChanged(params);
  }

  void _update(VoidCallback change) {
    setState(change);
    _emit();
  }

  // Num botão novo o snapshot pode não ter chegado ainda (só vem em broadcast raro):
  // sem isto os campos abririam dizendo "conta não vinculada" com a conta pareada.
  void _loadState() {
    Injector.get<DroidDeckClient>().getTuyaState().then((s) {
      if (s != null && mounted) {
        setState(() => _signalR.tuyaState.value = Map<String, dynamic>.from(s));
        _emit();
      }
    }).catchError((_) {});
  }

  List<dynamic> _devices() =>
      (_signalR.tuyaState.value['devices'] as List? ?? const []);

  Map<String, dynamic>? _device() {
    for (final d in _devices()) {
      if ((d as Map)['id'] == _deviceId) return Map<String, dynamic>.from(d);
    }
    return null;
  }

  /// Metadados da funcao escolhida (type/values), vindos do `specifications` do
  /// proprio aparelho -- e o que faz o campo de valor se adaptar sozinho.
  Map<String, dynamic>? _function() {
    final device = _device();
    if (device == null || _code == null) return null;
    final fns = device['functions'] as Map? ?? const {};
    final fn = fns[_code];
    return fn == null ? null : Map<String, dynamic>.from(fn as Map);
  }

  /// Os limites vem como JSON cru da Tuya: {"min":10,"max":1000} ou {"range":[...]}.
  Map<String, dynamic> _values() {
    final raw = _function()?['values'];
    if (raw is! String || raw.isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final paired = _signalR.tuyaState.value['paired'] == true;
    final devices = _devices();

    if (!paired) {
      return Card(
        color: Colors.orange.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Conta Tuya não vinculada'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                tr('Vincule sua conta Smart Life em Configurações → Casa inteligente '
                    'para escolher um dispositivo.'),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final device = _device();
    final fn = _function();
    final type = fn?['type'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: devices.any((d) => (d as Map)['id'] == _deviceId)
              ? _deviceId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('Dispositivo'),
            border: const OutlineInputBorder(),
            helperText: devices.isEmpty
                ? tr('Nenhum dispositivo — atualize em Configurações')
                : null,
          ),
          items: devices.map((d) {
            final dev = d as Map;
            return DropdownMenuItem(
              value: dev['id'] as String,
              child: Text(
                dev['online'] == true ? '${dev['name']}' : tr('{name} (offline)', {'name': dev['name']}),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (v) => _update(() {
            _deviceId = v;
            // Trocar de aparelho invalida a funcao: os DPs sao de cada modelo.
            _code = null;
            _value = '';
          }),
        ),
        const SizedBox(height: 12),
        if (device != null) ...[
          DropdownButtonFormField<String>(
            value: (device['functions'] as Map? ?? const {}).containsKey(_code)
                ? _code
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr('O que controlar'),
              border: const OutlineInputBorder(),
            ),
            items: (device['functions'] as Map? ?? const {})
                .entries
                .map((e) => DropdownMenuItem(
                      value: e.key as String,
                      child: Text('${e.key}  -  ${(e.value as Map)['type']}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => _update(() {
              _code = v;
              _value = '';
              // So booleano pode alternar; o resto exige um valor explicito.
              _op = _function()?['type'] == 'Boolean' ? 'toggle' : 'set';
            }),
          ),
          const SizedBox(height: 12),
        ],
        if (fn != null) ...[
          if (type == 'Boolean')
            DropdownButtonFormField<String>(
              value: _op,
              decoration: InputDecoration(
                labelText: tr('Ação'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                    value: 'toggle', child: Text(tr('Alternar (liga/desliga)'))),
                DropdownMenuItem(
                    value: 'set', child: Text(tr('Sempre ligar / sempre desligar'))),
              ],
              onChanged: (v) => _update(() => _op = v ?? 'toggle'),
            ),
          if (type == 'Boolean' && _op == 'set') ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_value == 'true' ? tr('Ligar') : tr('Desligar')),
              value: _value == 'true',
              onChanged: (v) => _update(() => _value = v ? 'true' : 'false'),
            ),
          ],
          if (type == 'Integer') ..._integerField(),
          if (type == 'Enum') ..._enumField(),
          if (type == 'String' || type == 'Json' || type == 'Raw')
            TextFormField(
              initialValue: _value,
              decoration: InputDecoration(
                labelText: tr('Valor'),
                border: const OutlineInputBorder(),
                helperText: tr('Tipo {type} — valor cru enviado à Tuya', {'type': type}),
              ),
              onChanged: (v) {
                _value = v;
                _emit();
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _test,
            icon: const Icon(Icons.play_arrow),
            label: Text(tr('Testar agora')),
          ),
        ],
        EditorHint(
            tr('O estado do botão acompanha o aparelho em tempo real; use "Cor ativa" '
                'para ele acender quando estiver ligado.')),
      ],
    );
  }

  List<Widget> _integerField() {
    final values = _values();
    final min = (values['min'] as num?)?.toDouble() ?? 0;
    final max = (values['max'] as num?)?.toDouble() ?? 100;
    final unit = values['unit'] as String? ?? '';
    final current = double.tryParse(_value) ?? min;
    final clamped = current.clamp(min, max);

    return [
      const SizedBox(height: 12),
      Text(tr('Valor: {value}{unit}', {'value': clamped.round(), 'unit': unit}),
          style: const TextStyle(fontSize: 12)),
      Slider(
        min: min,
        max: max,
        // Faixas grandes (brilho vai de 10 a 1000) ficariam travadas com poucas
        // divisoes; sem divisions o slider e continuo e arredondamos no fim.
        value: clamped.toDouble(),
        label: '${clamped.round()}',
        onChanged: (v) => _update(() => _value = '${v.round()}'),
      ),
      EditorHint(tr('Faixa: {min} a {max}{unit}', {'min': min.round(), 'max': max.round(), 'unit': unit})),
    ];
  }

  List<Widget> _enumField() {
    final range =
        (_values()['range'] as List? ?? const []).map((e) => '$e').toList();

    return [
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: range.contains(_value) ? _value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: tr('Valor'),
          border: const OutlineInputBorder(),
        ),
        items:
            range.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => _update(() => _value = v ?? ''),
      ),
    ];
  }

  Future<void> _test() async {
    if (_deviceId == null || _code == null) return;

    final type = _function()?['type'];
    Object? value;
    if (_op == 'toggle') {
      // Espelha o backend: inverte a partir do ultimo estado conhecido.
      final status = _device()?['status'] as Map? ?? const {};
      value = !(status[_code] == true);
    } else if (type == 'Boolean') {
      value = _value == 'true';
    } else if (type == 'Integer') {
      value = int.tryParse(_value) ?? 0;
    } else {
      value = _value;
    }

    try {
      await Injector.get<DroidDeckClient>()
          .sendTuyaCommand(_deviceId!, _code!, value);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('Comando enviado.'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }
}
