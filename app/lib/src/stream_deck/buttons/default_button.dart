import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import 'button_look.dart';

/// Botões sem visual próprio: atalho, abrir app, multi-ação, webhook, Steam (com a capa)...
class DefaultButtonRenderer extends ButtonRenderer {
  const DefaultButtonRenderer();

  @override
  Widget build(ButtonLook look) {
    final b = look.button;
    // Jogo da Steam: a capa ocupa o botão, não 32 px.
    final cover = look.type == 'steam' && (b.iconBase64?.isNotEmpty ?? false);
    return look.tile(
      active: false,
      icon: cover
          ? ButtonLook.cover(b.iconBase64!, fallback: Icons.sports_esports)
          : look.icon(),
      label: look.ownLabel,
    );
  }
}

/// Mídia: tocar/pausar reflete o que está tocando no Windows.
class MediaButtonRenderer extends ButtonRenderer {
  const MediaButtonRenderer();

  String _command(ButtonLook look) => (look.params['command'] ?? 'playpause').toLowerCase();

  bool _isPlayPause(String c) => c == 'playpause' || c == 'toggle';

  @override
  Widget build(ButtonLook look) {
    final c = _command(look);
    final IconData icon;
    final String label;
    switch (c) {
      case 'next':
        (icon, label) = (Icons.skip_next, tr('Próxima'));
      case 'previous':
        (icon, label) = (Icons.skip_previous, tr('Anterior'));
      case 'stop':
        (icon, label) = (Icons.stop, tr('Parar'));
      case 'pause':
        (icon, label) = (Icons.pause, 'Pause');
      case 'play':
        (icon, label) = (Icons.play_arrow, 'Play');
      default:
        // Pause quando está tocando, play quando parado.
        final playing = Injector.get<SignalRService>().mediaPlaying.value;
        (icon, label) = (playing ? Icons.pause : Icons.play_arrow, 'Play/Pause');
    }
    return look.tile(
      active: false,
      icon: look.icon(fallback: icon),
      label: look.ownLabel ?? label,
    );
  }

  @override
  void optimisticTap(ButtonLook look, SignalRService signalR) {
    if (_isPlayPause(_command(look))) signalR.mediaPlaying.value = !signalR.mediaPlaying.value;
  }
}

/// Mixer: o mudo de um app reflete o estado real; volume de dispositivo usa o ícone da operação.
class MixerButtonRenderer extends ButtonRenderer {
  const MixerButtonRenderer();

  /// Processo do botão de mudo de app, ou null.
  String? _muteProcess(ButtonLook look) {
    final op = look.op('toggleMute');
    final process = look.params['processName'];
    return process != null && process.isNotEmpty && op.contains('mute') ? process : null;
  }

  @override
  void init(ButtonLook look) {
    final process = _muteProcess(look);
    if (process == null) return;
    try {
      final sr = Injector.get<SignalRService>();
      if (sr.muteStates.value.containsKey(process)) return;
      Injector.get<DroidDeckClient>().getMuteState(process).then((muted) {
        if (muted == null) return;
        sr.muteStates.value = {...sr.muteStates.value, process: muted};
      }).catchError((_) {});
    } catch (_) {}
  }

  @override
  Widget build(ButtonLook look) {
    final process = _muteProcess(look);
    if (process != null) {
      final muted = Injector.get<SignalRService>().muteStates.value[process];
      return look.tile(
        active: muted == true,
        icon: muted == null
            ? look.icon()
            : Icon(muted ? Icons.volume_off : Icons.volume_up, size: 32),
        label: look.ownLabel,
      );
    }
    final hasDevice = (look.params['deviceId'] ?? '').isNotEmpty;
    final IconData? volumeIcon = !hasDevice
        ? null
        : switch (look.op('')) {
            'volumeup' => Icons.volume_up,
            'volumedown' => Icons.volume_down,
            'setvolume' => Icons.tune,
            _ => null,
          };
    return look.tile(
      active: false,
      icon: look.icon(fallback: volumeIcon),
      label: look.ownLabel,
    );
  }

  @override
  void optimisticTap(ButtonLook look, SignalRService signalR) {
    final process = _muteProcess(look);
    if (process == null) return;
    final op = look.op('toggleMute');
    final now = signalR.muteStates.value[process] == true;
    signalR.muteStates.value = {
      ...signalR.muteStates.value,
      process: op == 'mute' ? true : (op == 'unmute' ? false : !now),
    };
  }
}
