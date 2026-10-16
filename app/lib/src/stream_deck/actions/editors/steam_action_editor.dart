import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

/// Jogo da Steam: lista os jogos instalados no PC e, ao escolher um, usa o nome como
/// rótulo e a capa como ícone do botão.
class SteamActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const SteamActionEditor({super.key, required this.args});

  @override
  State<SteamActionEditor> createState() => _SteamActionEditorState();
}

class _SteamActionEditorState extends State<SteamActionEditor> {
  String? _appId;
  List<(String id, String name)> _games = [];
  bool _loading = true;
  String? _error;
  String _filter = '';

  DroidDeckClient get _client => Injector.get<DroidDeckClient>();

  @override
  void initState() {
    super.initState();
    _appId = widget.args.initial['appId'];
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() =>
      widget.args.onChanged({if (_appId != null) 'appId': _appId!});

  Future<void> _load() async {
    try {
      final data = await _client.getJson('/api/steam/games');
      final list = (data is List ? data : const [])
          .whereType<Map>()
          .map((m) => ('${m['value']}', '${m['label']}'))
          .toList();
      if (mounted) {
        setState(() {
          _games = list;
          _error = list.isEmpty ? tr('Nenhum jogo da Steam encontrado neste PC.') : null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = tr('Não foi possível listar os jogos.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick((String, String) game) async {
    setState(() => _appId = game.$1);
    _emit();
    widget.args.suggestLabel(game.$2);
    try {
      final data = await _client.getJson('/api/steam/icon/${game.$1}');
      final icon = (data as Map?)?['iconBase64'] as String?;
      if (icon != null && mounted) widget.args.suggestIcon(icon);
    } catch (_) {
      // Jogo sem capa no cache da Steam: fica o ícone escolhido no painel.
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final selected = _games.where((g) => g.$1 == _appId).firstOrNull;
    final visible = _games
        .where((g) => g.$2.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_appId != null)
          Card(
            color: Colors.green.withValues(alpha: 0.12),
            child: ListTile(
              leading: const Icon(Icons.sports_esports, color: Colors.green),
              title: Text(selected?.$2 ?? tr('Jogo {id}', {'id': _appId}),
                  overflow: TextOverflow.ellipsis),
              subtitle: Text(tr('Jogo selecionado')),
            ),
          ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_error != null)
          Text(_error!, style: TextStyle(color: muted))
        else ...[
          if (_games.length > 8)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: tr('Buscar jogo'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final g = visible[i];
                final isSelected = g.$1 == _appId;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  title: Text(g.$2, overflow: TextOverflow.ellipsis),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.add_circle_outline),
                  onTap: () => _pick(g),
                );
              },
            ),
          ),
        ],
        EditorHint(
            tr('Ao escolher, o botão ganha o nome e a capa do jogo. Tocar abre o jogo pela Steam no PC.')),
      ],
    );
  }
}
