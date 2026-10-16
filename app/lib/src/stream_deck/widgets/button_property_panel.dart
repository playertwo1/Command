import 'dart:convert';
import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/action_catalog.dart';
import 'package:companion/src/stream_deck/actions/action_picker.dart';
import 'package:companion/src/stream_deck/actions/action_schema.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  /// Trocar a chave recria o seletor do toque (ex.: ao virar monitor, que zera a ação).
  int _tapEpoch = 0;

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

  // TODO: Centralize icon list
  final List<String> _icons = [
    'play',
    'pause',
    'volume_up',
    'volume_off',
    'mic',
    'mic_off',
    'keyboard',
    'launch',
    'home',
    'settings',
    'code',
    'videocam',
    'call_end',
    'folder',
    'save',
    'delete'
  ];

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

    _catalog.load();
  }

  Future<void> _pickImage() async {
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
        _iconBase64 = base64;
        _selectedIcon = null; // Clear standard icon
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
    super.dispose();
  }

  void _save() {
    // Monitor (dynamicType) e ação do toque são exclusivos: botão-monitor não guarda ação.
    final isDynamic = _dynamicType != null && _dynamicType!.isNotEmpty;

    final newButton = DeckButton(
      id: widget.button.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.button.id,
      row: widget.button.row,
      column: widget.button.column,
      label: _labelController.text,
      backgroundColor: _colorToHex(_selectedColor),
      activeColor: _isStatefulAction ? _colorToHex(_activeColor) : null,
      iconName: _selectedIcon,
      iconBase64: _iconBase64,
      dynamicType: _dynamicType,
      action: isDynamic ? null : _tap,
      longPressAction: _longPress,
      doubleTapAction: _doubleTap,
    );

    widget.onSave(newButton);
  }

  void _suggestLabel(String label) {
    if (_labelController.text.trim().isEmpty ||
        _labelController.text == 'New Button') {
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
        title: const Text('Toque longo e toque duplo'),
        subtitle: Text(
          used
              ? [
                  if (_longPress != null)
                    'Longo: ${_catalog.find(_longPress!.type)?.title ?? _longPress!.type}',
                  if (_doubleTap != null)
                    'Duplo: ${_catalog.find(_doubleTap!.type)?.title ?? _doubleTap!.type}',
                ].join(' · ')
              : 'Opcional',
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Text(
            _remote
                ? 'Com um toque longo definido, segure o botão para executá-lo. Para '
                    'editar o botão depois, use o lápis (modo de edição) na barra do deck.'
                : 'Com um toque longo definido, segurar o botão no celular executa a '
                    'ação; o celular edita pelo modo de edição (lápis na barra do deck).',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _picker('Toque longo', _longPress,
              (a) => setState(() => _longPress = a)),
          const SizedBox(height: 20),
          _picker('Toque duplo', _doubleTap,
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
                  widget.button.id.isEmpty ? 'New Button' : 'Edit Button',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                // Label
                TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                _picker('Ação', _tap, (a) {
                  setState(() {
                    _tap = a;
                    // Ação e monitor (dynamicType) são exclusivos.
                    if (a != null) _dynamicType = null;
                  });
                }, key: ValueKey('tap$_tapEpoch')),
                const SizedBox(height: 16),
                _buildGestures(),

                const SizedBox(height: 32),

                // Icon Picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Icon',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Custom Image'),
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
                          child: const Text("Remove Image"),
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
                const Text('Background Color',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _colorRow(_selectedColor, (c) => _selectedColor = c),

                // Cor de "ativo" (toggle): só para ações que refletem estado.
                if (_isStatefulAction) ...[
                  const SizedBox(height: 20),
                  Text(
                    switch (_selectedActionType) {
                      'discord' => 'Cor quando ativo (mutado/ensurdecido)',
                      'timer' => 'Cor quando a contagem termina',
                      'windows' => 'Cor quando o dispositivo é o padrão',
                      _ => 'Cor quando ativo',
                    },
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _colorRow(_activeColor, (c) => _activeColor = c),
                  const SizedBox(height: 12),
                  _buildTogglePreview(),
                ],

                // Dynamic Type
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _dynamicType,
                  decoration: const InputDecoration(
                    labelText: 'Dynamic Feature',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(
                        value: 'cpu_monitor', child: Text('CPU Monitor')),
                    DropdownMenuItem(
                        value: 'memory_monitor', child: Text('Memory Monitor')),
                    DropdownMenuItem(
                        value: 'gpu_monitor', child: Text('GPU Monitor')),
                    DropdownMenuItem(
                        value: 'network_monitor',
                        child: Text('Network Monitor')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _dynamicType = val;
                      // Monitor é só display: zera a ação (eram exclusivos).
                      if (val != null && val.isNotEmpty && _tap != null) {
                        _tap = null;
                        _tapEpoch++;
                      }
                    });
                  },
                ),

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
                  child: const Text('Clear Button'),
                ),
              const Spacer(),
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save Changes'),
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
          chip('Desligado', false, icons.$1),
          Icon(Icons.arrow_forward,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          chip('Ativo', true, icons.$2),
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

  Widget _buildIconOption(String? iconName) {
    final isSelected = _selectedIcon == iconName;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        setState(() {
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

  IconData _getIconData(String name) {
    switch (name.toLowerCase()) {
      case 'play':
        return Icons.play_arrow;
      case 'pause':
        return Icons.pause;
      case 'volume_up':
        return Icons.volume_up;
      case 'volume_off':
        return Icons.volume_off;
      case 'mic':
        return Icons.mic;
      case 'mic_off':
        return Icons.mic_off;
      case 'keyboard':
        return Icons.keyboard;
      case 'launch':
        return Icons.rocket_launch;
      case 'home':
        return Icons.home;
      case 'settings':
        return Icons.settings;
      case 'code':
        return Icons.code;
      case 'videocam':
        return Icons.videocam;
      case 'call_end':
        return Icons.call_end;
      case 'folder':
        return Icons.folder;
      case 'save':
        return Icons.save;
      case 'delete':
        return Icons.delete;
      default:
        return Icons.extension;
    }
  }
}
