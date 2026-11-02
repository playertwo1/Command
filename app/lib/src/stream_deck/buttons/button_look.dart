import 'dart:convert';

import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../actions/action_catalog.dart';
import 'button_icons.dart';
import 'colors.dart';

/// Como um tipo de ação desenha o botão no deck. Cada tipo com visual próprio (OBS,
/// Discord, Spotify...) tem o seu; os demais usam o [DefaultButtonRenderer].
///
/// Para um tipo novo: escreva um renderer e registre em `renderers.dart`.
abstract class ButtonRenderer {
  const ButtonRenderer();

  /// Desenha o botão. Roda dentro de um Watch: ler um signal aqui já redesenha quando
  /// ele muda.
  Widget build(ButtonLook look);

  /// Busca o estado inicial, se o tipo precisar (chamado uma vez por botão).
  void init(ButtonLook look) {}

  /// Atualiza o estado local na hora do toque, antes da confirmação do PC, para o
  /// botão não parecer travado. O PC corrige pelo broadcast depois.
  void optimisticTap(ButtonLook look, SignalRService signalR) {}
}

/// Tudo que um renderer precisa de um botão: dados, cores e o [tile] que monta o visual
/// com o estado ativo (inclusive o dos botões de dois estados).
class ButtonLook {
  final DeckButton button;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  ButtonLook({
    required this.button,
    required this.onTap,
    required this.onLongPress,
  });

  DeckAction? get action => button.action;
  String? get type => action?.type;
  Map<String, String> get params => action?.parameters ?? const {};

  /// Operação da ação, em minúsculas.
  String op(String fallback) => (params['operation'] ?? fallback).toLowerCase();

  Color? get color => parseHexColor(button.backgroundColor);
  Color? get activeColor => parseHexColor(button.activeColor);

  /// Rótulo escolhido pelo usuário (null se vazio).
  String? get ownLabel => (button.label?.isNotEmpty ?? false) ? button.label : null;

  bool get hasOwnIcon =>
      (button.iconName?.isNotEmpty ?? false) || (button.iconBase64?.isNotEmpty ?? false);

  /// Liga/desliga do botão de dois estados (guardado no PC).
  bool get toggledOn {
    if (!button.toggle) return false;
    try {
      return Injector.get<SignalRService>().stateOf('ReceiveButtonToggles')[button.id] ==
          true;
    } catch (_) {
      return false;
    }
  }

  /// O ícone escolhido pelo usuário; sem ele, [fallback] ou o ícone do tipo de ação.
  Widget icon({IconData? fallback, double size = 32}) {
    if (button.iconBase64?.isNotEmpty ?? false) return base64Icon(button.iconBase64!);
    if (button.iconName?.isNotEmpty ?? false) {
      return Icon(buttonIconData(button.iconName!), size: size);
    }
    if (fallback != null) return Icon(fallback, size: size);
    final schema = ActionCatalog.instance.find(type);
    if (schema != null && type != 'hotkey') return Icon(schema.iconData, size: size);
    return Builder(
      builder: (context) => Icon(Icons.touch_app,
          size: size, color: DeckTile.foregroundOf(context).withValues(alpha: 0.54)),
    );
  }

  /// Monta o botão no estado certo: ativo pelo estado da ação ou pelo liga/desliga do
  /// botão. Ativo, o rótulo e o ícone do estado ativo (se definidos) substituem os normais.
  Widget tile({
    required bool active,
    required Widget icon,
    String? label,
    Color? activeColor,
  }) {
    final on = active || toggledOn;
    if (on && (button.activeIconBase64?.isNotEmpty ?? false)) {
      icon = base64Icon(button.activeIconBase64!);
    } else if (on && (button.activeIconName?.isNotEmpty ?? false)) {
      icon = Icon(buttonIconData(button.activeIconName!), size: 32);
    }
    final text = button.hideLabel
        ? null
        : (on && (button.activeLabel?.isNotEmpty ?? false) ? button.activeLabel : label);
    final vertical = switch (button.labelVAlign) {
      'top' => MainAxisAlignment.start,
      'bottom' => MainAxisAlignment.end,
      _ => MainAxisAlignment.center,
    };
    final horizontal = switch (button.labelAlign) {
      'left' => CrossAxisAlignment.start,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };
    final textAlign = switch (button.labelAlign) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
    return DeckTile(
      color: color,
      active: on,
      activeColor: activeColor ?? this.activeColor,
      onTap: onTap,
      onLongPress: onLongPress,
      radius: button.cornerRadius?.toDouble(),
      borderWidth: button.borderWidth?.toDouble(),
      borderColor: parseHexColor(button.borderColor),
      haptic: button.haptic,
      child: Column(
        mainAxisAlignment: vertical,
        crossAxisAlignment: horizontal,
        children: [
          icon,
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final chosen = button.labelFontSize?.toDouble();
                final preferred = chosen ??
                    (constraints.maxWidth * 0.15).clamp(12.0, 16.0).toDouble();
                final fontSize = chosen ??
                    fitWordsFontSize(
                      text,
                      preferred,
                      constraints.maxWidth,
                      MediaQuery.textScalerOf(context),
                    );
                return Text(
                  text,
                  textAlign: textAlign,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Imagem quadrada que ocupa boa parte do botão (capa de jogo, de álbum).
  static Widget cover(String base64, {double fraction = 0.78, IconData fallback = Icons.image}) {
    return Flexible(
      child: LayoutBuilder(builder: (context, c) {
        final side = c.maxWidth.isFinite ? c.maxWidth * fraction : 64.0;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: side,
            height: side,
            child: Image.memory(
              base64Decode(stripDataUri(base64)),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(fallback),
            ),
          ),
        );
      }),
    );
  }

  static Widget base64Icon(String data, {double size = 32}) {
    try {
      final bytes = base64Decode(stripDataUri(data));
      if (buttonImageKind(bytes) == ButtonImageKind.svg) {
        return SvgPicture.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      }
      return Image.memory(
        bytes,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
      );
    } catch (_) {
      return const Icon(Icons.broken_image);
    }
  }

  /// Tira o "data:image/...;base64," da frente, quando vem.
  static String stripDataUri(String data) =>
      data.startsWith('data:') ? data.substring(data.indexOf(',') + 1) : data;

  /// Reduz o tamanho até a palavra mais larga caber, mantendo o mínimo de 12 px.
  static double fitWordsFontSize(
    String text,
    double preferred,
    double maxWidth,
    TextScaler scaler,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) return preferred;
    final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    bool fits(double size) {
      for (final word in words) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (painter.width > maxWidth) return false;
      }
      return true;
    }

    if (fits(preferred)) return preferred;
    if (!fits(12)) return 12;
    var low = 12.0;
    var high = preferred;
    for (var i = 0; i < 8; i++) {
      final mid = (low + high) / 2;
      if (fits(mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

enum ButtonImageKind { gif, svg, raster }

/// GIF animado, SVG ou imagem comum. O Image.memory do Flutter anima o GIF.
ButtonImageKind buttonImageKind(List<int> bytes) {
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return ButtonImageKind.gif;
  }
  final head = utf8
      .decode(bytes.take(180).toList(), allowMalformed: true)
      .trimLeft()
      .toLowerCase();
  if (head.startsWith('<svg') ||
      head.startsWith('<?xml') ||
      head.startsWith('<!doctype svg')) {
    return ButtonImageKind.svg;
  }
  return ButtonImageKind.raster;
}
