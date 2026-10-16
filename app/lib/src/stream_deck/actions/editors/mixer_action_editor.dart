import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

/// Volume/mudo de um aplicativo (por processo) ou de um dispositivo do Windows.
class MixerActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const MixerActionEditor({super.key, required this.args});

  @override
  State<MixerActionEditor> createState() => _MixerActionEditorState();
}

class _MixerActionEditorState extends State<MixerActionEditor> {
  /// Operações que existem para os dois alvos. Volume só faz sentido no dispositivo:
  /// o IAudioControlService do backend só expõe mudo por processo.
  static const _muteOps = ['toggleMute', 'mute', 'unmute'];

  String _operation = 'toggleMute';
  // Alvo do botão — 'app' (sessão de um processo) ou 'device' (dispositivo do Windows)
  String _target = 'app';
  // 'default' = dispositivo padrão do Windows. É o valor recomendado: o id do endpoint muda
  // quando o usuário troca de fone/monitor e o botão passaria a apontar pra nada.
  String _deviceId = 'default';
  String _deviceKind = 'output'; // output | input
  int _volume = 50; // usado com setVolume
  int _step = 5; // passo do volumeUp/volumeDown
  String _processName = '';
  List<MixerEntity> _outputs = [];
  List<MixerEntity> _inputs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final p = widget.args.initial;
    _processName = p['processName'] ?? '';
    _operation = p['operation'] ?? 'toggleMute';
    _target = (p['deviceId'] ?? '').isNotEmpty ? 'device' : 'app';
    _deviceId = (p['deviceId'] ?? '').isNotEmpty ? p['deviceId']! : 'default';
    _deviceKind = p['deviceKind'] ?? 'output';
    _volume = int.tryParse(p['volume'] ?? '') ?? 50;
    _step = int.tryParse(p['step'] ?? '') ?? 5;
    if (_target == 'device') _loadDevices();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    final params = <String, String>{'operation': _operation};
    if (_target == 'device') {
      params['deviceId'] = _deviceId;
      params['deviceKind'] = _deviceKind;
      if (_operation == 'setVolume') {
        params['volume'] = '$_volume';
      } else if (_operation == 'volumeUp' || _operation == 'volumeDown') {
        params['step'] = '$_step';
      }
    } else {
      params['processName'] = _processName.trim();
    }
    widget.args.onChanged(params);
  }

  void _update(VoidCallback change) {
    setState(change);
    _emit();
  }

  List<MixerEntity> get _devices => _deviceKind == 'input' ? _inputs : _outputs;

  Future<void> _loadDevices() async {
    if (_loading) return;
    setState(() => _loading = true);
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
      // Sem a lista o botão ainda funciona apontando pro dispositivo padrão.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _deviceLabel(MixerEntity e) => e.device.title?.trim().isNotEmpty == true
      ? e.device.title!.trim()
      : (e.id ?? tr('Dispositivo'));

  @override
  Widget build(BuildContext context) {
    final isDevice = _target == 'device';
    final devices = _devices;
    final knownIds = {'default', ...devices.map((d) => d.id ?? '')};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _target,
          decoration: InputDecoration(
            labelText: tr('Alvo'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'app', child: Text(tr('Aplicativo (processo)'))),
            DropdownMenuItem(
                value: 'device', child: Text(tr('Dispositivo do Windows'))),
          ],
          onChanged: (val) {
            _update(() {
              _target = val ?? 'app';
              if (_target == 'app' && !_muteOps.contains(_operation)) {
                _operation = 'toggleMute';
              }
            });
            if (_target == 'device') _loadDevices();
          },
        ),
        const SizedBox(height: 16),
        if (isDevice) ...[
          DropdownButtonFormField<String>(
            value: _deviceKind,
            decoration: InputDecoration(
              labelText: tr('Tipo'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                  value: 'output', child: Text(tr('Saída (alto-falante/fone)'))),
              DropdownMenuItem(
                  value: 'input', child: Text(tr('Entrada (microfone)'))),
            ],
            onChanged: (val) => _update(() {
              _deviceKind = val ?? 'output';
              // O id salvo pertence à outra lista; volta pro padrão.
              _deviceId = 'default';
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: knownIds.contains(_deviceId) ? _deviceId : null,
            decoration: InputDecoration(
              labelText: tr('Dispositivo'),
              border: const OutlineInputBorder(),
              helperText: _deviceId == 'default'
                  ? tr('Acompanha a troca de fone/monitor')
                  : tr('Id fixo: se você trocar de dispositivo, o botão para de valer'),
            ),
            // Um id salvo que não está na lista (dispositivo desconectado) continua
            // selecionável, senão salvar de novo trocaria a configuração sem avisar.
            items: [
              DropdownMenuItem(
                  value: 'default', child: Text(tr('Padrão do Windows'))),
              ...devices.map((d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(_deviceLabel(d), overflow: TextOverflow.ellipsis),
                  )),
              if (!knownIds.contains(_deviceId))
                DropdownMenuItem(
                  value: _deviceId,
                  child: Text(tr('Dispositivo salvo (desconectado)')),
                ),
            ],
            onChanged: (val) => _update(() => _deviceId = val ?? 'default'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 16),
        ],
        DropdownButtonFormField<String>(
          value: _operation,
          decoration: InputDecoration(
            labelText: tr('Operação'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
                value: 'toggleMute', child: Text(tr('Alternar mudo'))),
            DropdownMenuItem(value: 'mute', child: Text(tr('Mutar'))),
            DropdownMenuItem(value: 'unmute', child: Text(tr('Desmutar'))),
            if (isDevice) ...[
              const DropdownMenuItem(value: 'volumeUp', child: Text('Volume +')),
              const DropdownMenuItem(
                  value: 'volumeDown', child: Text('Volume −')),
              DropdownMenuItem(
                  value: 'setVolume', child: Text(tr('Definir volume'))),
            ],
          ],
          onChanged: (val) => _update(() => _operation = val ?? 'toggleMute'),
        ),
        if (isDevice && _operation == 'setVolume') ...[
          const SizedBox(height: 16),
          Text(tr('Volume: {value}%', {'value': _volume})),
          Slider(
            value: _volume.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$_volume%',
            onChanged: (v) => _update(() => _volume = v.round()),
          ),
        ],
        if (isDevice &&
            (_operation == 'volumeUp' || _operation == 'volumeDown')) ...[
          const SizedBox(height: 16),
          Text(tr('Passo: {n} pontos', {'n': _step})),
          Slider(
            value: _step.toDouble(),
            min: 1,
            max: 25,
            divisions: 24,
            label: '$_step',
            onChanged: (v) => _update(() => _step = v.round()),
          ),
        ],
        if (!isDevice) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _processName,
            decoration: InputDecoration(
              labelText: tr('Nome do app (processo)'),
              hintText: 'Spotify, Discord, chrome…',
              helperText: tr('Sem .exe — o nome do processo no Windows'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              _processName = v;
              _emit();
            },
          ),
        ],
      ],
    );
  }
}
