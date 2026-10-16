import 'package:companion/core/core.dart';
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
    'network_monitor': 'Rede',
    'clock': 'Relógio',
    'weather': 'Clima',
    'now_playing': 'Tocando agora',
    'command': 'Saída de um comando (PC)',
    'url': 'Valor de uma URL (PC)',
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
    final hint = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
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
          hasType ? (labels[type] != null ? tr(labels[type]!) : type!) : tr('Opcional'),
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
              ...options.map((e) => DropdownMenuItem(value: e.key, child: Text(tr(e.value)))),
            ],
            // Trocar o tipo zera os parâmetros do anterior.
            onChanged: _locked ? null : (v) => onChanged(v, v == type ? params : {}),
          ),
          if (_locked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr('Botões que rodam um comando ou leem uma URL no PC só mudam no '
                    'configurador do PC (http://localhost:4787).'),
                style: hint,
              ),
            ),
          ..._fields(),
          if (hasType)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(tr('O toque continua executando a ação do botão, se houver uma.'),
                  style: hint),
            ),
        ],
      ),
    );
  }

  Widget _field(String key, String label,
      {String? hint, String? help, bool number = false, int maxLines = 1}) {
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

  Widget _switch(String key, String label, bool def, {String on = 'true', String off = 'false'}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: _p(key, def ? on : off) == on,
      onChanged: (v) => _set(key, v ? on : off),
    );
  }

  List<Widget> _fields() {
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
          _field('command', tr('Comando'),
              hint: 'powershell -c "(Get-Date).DayOfYear"',
              help: tr('Roda no cmd do PC; o botão mostra a saída (até 10 s).'),
              maxLines: 2),
          _field('format', tr('Modelo'),
              hint: '{value}', help: tr('{value} é a saída. Ex.: "Dia {value}"')),
          _field('interval', tr('Atualizar a cada (segundos)'), hint: '60', number: true),
        ];
      case 'url':
        return [
          _field('url', tr('URL'), hint: 'https://api.exemplo.com/status'),
          _field('path', tr('Campo do JSON'),
              hint: 'data.items[0].name', help: tr('Vazio = a resposta inteira.')),
          _field('format', tr('Modelo'), hint: '{value}', help: tr('{value} é o valor lido.')),
          _field('interval', tr('Atualizar a cada (segundos)'), hint: '60', number: true),
        ];
      default:
        return const [];
    }
  }
}
