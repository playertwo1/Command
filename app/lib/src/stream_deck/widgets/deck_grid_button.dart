import 'dart:convert';
import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import '../actions/action_catalog.dart';
import '../tuya_display.dart';
import 'button_icons.dart';
import 'timer_deck_button.dart';

class DeckGridButton extends StatefulWidget {
  final DeckButton button;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DeckGridButton({
    super.key,
    required this.button,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<DeckGridButton> createState() => _DeckGridButtonState();
}

class _DeckGridButtonState extends State<DeckGridButton> {
  /// Se o botão é um toggle de mute (ação mixer mute/toggle com processName),
  /// retorna o nome do processo-alvo; senão null (botão comum).
  String? get _muteProcess {
    final a = widget.button.action;
    if (a == null || a.type != 'mixer') return null;
    final op = (a.parameters['operation'] ?? 'toggleMute').toLowerCase();
    final pn = a.parameters['processName'];
    if (pn != null && pn.isNotEmpty && op.contains('mute')) return pn;
    return null;
  }

  /// Operação de volume de um botão de mixer com alvo dispositivo
  /// (volumeup/volumedown/setvolume), em minúsculas; null se não for esse caso.
  String? get _mixerVolumeOp {
    final a = widget.button.action;
    if (a == null || a.type != 'mixer') return null;
    if ((a.parameters['deviceId'] ?? '').isEmpty) return null;
    final op = (a.parameters['operation'] ?? '').toLowerCase();
    return const ['volumeup', 'volumedown', 'setvolume'].contains(op)
        ? op
        : null;
  }

  IconData _mixerVolumeIconData(String op) {
    switch (op) {
      case 'volumeup':
        return Icons.volume_up;
      case 'volumedown':
        return Icons.volume_down;
      default: // setvolume
        return Icons.tune;
    }
  }

  // Operação do Discord (crua, minúscula) se for um botão de Discord; senão null.
  String? get _discordOp {
    final a = widget.button.action;
    if (a == null || a.type != 'discord') return null;
    return (a.parameters['operation'] ?? 'toggleMute').toLowerCase();
  }

  // Comando de mídia (play/pause/next/...) se for um botão de mídia; senão null.
  String? get _mediaCommand {
    final a = widget.button.action;
    if (a == null || a.type != 'media') return null;
    return (a.parameters['command'] ?? 'playpause').toLowerCase();
  }

  // Operação do OBS (setscene/togglerecord/...) se for um botão de OBS; senão null.
  String? get _obsOp {
    final a = widget.button.action;
    if (a == null || a.type != 'obs') return null;
    return (a.parameters['operation'] ?? 'setScene').toLowerCase();
  }

  /// (deviceId, code) do botão de casa inteligente, ou null se não for um.
  (String, String)? get _tuyaTarget {
    final a = widget.button.action;
    if (a == null || a.type != 'tuya') return null;
    final deviceId = a.parameters['deviceId'];
    final code = a.parameters['code'];
    if (deviceId == null || code == null) return null;
    return (deviceId, code);
  }

  IconData _mediaIconData(String cmd) {
    switch (cmd) {
      case 'next':
        return Icons.skip_next;
      case 'previous':
        return Icons.skip_previous;
      case 'stop':
        return Icons.stop;
      case 'pause':
        return Icons.pause;
      case 'play':
        return Icons.play_arrow;
      default: // playpause / toggle
        return Icons.play_arrow;
    }
  }

  String _mediaDefaultLabel(String cmd) {
    switch (cmd) {
      case 'next':
        return tr('Próxima');
      case 'previous':
        return tr('Anterior');
      case 'stop':
        return tr('Parar');
      case 'pause':
        return 'Pause';
      case 'play':
        return 'Play';
      default:
        return 'Play/Pause';
    }
  }

  @override
  void initState() {
    super.initState();
    final p = _muteProcess;
    if (p != null) {
      // Consulta o estado de mute inicial uma vez (se ainda não conhecido).
      try {
        final sr = Injector.get<SignalRService>();
        if (!sr.muteStates.value.containsKey(p)) {
          Injector.get<DroidDeckClient>().getMuteState(p).then((m) {
            if (m != null && mounted) {
              final cur = Map<String, bool>.from(sr.muteStates.value);
              cur[p] = m;
              sr.muteStates.value = cur;
            }
          }).catchError((_) {});
        }
      } catch (_) {}
    }
    if (_discordOp != null) {
      try {
        final sr = Injector.get<SignalRService>();
        Injector.get<DroidDeckClient>().getDiscordState().then((s) {
          if (s != null && mounted) {
            sr.discordState.value = Map<String, dynamic>.from(s);
          }
        }).catchError((_) {});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final dop = _discordOp;
    if (dop != null) {
      // .value (não .watch(context)) é o idiomático dentro de Watch — garante rebuild.
      return Watch((context) {
        final ds = Injector.get<SignalRService>().discordState.value;
        return _renderDiscord(dop, ds);
      });
    }
    // Botão de mídia Play/Pause: reflete o estado de reprodução ao vivo.
    final mc = _mediaCommand;
    if (mc == 'playpause' || mc == 'toggle') {
      return Watch((context) {
        Injector.get<SignalRService>().mediaPlaying.value; // assina o estado
        return _render(null);
      });
    }
    // Botão de OBS: reflete cena atual / gravando / transmitindo / etc. ao vivo.
    final oop = _obsOp;
    if (oop != null) {
      return Watch((context) {
        final ds = Injector.get<SignalRService>().obsState.value;
        return _renderObs(oop, ds);
      });
    }
    final type = widget.button.action?.type;
    // Timer/pomodoro/contador: relógio ao vivo, com estado no PC.
    if (type == 'timer') {
      return TimerDeckButton(
        button: widget.button,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        color: _color,
        activeColor: _activeColor(),
      );
    }
    // Ações do Windows: "trocar áudio" acende quando o dispositivo já é o padrão.
    if (type == 'windows') {
      return Watch((context) {
        final ws = Injector.get<SignalRService>().stateOf('ReceiveWindowsState');
        return _renderWindows(ws);
      });
    }
    // Integrações com conta: o botão mostra o estado que o PC publica.
    if (type == 'homeassistant' ||
        type == 'spotify' ||
        type == 'twitch' ||
        type == 'youtube') {
      return Watch((context) {
        final sr = Injector.get<SignalRService>();
        return switch (type) {
          'homeassistant' =>
            _renderHomeAssistant(sr.stateOf('ReceiveHomeAssistantState')),
          'spotify' => _renderSpotify(sr.stateOf('ReceiveSpotifyState')),
          _ => _renderLive(type!, sr.stateOf(
              type == 'twitch' ? 'ReceiveTwitchState' : 'ReceiveYouTubeState')),
        };
      });
    }
    // Botão de casa inteligente: acende conforme o estado real do aparelho.
    final tuya = _tuyaTarget;
    if (tuya != null) {
      return Watch((context) {
        final ts = Injector.get<SignalRService>().tuyaState.value;
        return _renderTuya(ts, tuya.$1, tuya.$2);
      });
    }
    final p = _muteProcess;
    if (p == null) {
      // Dois estados: acompanha o liga/desliga guardado no PC.
      return widget.button.toggle ? Watch((_) => _render(null)) : _render(null);
    }
    // Reage ao estado de mute vindo do backend (toque ou mudança externa).
    return Watch((context) {
      final muted = Injector.get<SignalRService>().muteStates.value[p];
      return _render(muted);
    });
  }

  /// Cor exibida quando o botão está "ativo" (toggle ligado). Configurável; nula
  /// usa a do tema.
  Color? _activeColor() => _parseColor(widget.button.activeColor);

  Color? get _color => _parseColor(widget.button.backgroundColor);

  /// Atualiza o estado local na hora do toque (otimista): o botão pinta imediatamente,
  /// sem depender da volta do broadcast. O broadcast do backend confirma/corrige depois.
  void _handleTap() {
    try {
      final sr = Injector.get<SignalRService>();
      if (widget.button.toggle) {
        // Dois estados: inverte na hora; o PC confirma pelo ReceiveButtonToggles.
        final cur = Map<String, dynamic>.from(sr.stateOf('ReceiveButtonToggles'))
          ..remove('_receivedAt');
        if (cur[widget.button.id] == true) {
          cur.remove(widget.button.id);
        } else {
          cur[widget.button.id] = true;
        }
        sr.seedState('ReceiveButtonToggles', cur);
      }
      final dop = _discordOp;
      if (dop != null) {
        // Otimismo só para toggles (mute/deaf/modo). Os demais (entrar canal,
        // volume, etc.) atualizam pelo broadcast do backend.
        final cur = Map<String, dynamic>.from(sr.discordState.value);
        if (dop == 'togglemute') {
          cur['mute'] = !(cur['mute'] == true);
        } else if (dop.contains('deaf')) {
          cur['deaf'] = !(cur['deaf'] == true);
        } else if (dop.contains('voicemode') || dop.contains('ptt')) {
          cur['voiceMode'] = cur['voiceMode'] == 'PUSH_TO_TALK'
              ? 'VOICE_ACTIVITY'
              : 'PUSH_TO_TALK';
        } else {
          widget.onTap();
          return;
        }
        sr.discordState.value = cur;
      } else if (_tuyaTarget case (final deviceId, final code)?) {
        // O push MQTT confirma em ~800ms; sem otimismo o botão pareceria travado.
        // Só para "toggle": em "set" o valor é fixo e o push já traz a verdade.
        final op = (widget.button.action?.parameters['operation'] ?? 'toggle')
            .toLowerCase();
        if (op == 'toggle') {
          final snapshot = Map<String, dynamic>.from(sr.tuyaState.value);
          final devices = List<dynamic>.from(snapshot['devices'] as List? ?? const []);
          final index = devices.indexWhere((d) => (d as Map)['id'] == deviceId);
          if (index >= 0) {
            final device = Map<String, dynamic>.from(devices[index] as Map);
            final status = Map<String, dynamic>.from(device['status'] as Map? ?? const {});
            status[code] = !(status[code] == true);
            device['status'] = status;
            devices[index] = device;
            snapshot['devices'] = devices;
            sr.tuyaState.value = snapshot;
          }
        }
      } else {
        final mc = _mediaCommand;
        if (mc == 'playpause' || mc == 'toggle') {
          sr.mediaPlaying.value = !sr.mediaPlaying.value; // otimista
        } else {
          final p = _muteProcess;
          if (p != null) {
            final op =
                (widget.button.action?.parameters['operation'] ?? 'toggleMute')
                    .toLowerCase();
            final cur = Map<String, bool>.from(sr.muteStates.value);
            final now = cur[p] == true;
            cur[p] = op == 'mute' ? true : (op == 'unmute' ? false : !now);
            sr.muteStates.value = cur;
          }
        }
      }
    } catch (_) {}
    widget.onTap();
  }

  Widget _render(bool? muted) {
    // Label: o do botão; se vazio e for mídia, usa o rótulo padrão do comando.
    final label = (widget.button.label != null && widget.button.label!.isNotEmpty)
        ? widget.button.label!
        : (_mediaCommand != null ? _mediaDefaultLabel(_mediaCommand!) : null);
    return _tile(
      active: muted == true,
      icon: _isCoverArt ? _buildCover() : _buildIcon(muted),
      label: label,
    );
  }

  /// Liga/desliga do botão de dois estados (guardado no PC). Chame dentro de um Watch.
  bool get _toggledOn {
    if (!widget.button.toggle) return false;
    try {
      return Injector.get<SignalRService>()
              .stateOf('ReceiveButtonToggles')[widget.button.id] ==
          true;
    } catch (_) {
      return false;
    }
  }

  /// Monta o botão no estado certo: ativo pelo estado da ação ou pelo liga/desliga do
  /// botão. Ativo, o rótulo e o ícone do estado ativo (se definidos) substituem os normais.
  Widget _tile({
    required bool active,
    required Widget icon,
    String? label,
    Color? activeColor,
  }) {
    final b = widget.button;
    final on = active || _toggledOn;
    if (on && (b.activeIconBase64?.isNotEmpty ?? false)) {
      icon = _base64Icon(b.activeIconBase64!);
    } else if (on && (b.activeIconName?.isNotEmpty ?? false)) {
      icon = Icon(buttonIconData(b.activeIconName!), size: 32);
    }
    final text = on && (b.activeLabel?.isNotEmpty ?? false) ? b.activeLabel : label;
    return DeckTile(
      color: _color,
      active: on,
      activeColor: activeColor ?? _activeColor(),
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  /// Botão de jogo com a capa como ícone: a imagem ocupa o botão, não 32 px.
  bool get _isCoverArt =>
      widget.button.action?.type == 'steam' &&
      (widget.button.iconBase64?.isNotEmpty ?? false);

  Widget _buildCover() {
    return Flexible(
      child: LayoutBuilder(builder: (context, c) {
        final side = c.maxWidth.isFinite ? c.maxWidth * 0.78 : 64.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: side,
            height: side,
            child: Image.memory(
              base64Decode(widget.button.iconBase64!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.sports_esports),
            ),
          ),
        );
      }),
    );
  }

  Widget _renderDiscord(String op, Map<String, dynamic> ds) {
    final params = widget.button.action?.parameters ?? const <String, String>{};
    IconData icon;
    bool active = false;
    String defLabel;

    if (op.contains('deaf')) {
      active = ds['deaf'] == true;
      icon = active ? Icons.headset_off : Icons.headset_mic;
      defLabel = tr('Ensurdecer');
    } else if (op == 'joinchannel') {
      final ch = params['channelId'];
      active = ch != null && ch.isNotEmpty && ds['channelId'] == ch;
      icon = active ? Icons.headset : Icons.login;
      defLabel = (params['channelName']?.isNotEmpty ?? false)
          ? params['channelName']!
          : tr('Canal');
    } else if (op == 'disconnect' || op == 'leavechannel') {
      icon = Icons.call_end;
      defLabel = tr('Sair');
    } else if (op.contains('inputvolume')) {
      icon = op.contains('up') ? Icons.mic : Icons.mic_none;
      defLabel = op.contains('up') ? 'Mic +' : 'Mic −';
    } else if (op.contains('outputvolume')) {
      icon = op.contains('up') ? Icons.volume_up : Icons.volume_down;
      defLabel = op.contains('up') ? tr('Som +') : tr('Som −');
    } else if (op.contains('voicemode') || op.contains('ptt')) {
      active = ds['voiceMode'] == 'PUSH_TO_TALK';
      icon = active ? Icons.record_voice_over : Icons.graphic_eq;
      defLabel = active ? 'PTT' : tr('Voz');
    } else if (op.startsWith('usermute')) {
      icon = Icons.person_off;
      defLabel =
          (params['userName']?.isNotEmpty ?? false) ? params['userName']! : tr('Mutar');
    } else if (op == 'uservolume') {
      icon = Icons.person;
      defLabel =
          (params['userName']?.isNotEmpty ?? false) ? params['userName']! : 'Vol';
    } else {
      // toggleMute (padrão)
      active = ds['mute'] == true;
      icon = active ? Icons.mic_off : Icons.mic;
      defLabel = tr('Mutar');
    }

    final label =
        (widget.button.label != null && widget.button.label!.isNotEmpty)
            ? widget.button.label!
            : defLabel;
    return _tile(active: active, icon: Icon(icon, size: 30), label: label);
  }

  /// Dispositivo do snapshot da Tuya, ou null se ainda não enumerado.
  Map<String, dynamic>? _tuyaDeviceOf(Map<String, dynamic> state, String deviceId) {
    for (final d in (state['devices'] as List? ?? const [])) {
      if ((d as Map)['id'] == deviceId) return Map<String, dynamic>.from(d);
    }
    return null;
  }

  /// Botão de casa inteligente: reflete estado, nível e cor reais do aparelho.
  Widget _renderTuya(Map<String, dynamic> state, String deviceId, String code) {
    final device = _tuyaDeviceOf(state, deviceId);
    final status = device?['status'] as Map? ?? const {};
    final functions = device?['functions'] as Map? ?? const {};

    final on = tuyaIsOn(status, code);
    final level = tuyaLevel(status, functions, code);
    final rgb = tuyaColor(status);

    final label = (widget.button.label != null && widget.button.label!.isNotEmpty)
        ? widget.button.label!
        : (device?['name'] as String?);

    // Cor real do RGB tem prioridade sobre a "cor ativa" configurada: se o usuário
    // pintou a sala de roxo, o botão mostra roxo. Só faz sentido com o aparelho aceso.
    // Sobre fundo claro o DeckTile já troca o texto para escuro.
    return DeckTile(
      color: _color,
      active: on,
      activeColor: rgb ?? _activeColor(),
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: Builder(builder: (context) {
        final fg = DeckTile.foregroundOf(context);
        return Stack(
          children: [
            // Preenchimento proporcional ao nível, subindo do rodapé. Some quando o
            // aparelho está apagado — nível de luz apagada não significa nada.
            if (level != null && on)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: level,
                  child: Container(
                    color: fg.withValues(alpha: 0.18),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tuyaIconFor(device?['category'] as String?, on),
                    size: 24,
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                  if (level != null && on)
                    Text(
                      '${(level * 100).round()}%',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _renderObs(String op, Map<String, dynamic> ds) {
    final params = widget.button.action?.parameters ?? const <String, String>{};
    IconData icon;
    bool active = false;
    String defLabel;

    switch (op) {
      case 'setscene':
        final sc = params['scene'];
        active = sc != null && sc.isNotEmpty && ds['currentScene'] == sc;
        icon = Icons.movie_outlined;
        defLabel = (sc?.isNotEmpty ?? false) ? sc! : tr('Cena');
        break;
      case 'togglerecord':
        active = ds['recording'] == true;
        icon = Icons.fiber_manual_record;
        defLabel = active ? tr('Gravando') : tr('Gravar');
        break;
      case 'togglestream':
        active = ds['streaming'] == true;
        icon = Icons.sensors;
        defLabel = active ? tr('No ar') : 'Live';
        break;
      case 'togglevirtualcam':
        active = ds['virtualCam'] == true;
        icon = Icons.videocam;
        defLabel = tr('Câmera virtual');
        break;
      case 'togglereplaybuffer':
        active = ds['replayBuffer'] == true;
        icon = Icons.history;
        defLabel = 'Replay buffer';
        break;
      case 'savereplay':
        icon = Icons.save_alt;
        defLabel = tr('Salvar replay');
        break;
      case 'toggleinputmute':
        icon = Icons.mic_off;
        defLabel = (params['inputName']?.isNotEmpty ?? false)
            ? params['inputName']!
            : tr('Mutar fonte');
        break;
      case 'togglesourcevisibility':
        icon = Icons.visibility;
        defLabel = (params['sourceName']?.isNotEmpty ?? false)
            ? params['sourceName']!
            : tr('Fonte');
        break;
      case 'togglefilter':
        icon = Icons.auto_fix_high;
        defLabel = (params['filterName']?.isNotEmpty ?? false)
            ? params['filterName']!
            : tr('Filtro');
        break;
      case 'togglerecordpause':
        active = ds['recordPaused'] == true;
        icon = active ? Icons.play_arrow : Icons.pause;
        defLabel = active ? tr('Retomar') : tr('Pausar gravação');
        break;
      case 'createchapter':
        icon = Icons.bookmark_add;
        defLabel = tr('Capítulo');
        break;
      case 'screenshot':
        icon = Icons.photo_camera;
        defLabel = tr('Captura');
        break;
      default:
        icon = Icons.videocam;
        defLabel = 'OBS';
    }

    final label = (widget.button.label != null && widget.button.label!.isNotEmpty)
        ? widget.button.label!
        : defLabel;
    return _tile(active: active, icon: Icon(icon, size: 30), label: label);
  }

  String? get _ownLabel =>
      (widget.button.label?.isNotEmpty ?? false) ? widget.button.label : null;

  bool get _hasOwnIcon =>
      (widget.button.iconName?.isNotEmpty ?? false) ||
      (widget.button.iconBase64?.isNotEmpty ?? false);

  // ---- Home Assistant ----

  static const _haOnStates = {
    'on', 'open', 'opening', 'playing', 'unlocked', 'home', 'heat', 'cool',
    'heat_cool', 'auto', 'dry', 'fan_only', 'cleaning', 'active',
  };

  static IconData _haIcon(String domain, bool on) => switch (domain) {
        'light' => on ? Icons.lightbulb : Icons.lightbulb_outline,
        'switch' || 'input_boolean' => on ? Icons.toggle_on : Icons.toggle_off,
        'fan' => Icons.mode_fan_off_outlined,
        'cover' => on ? Icons.blinds : Icons.blinds_closed,
        'lock' => on ? Icons.lock_open : Icons.lock,
        'media_player' => on ? Icons.play_circle : Icons.speaker,
        'climate' => Icons.thermostat,
        'scene' => Icons.palette_outlined,
        'script' => Icons.play_arrow,
        'automation' => Icons.smart_toy_outlined,
        'sensor' || 'binary_sensor' => Icons.sensors,
        'person' || 'device_tracker' => Icons.person,
        'vacuum' => Icons.cleaning_services,
        _ => Icons.home,
      };

  Widget _renderHomeAssistant(Map<String, dynamic> ha) {
    final params = widget.button.action?.parameters ?? const <String, String>{};
    final id = params['entityId'] ?? '';
    final op = (params['operation'] ?? 'toggle').toLowerCase();
    final domain = id.contains('.') ? id.split('.').first : '';
    final entities = ha['entities'] as Map? ?? const {};
    final e = entities[id] is Map ? Map<String, dynamic>.from(entities[id] as Map) : null;
    final state = '${e?['state'] ?? ''}';
    final name = (e?['name'] as String?) ?? (id.contains('.') ? id.split('.').last : 'Home Assistant');

    // "Só mostrar": o valor do sensor no lugar do ícone.
    if (op == 'display') {
      final unit = e?['unit'] as String?;
      final value = state.isEmpty ? '—' : (unit != null ? '$state $unit' : state);
      return _tile(
        active: false,
        icon: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        label: _ownLabel ?? name,
      );
    }
    final on = _haOnStates.contains(state);
    final brightness = e?['brightness'] as int?;
    final color = _parseColor(e?['color'] as String?);
    final label = _ownLabel ?? name;
    return _tile(
      active: on && domain != 'scene' && domain != 'script',
      activeColor: color,
      icon: _hasOwnIcon ? _buildIcon(null) : Icon(_haIcon(domain, on), size: 30),
      label: on && brightness != null ? '$label · $brightness%' : label,
    );
  }

  // ---- Spotify ----

  Widget _renderSpotify(Map<String, dynamic> sp) {
    final op = (widget.button.action?.parameters['operation'] ?? 'playPause')
        .toLowerCase();
    final playing = sp['playing'] == true;
    if (op == 'nowplaying') {
      final cover = sp['coverBase64'] as String?;
      Widget icon = const Icon(Icons.music_note, size: 30);
      if (cover != null && cover.isNotEmpty) {
        icon = Flexible(
          child: LayoutBuilder(builder: (context, c) {
            final side = c.maxWidth.isFinite ? c.maxWidth * 0.6 : 48.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: side,
                height: side,
                child: Image.memory(base64Decode(cover),
                    fit: BoxFit.cover, gaplessPlayback: true),
              ),
            );
          }),
        );
      }
      final track = sp['track'] as String?;
      return _tile(
        active: false,
        icon: icon,
        label: _ownLabel ??
            (track == null ? 'Spotify' : '$track\n${sp['artist'] ?? ''}'),
      );
    }
    final (IconData icon, bool active, String label) = switch (op) {
      'next' => (Icons.skip_next, false, tr('Próxima')),
      'previous' => (Icons.skip_previous, false, tr('Anterior')),
      'like' => (
          sp['liked'] == true ? Icons.favorite : Icons.favorite_border,
          sp['liked'] == true,
          tr('Curtir')
        ),
      'shuffle' => (Icons.shuffle, sp['shuffle'] == true, tr('Aleatório')),
      'repeat' => (
          sp['repeat'] == 'track' ? Icons.repeat_one : Icons.repeat,
          sp['repeat'] != null && sp['repeat'] != 'off',
          tr('Repetir')
        ),
      'volume' => (
          (int.tryParse(widget.button.action?.parameters['step'] ?? '') ?? 10) < 0
              ? Icons.volume_down
              : Icons.volume_up,
          false,
          sp['volume'] != null ? 'Vol ${sp['volume']}%' : 'Volume'
        ),
      'playlist' => (Icons.queue_music, false, 'Playlist'),
      _ => (playing ? Icons.pause : Icons.play_arrow, false, 'Spotify'),
    };
    return _tile(
      active: active,
      icon: _hasOwnIcon ? _buildIcon(null) : Icon(icon, size: 30),
      label: _ownLabel ?? label,
    );
  }

  // ---- Twitch / YouTube ----

  Widget _renderLive(String type, Map<String, dynamic> st) {
    final op = (widget.button.action?.parameters['operation'] ?? '').toLowerCase();
    final live = st['live'] == true;
    final viewers = st['viewers'];
    final (IconData icon, String label) = switch (op) {
      'marker' => (Icons.bookmark_add, tr('Marcador')),
      'clip' => (Icons.movie_creation_outlined, tr('Clipe')),
      'ad' => (Icons.campaign, tr('Anúncio')),
      'chat' => (Icons.chat, 'Chat'),
      'poll' => (Icons.poll_outlined, tr('Enquete')),
      'title' => (Icons.title, tr('Título')),
      _ => (
          type == 'twitch' ? Icons.sensors : Icons.smart_display,
          live
              ? (viewers != null
                  ? tr('{n} assistindo', {'n': viewers})
                  : tr('Ao vivo'))
              : tr('Fora do ar')
        ),
    };
    return _tile(
      active: op == 'status' && live,
      icon: _hasOwnIcon ? _buildIcon(null) : Icon(icon, size: 30),
      label: op == 'status' ? label : (_ownLabel ?? label),
    );
  }

  Widget _renderWindows(Map<String, dynamic> ws) {
    final params = widget.button.action?.parameters ?? const <String, String>{};
    final op = (params['operation'] ?? 'setDefaultAudio').toLowerCase();
    IconData icon;
    String defLabel;
    var active = false;
    switch (op) {
      case 'lock':
        icon = Icons.lock;
        defLabel = tr('Travar');
        break;
      case 'sleep':
        icon = Icons.bedtime;
        defLabel = tr('Suspender');
        break;
      case 'displayoff':
        icon = Icons.desktop_access_disabled;
        defLabel = tr('Desligar tela');
        break;
      default:
        final input = params['deviceKind'] == 'input';
        final current = ws[input ? 'defaultInput' : 'defaultOutput'];
        final alt = params['altDeviceId'];
        final hasAlt = alt != null && alt.isNotEmpty && alt != 'none';
        // Com alternância, o ícone diz qual dos dois está valendo; sem ela, o botão
        // acende quando o dispositivo escolhido já é o padrão.
        final onMain = current != null && current == params['deviceId'];
        active = !hasAlt && onMain;
        icon = input
            ? Icons.mic
            : (hasAlt && !onMain ? Icons.speaker : Icons.headphones);
        defLabel = input ? tr('Microfone') : tr('Saída de áudio');
    }

    final hasIcon = (widget.button.iconName?.isNotEmpty ?? false) ||
        (widget.button.iconBase64?.isNotEmpty ?? false);
    final label = (widget.button.label?.isNotEmpty ?? false)
        ? widget.button.label!
        : defLabel;
    return _tile(
      active: active,
      icon: hasIcon ? _buildIcon(null) : Icon(icon, size: 30),
      label: label,
    );
  }

  Widget _buildIcon(bool? muted) {
    // Toggle de mute: o ícone reflete o estado real.
    if (muted != null) {
      return Icon(muted ? Icons.volume_off : Icons.volume_up,
          size: 32);
    }
    if (widget.button.iconBase64 != null &&
        widget.button.iconBase64!.isNotEmpty) {
      return _base64Icon(widget.button.iconBase64!);
    }
    if (widget.button.iconName != null && widget.button.iconName!.isNotEmpty) {
      return Icon(_getIconData(widget.button.iconName!),
          size: 32);
    }
    // Botão de volume de dispositivo sem ícone custom: o ícone sai da operação.
    final mv = _mixerVolumeOp;
    if (mv != null) {
      return Icon(_mixerVolumeIconData(mv), size: 32);
    }
    // Botão de mídia sem ícone custom: usa o ícone do comando.
    final mc = _mediaCommand;
    if (mc != null) {
      if (mc == 'playpause' || mc == 'toggle') {
        // Reativo: pause quando tocando, play quando pausado (dentro do Watch do build).
        final playing = Injector.get<SignalRService>().mediaPlaying.value;
        return Icon(playing ? Icons.pause : Icons.play_arrow,
            size: 32);
      }
      return Icon(_mediaIconData(mc), size: 32);
    }
    // Sem ícone escolhido: o do tipo da ação (webhook, Windows...), se o catálogo souber.
    final schema = ActionCatalog.instance.find(widget.button.action?.type);
    if (schema != null && widget.button.action?.type != 'hotkey') {
      return Icon(schema.iconData, size: 32);
    }
    return Builder(
        builder: (context) => Icon(Icons.touch_app,
            size: 32,
            color: DeckTile.foregroundOf(context).withValues(alpha: 0.54)));
  }

  Widget _base64Icon(String data) {
    try {
      String base64String = data;
      if (base64String.startsWith('data:image')) {
        base64String = base64String.split(',')[1];
      }
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        width: 32,
        height: 32,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.error, color: Colors.red),
      );
    } catch (_) {
      return const Icon(Icons.broken_image);
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

  IconData _getIconData(String name) => buttonIconData(name);
}
