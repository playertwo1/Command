import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

import '../buttons/button_look.dart';
import '../buttons/renderers.dart';
import 'timer_deck_button.dart';

/// Um botão do deck. O visual de cada tipo de ação fica no renderer dele
/// (`buttons/renderers.dart`); aqui só se escolhe o renderer e se trata o toque.
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
  late ButtonLook _look;

  ButtonLook _makeLook() => ButtonLook(
        button: widget.button,
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
      );

  @override
  void initState() {
    super.initState();
    _look = _makeLook();
    rendererFor(widget.button.action?.type).init(_look);
  }

  @override
  void didUpdateWidget(DeckGridButton old) {
    super.didUpdateWidget(old);
    _look = _makeLook();
  }

  @override
  Widget build(BuildContext context) {
    // Timer/pomodoro/contador: relógio que anda sozinho, com widget próprio.
    if (widget.button.action?.type == 'timer') {
      return TimerDeckButton(
        button: widget.button,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        color: _look.color,
        activeColor: _look.activeColor,
      );
    }
    final renderer = rendererFor(widget.button.action?.type);
    // O renderer lê os signals de estado dentro deste Watch.
    return Watch((_) => renderer.build(_look));
  }

  /// Atualiza o estado na hora do toque (o PC confirma depois) e executa.
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
      rendererFor(widget.button.action?.type).optimisticTap(_look, sr);
    } catch (_) {}
    widget.onTap();
  }
}
