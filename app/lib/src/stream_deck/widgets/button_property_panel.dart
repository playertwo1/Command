import 'dart:convert';

import 'package:command/core/core.dart';
import 'package:command/src/stream_deck/actions/action_catalog.dart';
import 'package:command/src/stream_deck/actions/action_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../buttons/colors.dart';
import 'editor/info_section.dart';
import 'editor/look_pickers.dart';
import 'editor/two_state_section.dart';

/// Editor de um botão: rótulo, ações (toque, toque longo, toque duplo), dois estados,
/// informação no botão, ícone e cores. A escolha de cada ação fica no [ActionPicker];
/// as seções maiores ficam em `editor/`.
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

  static Key stateKeyFor(DeckButton button) =>
      ValueKey((button.id, button.row, button.column));

  @override
  State<ButtonPropertyPanel> createState() => ButtonPropertyPanelState();
}

class ButtonPropertyPanelState extends State<ButtonPropertyPanel> {
  final _catalog = ActionCatalog.instance;
  late final _labelController = TextEditingController(text: widget.button.label);
  late final String _newId = DateTime.now().millisecondsSinceEpoch.toString();
  String? _initialJson;

  /// Há mudanças no formulário que ainda não foram salvas?
  bool get isDirty =>
      _initialJson != null && jsonEncode(_compose().toJson()) != _initialJson;

  /// Ação de cada gesto. Null = nenhuma.
  late DeckAction? _tap = widget.button.action?.type == 'none' ? null : widget.button.action;
  late DeckAction? _longPress = widget.button.longPressAction;
  late DeckAction? _doubleTap = widget.button.doubleTapAction;

  late Color _color = parseHexColor(widget.button.backgroundColor) ?? ColorRow.palette.first;
  late Color _activeColor = parseHexColor(widget.button.activeColor) ?? Colors.red[900]!;
  late String? _icon = widget.button.iconName;
  late String? _iconBase64 = widget.button.iconBase64;

  late String? _infoType = widget.button.dynamicType;
  late Map<String, String> _infoParams = Map.of(widget.button.dynamicParameters ?? const {});
  late TwoStateValue _twoState = TwoStateValue.of(widget.button);
  late int _columnSpan = widget.button.columnSpan;
  late int _rowSpan = widget.button.rowSpan;
  late int? _fontSize = widget.button.labelFontSize;
  late String _align = widget.button.labelAlign ?? 'center';
  late String _valign = widget.button.labelVAlign ?? 'center';
  late bool _hideLabel = widget.button.hideLabel;
  late int _radius = widget.button.cornerRadius ?? -1;
  late double _border = (widget.button.borderWidth ?? 0).toDouble();
  late Color _borderColor = parseHexColor(widget.button.borderColor) ?? const Color(0xFFA78BFA);
  late String _haptic = widget.button.haptic ?? '';

  /// Ações que refletem um estado ligado/desligado (e portanto têm "cor de ativo").
  bool get _isStatefulAction => _catalog.find(_tap?.type)?.stateful ?? false;

  bool get _isMixerSlider => _infoType == 'mixer_slider';

  bool get _showsActive => !_isMixerSlider && (_isStatefulAction || _twoState.toggle);

  /// No navegador o painel roda no configurador (localhost); fora dele, no celular.
  bool get _remote => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _initialJson = jsonEncode(_compose().toJson());
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  DeckButton _compose() {
    final hasInfo = _infoType != null && _infoType!.isNotEmpty;
    final activeLabel = _twoState.activeLabel.trim();
    return DeckButton(
      id: widget.button.id.isEmpty ? _newId : widget.button.id,
      row: widget.button.row,
      column: widget.button.column,
      label: _labelController.text,
      backgroundColor: colorToHex(_color),
      activeColor: _showsActive ? colorToHex(_activeColor) : null,
      iconName: _icon,
      iconBase64: _iconBase64,
      dynamicType: _infoType,
      dynamicParameters: hasInfo && _infoParams.isNotEmpty ? Map.of(_infoParams) : null,
      action: _isMixerSlider ? null : _tap,
      longPressAction: _isMixerSlider ? null : _longPress,
      doubleTapAction: _isMixerSlider ? null : _doubleTap,
      toggle: !_isMixerSlider && _twoState.toggle,
      activeAction: !_isMixerSlider && _twoState.toggle ? _twoState.activeAction : null,
      activeLabel: _showsActive && activeLabel.isNotEmpty ? activeLabel : null,
      activeIconName: _showsActive ? _twoState.activeIcon : null,
      activeIconBase64: _showsActive ? _twoState.activeIconBase64 : null,
      columnSpan: _columnSpan,
      rowSpan: _rowSpan,
      labelFontSize: _fontSize,
      labelAlign: _align,
      labelVAlign: _valign,
      hideLabel: _hideLabel,
      cornerRadius: _radius < 0 ? null : _radius,
      borderWidth: _border.round() == 0 ? null : _border.round(),
      borderColor: _border.round() == 0 ? null : colorToHex(_borderColor),
      haptic: _haptic.isEmpty ? null : _haptic,
    );
  }

  void _save() {
    final button = _compose();
    setState(() => _initialJson = jsonEncode(button.toJson()));
    widget.onSave(button);
  }

  void _delete() {
    widget.onSave(DeckButton(
      id: '',
      row: widget.button.row,
      column: widget.button.column,
      label: '',
      backgroundColor: '',
    ));
  }

  /// Preenche o rótulo com a sugestão da ação, se ele estiver vazio ou no padrão.
  void _suggestLabel(String label) {
    final current = _labelController.text.trim();
    if (current.isEmpty ||
        current == tr('Novo botão') ||
        current == 'Novo botão' ||
        current == 'New Button') {
      _labelController.text = label;
    }
  }

  void _suggestIcon(String base64) => setState(() {
        _iconBase64 = base64;
        _icon = null;
      });

  Future<void> _pickImage() async {
    final image = await pickButtonImage();
    if (image != null) _suggestIcon(image);
  }

  ActionPicker _picker(String label, DeckAction? initial, ValueChanged<DeckAction?> onChanged) =>
      ActionPicker(
        label: label,
        initial: initial,
        onChanged: onChanged,
        remote: _remote,
        profiles: widget.profiles,
        suggestLabel: _suggestLabel,
        suggestIcon: _suggestIcon,
      );

  @override
  Widget build(BuildContext context) {
    // Watch: o catálogo do PC chega depois do primeiro build e pode mudar os campos.
    return Watch((context) {
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
                  TextField(
                    controller: _labelController,
                    decoration: InputDecoration(
                      labelText: tr('Rótulo'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: '${_columnSpan}x${_rowSpan}',
                    decoration: InputDecoration(
                      labelText: tr('Tamanho na grade'),
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '1x1', child: Text('1 × 1')),
                      DropdownMenuItem(value: '2x1', child: Text('2 × 1')),
                      DropdownMenuItem(value: '1x2', child: Text('1 × 2')),
                      DropdownMenuItem(value: '2x2', child: Text('2 × 2')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      final span = value.split('x');
                      setState(() {
                        _columnSpan = int.parse(span[0]);
                        _rowSpan = int.parse(span[1]);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_isMixerSlider) ...[
                    _picker(tr('Ação'), _tap, (a) => setState(() => _tap = a)),
                    const SizedBox(height: 16),
                    _buildGestures(),
                    const SizedBox(height: 12),
                    TwoStateSection(
                      value: _twoState,
                      statefulAction: _isStatefulAction,
                      actionPicker: _picker,
                      onChanged: (v) => setState(() => _twoState = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  InfoSection(
                    type: _infoType,
                    params: _infoParams,
                    savedType: widget.button.dynamicType,
                    remote: _remote,
                    onChanged: (type, params) => setState(() {
                      _infoType = type;
                      _infoParams = params;
                      if (type == 'mixer_slider' && _columnSpan == 1 && _rowSpan == 1) {
                        _columnSpan = 2;
                      }
                    }),
                  ),
                  const SizedBox(height: 32),
                  ..._buildLook(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildActionBar(),
        ],
      );
    });
  }

  /// Toque longo e toque duplo, recolhidos quando não usados.
  Widget _buildGestures() {
    final used = _longPress != null || _doubleTap != null;
    String title(DeckAction a) => _catalog.find(a.type)?.title ?? a.type;
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
                  if (_longPress != null) tr('Longo: {action}', {'action': title(_longPress!)}),
                  if (_doubleTap != null) tr('Duplo: {action}', {'action': title(_doubleTap!)}),
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
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _picker(tr('Toque longo'), _longPress, (a) => setState(() => _longPress = a)),
          const SizedBox(height: 20),
          _picker(tr('Toque duplo'), _doubleTap, (a) => setState(() => _doubleTap = a)),
        ],
      ),
    );
  }

  /// Ícone e cores.
  List<Widget> _buildLook() {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tr('Ícone'), style: bold),
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.upload_file),
            label: Text(tr('Imagem própria')),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_iconBase64 != null) ...[
        ImagePreview(base64: _iconBase64!, onRemove: () => setState(() => _iconBase64 = null)),
        const SizedBox(height: 8),
      ],
      IconGrid(
        selected: _icon,
        onSelect: (name) => setState(() {
          _icon = name;
          if (name != null) _iconBase64 = null;
        }),
      ),
      const SizedBox(height: 24),
      Text(tr('Cor de fundo'), style: bold),
      const SizedBox(height: 8),
      ColorRow(selected: _color, onSelect: (c) => setState(() => _color = c)),
      const SizedBox(height: 8),
      HexColorField(color: _color, onChanged: (c) => setState(() => _color = c)),
      const SizedBox(height: 16),
      Text(tr('Rótulo'), style: bold),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(tr('Ocultar rótulo')),
        value: _hideLabel,
        onChanged: (value) => setState(() => _hideLabel = value),
      ),
      if (!_hideLabel) ...[
        Text(tr('Tamanho: ${_fontSize ?? tr('automático')}')),
        Slider(
          min: 8,
          max: 18,
          divisions: 10,
          value: (_fontSize ?? 12).toDouble(),
          label: '${_fontSize ?? 12}',
          onChanged: (value) => setState(() => _fontSize = value.round()),
        ),
        TextButton(
          onPressed: () => setState(() => _fontSize = null),
          child: Text(tr('Tamanho automático')),
        ),
        DropdownButtonFormField<String>(
          initialValue: _align,
          decoration: InputDecoration(labelText: tr('Alinhamento horizontal'), border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: 'left', child: Text(tr('Esquerda'))),
            DropdownMenuItem(value: 'center', child: Text(tr('Centro'))),
            DropdownMenuItem(value: 'right', child: Text(tr('Direita'))),
          ],
          onChanged: (value) => setState(() => _align = value ?? 'center'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _valign,
          decoration: InputDecoration(labelText: tr('Alinhamento vertical'), border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: 'top', child: Text(tr('Topo'))),
            DropdownMenuItem(value: 'center', child: Text(tr('Centro'))),
            DropdownMenuItem(value: 'bottom', child: Text(tr('Base'))),
          ],
          onChanged: (value) => setState(() => _valign = value ?? 'center'),
        ),
      ],
      const SizedBox(height: 16),
      Text(tr('Cantos e borda'), style: bold),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(label: Text(tr('Tema')), selected: _radius < 0, onSelected: (_) => setState(() => _radius = -1)),
          ChoiceChip(label: Text(tr('Quadrado')), selected: _radius == 0, onSelected: (_) => setState(() => _radius = 0)),
          ChoiceChip(label: Text(tr('Arredondado')), selected: _radius == 16, onSelected: (_) => setState(() => _radius = 16)),
          ChoiceChip(label: Text(tr('Pílula')), selected: _radius == 40, onSelected: (_) => setState(() => _radius = 40)),
        ],
      ),
      Text(tr('Espessura da borda: ${_border.round()}')),
      Slider(
        min: 0,
        max: 6,
        divisions: 6,
        value: _border,
        onChanged: (value) => setState(() => _border = value),
      ),
      if (_border > 0) HexColorField(color: _borderColor, onChanged: (c) => setState(() => _borderColor = c)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _haptic,
        decoration: InputDecoration(labelText: tr('Vibração ao tocar'), border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: '', child: Text(tr('Padrão do app'))),
          DropdownMenuItem(value: 'off', child: Text(tr('Desligada'))),
          DropdownMenuItem(value: 'light', child: Text(tr('Leve'))),
          DropdownMenuItem(value: 'medium', child: Text(tr('Média'))),
          DropdownMenuItem(value: 'heavy', child: Text(tr('Forte'))),
        ],
        onChanged: (value) => setState(() => _haptic = value ?? ''),
      ),
      // Cor de "ativo": ações que refletem estado e botões de dois estados.
      if (_showsActive) ...[
        const SizedBox(height: 20),
        Text(
          switch (_tap?.type) {
            'discord' => tr('Cor quando ativo (mutado/ensurdecido)'),
            'timer' => tr('Cor quando a contagem termina'),
            'windows' => tr('Cor quando o dispositivo é o padrão'),
            _ => tr('Cor quando ativo'),
          },
          style: bold,
        ),
        const SizedBox(height: 8),
        ColorRow(selected: _activeColor, onSelect: (c) => setState(() => _activeColor = c)),
        const SizedBox(height: 8),
        HexColorField(color: _activeColor, onChanged: (c) => setState(() => _activeColor = c)),
        const SizedBox(height: 12),
        ActivePreview(
          color: _color,
          activeColor: _activeColor,
          icons: ActivePreview.iconsFor(_tap),
        ),
      ],
    ];
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          if (widget.button.id.isNotEmpty)
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(tr('Limpar botão')),
            ),
          const Spacer(),
          if (widget.onCancel != null)
            TextButton(onPressed: widget.onCancel, child: Text(tr('Cancelar'))),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _save, child: Text(tr('Salvar'))),
        ],
      ),
    );
  }
}
