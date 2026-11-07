import 'dart:convert';

import 'package:command/core/core.dart';
import 'package:command/src/stream_deck/buttons/colors.dart';
import 'package:command/src/stream_deck/widgets/editor/look_pickers.dart';
import 'package:flutter/material.dart';

/// Nome do perfil e os apps que o trazem para a frente quando ganham o foco no PC.
class ProfileSettingsDialog extends StatefulWidget {
  final DeckProfile profile;
  final ValueChanged<DeckProfile> onSave;

  const ProfileSettingsDialog({
    super.key,
    required this.profile,
    required this.onSave,
  });

  static Future<void> show(BuildContext context, DeckProfile profile,
          ValueChanged<DeckProfile> onSave) =>
      showDialog(
        context: context,
        builder: (_) => ProfileSettingsDialog(profile: profile, onSave: onSave),
      );

  @override
  State<ProfileSettingsDialog> createState() => _ProfileSettingsDialogState();
}

class _ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
  late final _name = TextEditingController(text: widget.profile.name);
  final _app = TextEditingController();
  late final List<String> _apps = [...?widget.profile.autoSwitchApps];
  late bool _customGrid = widget.profile.useCustomGrid;
  late double _columns = widget.profile.columns.clamp(2, 8).toDouble();
  late double _rows = widget.profile.rows.clamp(2, 6).toDouble();
  late double _gap = widget.profile.gap.clamp(4, 24).toDouble();
  late double _margin = widget.profile.margin.clamp(0, 32).toDouble();
  late Color _bg = parseHexColor(widget.profile.backgroundColor) ?? const Color(0xFF13101B);
  late Color _bgEnd = parseHexColor(widget.profile.backgroundColorEnd) ?? _bg;
  late bool _gradient = widget.profile.backgroundColorEnd?.isNotEmpty == true;
  late String? _image = widget.profile.backgroundImageBase64;
  late bool _clearImage = false;

  /// Apps com janela aberta no PC agora: (processo, "processo — título").
  List<(String, String)> _running = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRunning();
  }

  @override
  void dispose() {
    _name.dispose();
    _app.dispose();
    super.dispose();
  }

  Future<void> _loadRunning() async {
    try {
      final data = await Injector.get<CommandClient>().getJson('/api/system/apps');
      final list = (data is List ? data : const [])
          .whereType<Map>()
          .map((m) => ('${m['value']}', '${m['label'] ?? m['value']}'))
          .toList();
      if (mounted) setState(() => _running = list);
    } catch (_) {
      // PC antigo ou fora do ar: dá para digitar o nome do processo.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _add(String raw) {
    var app = raw.trim();
    if (app.toLowerCase().endsWith('.exe')) app = app.substring(0, app.length - 4);
    if (app.isEmpty ||
        _apps.any((a) => a.toLowerCase() == app.toLowerCase())) {
      return;
    }
    setState(() {
      _apps.add(app);
      _app.clear();
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.onSave(widget.profile.copyWith(
      name: name,
      autoSwitchApps: _apps,
      useCustomGrid: _customGrid,
      columns: _customGrid ? _columns.round() : null,
      rows: _customGrid ? _rows.round() : null,
      gap: _gap.round(),
      margin: _margin.round(),
      backgroundColor: colorToHex(_bg),
      backgroundColorEnd: _gradient ? colorToHex(_bgEnd) : '',
      backgroundImageBase64: _image,
      clearBackgroundImage: _clearImage && _image == null,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final suggestions = _running
        .where((r) => !_apps.any((a) => a.toLowerCase() == r.$1.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text(tr('Perfil')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: tr('Nome'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Grade fixa')),
                subtitle: Text(
                  tr('2 a 8 colunas e 2 a 6 linhas. Desligado, a grade continua acompanhando a tela.'),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                value: _customGrid,
                onChanged: (value) => setState(() => _customGrid = value),
              ),
              if (_customGrid) ...[
                Text(tr('Colunas: ${_columns.round()}')),
                Slider(
                  min: 2,
                  max: 8,
                  divisions: 6,
                  value: _columns,
                  label: '${_columns.round()}',
                  onChanged: (value) => setState(() => _columns = value),
                ),
                Text(tr('Linhas: ${_rows.round()}')),
                Slider(
                  min: 2,
                  max: 6,
                  divisions: 4,
                  value: _rows,
                  label: '${_rows.round()}',
                  onChanged: (value) => setState(() => _rows = value),
                ),
              ],
              Text(tr('Espaço entre botões: ${_gap.round()}')),
              Slider(
                min: 4,
                max: 24,
                divisions: 20,
                value: _gap,
                onChanged: (value) => setState(() => _gap = value),
              ),
              Text(tr('Margem da tela: ${_margin.round()}')),
              Slider(
                min: 0,
                max: 32,
                divisions: 16,
                value: _margin,
                onChanged: (value) => setState(() => _margin = value),
              ),
              const SizedBox(height: 8),
              Text(tr('Fundo do perfil'), style: const TextStyle(fontWeight: FontWeight.bold)),
              HexColorField(color: _bg, onChanged: (color) => setState(() => _bg = color)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Gradiente')),
                value: _gradient,
                onChanged: (value) => setState(() => _gradient = value),
              ),
              if (_gradient)
                HexColorField(color: _bgEnd, onChanged: (color) => setState(() => _bgEnd = color)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final image = await pickButtonImage();
                      if (image == null) return;
                      setState(() {
                        _image = image;
                        _clearImage = false;
                      });
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(tr('Imagem de fundo')),
                  ),
                  if (_image != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _image = null;
                        _clearImage = true;
                      }),
                      child: Text(tr('Remover imagem')),
                    ),
                ],
              ),
              if (_image != null)
                SizedBox(
                  height: 48,
                  child: Image.memory(
                    base64Decode(_image!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
                  ),
                ),
              const SizedBox(height: 12),
              Text(tr('Abrir com o app em foco'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                tr('Quando um destes programas estiver em primeiro plano no PC, o deck '
                    'vai para este perfil sozinho. Ao sair dele, volta para onde estava.'),
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final app in _apps)
                    InputChip(
                      label: Text(app),
                      onDeleted: () => setState(() => _apps.remove(app)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _app,
                      decoration: InputDecoration(
                        labelText: tr('Nome do processo'),
                        hintText: 'obs64, Code, chrome…',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: _add,
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Adicionar'),
                    icon: const Icon(Icons.add),
                    onPressed: () => _add(_app.text),
                  ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tr('Abertos no PC agora:'), style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in suggestions)
                      Tooltip(
                        message: r.$2,
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(r.$1),
                          onPressed: () => _add(r.$1),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancelar')),
        ),
        FilledButton(onPressed: _save, child: Text(tr('Salvar'))),
      ],
    );
  }
}
