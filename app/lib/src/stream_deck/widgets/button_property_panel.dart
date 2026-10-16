import 'dart:convert';
import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/action_catalog.dart';
import 'package:companion/src/stream_deck/actions/action_schema.dart';
import 'package:companion/src/stream_deck/actions/editors/action_editor.dart';
import 'package:companion/src/stream_deck/actions/schema_action_form.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Editor de um botão: rótulo, ação, ícone e cores.
///
/// Os campos de cada tipo de ação vêm do catálogo do PC (GET /api/actions/schema):
/// tipos simples viram um formulário gerado ([SchemaActionForm]); os que precisam de
/// tela própria (Discord, Tuya, soundboard...) ficam em actions/editors/.
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
  String _selectedActionType = 'none';

  /// Parâmetros da ação, mantidos pelo formulário/tela própria do tipo atual.
  Map<String, String> _params = {};

  Color _selectedColor = Colors.grey[800]!;
  Color _activeColor = Colors.red[900]!;

  final _catalog = ActionCatalog.instance;

  ActionSchema? get _schema => _catalog.find(_selectedActionType);

  /// Ações que refletem um estado ligado/desligado (e portanto têm "cor de ativo").
  bool get _isStatefulAction => _schema?.stateful ?? false;

  // Abrir app, atalho e ativar janela executam código no PC. O backend só aceita
  // criá-los ou alterá-los pelo configurador em localhost (ActionPolicy): no celular o
  // painel não oferece esses tipos e trava a ação dos botões que já os têm — label,
  // ícone e cores continuam editáveis, e o botão continua funcionando.
  static const _privilegedTypes = {
    'hotkey',
    'launch_app',
    'launchApp',
    'activatewindow',
  };

  bool _isPrivilegedType(String type) =>
      _privilegedTypes.contains(type) || (_catalog.find(type)?.privileged ?? false);

  bool _isPrivileged(DeckAction? action) {
    if (action == null) return false;
    if (_isPrivilegedType(action.type)) return true;
    if (action.type != 'multi') return false;
    try {
      final steps = jsonDecode(action.parameters['steps'] ?? '[]') as List;
      return steps.any((s) => _isPrivilegedType('${(s as Map)['type']}'));
    } catch (_) {
      return true;
    }
  }

  /// No navegador o painel roda no configurador (localhost); fora dele, no celular.
  bool get _remote => !kIsWeb;
  late final bool _lockedAction =
      _remote && _isPrivileged(widget.button.action);

  List<ActionSchema> get _availableSchemas => _catalog.schemas.value
      .where((s) => !_remote || _lockedAction || !s.privileged)
      .toList();

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

    final action = widget.button.action;
    if (action != null) {
      _selectedActionType = action.type == 'launchApp' ? 'launch_app' : action.type;
      _params = Map<String, String>.from(action.parameters);
    }

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
    // Monitor (dynamicType) e ação são exclusivos: botão-monitor não guarda ação.
    final isDynamic = _dynamicType != null && _dynamicType!.isNotEmpty;
    final newAction = (isDynamic || _selectedActionType == 'none')
        ? null
        : _lockedAction
            ? widget.button.action
            : DeckAction(type: _selectedActionType, parameters: Map.of(_params));

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
      action: newAction,
    );

    widget.onSave(newButton);
  }

  /// Aviso no lugar dos campos de uma ação que só pode mudar no PC.
  Widget _buildLockedActionNotice() {
    final a = widget.button.action!;
    final String summary;
    switch (a.type) {
      case 'hotkey':
        summary = 'Atalho: ${a.parameters['keys'] ?? ''}';
      case 'launch_app':
      case 'launchApp':
        summary = 'Abre: ${a.parameters['path'] ?? ''}';
      case 'multi':
        summary = 'Multi-ação';
      default:
        summary = _catalog.find(a.type)?.title ?? a.type;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Ações que abrem programas, enviam atalhos ou fazem requisições '
                  'só podem ser alteradas no configurador do PC (http://localhost:4787). '
                  'Aqui você pode mudar o nome, o ícone e as cores.',
                ),
              ],
            ),
          ),
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

  void _selectType(String type) {
    setState(() {
      if (type != _selectedActionType) _params = {};
      _selectedActionType = type;
      // Ação e monitor (dynamicType) são exclusivos.
      if (type != 'none') _dynamicType = null;
    });
  }

  /// Seletor de tipo agrupado por categoria.
  Widget _buildTypePicker() {
    return Builder(builder: (context) {
      final schemas = _availableSchemas;
      final categories = <String, List<ActionSchema>>{};
      for (final s in schemas) {
        categories.putIfAbsent(s.category, () => []).add(s);
      }
      final known = schemas.any((s) => s.type == _selectedActionType);
      final muted = Theme.of(context).colorScheme.onSurfaceVariant;

      final items = <DropdownMenuItem<String>>[
        const DropdownMenuItem(value: 'none', child: Text('Nenhuma')),
        for (final entry in categories.entries) ...[
          DropdownMenuItem<String>(
            enabled: false,
            value: '__${entry.key}',
            child: Text(entry.key.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: muted)),
          ),
          for (final s in entry.value)
            DropdownMenuItem(
              value: s.type,
              child: Row(
                children: [
                  Icon(s.iconData, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(s.title, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
        // Tipo que este PC não anuncia (botão de uma versão mais nova/antiga).
        if (!known && _selectedActionType != 'none')
          DropdownMenuItem(
              value: _selectedActionType,
              child: Text('$_selectedActionType (desconhecido)')),
      ];

      return DropdownButtonFormField<String>(
        value: _selectedActionType,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Ação',
          border: OutlineInputBorder(),
        ),
        items: items,
        onChanged: _lockedAction
            ? null
            : (val) {
                if (val != null && !val.startsWith('__')) _selectType(val);
              },
      );
    });
  }

  /// Campos do tipo escolhido: tela própria ou formulário gerado pelo schema.
  Widget _buildActionEditor() {
    final schema = _schema;
    if (_lockedAction || schema == null) return const SizedBox.shrink();

    // A chave pelo tipo recria o editor (e o estado dele) ao trocar de tipo.
    final key = ValueKey('editor_${schema.type}');
    final args = ActionEditorArgs(
      initial: _params,
      onChanged: (p) => setState(() => _params = p),
      suggestLabel: (label) {
        if (_labelController.text.trim().isEmpty) _labelController.text = label;
      },
      remote: _remote,
      profiles: widget.profiles,
    );

    final custom =
        schema.editor != null ? buildCustomActionEditor(schema.editor!, args) : null;
    if (custom != null) return KeyedSubtree(key: key, child: custom);

    if (schema.fields.isEmpty) {
      return schema.description != null
          ? EditorHint(schema.description!)
          : const SizedBox.shrink();
    }
    return SchemaActionForm(
      key: key,
      schema: schema,
      initial: _params,
      onChanged: (p) => setState(() => _params = p),
    );
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

                if (_lockedAction) ...[
                  _buildLockedActionNotice(),
                  const SizedBox(height: 16),
                ],

                _buildTypePicker(),
                const SizedBox(height: 16),
                _buildActionEditor(),

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
                      if (val != null && val.isNotEmpty) {
                        _selectedActionType = 'none';
                        _params = {};
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
      return _params['operation'] == 'toggleDeafen'
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
