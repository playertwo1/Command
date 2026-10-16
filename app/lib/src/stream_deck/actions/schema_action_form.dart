import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:companion/src/stream_deck/actions/action_schema.dart';
import 'package:companion/src/config/integrations_page.dart';
import 'package:flutter/material.dart';

/// Formulário montado a partir do [ActionSchema]. Avisa o painel a cada mudança com
/// os parâmetros dos campos visíveis (os escondidos não vão para o botão).
class SchemaActionForm extends StatefulWidget {
  final ActionSchema schema;
  final Map<String, String> initial;
  final ValueChanged<Map<String, String>> onChanged;

  const SchemaActionForm({
    super.key,
    required this.schema,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<SchemaActionForm> createState() => _SchemaActionFormState();
}

class _SchemaActionFormState extends State<SchemaActionForm> {
  late final Map<String, String> _values;

  /// Opções carregadas por URL já resolvida (com os {placeholders} trocados).
  final Map<String, List<FieldOption>> _options = {};
  final Map<String, String> _errors = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _values = {...widget.schema.defaults(), ...widget.initial};
    // O painel precisa dos valores padrão mesmo que o usuário não toque em nada.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    final out = <String, String>{};
    for (final f in widget.schema.fields) {
      if (!f.isVisible(_values)) continue;
      final v = _values[f.key];
      if (v != null && v.isNotEmpty) out[f.key] = v;
    }
    widget.onChanged(out);
  }

  void _set(String key, String value) {
    setState(() => _values[key] = value);
    _emit();
  }

  /// Troca {chave} pelo valor atual; null se alguma dependência ainda está vazia.
  String? _resolve(String source) {
    var missing = false;
    final url = source.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final v = _values[m.group(1)!] ?? '';
      if (v.isEmpty) missing = true;
      return Uri.encodeQueryComponent(v);
    });
    return missing ? null : url;
  }

  Future<void> _fetch(String url, {bool force = false}) async {
    if (_loading.contains(url) || (!force && _options.containsKey(url))) return;
    setState(() {
      _loading.add(url);
      _errors.remove(url);
    });
    try {
      final data = await Injector.get<DroidDeckClient>().getJson(url);
      final list = (data is List ? data : const [])
          .map(FieldOption.fromJson)
          .where((o) => o.value.isNotEmpty)
          .toList();
      if (mounted) setState(() => _options[url] = list);
    } catch (e) {
      if (mounted) {
        setState(() {
          _options[url] = const [];
          _errors[url] = _errorText(e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading.remove(url));
    }
  }

  String _errorText(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) return data['error'] as String;
    }
    return tr('Não foi possível carregar a lista.');
  }

  @override
  Widget build(BuildContext context) {
    final schema = widget.schema;
    final muted = TextStyle(
        fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant);

    final children = <Widget>[
      if (schema.settings != null && schema.stateEvent != null)
        IntegrationWarning(schema: schema),
      if (schema.description != null) ...[
        Text(schema.description!, style: muted.copyWith(fontSize: 12)),
        const SizedBox(height: 12),
      ],
    ];

    for (final f in schema.fields) {
      if (!f.isVisible(_values)) continue;
      children
        ..add(_field(f))
        ..add(const SizedBox(height: 12));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _field(ActionField f) {
    switch (f.kind) {
      case 'select':
        return f.optionsSource != null ? _dynamicSelect(f) : _select(f, f.options);
      case 'toggle':
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.help != null ? Text(f.help!) : null,
          value: _values[f.key] == 'true',
          onChanged: (v) => _set(f.key, v ? 'true' : 'false'),
        );
      case 'number':
        return _number(f);
      case 'multiline':
        return _text(f, maxLines: 5);
      default:
        return _text(f);
    }
  }

  InputDecoration _decoration(ActionField f, {String? helper, Widget? suffix}) =>
      InputDecoration(
        labelText: f.label,
        hintText: f.hint,
        helperText: helper ?? f.help,
        helperMaxLines: 3,
        suffixText: f.unit,
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      );

  Widget _text(ActionField f, {int maxLines = 1}) => TextFormField(
        key: ValueKey('f_${f.key}'),
        initialValue: _values[f.key] ?? '',
        minLines: maxLines > 1 ? 3 : 1,
        maxLines: maxLines,
        decoration: _decoration(f),
        onChanged: (v) => _set(f.key, v),
      );

  Widget _number(ActionField f) {
    final current = double.tryParse(_values[f.key] ?? '') ?? f.min ?? 0;
    final min = f.min, max = f.max;
    // Faixa curta e limitada: slider. O resto (segundos, ms...) é digitado.
    if (min != null && max != null && max - min <= 200) {
      final v = current.clamp(min, max).toDouble();
      final unit = f.unit ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${f.label}: ${_fmt(v)}$unit'),
          Slider(
            value: v,
            min: min,
            max: max,
            divisions: (max - min).round().clamp(1, 200),
            label: '${_fmt(v)}$unit',
            onChanged: (n) => _set(f.key, _fmt(n)),
          ),
          if (f.help != null)
            Text(f.help!,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
    }
    return TextFormField(
      key: ValueKey('f_${f.key}'),
      initialValue: _values[f.key] ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _decoration(f),
      onChanged: (v) => _set(f.key, v.replaceAll(',', '.')),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  Widget _select(ActionField f, List<FieldOption> options,
      {String? helper, Widget? suffix}) {
    final value = _values[f.key];
    final known = options.any((o) => o.value == value);
    return DropdownButtonFormField<String>(
      key: ValueKey('f_${f.key}_${options.length}'),
      value: (value != null && value.isNotEmpty) ? value : null,
      isExpanded: true,
      decoration: _decoration(f, helper: helper, suffix: suffix),
      items: [
        ...options.map((o) => DropdownMenuItem(
            value: o.value,
            child: Text(o.label, overflow: TextOverflow.ellipsis))),
        // Valor salvo que a lista não traz (fonte apagada, OBS fechado): continua
        // selecionável, senão salvar de novo apagaria a configuração sem aviso.
        if (value != null && value.isNotEmpty && !known)
          DropdownMenuItem(
              value: value,
              child: Text(tr('{value} (salvo)', {'value': value}), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        if (v == null) return;
        _set(f.key, v);
        // Campos que dependem deste (ex.: filtros de uma fonte) recarregam sozinhos
        // no próximo build, pela URL nova.
      },
    );
  }

  Widget _dynamicSelect(ActionField f) {
    final url = _resolve(f.optionsSource!);
    if (url == null) {
      return InputDecorator(
        decoration: _decoration(f, helper: tr('Escolha o campo acima primeiro.')),
        child: const SizedBox(height: 20),
      );
    }
    if (!_options.containsKey(url)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(url));
    }

    final options = _options[url] ?? const [];
    final loading = _loading.contains(url);
    final error = _errors[url];
    final refresh = loading
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        : IconButton(
            tooltip: tr('Recarregar a lista'),
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetch(url, force: true),
          );

    // Sem lista (erro ou vazia) e o campo aceita texto livre: deixa digitar.
    if (options.isEmpty && !loading && (f.allowCustom || error != null)) {
      return TextFormField(
        key: ValueKey('f_${f.key}_text'),
        initialValue: _values[f.key] ?? '',
        decoration: _decoration(f,
            helper: error != null ? tr('{error} Digite o nome.', {'error': error}) : f.help,
            suffix: refresh),
        onChanged: (v) => _set(f.key, v),
      );
    }

    return _select(f, options,
        helper: options.isEmpty && !loading ? tr('Lista vazia.') : f.help,
        suffix: refresh);
  }
}

/// Aviso de integração desconectada, com atalho para a tela de configuração.
class IntegrationWarning extends StatelessWidget {
  final ActionSchema schema;

  const IntegrationWarning({super.key, required this.schema});

  static Widget? settingsPage(String? key) => IntegrationsPage.pageFor(key);

  @override
  Widget build(BuildContext context) {
    final signalR = Injector.get<SignalRService>();
    return Watch((context) {
      // Lê o signal certo para o Watch se inscrever nele.
      signalR.obsState.value;
      signalR.discordState.value;
      signalR.tuyaState.value;
      signalR.actionStates.value;
      final state = signalR.stateOf(schema.stateEvent!);
      if (state['connected'] == true) return const SizedBox.shrink();

      final page = settingsPage(schema.settings);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr('{name} não está conectado — esta ação não funciona até conectar.',
                    {'name': schema.title}),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (page != null)
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => page)),
                child: Text(tr('Configurar')),
              ),
          ],
        ),
      );
    });
  }
}
