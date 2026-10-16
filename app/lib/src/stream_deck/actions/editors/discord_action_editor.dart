import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/config/discord_settings_page.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:droiddeck/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

class DiscordActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const DiscordActionEditor({super.key, required this.args});

  @override
  State<DiscordActionEditor> createState() => _DiscordActionEditorState();
}

class _DiscordActionEditorState extends State<DiscordActionEditor> {
  String _op = 'toggleMute';
  List<Map<String, String>> _guilds = [];
  List<Map<String, String>> _channels = [];
  List<Map<String, dynamic>> _participants = [];
  String? _guildId;
  String? _channelId;
  String? _channelName;
  String? _userId;
  String? _userName;
  int _delta = 10;
  int _value = 100;

  @override
  void initState() {
    super.initState();
    final p = widget.args.initial;
    _op = p['operation'] ?? 'toggleMute';
    _channelId = p['channelId'];
    _channelName = p['channelName'];
    _userId = p['userId'];
    _userName = p['userName'];
    _delta = int.tryParse(p['delta'] ?? '') ?? 10;
    _value = int.tryParse(p['value'] ?? '') ?? 100;
    _loadDataFor(_op);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    final params = <String, String>{'operation': _op};
    if (_op == 'joinChannel') {
      if (_channelId != null) params['channelId'] = _channelId!;
      if (_channelName != null) params['channelName'] = _channelName!;
    } else if (_op == 'userMute' || _op == 'userVolume') {
      if (_userId != null) params['userId'] = _userId!;
      if (_userName != null) params['userName'] = _userName!;
      if (_op == 'userVolume') params['value'] = '$_value';
    } else if (_op.toLowerCase().contains('volume')) {
      params['delta'] = '$_delta';
    }
    widget.args.onChanged(params);
  }

  void _update(VoidCallback change) {
    setState(change);
    _emit();
  }

  void _loadDataFor(String op) {
    // Atualiza configured/connected (pro aviso) no signal compartilhado.
    Injector.get<DroidDeckClient>().getDiscordState().then((s) {
      if (s != null && mounted) {
        Injector.get<SignalRService>().discordState.value =
            Map<String, dynamic>.from(s);
      }
    }).catchError((_) {});
    if (op == 'joinChannel' && _guilds.isEmpty) _loadGuilds();
    if ((op == 'userMute' || op == 'userVolume') && _participants.isEmpty) {
      _loadParticipants();
    }
  }

  Future<void> _loadGuilds() async {
    final g = await Injector.get<DroidDeckClient>().getDiscordGuilds();
    if (mounted) setState(() => _guilds = g);
  }

  Future<void> _loadChannels(String guildId) async {
    final c = await Injector.get<DroidDeckClient>().getDiscordChannels(guildId);
    if (mounted) setState(() => _channels = c);
  }

  Future<void> _loadParticipants() async {
    final s = await Injector.get<DroidDeckClient>().getDiscordState();
    final list = (s?['participants'] as List?) ?? [];
    if (mounted) {
      setState(() => _participants =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    }
  }

  /// Aviso quando a ação Discord depende de algo ainda não pronto
  /// (app não configurado, ou configurado mas desconectado).
  Widget _warning() {
    return Watch((context) {
      final ds = Injector.get<SignalRService>().discordState.value;
      final configured = ds['configured'] == true;
      final connected = ds['connected'] == true;
      if (configured && connected) return const SizedBox.shrink();

      final c = configured ? Colors.blueGrey : Colors.orange;
      final msg = configured
          ? tr('Discord configurado, mas desconectado. Abra o Discord no PC e conecte.')
          : tr('Discord não configurado — esta ação não vai funcionar até configurar o app do Discord.');
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(configured ? Icons.link_off : Icons.warning_amber_rounded,
                color: c, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 12))),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiscordSettingsPage()),
              ),
              child: Text(tr('Configurar')),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final op = _op;
    final fields = <Widget>[
      _warning(),
      DropdownButtonFormField<String>(
        value: _op,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: tr('Ação do Discord'), border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(
              value: 'toggleMute', child: Text(tr('Microfone (mutar/desmutar)'))),
          DropdownMenuItem(
              value: 'toggleDeafen', child: Text(tr('Ensurdecer (liga/desliga)'))),
          DropdownMenuItem(
              value: 'joinChannel', child: Text(tr('Entrar em canal de voz'))),
          DropdownMenuItem(
              value: 'disconnect', child: Text(tr('Desconectar da voz'))),
          DropdownMenuItem(
              value: 'inputVolumeUp', child: Text(tr('Volume do mic  +'))),
          DropdownMenuItem(
              value: 'inputVolumeDown', child: Text(tr('Volume do mic  −'))),
          DropdownMenuItem(
              value: 'outputVolumeUp', child: Text(tr('Volume de saída  +'))),
          DropdownMenuItem(
              value: 'outputVolumeDown', child: Text(tr('Volume de saída  −'))),
          DropdownMenuItem(
              value: 'toggleVoiceMode', child: Text(tr('Alternar PTT / Voz'))),
          DropdownMenuItem(
              value: 'userMute', child: Text(tr('Mutar usuário (alternar)'))),
          DropdownMenuItem(
              value: 'userVolume', child: Text(tr('Volume de usuário'))),
        ],
        onChanged: (v) {
          _update(() => _op = v ?? 'toggleMute');
          _loadDataFor(_op);
        },
      ),
      const SizedBox(height: 12),
    ];

    if (op == 'joinChannel') {
      fields.addAll([
        DropdownButtonFormField<String>(
          value: _guilds.any((g) => g['id'] == _guildId) ? _guildId : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('Servidor'),
            border: const OutlineInputBorder(),
            helperText: _guilds.isEmpty ? tr('Carregando…') : null,
          ),
          items: _guilds
              .map((g) => DropdownMenuItem(
                  value: g['id'],
                  child:
                      Text(g['name'] ?? '', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _guildId = v;
              _channels = [];
            });
            if (v != null) _loadChannels(v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value:
              _channels.any((c) => c['id'] == _channelId) ? _channelId : null,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: tr('Canal de voz'), border: const OutlineInputBorder()),
          items: _channels
              .map((c) => DropdownMenuItem(
                  value: c['id'],
                  child:
                      Text(c['name'] ?? '', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => _update(() {
            _channelId = v;
            _channelName = _channels
                .firstWhere((c) => c['id'] == v, orElse: () => {})['name'];
          }),
        ),
        if (_channelName != null && _channelName!.isNotEmpty)
          EditorHint(tr('Canal salvo: {name}', {'name': _channelName!})),
      ]);
    } else if (op == 'userMute' || op == 'userVolume') {
      fields.addAll([
        DropdownButtonFormField<String>(
          value: _participants.any((p) => '${p['id']}' == _userId)
              ? _userId
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('Usuário na call'),
            border: const OutlineInputBorder(),
            helperText:
                _participants.isEmpty ? tr('Entre numa call pra listar') : null,
          ),
          items: _participants.map((p) {
            final name = (p['nick'] ?? p['username'] ?? p['id']).toString();
            return DropdownMenuItem(
                value: '${p['id']}',
                child: Text(name, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) => _update(() {
            _userId = v;
            final pp = _participants
                .firstWhere((p) => '${p['id']}' == v, orElse: () => {});
            _userName = (pp['nick'] ?? pp['username'])?.toString();
          }),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loadParticipants,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(tr('Atualizar lista')),
          ),
        ),
        if (op == 'userVolume') ...[
          Text(tr('Volume: {value}%', {'value': _value})),
          Slider(
            value: _value.clamp(0, 200).toDouble(),
            min: 0,
            max: 200,
            divisions: 40,
            label: '$_value%',
            onChanged: (v) => _update(() => _value = v.round()),
          ),
        ],
      ]);
    } else if (op.toLowerCase().contains('volume')) {
      fields.add(Row(
        children: [
          Text(tr('Passo: ')),
          Expanded(
            child: Slider(
              value: _delta.clamp(1, 50).toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              label: '$_delta%',
              onChanged: (v) => _update(() => _delta = v.round()),
            ),
          ),
          Text('$_delta%'),
        ],
      ));
    }

    fields.add(EditorHint(
        tr('Requer o Discord conectado no PC (config do DroidDeck).')));
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
  }
}
