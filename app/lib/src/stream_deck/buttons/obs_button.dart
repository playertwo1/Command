import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import 'button_look.dart';

/// OBS: cena atual, gravando, ao vivo, câmera virtual, replay e pausa refletem o OBS.
class ObsButtonRenderer extends ButtonRenderer {
  const ObsButtonRenderer();

  @override
  Widget build(ButtonLook look) {
    final ds = Injector.get<SignalRService>().obsState.value;
    final params = look.params;
    String named(String key, String fallback) =>
        (params[key]?.isNotEmpty ?? false) ? params[key]! : fallback;

    final (IconData icon, bool active, String label) = switch (look.op('setScene')) {
      'setscene' => (
          Icons.movie_outlined,
          (params['scene']?.isNotEmpty ?? false) && ds['currentScene'] == params['scene'],
          named('scene', tr('Cena')),
        ),
      'togglerecord' => (
          Icons.fiber_manual_record,
          ds['recording'] == true,
          ds['recording'] == true ? tr('Gravando') : tr('Gravar'),
        ),
      'togglestream' => (
          Icons.sensors,
          ds['streaming'] == true,
          ds['streaming'] == true ? tr('No ar') : 'Live',
        ),
      'togglevirtualcam' => (Icons.videocam, ds['virtualCam'] == true, tr('Câmera virtual')),
      'togglereplaybuffer' => (Icons.history, ds['replayBuffer'] == true, 'Replay buffer'),
      'savereplay' => (Icons.save_alt, false, tr('Salvar replay')),
      'toggleinputmute' => (Icons.mic_off, false, named('inputName', tr('Mutar fonte'))),
      'togglesourcevisibility' => (Icons.visibility, false, named('sourceName', tr('Fonte'))),
      'togglefilter' => (Icons.auto_fix_high, false, named('filterName', tr('Filtro'))),
      'togglerecordpause' => (
          ds['recordPaused'] == true ? Icons.play_arrow : Icons.pause,
          ds['recordPaused'] == true,
          ds['recordPaused'] == true ? tr('Retomar') : tr('Pausar gravação'),
        ),
      'createchapter' => (Icons.bookmark_add, false, tr('Capítulo')),
      'screenshot' => (Icons.photo_camera, false, tr('Captura')),
      _ => (Icons.videocam, false, 'OBS'),
    };
    return look.tile(active: active, icon: Icon(icon, size: 30), label: look.ownLabel ?? label);
  }
}
