import 'dart:convert';
import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/action_catalog.dart';
import 'package:companion/src/stream_deck/actions/action_picker.dart';
import 'package:companion/src/stream_deck/actions/action_schema.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'button_icons.dart';

/// Editor de um botão: rótulo, ações (toque, toque longo, toque duplo), ícone e cores.
/// A escolha de cada ação fica no [ActionPicker].
class ButtonPropertyPanel extends StatefulWidget {
  final DeckButton button;
  final Function(DeckButton) onSave;
  final VoidCallback? onCancel;
  final List<DeckProfile> profiles;

  const ButtonPropertyPanel({
    super.key,
    required this.button,
    required this.onSave,
    this.onCancel,
    this.profiles = const [],
  });

  @override
  State<ButtonPropertyPanel> createState() => _ButtonPropertyPanelState();
}

class _ButtonPropertyPanelState extends State<ButtonPropertyPanel> {
  late TextEditingController _labelController;
  /// Ação de cada gesto. Null = nenhuma.
  DeckAction? _tap;
  DeckAction? _longPress;
  DeckAction? _doubleTap;

  Color _selectedColor = Colors.grey[800]!;
  Color _activeColor = Colors.red[900]!;

  final _catalog = ActionCatalog.instance;

  String get _selectedActionType => _tap?.type ?? 'none';

  ActionSchema? get _schema => _catalog.find(_selectedActionType);

  /// Ações que refletem um estado ligado/desligado (e portanto têm "cor de ativo").
  bool get _isStatefulAction => _schema?.stateful ?? false;

  /// No navegador o painel roda no configurador (localhost); fora dele, no celular.
  bool get _remote => !kIsWeb;

  final List<Color> _colors = [
    Colors.grey[800]!,
    Colors.red[900]!,
    Colors.blue[900]!,
    Colors.green[900]!,
    Colors.orange[900]!,
    Colors.purple[900]!,
    Colors.black,
  ];

  String? _selectedIcon;
  String? _iconBase64;
  String? _dynamicType;

  final List<String> _icons = buttonIcons.keys.toList();

  // Dois estados.
  bool _toggle = false;
  DeckAction? _activeAction;
  late TextEditingController _activeLabelController;
  String? _activeIcon;
  String? _activeIconBase64;

  /// Parâmetros do botão de informação (cidade, comando, URL...).
  Map<String, String> _dynamicParams = {};

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.button.label);
    _selectedIcon = widget.button.iconName;

    _tap = widget.button.action?.type == 'none' ? null : widget.button.action;
    _longPress = widget.button.longPressAction;
    _doubleTap = widget.button.doubleTapAction;

    if (widget.button.backgroundColor != null &&
        widget.button.backgroundColor!.isNotEmpty) {
      _selectedColor =
          _parseColor(widget.button.backgroundColor!) ?? Colors.grey[800]!;
    }
    if (widget.button.activeColor != null &&
        widget.button.activeColor!.isNotEmpty) {
      _activeColor = _parseColor(widget.button.activeColor!) ?? Colors.red[900]!;
    }
    _iconBase64 = widget.button.iconBase64;
    _dynamicType = widget.button.dynamicType;
    _dynamicParams = Map.of(widget.button.dynamicParameters ?? const {});
    _toggle = widget.button.toggle;
    _activeAction = widget.button.activeAction;
    _activeLabelController =
        TextEditingController(text: widget.button.activeLabel);
    _activeIcon = widget.button.activeIconName;
    _activeIconBase64 = widget.button.activeIconBase64;

    _catalog.load();
  }

  Future<void> _pickImage({bool active = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      final base64 = base64Encode(bytes);
      setState(() {
        if (active) {
          _activeIconBase64 = base64;
          _activeIcon = null;
        } else {
          _iconBase64 = base64;
          _selectedIcon = null; // Clear standard icon
        }
      });
    }
  }

  Color? _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _activeLabelController.dispose();
    super.dispose();
  }

  void _save() {
    final isDynamic = _dynamicType != null && _dynamicType!.isNotEmpty;
    final showsActive = _isStatefulAction || _toggle;

    final newButton = DeckButton(
      id: widget.button.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.button.id,
      row: widget.button.row,
      column: widget.button.column,
      label: _labelController.text,
      backgroundColor: _colorToHex(_selectedColor),
      activeColor: showsActive ? _colorToHex(_activeColor) : null,
      iconName: _selectedIcon,
      iconBase64: _iconBase64,
      dynamicType: _dynamicType,
      action: _tap,
      longPressAction: _longPress,
      doubleTapAction: _doubleTap,
      dynamicParameters: isDynamic && _dynamicParams.isNotEmpty
          ? Map.of(_dynamicParams)
          : null,
      toggle: _toggle,
      activeAction: _toggle ? _activeAction : null,
      activeLabel: showsActive && _activeLabelController.text.trim().isNotEmpty
          ? _activeLabelController.text.trim()
          : null,
      activeIconName: showsActive ? _activeIcon : null,
      activeIconBase64: showsActive ? _activeIconBase64 : null,
    );

    widget.onSave(newButton);
  }

  void _suggestLabel(String label) {
    // Rótulo padrão de botão novo (em qualquer idioma) também é substituído.
    final current = _labelController.text.trim();
    if (current.isEmpty ||
        current == tr('Novo botão') ||
        current == 'Novo botão' ||
        current == 'New Button') {
      _labelController.text = label;
    }
  }

  void _suggestIcon(String base64) {
    setState(() {
      _iconBase64 = base64;
      _selectedIcon = null;
    });
  }

  ActionPicker _picker(String label, DeckAction? initial,
          ValueChanged<DeckAction?> onChanged,
          {Key? key}) =>
      ActionPicker(
        key: key,
        label: label,
        initial: initial,
        onChanged: onChanged,
        remote: _remote,
        profiles: widget.profiles,
        suggestLabel: _suggestLabel,
        suggestIcon: _suggestIcon,
      );

  /// Toque longo e toque duplo, recolhidos quando não usados.
  Widget _buildGestures() {
    final used = _longPress != null || _doubleTap != null;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: used,
        shape: const Border(),
        leading: const Icon(Icons.touch_app_outlined),
        title: Text(tr('Toque longo e toque duplo')),
        subtitle: Text(
          used
              ? [
                  if (_longPress != null)
                    tr('Longo: {action}', {
                      'action': _catalog.find(_longPress!.type)?.title ?? _longPress!.type
                    }),
                  if (_doubleTap != null)
                    tr('Duplo: {action}', {
                      'action': _catalog.find(_doubleTap!.type)?.title ?? _doubleTap!.type
                    }),
                ].join(' · ')
              : tr('Opcional'),
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Text(
            _remote
                ? tr('Com um toque longo definido, segure o botão para executá-lo. Para '
                    'editar o botão depois, use o lápis (modo de edição) na barra do deck.')
                : tr('Com um toque longo definido, segurar o botão no celular executa a '
                    'ação; o celular edita pelo modo de edição (lápis na barra do deck).'),
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _picker(tr('Toque longo'), _longPress,
              (a) => setState(() => _longPress = a)),
          const SizedBox(height: 20),
          _picker(tr('Toque duplo'), _doubleTap,
              (a) => setState(() => _doubleTap = a)),
        ],
      ),
    );
  }

  void _delete() {
    final clearedButton = DeckButton(
      id: '',
      row: widget.button.row,
      column: widget.button.column,
      label: '',
      backgroundColor: '',
      action: null,
      iconName: null,
      iconBase64: null,
    );
    widget.onSave(clearedButton);
  }

  @override
  Widget build(BuildContext context) {
    // Watch: o catálogo do PC chega depois do primeiro build e pode mudar os campos.
    return Watch((context) => _buildPanel(context));
  }

  Widget _buildPanel(BuildContext context) {
    _catalog.schemas.value;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.button.id.isEmpty ? tr('Novo botão') : tr('Editar botão'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                // Label
                TextField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    labelText: tr('Rótulo'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                _picker(tr('Ação'), _tap, (a) => setState(() => _tap = a)),
                const SizedBox(height: 16),
                _buildGestures(),
                const SizedBox(height: 12),
                _buildTwoState(),
                const SizedBox(height: 12),
                _buildInfo(),

                const SizedBox(height: 32),

                // Icon Picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr('Ícone'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: Text(tr('Imagem própria')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_iconBase64 != null) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).colorScheme.primary),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black12,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(_iconBase64!),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _iconBase64 = null),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent),
                          child: Text(tr('Remover imagem')),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildIconOption(null), // Clear icon
                    ..._icons.map((icon) => _buildIconOption(icon)),
                  ],
                ),

                const SizedBox(height: 24),

                // Color Config
                Text(tr('Cor de fundo'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _colorRow(_selectedColor, (c) => _selectedColor = c),

                // Cor de "ativo": ações que refletem estado e botões de dois estados.
                if (_isStatefulAction || _toggle) ...[
                  const SizedBox(height: 20),
                  Text(
                    switch (_selectedActionType) {
                      'discord' => tr('Cor quando ativo (mutado/ensurdecido)'),
                      'timer' => tr('Cor quando a contagem termina'),
                      'windows' => tr('Cor quando o dispositivo é o padrão'),
                      _ => tr('Cor quando ativo'),
                    },
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _colorRow(_activeColor, (c) => _activeColor = c),
                  const SizedBox(height: 12),
                  _buildTogglePreview(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.button.id.isNotEmpty)
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(tr('Limpar botão')),
                ),
              const Spacer(),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(tr('Cancelar')),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                child: Text(tr('Salvar')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorRow(Color selected, void Function(Color) pick) {
    return Wrap(
      spacing: 8,
      children: _colors
          .map((c) => InkWell(
                onTap: () => setState(() => pick(c)),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selected == c
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: const [
                        BoxShadow(blurRadius: 2, color: Colors.black26)
                      ]),
                ),
              ))
          .toList(),
    );
  }

  /// Mostra lado a lado como o botão fica desligado x ativo (com a cor escolhida).
  Widget _buildTogglePreview() {
    final icons = _previewIcons();
    // Mesmo DeckTile do deck: a prévia acompanha o estilo do tema atual.
    Widget chip(String label, bool active, IconData icon) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: DeckTile(
              color: _selectedColor,
              active: active,
              activeColor: _activeColor,
              child: Icon(icon, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: DeckTheme.of(context).background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          chip(tr('Desligado'), false, icons.$1),
          Icon(Icons.arrow_forward,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          chip(tr('Ativo'), true, icons.$2),
        ],
      ),
    );
  }

  /// (ícone desligado, ícone ativo) conforme a ação — espelha o runtime.
  (IconData, IconData) _previewIcons() {
    if (_selectedActionType == 'discord') {
      return _tap?.parameters['operation'] == 'toggleDeafen'
          ? (Icons.headset_mic, Icons.headset_off)
          : (Icons.mic, Icons.mic_off);
    }
    if (_selectedActionType == 'obs') {
      return (Icons.fiber_manual_record_outlined, Icons.fiber_manual_record);
    }
    if (_selectedActionType == 'tuya') {
      return (Icons.lightbulb_outline, Icons.lightbulb);
    }
    if (_selectedActionType == 'timer') {
      return (Icons.hourglass_bottom, Icons.alarm);
    }
    if (_selectedActionType == 'windows') {
      return (Icons.headphones, Icons.headphones);
    }
    return (Icons.volume_up, Icons.volume_off);
  }

  Widget _buildIconOption(String? iconName, {bool active = false}) {
    final isSelected = (active ? _activeIcon : _selectedIcon) == iconName;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        setState(() {
          if (active) {
            _activeIcon = iconName;
            if (iconName != null) _activeIconBase64 = null;
            return;
          }
          _selectedIcon = iconName;
          if (iconName != null) {
            _iconBase64 = null; // Clear custom image if icon selected
          }
        });
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: scheme.primary)
              : Border.all(color: scheme.outlineVariant),
        ),
        child: iconName == null
            ? Icon(Icons.block, color: scheme.onSurfaceVariant)
            : Icon(_getIconData(iconName), color: scheme.onSurface),
      ),
    );
  }

  // ---- Dois estados ----

  Widget _buildTwoState() {
    final used = _toggle ||
        _activeLabelController.text.isNotEmpty ||
        _activeIcon != null ||
        _activeIconBase64 != null;
    final scheme = Theme.of(context).colorScheme;
    final hint = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: used,
        shape: const Border(),
        leading: const Icon(Icons.toggle_on_outlined),
        title: Text(tr('Dois estados')),
        subtitle: Text(
          _toggle
              ? tr('Liga e desliga a cada toque')
              : (_isStatefulAction ? tr('Visual quando ativo') : tr('Opcional')),
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Alternar a cada toque')),
            subtitle: Text(
              _isStatefulAction
                  ? tr('Esta ação já mostra o próprio estado; ligue só se quiser um '
                      'liga/desliga separado, guardado no PC.')
                  : tr('O botão fica ligado num toque e desligado no seguinte. O estado '
                      'fica no PC e aparece igual em todos os celulares.'),
              style: hint,
            ),
            value: _toggle,
            onChanged: (v) => setState(() => _toggle = v),
          ),
          if (_toggle) ...[
            const SizedBox(height: 8),
            _picker(tr('Ação quando ligado'), _activeAction,
                (a) => setState(() => _activeAction = a)),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('Roda no toque que desliga o botão. Sem ela, o mesmo toque roda sempre.'),
                style: hint,
              ),
            ),
          ],
          if (_toggle || _isStatefulAction) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _activeLabelController,
              decoration: InputDecoration(
                labelText: tr('Rótulo quando ativo'),
                hintText: tr('Vazio = o mesmo rótulo'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('Ícone quando ativo'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _pickImage(active: true),
                  icon: const Icon(Icons.upload_file),
                  label: Text(tr('Imagem')),
                ),
              ],
            ),
            if (_activeIconBase64 != null)
              Row(children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.memory(base64Decode(_activeIconBase64!),
                      errorBuilder: (_, __, ___) => const Icon(Icons.error)),
                ),
                TextButton(
                  onPressed: () => setState(() => _activeIconBase64 = null),
                  child: Text(tr('Remover imagem')),
                ),
              ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildIconOption(null, active: true),
                ..._icons.map((i) => _buildIconOption(i, active: true)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- Mostrar no botão (monitores e informação) ----

  static const _infoLabels = {
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
  static const _privilegedInfo = {'command', 'url'};

  bool get _infoLocked =>
      _remote && _privilegedInfo.contains(widget.button.dynamicType);

  String _p(String key, [String fallback = '']) =>
      _dynamicParams[key] ?? fallback;

  void _setP(String key, String value) => setState(() {
        if (value.isEmpty) {
          _dynamicParams.remove(key);
        } else {
          _dynamicParams[key] = value;
        }
      });

  Widget _infoField(String key, String label,
      {String? hint, String? help, bool number = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        key: ValueKey('info_${_dynamicType}_$key'),
        initialValue: _p(key),
        enabled: !_infoLocked,
        keyboardType: number ? TextInputType.number : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: help,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => _setP(key, v.trim()),
      ),
    );
  }

  Widget _infoSwitch(String key, String label, bool def,
      {String on = 'true', String off = 'false'}) {
    final value = _p(key, def ? on : off) == on;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: (v) => _setP(key, v ? on : off),
    );
  }

  Widget _buildInfo() {
    final type = _dynamicType;
    final hint = TextStyle(
        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final options = _infoLabels.entries
        .where((e) =>
            !_remote || !_privilegedInfo.contains(e.key) || e.key == type)
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: type != null && type.isNotEmpty,
        shape: const Border(),
        leading: const Icon(Icons.insights_outlined),
        title: Text(tr('Mostrar no botão')),
        subtitle: Text(
          (type?.isNotEmpty ?? false)
              ? (_infoLabels[type] != null ? tr(_infoLabels[type]!) : type!)
              : tr('Opcional'),
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: (type?.isEmpty ?? true) ? null : type,
            decoration: InputDecoration(
              labelText: tr('Informação'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(tr('Nenhuma'))),
              ...options.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(tr(e.value)))),
            ],
            onChanged: _infoLocked
                ? null
                : (val) => setState(() {
                      if (val != _dynamicType) _dynamicParams = {};
                      _dynamicType = val;
                    }),
          ),
          if (_infoLocked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr('Botões que rodam um comando ou leem uma URL no PC só mudam no '
                    'configurador do PC (http://localhost:4787).'),
                style: hint,
              ),
            ),
          ..._infoFields(type),
          if (type != null && type.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                tr('O toque continua executando a ação do botão, se houver uma.'),
                style: hint,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _infoFields(String? type) {
    switch (type) {
      case 'clock':
        return [
          _infoSwitch('format24', tr('24 horas'), true),
          _infoSwitch('showSeconds', tr('Mostrar os segundos'), false),
          _infoSwitch('showDate', tr('Mostrar a data'), true),
        ];
      case 'weather':
        return [
          _infoField('city', tr('Cidade'), hint: 'São Paulo'),
          _infoSwitch('units', tr('Em Fahrenheit'), false, on: 'f', off: 'c'),
        ];
      case 'command':
        return [
          _infoField('command', tr('Comando'),
              hint: 'powershell -c "(Get-Date).DayOfYear"',
              help: tr('Roda no cmd do PC; o botão mostra a saída (até 10 s).'),
              maxLines: 2),
          _infoField('format', tr('Modelo'),
              hint: '{value}', help: tr('{value} é a saída. Ex.: "Dia {value}"')),
          _infoField('interval', tr('Atualizar a cada (segundos)'),
              hint: '60', number: true),
        ];
      case 'url':
        return [
          _infoField('url', tr('URL'), hint: 'https://api.exemplo.com/status'),
          _infoField('path', tr('Campo do JSON'),
              hint: 'data.items[0].name', help: tr('Vazio = a resposta inteira.')),
          _infoField('format', tr('Modelo'),
              hint: '{value}', help: tr('{value} é o valor lido.')),
          _infoField('interval', tr('Atualizar a cada (segundos)'),
              hint: '60', number: true),
        ];
      default:
        return const [];
    }
  }


  IconData _getIconData(String name) => buttonIconData(name);
}
