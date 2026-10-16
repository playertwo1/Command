import 'dart:async';
import 'dart:convert';

import 'package:companion/core/core.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:flutter/material.dart';

/// Tipos de botão de informação (dynamicType) desenhados por [InfoDeckButton].
const infoTypes = {'clock', 'weather', 'now_playing', 'command', 'url'};

/// Botão que mostra uma informação ao vivo: relógio, clima, o que está tocando, a saída
/// de um comando ou um valor de uma URL. O relógio é calculado aqui; o resto vem do PC
/// (ReceiveInfoState / ReceiveNowPlaying). O toque executa a ação do botão, se houver.
class InfoDeckButton extends StatefulWidget {
  final DeckButton button;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Color? color;

  const InfoDeckButton({
    super.key,
    required this.button,
    required this.onTap,
    required this.onLongPress,
    this.color,
  });

  @override
  State<InfoDeckButton> createState() => _InfoDeckButtonState();
}

class _InfoDeckButtonState extends State<InfoDeckButton> {
  Timer? _clock;

  String get _type => widget.button.dynamicType ?? '';
  Map<String, String> get _params => widget.button.dynamicParameters ?? const {};

  @override
  void initState() {
    super.initState();
    if (_type == 'clock') {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeckTile(
      color: widget.color,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: switch (_type) {
        'clock' => _buildClock(),
        'now_playing' => Watch((_) => _buildNowPlaying(Injector.get<SignalRService>()
            .stateOf('ReceiveNowPlaying'))),
        _ => Watch((_) {
            final all = Injector.get<SignalRService>().stateOf('ReceiveInfoState');
            final v = all[widget.button.id];
            return _buildValue(v is Map ? Map<String, dynamic>.from(v) : null);
          }),
      },
    );
  }

  String? get _label =>
      (widget.button.label?.isNotEmpty ?? false) ? widget.button.label : null;

  Widget _small(String text, {double alpha = 0.7}) => Builder(
        builder: (context) => Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: DeckTile.foregroundOf(context).withValues(alpha: alpha),
          ),
        ),
      );

  Widget _big(String text, {int maxLines = 1}) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      );

  // ---- Relógio ----

  static const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  Widget _buildClock() {
    final now = DateTime.now();
    final h24 = _params['format24'] != 'false';
    final seconds = _params['showSeconds'] == 'true';
    final date = _params['showDate'] != 'false';
    String two(int n) => n.toString().padLeft(2, '0');
    final hour = h24 ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    var time = '${h24 ? two(hour) : hour}:${two(now.minute)}';
    if (seconds) time += ':${two(now.second)}';
    if (!h24) time += now.hour < 12 ? ' AM' : ' PM';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_label != null) _small(_label!),
          _big(time),
          if (date)
            // Dia/mês em português, mês/dia em inglês.
            _small('${tr(_weekdays[now.weekday - 1])}, ' +
                (AppLanguage.current.value == 'en'
                    ? '${two(now.month)}/${two(now.day)}'
                    : '${two(now.day)}/${two(now.month)}')),
        ],
      ),
    );
  }

  // ---- Clima, comando e URL ----

  Widget _buildValue(Map<String, dynamic>? v) {
    if (v == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          if (_label != null) ...[const SizedBox(height: 6), _small(_label!)],
        ],
      );
    }
    final text = '${v['text'] ?? ''}';
    final sub = v['sub'] as String?;
    final error = v['error'] == true;
    if (_type == 'weather' && !error) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(weatherIcon(v['code'] as int?, v['isDay'] != false), size: 26),
          _big(text),
          _small(_label ?? sub ?? ''),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_label != null) _small(_label!),
          if (error) ...[
            const Icon(Icons.error_outline, size: 22, color: Colors.amber),
            if (sub != null) _small(sub),
          ] else
            Flexible(
              child: text.length <= 8
                  ? _big(text)
                  : Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
            ),
        ],
      ),
    );
  }

  // ---- Tocando agora ----

  Widget _buildNowPlaying(Map<String, dynamic> np) {
    final title = np['title'] as String?;
    final artist = np['artist'] as String?;
    var thumb = np['thumbnailBase64'] as String?;
    if (thumb != null && thumb.startsWith('data:')) {
      thumb = thumb.substring(thumb.indexOf(',') + 1);
    }
    if (title == null || title.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_off, size: 28),
          const SizedBox(height: 4),
          _small(_label ?? tr('Nada tocando')),
        ],
      );
    }
    Widget? cover;
    if (thumb != null && thumb.isNotEmpty) {
      try {
        cover = Image.memory(base64Decode(thumb),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const Icon(Icons.music_note));
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: LayoutBuilder(builder: (context, c) {
              final side = c.maxWidth.isFinite ? c.maxWidth * 0.62 : 48.0;
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: side,
                  height: side,
                  child: Stack(fit: StackFit.expand, children: [
                    cover ?? const Icon(Icons.music_note, size: 28),
                    if (np['playing'] != true)
                      Container(
                        color: Colors.black45,
                        child: const Icon(Icons.pause, color: Colors.white),
                      ),
                  ]),
                ),
              );
            }),
          ),
          const SizedBox(height: 2),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          if (artist != null && artist.isNotEmpty) _small(artist),
        ],
      ),
    );
  }
}

/// Ícone do tempo pelo código WMO do Open-Meteo.
IconData weatherIcon(int? code, bool isDay) {
  if (code == null) return Icons.thermostat;
  if (code == 0) return isDay ? Icons.wb_sunny : Icons.nightlight_round;
  if (code <= 2) return isDay ? Icons.wb_cloudy : Icons.nights_stay;
  if (code == 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 67) return Icons.grain;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.umbrella;
  if (code == 85 || code == 86) return Icons.ac_unit;
  if (code >= 95) return Icons.thunderstorm;
  return Icons.cloud;
}
