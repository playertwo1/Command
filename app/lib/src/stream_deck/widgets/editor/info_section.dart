import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/core/droiddeck_client/models/mixer_entity.dart';
import 'package:flutter/material.dart';

/// "Mostrar no botão": monitor do PC ou informação (relógio, clima, comando, URL...),
/// com os campos de cada tipo. Quem chama guarda o tipo e os parâmetros.
class InfoSection extends StatelessWidget {
  final String? type;
  final Map<String, String> params;

  /// Tipo gravado no botão antes da edição (para saber se está travado no celular).
  final String? savedType;

  /// Editando no celular (comando e URL só mudam no configurador do PC).
  final bool remote;

  final void Function(String? type, Map<String, String> params) onChanged;

  const InfoSection({
    super.key,
    required this.type,
    required this.params,
    required this.savedType,
    required this.remote,
    required this.onChanged,
  });

  static const labels = {
    'cpu_monitor': 'Uso da CPU',
    'memory_monitor': 'Uso da memória',
    'gpu_monitor': 'Uso da GPU',
    'temp_monitor': 'Temperatura',
    'network_monitor': 'Rede',
    'clock': 'Relógio',
    'weather': 'Clima',
    'now_playing': 'Tocando agora',
    'command': 'Saída de um comando (PC)',
    'url': 'Valor de uma URL (PC)',
    'mixer_slider': 'Controle de volume do PC',
  };

  /// Comando e URL rodam no PC: como os atalhos, só mudam no configurador.
  static const privileged = {'command', 'url'};

  bool get _locked => remote && privileged.contains(savedType);

  String _p(String key, [String fallback = '']) => params[key] ?? fallback;

  void _set(String key, String value) {
    final next = Map.of(params);
    if (value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    onChanged(type, next);
  }

  @override
  Widget build(BuildContext context) {
    final hint = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final options = labels.entries
        .where((e) => !remote || !privileged.contains(e.key) || e.key == type)
        .toList();
    final hasType = type != null && type!.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: hasType,
        shape: const Border(),
        leading: const Icon(Icons.insights_outlined),
        title: Text(tr('Mostrar no botão')),
        subtitle: Text(
          hasType
              ? (labels[type] != null ? tr(labels[type]!) : type!)
              : tr('Opcional'),
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: hasType ? type : null,
            decoration: InputDecoration(
              labelText: tr('Informação'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(tr('Nenhuma'))),
              ...options.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(tr(e.value))),
              ),
            ],
            // Trocar o tipo zera os parâmetros do anterior.
            onChanged: _locked
                ? null
                : (v) => onChanged(v, v == type ? params : {}),
          ),
          if (_locked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(
                  'Botões que rodam um comando ou leem uma URL no PC só mudam no '
                  'configurador do PC (http://localhost:4787).',
                ),
                style: hint,
              ),
            ),
          ..._fields(context),
          if (hasType)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                tr(
                  'O toque continua executando a ação do botão, se houver uma.',
                ),
                style: hint,
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    String? help,
    bool number = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        key: ValueKey('info_${type}_$key'),
        initialValue: _p(key),
        enabled: !_locked,
        keyboardType: number ? TextInputType.number : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: help,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => _set(key, v.trim()),
      ),
    );
  }

  Widget _switch(
    String key,
    String label,
    bool def, {
    String on = 'true',
    String off = 'false',
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: _p(key, def ? on : off) == on,
      onChanged: (v) => _set(key, v ? on : off),
    );
  }

  List<Widget> _fields(BuildContext context) {
    switch (type) {
      case 'clock':
        return [
          _switch('format24', tr('24 horas'), true),
          _switch('showSeconds', tr('Mostrar os segundos'), false),
          _switch('showDate', tr('Mostrar a data'), true),
        ];
      case 'weather':
        return [
          _field('city', tr('Cidade'), hint: 'São Paulo'),
          _switch('units', tr('Em Fahrenheit'), false, on: 'f', off: 'c'),
        ];
      case 'command':
        return [
          _field(
            'command',
            tr('Comando'),
            hint: 'powershell -c "(Get-Date).DayOfYear"',
            help: tr('Roda no cmd do PC; o botão mostra a saída (até 10 s).'),
            maxLines: 2,
          ),
          _field(
            'format',
            tr('Modelo'),
            hint: '{value}',
            help: tr('{value} é a saída. Ex.: "Dia {value}"'),
          ),
          _field(
            'interval',
            tr('Atualizar a cada (segundos)'),
            hint: '60',
            number: true,
          ),
        ];
      case 'url':
        return [
          _field('url', tr('URL'), hint: 'https://api.exemplo.com/status'),
          _field(
            'path',
            tr('Campo do JSON'),
            hint: 'data.items[0].name',
            help: tr('Vazio = a resposta inteira.'),
          ),
          _field(
            'format',
            tr('Modelo'),
            hint: '{value}',
            help: tr('{value} é o valor lido.'),
          ),
          _field(
            'interval',
            tr('Atualizar a cada (segundos)'),
            hint: '60',
            number: true,
          ),
        ];
      case 'mixer_slider':
        return [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              tr(
                'Ajusta o volume do dispositivo selecionado no PC atual. Este controle não executa comandos.',
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          MixerSliderSettings(
            parameters: params,
            onChanged: (next) => onChanged(type, next),
          ),
        ];
      default:
        return const [];
    }
  }
}

class MixerSliderSettings extends StatefulWidget {
  final Map<String, String> parameters;
  final ValueChanged<Map<String, String>> onChanged;

  const MixerSliderSettings({
    super.key,
    required this.parameters,
    required this.onChanged,
  });

  @override
  State<MixerSliderSettings> createState() => _MixerSliderSettingsState();
}

class _MixerSliderSettingsState extends State<MixerSliderSettings> {
  late String _deviceKind = widget.parameters['deviceKind'] == 'input'
      ? 'input'
      : 'output';
  late String? _deviceId = widget.parameters['deviceId'];
  List<MixerEntity> _outputs = const [];
  List<MixerEntity> _inputs = const [];
  bool _loading = false;
  bool _loadFailed = false;

  List<MixerEntity> get _devices => _deviceKind == 'input' ? _inputs : _outputs;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final client = Injector.get<DroidDeckClient>();
      final outputs = await client.getOutputs();
      final inputs = await client.getInputs();
      if (!mounted) return;
      setState(() {
        _outputs = outputs;
        _inputs = inputs;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _publish({String? kind, String? id, bool clearId = false}) {
    final next = Map<String, String>.of(widget.parameters);
    final resolvedKind = kind ?? _deviceKind;
    next['deviceKind'] = resolvedKind;
    if (clearId || id == null || id.isEmpty) {
      next.remove('deviceId');
    } else {
      next['deviceId'] = id;
    }
    widget.onChanged(next);
  }

  String _label(MixerEntity entity) {
    final name = entity.device.title?.trim();
    return name == null || name.isEmpty ? entity.id ?? tr('Dispositivo') : name;
  }

  @override
  Widget build(BuildContext context) {
    final availableIds = _devices.map((d) => d.id).whereType<String>().toSet();
    final currentId = _deviceId;
    return Column(
      children: [
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _deviceKind,
          decoration: InputDecoration(
            labelText: tr('Tipo'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'output',
              child: Text(tr('Saída (alto-falante/fone)')),
            ),
            DropdownMenuItem(
              value: 'input',
              child: Text(tr('Entrada (microfone)')),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == _deviceKind) return;
            setState(() {
              _deviceKind = value;
              _deviceId = null;
            });
            _publish(kind: value, clearId: true);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: currentId != null && availableIds.contains(currentId)
              ? currentId
              : null,
          decoration: InputDecoration(
            labelText: tr('Dispositivo'),
            hintText: tr('Selecione um dispositivo de áudio'),
            border: const OutlineInputBorder(),
          ),
          items: [
            if (currentId != null && !availableIds.contains(currentId))
              DropdownMenuItem(
                value: currentId,
                child: Text(tr('Dispositivo indisponível')),
              ),
            for (final device in _devices)
              if (device.id != null)
                DropdownMenuItem(
                  value: device.id!,
                  child: Text(_label(device), overflow: TextOverflow.ellipsis),
                ),
          ],
          onChanged: (value) {
            setState(() => _deviceId = value);
            _publish(id: value, clearId: value == null);
          },
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_loadFailed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr('Não foi possível listar os dispositivos de áudio.'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loading ? null : _loadDevices,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(tr('Atualizar lista')),
          ),
        ),
      ],
    );
  }
}
