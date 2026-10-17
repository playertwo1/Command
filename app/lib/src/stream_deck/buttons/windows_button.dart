import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import 'button_look.dart';

/// Ações do Windows: "trocar áudio" acende quando o dispositivo já é o padrão.
class WindowsButtonRenderer extends ButtonRenderer {
  const WindowsButtonRenderer();

  @override
  Widget build(ButtonLook look) {
    final ws = Injector.get<SignalRService>().stateOf('ReceiveWindowsState');
    final params = look.params;
    IconData icon;
    String label;
    var active = false;
    switch (look.op('setDefaultAudio')) {
      case 'lock':
        (icon, label) = (Icons.lock, tr('Travar'));
      case 'sleep':
        (icon, label) = (Icons.bedtime, tr('Suspender'));
      case 'displayoff':
        (icon, label) = (Icons.desktop_access_disabled, tr('Desligar tela'));
      default:
        final input = params['deviceKind'] == 'input';
        final current = ws[input ? 'defaultInput' : 'defaultOutput'];
        final alt = params['altDeviceId'];
        final hasAlt = alt != null && alt.isNotEmpty && alt != 'none';
        // Com alternância, o ícone diz qual dos dois está valendo; sem ela, o botão
        // acende quando o dispositivo escolhido já é o padrão.
        final onMain = current != null && current == params['deviceId'];
        active = !hasAlt && onMain;
        icon = input ? Icons.mic : (hasAlt && !onMain ? Icons.speaker : Icons.headphones);
        label = input ? tr('Microfone') : tr('Saída de áudio');
    }
    return look.tile(
      active: active,
      icon: look.hasOwnIcon ? look.icon() : Icon(icon, size: 30),
      label: look.ownLabel ?? label,
    );
  }
}
