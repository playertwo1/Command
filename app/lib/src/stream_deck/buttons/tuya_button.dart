import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import '../tuya_display.dart';
import 'button_look.dart';

/// Casa inteligente (Tuya): estado, nível e cor reais do aparelho.
class TuyaButtonRenderer extends ButtonRenderer {
  const TuyaButtonRenderer();

  (String, String)? _target(ButtonLook look) {
    final deviceId = look.params['deviceId'];
    final code = look.params['code'];
    return deviceId == null || code == null ? null : (deviceId, code);
  }

  Map<String, dynamic>? _device(Map<String, dynamic> state, String deviceId) {
    for (final d in (state['devices'] as List? ?? const [])) {
      if ((d as Map)['id'] == deviceId) return Map<String, dynamic>.from(d);
    }
    return null;
  }

  @override
  Widget build(ButtonLook look) {
    final target = _target(look);
    if (target == null) {
      // Ainda sem aparelho escolhido.
      return look.tile(active: false, icon: look.icon(), label: look.ownLabel);
    }
    final (deviceId, code) = target;
    final device = _device(Injector.get<SignalRService>().tuyaState.value, deviceId);
    final status = device?['status'] as Map? ?? const {};
    final functions = device?['functions'] as Map? ?? const {};

    final on = tuyaIsOn(status, code);
    final level = tuyaLevel(status, functions, code);
    final rgb = tuyaColor(status);
    final label = look.ownLabel ?? (device?['name'] as String?);

    // A cor real (RGB) vence a "cor ativa": a sala pintada de roxo aparece roxa. Sobre
    // fundo claro o DeckTile já troca o texto para escuro.
    return DeckTile(
      color: look.color,
      active: on,
      activeColor: rgb ?? look.activeColor,
      onTap: look.onTap,
      onLongPress: look.onLongPress,
      child: Builder(builder: (context) {
        final fg = DeckTile.foregroundOf(context);
        return Stack(
          children: [
            // Preenchimento proporcional ao nível, do rodapé para cima. Apagado, some.
            if (level != null && on)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: level,
                  child: Container(color: fg.withValues(alpha: 0.18)),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tuyaIconFor(device?['category'] as String?, on), size: 24),
                  if (label != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, overflow: TextOverflow.ellipsis),
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

  @override
  void optimisticTap(ButtonLook look, SignalRService signalR) {
    // O push MQTT confirma em ~800 ms; sem isto o botão pareceria travado. Só no
    // "toggle": no "set" o valor é fixo e o push já traz a verdade.
    final target = _target(look);
    if (target == null || look.op('toggle') != 'toggle') return;
    final (deviceId, code) = target;
    final snapshot = Map<String, dynamic>.from(signalR.tuyaState.value);
    final devices = List<dynamic>.from(snapshot['devices'] as List? ?? const []);
    final index = devices.indexWhere((d) => (d as Map)['id'] == deviceId);
    if (index < 0) return;
    final device = Map<String, dynamic>.from(devices[index] as Map);
    final status = Map<String, dynamic>.from(device['status'] as Map? ?? const {});
    status[code] = !(status[code] == true);
    device['status'] = status;
    devices[index] = device;
    snapshot['devices'] = devices;
    signalR.tuyaState.value = snapshot;
  }
}
