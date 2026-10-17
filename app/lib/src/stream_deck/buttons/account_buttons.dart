import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import 'button_look.dart';
import 'colors.dart';

/// Home Assistant: entidade ligada acende (com brilho e cor da luz); "só mostrar" exibe o valor.
class HomeAssistantButtonRenderer extends ButtonRenderer {
  const HomeAssistantButtonRenderer();

  static const _onStates = {
    'on', 'open', 'opening', 'playing', 'unlocked', 'home', 'heat', 'cool',
    'heat_cool', 'auto', 'dry', 'fan_only', 'cleaning', 'active',
  };

  static IconData _icon(String domain, bool on) => switch (domain) {
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

  @override
  Widget build(ButtonLook look) {
    final ha = Injector.get<SignalRService>().stateOf('ReceiveHomeAssistantState');
    final id = look.params['entityId'] ?? '';
    final domain = id.contains('.') ? id.split('.').first : '';
    final entities = ha['entities'] as Map? ?? const {};
    final e = entities[id] is Map ? Map<String, dynamic>.from(entities[id] as Map) : null;
    final state = '${e?['state'] ?? ''}';
    final name = (e?['name'] as String?) ??
        (id.contains('.') ? id.split('.').last : 'Home Assistant');

    if (look.op('toggle') == 'display') {
      final unit = e?['unit'] as String?;
      final value = state.isEmpty ? '—' : (unit != null ? '$state $unit' : state);
      return look.tile(
        active: false,
        icon: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        label: look.ownLabel ?? name,
      );
    }
    final on = _onStates.contains(state);
    final brightness = e?['brightness'] as int?;
    final label = look.ownLabel ?? name;
    return look.tile(
      active: on && domain != 'scene' && domain != 'script',
      activeColor: parseHexColor(e?['color'] as String?),
      icon: look.hasOwnIcon ? look.icon() : Icon(_icon(domain, on), size: 30),
      label: on && brightness != null ? '$label · $brightness%' : label,
    );
  }
}

/// Spotify: play/pause, curtida, aleatório e repetir refletem a conta; "mostrar o que
/// está tocando" traz a capa.
class SpotifyButtonRenderer extends ButtonRenderer {
  const SpotifyButtonRenderer();

  @override
  Widget build(ButtonLook look) {
    final sp = Injector.get<SignalRService>().stateOf('ReceiveSpotifyState');
    final op = look.op('playPause');
    if (op == 'nowplaying') {
      final cover = sp['coverBase64'] as String?;
      final track = sp['track'] as String?;
      return look.tile(
        active: false,
        icon: cover != null && cover.isNotEmpty
            ? ButtonLook.cover(cover, fraction: 0.6, fallback: Icons.music_note)
            : const Icon(Icons.music_note, size: 30),
        label: look.ownLabel ?? (track == null ? 'Spotify' : '$track\n${sp['artist'] ?? ''}'),
      );
    }
    final (IconData icon, bool active, String label) = switch (op) {
      'next' => (Icons.skip_next, false, tr('Próxima')),
      'previous' => (Icons.skip_previous, false, tr('Anterior')),
      'like' => (
          sp['liked'] == true ? Icons.favorite : Icons.favorite_border,
          sp['liked'] == true,
          tr('Curtir'),
        ),
      'shuffle' => (Icons.shuffle, sp['shuffle'] == true, tr('Aleatório')),
      'repeat' => (
          sp['repeat'] == 'track' ? Icons.repeat_one : Icons.repeat,
          sp['repeat'] != null && sp['repeat'] != 'off',
          tr('Repetir'),
        ),
      'volume' => (
          (int.tryParse(look.params['step'] ?? '') ?? 10) < 0 ? Icons.volume_down : Icons.volume_up,
          false,
          sp['volume'] != null ? 'Vol ${sp['volume']}%' : 'Volume',
        ),
      'playlist' => (Icons.queue_music, false, 'Playlist'),
      _ => (sp['playing'] == true ? Icons.pause : Icons.play_arrow, false, 'Spotify'),
    };
    return look.tile(
      active: active,
      icon: look.hasOwnIcon ? look.icon() : Icon(icon, size: 30),
      label: look.ownLabel ?? label,
    );
  }
}

/// Twitch e YouTube: "só mostrar" acende ao vivo, com os espectadores.
class LiveButtonRenderer extends ButtonRenderer {
  final String stateEvent;
  final IconData statusIcon;

  const LiveButtonRenderer(this.stateEvent, this.statusIcon);

  @override
  Widget build(ButtonLook look) {
    final st = Injector.get<SignalRService>().stateOf(stateEvent);
    final op = look.op('');
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
          statusIcon,
          live
              ? (viewers != null ? tr('{n} assistindo', {'n': viewers}) : tr('Ao vivo'))
              : tr('Fora do ar'),
        ),
    };
    return look.tile(
      active: op == 'status' && live,
      icon: look.hasOwnIcon ? look.icon() : Icon(icon, size: 30),
      // No "só mostrar" o texto é o estado; nos outros vale o rótulo do usuário.
      label: op == 'status' ? label : (look.ownLabel ?? label),
    );
  }
}
