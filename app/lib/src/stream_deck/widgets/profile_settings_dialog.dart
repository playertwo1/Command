import 'package:droiddeck/core/core.dart';
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
      final data = await Injector.get<DroidDeckClient>().getJson('/api/system/apps');
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
    widget.onSave(widget.profile.copyWith(name: name, autoSwitchApps: _apps));
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
