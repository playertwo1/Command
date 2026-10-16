import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

/// Soundboard: busca no MyInstants (toca no PC) ou som nativo do Discord.
class SoundboardActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const SoundboardActionEditor({super.key, required this.args});

  @override
  State<SoundboardActionEditor> createState() => _SoundboardActionEditorState();
}

class _SoundboardActionEditorState extends State<SoundboardActionEditor> {
  String _operation = 'play'; // play | stop
  String _source = 'myinstants'; // myinstants | discord
  String? _id;
  String? _url;
  String? _title;
  final _searchController = TextEditingController();
  List<SoundResult> _results = [];
  bool _searching = false;
  // Soundboard nativa do Discord
  String? _dcSoundId;
  String? _dcGuildId;
  List<Map<String, String>> _dcSounds = [];
  bool _dcLoading = false;

  DroidDeckClient get _client => Injector.get<DroidDeckClient>();

  @override
  void initState() {
    super.initState();
    final p = widget.args.initial;
    _operation = p['operation'] ?? 'play';
    _source = p['source'] ?? 'myinstants';
    _id = p['id'];
    _url = p['url'];
    _title = p['title'];
    _dcSoundId = p['soundId'];
    _dcGuildId = p['guildId'];
    if (_source == 'discord') _loadDiscordSounds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _emit() {
    final params = <String, String>{'operation': _operation};
    if (_operation == 'play') {
      params['source'] = _source;
      if (_source == 'discord') {
        if (_dcSoundId != null) params['soundId'] = _dcSoundId!;
        if (_dcGuildId != null && _dcGuildId!.isNotEmpty) {
          params['guildId'] = _dcGuildId!;
        }
      } else {
        if (_id != null) params['id'] = _id!;
        if (_url != null) params['url'] = _url!;
      }
      if (_title != null) params['title'] = _title!;
    }
    widget.args.onChanged(params);
  }

  void _update(VoidCallback change) {
    setState(change);
    _emit();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await _client.searchSounds(q);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadDiscordSounds() async {
    setState(() => _dcLoading = true);
    try {
      final sounds = await _client.getDiscordSoundboardSounds();
      if (mounted) setState(() => _dcSounds = sounds);
    } finally {
      if (mounted) setState(() => _dcLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      DropdownButtonFormField<String>(
        value: _operation,
        isExpanded: true,
        decoration:
            const InputDecoration(labelText: 'Ação', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'play', child: Text('Tocar um som')),
          DropdownMenuItem(value: 'stop', child: Text('Parar tudo')),
        ],
        onChanged: (v) => _update(() => _operation = v ?? 'play'),
      ),
      const SizedBox(height: 12),
    ];

    if (_operation == 'stop') {
      fields.add(const EditorHint(
          'Para qualquer som que estiver tocando na soundboard.'));
    } else {
      // operação "play": escolhe a fonte do som
      fields
        ..add(DropdownButtonFormField<String>(
          value: _source,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Fonte', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(
                value: 'myinstants',
                child: Text('MyInstants (toca no PC → cabo/OBS)')),
            DropdownMenuItem(
                value: 'discord',
                child: Text('Soundboard do Discord (canal de voz)')),
          ],
          onChanged: (v) {
            _update(() {
              _source = v ?? 'myinstants';
              // A seleção pertence a uma fonte específica: limpa ao trocar.
              _title = null;
              _id = null;
              _url = null;
              _dcSoundId = null;
              _dcGuildId = null;
            });
            if (_source == 'discord' && _dcSounds.isEmpty) _loadDiscordSounds();
          },
        ))
        ..add(const SizedBox(height: 12))
        ..addAll(_source == 'discord' ? _discordFields() : _myInstantsFields());
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
  }

  Widget _selectedCard(IconData icon, String tooltip, VoidCallback? onPlay) =>
      Card(
        color: Colors.green.withValues(alpha: 0.12),
        child: ListTile(
          leading: Icon(icon, color: Colors.green),
          title: Text(_title!, overflow: TextOverflow.ellipsis),
          subtitle: const Text('Som selecionado'),
          trailing: IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: tooltip,
            onPressed: onPlay,
          ),
        ),
      );

  List<Widget> _myInstantsFields() {
    return [
      if (_title != null && _title!.isNotEmpty) ...[
        _selectedCard(
          Icons.music_note,
          'Testar no PC',
          _url == null ? null : () => _client.playSound(_id ?? '', _url!, _title ?? ''),
        ),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Buscar som no MyInstants',
                hintText: 'ex.: risada, bruh, aplausos…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          _searching
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton.filled(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
        ],
      ),
      const SizedBox(height: 8),
      if (_results.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _results.length,
            itemBuilder: (context, i) {
              final s = _results[i];
              final selected = s.mp3 == _url;
              return ListTile(
                dense: true,
                selected: selected,
                leading: IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Ouvir (toca no PC)',
                  onPressed: () => _client.playSound(s.id, s.mp3, s.title),
                ),
                title: Text(s.title, overflow: TextOverflow.ellipsis),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.add_circle_outline),
                onTap: () {
                  _update(() {
                    _id = s.id;
                    _url = s.mp3;
                    _title = s.title;
                  });
                  widget.args.suggestLabel(s.title);
                },
              );
            },
          ),
        ),
      const EditorHint(
          'O som toca no PC e sai pelo dispositivo configurado (cabo p/ Discord/OBS + monitor). '
          'Configure a saída em Configurações › Soundboard.'),
    ];
  }

  List<Widget> _discordFields() {
    return [
      if (_title != null && _title!.isNotEmpty) ...[
        _selectedCard(
          Icons.graphic_eq,
          'Testar no canal de voz',
          _dcSoundId == null
              ? null
              : () => _client.playDiscordSoundboard(_dcSoundId!, _dcGuildId),
        ),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          const Expanded(
            child: Text('Sons da soundboard do Discord',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _dcLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recarregar',
                  onPressed: _loadDiscordSounds,
                ),
        ],
      ),
      const SizedBox(height: 8),
      if (_dcSounds.isEmpty && !_dcLoading)
        Text(
          'Nenhum som carregado. Conecte o Discord no PC, entre num canal de voz e toque em recarregar.',
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        )
      else if (_dcSounds.isNotEmpty)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _dcSounds.length,
            itemBuilder: (context, i) {
              final s = _dcSounds[i];
              final sid = s['soundId'] ?? '';
              final name = s['name'] ?? '';
              final emoji = s['emojiName'] ?? '';
              final selected = sid == _dcSoundId;
              return ListTile(
                dense: true,
                selected: selected,
                leading: IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Ouvir (no canal de voz)',
                  onPressed: () =>
                      _client.playDiscordSoundboard(sid, s['guildId']),
                ),
                title: Text('${emoji.isNotEmpty ? '$emoji  ' : ''}$name',
                    overflow: TextOverflow.ellipsis),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.add_circle_outline),
                onTap: () {
                  _update(() {
                    _dcSoundId = sid;
                    _dcGuildId = s['guildId'];
                    _title = name;
                  });
                  widget.args.suggestLabel(name);
                },
              );
            },
          ),
        ),
      const EditorHint(
          'Toca a soundboard NATIVA do Discord no canal de voz atual (sem cabo). '
          'Você precisa estar num canal de voz. Não sai na live/OBS.'),
    ];
  }
}
