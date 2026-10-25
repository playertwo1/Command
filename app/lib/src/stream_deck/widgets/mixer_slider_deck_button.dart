import 'dart:async';

import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/core/droiddeck_client/models/mixer_data.dart';
import 'package:droiddeck/core/ui/molecules/deck_tile.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/stream_deck/buttons/colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Controle local de volume do dispositivo escolhido no perfil atual.
/// Usa os endpoints tipados existentes do Mixer e fixa o cliente no PC atual.
class MixerSliderDeckButton extends StatefulWidget {
  final DeckButton button;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MixerSliderDeckButton({
    super.key,
    required this.button,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<MixerSliderDeckButton> createState() => _MixerSliderDeckButtonState();
}

class _MixerSliderDeckButtonState extends State<MixerSliderDeckButton> {
  DroidDeckClient? _client;
  String? _ownerPcId;
  int? _volume;
  bool _muted = false;
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  int? _pendingVolume;
  Timer? _debounce;
  String? _signature;

  Map<String, String> get _parameters =>
      widget.button.dynamicParameters ?? const <String, String>{};

  String get _deviceId => _parameters['deviceId'] ?? '';

  bool get _isInput => _parameters['deviceKind'] == 'input';

  String _makeSignature() =>
      '${PcStore.currentId}|${widget.button.id}|$_deviceId|${_isInput ? 'input' : 'output'}';

  @override
  void initState() {
    super.initState();
    _signature = _makeSignature();
    _loadDevice();
  }

  @override
  void didUpdateWidget(covariant MixerSliderDeckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _makeSignature();
    if (next != _signature) {
      _signature = next;
      _debounce?.cancel();
      _pendingVolume = null;
      _client = null;
      _volume = null;
      _loading = true;
      _failed = false;
      _loadDevice();
    }
  }

  Future<void> _loadDevice() async {
    final id = _deviceId;
    if (id.isEmpty) {
      if (mounted)
        setState(() {
          _loading = false;
          _failed = true;
        });
      return;
    }

    try {
      DroidDeckClient client;
      if (kIsWeb) {
        client = Injector.get<DroidDeckClient>();
        _ownerPcId = PcStore.currentId;
      } else {
        final pc = await PcStore.current();
        if (pc == null) {
          client = Injector.get<DroidDeckClient>();
          _ownerPcId = PcStore.currentId;
        } else {
          client = DroidDeckClient(baseUrl: pc.baseUrl)..setApiKey(pc.apiKey);
          _ownerPcId = pc.id;
        }
      }
      if (!mounted) return;
      _client = client;
      final current = _isInput
          ? await client.getInput(id)
          : await client.getOutput(id);
      if (!mounted) return;
      setState(() {
        _volume = current.volume.clamp(0, 100).toInt();
        _muted = current.mute;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool get _stillTargetsSelectedPc => kIsWeb || _ownerPcId == PcStore.currentId;

  void _queueVolume(double value) {
    final volume = value.round().clamp(0, 100).toInt();
    setState(() {
      _volume = volume;
      _failed = false;
    });
    _pendingVolume = volume;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), _drainQueue);
  }

  Future<void> _drainQueue() async {
    if (_sending || _pendingVolume == null) return;
    _sending = true;
    try {
      while (_pendingVolume != null) {
        final volume = _pendingVolume!;
        _pendingVolume = null;
        final client = _client;
        if (client == null || !_stillTargetsSelectedPc) {
          if (mounted) setState(() => _failed = true);
          break;
        }
        try {
          final result = _isInput
              ? await client.setInput(_deviceId, MixerData(volume: volume))
              : await client.setOutput(_deviceId, MixerData(volume: volume));
          if (mounted) {
            setState(() {
              _volume = result.volume.clamp(0, 100).toInt();
              _muted = result.mute;
              _failed = false;
            });
          }
        } catch (_) {
          _pendingVolume = null;
          if (mounted) setState(() => _failed = true);
          break;
        }
      }
    } finally {
      _sending = false;
      if (_pendingVolume != null) _drainQueue();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final volume = (_volume ?? 0).clamp(0, 100).toInt().toDouble();
    final label = widget.button.label?.trim().isNotEmpty == true
        ? widget.button.label!.trim()
        : tr('Volume do dispositivo');
    final foreground = DeckTile.foregroundOf(context);
    final status = _failed
        ? tr('Volume indisponível')
        : _loading
        ? tr('Carregando volume…')
        : '${volume.round()}%${_muted ? ' · ${tr('Mudo')}' : ''}';

    return DeckTile(
      color: parseHexColor(widget.button.backgroundColor),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: foreground.withValues(alpha: 0.8),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Slider(
                      value: volume,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${volume.round()}%',
                      semanticFormatterCallback: (value) => '${value.round()}%',
                      onChanged: _failed ? null : _queueVolume,
                      onChangeEnd: _failed
                          ? null
                          : (_) {
                              _debounce?.cancel();
                              _drainQueue();
                            },
                    ),
            ),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: _failed
                    ? Theme.of(context).colorScheme.error
                    : foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
