import 'dart:async';
import 'package:command/core/core.dart';
import 'package:command/src/connection/pc_store.dart';
import 'package:command/src/desktop_stream/desktop_stream_controller.dart';
import 'package:command/src/desktop_stream/screen_coordinate_mapper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RemoteInputStatus {
  connecting,
  connected,
  locked,
  forbidden,
  conflict,
  error,
}

/// Tela de Controle Remoto via Trackpad e Teclado Virtual (Fase R1 + R3 Live Screen).
class TrackpadPage extends StatefulWidget {
  final CommandClient? client;
  final SavedPc? initialPc;
  final List<SavedPc>? availablePcs;
  final CommandClient Function(SavedPc pc)? clientForPc;
  final DesktopStreamController? streamController;

  const TrackpadPage({
    super.key,
    this.client,
    this.initialPc,
    this.availablePcs,
    this.clientForPc,
    this.streamController,
  });

  @override
  State<TrackpadPage> createState() => _TrackpadPageState();
}

class _TrackpadPageState extends State<TrackpadPage> {
  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color background = Color(0xFF0F0D17);
  static const Color surface = Color(0xFF161424);
  static const Color trackpadColor = Color(0xFF13101C);
  static const Color buttonBg = Color(0xFF1E1B2E);
  static const Color borderColor = Color(0xFF2E2A4A);

  CommandClient? _client;
  SavedPc? _activePc;
  List<SavedPc> _availablePcs = [];

  late final DesktopStreamController _streamController;
  bool _createdLocalController = false;
  bool _directTouchMode = false;
  bool _streamEnabled = true;
  Offset? _tapRipplePosition;
  Timer? _rippleTimer;

  RemoteInputStatus _status = RemoteInputStatus.connecting;
  String? _statusMessage;
  bool _showKeyboardPanel = false;
  int _pointerCount = 0;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  static const List<String> _shortcuts = [
    'Esc',
    'Tab',
    'Alt+Tab',
    'Win',
    'Ctrl+C',
    'Ctrl+V',
    'Ctrl+Z',
    'Ctrl+A',
    'Enter',
    'Backspace',
  ];

  @override
  void initState() {
    super.initState();
    _activePc = widget.initialPc;
    _availablePcs = widget.availablePcs != null ? List.from(widget.availablePcs!) : [];
    _client = widget.client;

    if (widget.streamController != null) {
      _streamController = widget.streamController!;
    } else {
      _streamController = DesktopStreamController();
      _createdLocalController = true;
    }

    _bootstrapAndStartSession();
  }

  @override
  void dispose() {
    _rippleTimer?.cancel();
    _streamController.stop();
    if (_createdLocalController) {
      _streamController.dispose();
    }
    _textController.dispose();
    _textFocusNode.dispose();
    _endSession();
    super.dispose();
  }

  Future<void> _bootstrapAndStartSession() async {
    if (_activePc == null || _availablePcs.isEmpty) {
      try {
        final pcs = await PcStore.load();
        final current = await PcStore.current();
        if (mounted) {
          setState(() {
            _availablePcs = pcs;
            _activePc ??= current ?? (pcs.isNotEmpty ? pcs.first : null);
          });
        }
      } catch (_) {}
    }

    if (_client == null && _activePc != null) {
      if (widget.clientForPc != null) {
        _client = widget.clientForPc!(_activePc!);
      } else {
        _client = CommandClient(baseUrl: _activePc!.baseUrl)
          ..setApiKey(_activePc!.apiKey);
      }
    }

    await _startSession();
  }

  void _startStream() {
    if (!_streamEnabled || _activePc == null) return;
    final url = _activePc!.baseUrl;
    if (url.isEmpty) return;
    _streamController.start(
      baseUrl: url,
      apiKey: _activePc!.apiKey,
    );
  }

  Future<void> _startSession() async {
    if (_client == null) {
      setState(() {
        _status = RemoteInputStatus.error;
        _statusMessage = 'Bridge não configurada.';
      });
      return;
    }

    setState(() {
      _status = RemoteInputStatus.connecting;
      _statusMessage = null;
    });

    try {
      await _client!.startRemoteInputSession(deviceId: _activePc?.id);
      if (mounted) {
        setState(() {
          _status = RemoteInputStatus.connected;
          _statusMessage = null;
        });
        _startStream();
      }
    } on RemoteInputLockedException catch (e) {
      if (mounted) {
        setState(() {
          _status = RemoteInputStatus.locked;
          _statusMessage = e.message;
        });
      }
    } on RemoteInputForbiddenException catch (e) {
      if (mounted) {
        setState(() {
          _status = RemoteInputStatus.forbidden;
          _statusMessage = e.message;
        });
      }
    } on RemoteInputConflictException catch (e) {
      if (mounted) {
        setState(() {
          _status = RemoteInputStatus.conflict;
          _statusMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = RemoteInputStatus.error;
          _statusMessage = 'Falha ao iniciar sessão de controle remoto.';
        });
      }
    }
  }

  Future<void> _endSession() async {
    try {
      await _client?.endRemoteInputSession(deviceId: _activePc?.id);
    } catch (_) {}
  }

  Future<void> _switchPc(SavedPc pc) async {
    if (pc.id == _activePc?.id) return;
    await _endSession();
    _streamController.stop();

    setState(() {
      _activePc = pc;
      if (widget.clientForPc != null) {
        _client = widget.clientForPc!(pc);
      } else {
        _client = CommandClient(baseUrl: pc.baseUrl)..setApiKey(pc.apiKey);
      }
    });

    await _startSession();
  }

  void _handleException(Object e) {
    if (!mounted) return;
    if (e is RemoteInputLockedException) {
      setState(() {
        _status = RemoteInputStatus.locked;
        _statusMessage = e.message;
      });
    } else if (e is RemoteInputForbiddenException) {
      setState(() {
        _status = RemoteInputStatus.forbidden;
        _statusMessage = e.message;
      });
    } else if (e is RemoteInputConflictException) {
      setState(() {
        _status = RemoteInputStatus.conflict;
        _statusMessage = e.message;
      });
    } else if (e is RemoteInputTextTooLargeException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else if (e is RemoteInputRateLimitException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
  }

  Future<void> _sendMouseMove(double dx, double dy) async {
    if (_client == null || _status == RemoteInputStatus.locked || _status == RemoteInputStatus.forbidden) {
      return;
    }
    try {
      await _client!.sendMouseMove(dx, dy, deviceId: _activePc?.id);
    } catch (e) {
      _handleException(e);
    }
  }

  Future<void> _sendMouseClick(String button, {String action = 'click'}) async {
    if (_client == null || _status == RemoteInputStatus.locked || _status == RemoteInputStatus.forbidden) {
      return;
    }
    try {
      await _client!.sendMouseClick(button, action: action, deviceId: _activePc?.id);
    } catch (e) {
      _handleException(e);
    }
  }

  Future<void> _handleDirectTapAt(Offset localPosition, Size containerSize, {String button = 'left'}) async {
    if (_client == null || _status == RemoteInputStatus.locked || _status == RemoteInputStatus.forbidden) {
      return;
    }

    final norm = ScreenCoordinateMapper.mapContainerToNormalized(
      localPosition: localPosition,
      containerSize: containerSize,
      imageAspectRatio: _streamController.aspectRatio,
    );

    if (norm == null) {
      return;
    }

    setState(() {
      _tapRipplePosition = localPosition;
    });
    _rippleTimer?.cancel();
    _rippleTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _tapRipplePosition = null;
        });
      }
    });

    try {
      await _client!.sendMouseClick(
        button,
        normalizedX: norm.dx,
        normalizedY: norm.dy,
        deviceId: _activePc?.id,
      );
    } catch (e) {
      _handleException(e);
    }
  }

  Future<void> _sendMouseScroll(int deltaX, int deltaY) async {
    if (_client == null || _status == RemoteInputStatus.locked || _status == RemoteInputStatus.forbidden) {
      return;
    }
    try {
      await _client!.sendMouseScroll(deltaX, deltaY, deviceId: _activePc?.id);
    } catch (e) {
      _handleException(e);
    }
  }

  Future<void> _sendKey(String key) async {
    if (_client == null || _status == RemoteInputStatus.locked || _status == RemoteInputStatus.forbidden) {
      return;
    }
    try {
      await _client!.sendKeyInput(key, deviceId: _activePc?.id);
    } catch (e) {
      _handleException(e);
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.isEmpty) return;
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texto excede o limite máximo permitido de 500 caracteres.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await _client!.sendTextInput(text, deviceId: _activePc?.id);
      _textController.clear();
      _textFocusNode.unfocus();
    } catch (e) {
      _handleException(e);
    }
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;
    IconData icon;

    switch (_status) {
      case RemoteInputStatus.connecting:
        color = Colors.amber;
        text = 'Conectando';
        icon = Icons.sync;
        break;
      case RemoteInputStatus.connected:
        color = const Color(0xFF4ADE80);
        text = 'Conectado';
        icon = Icons.check_circle_outline;
        break;
      case RemoteInputStatus.locked:
        color = const Color(0xFFF87171);
        text = 'Bloqueado (423)';
        icon = Icons.lock_outline;
        break;
      case RemoteInputStatus.forbidden:
        color = const Color(0xFFFBBF24);
        text = 'ViewerOnly (403)';
        icon = Icons.visibility_outlined;
        break;
      case RemoteInputStatus.conflict:
        color = const Color(0xFFF87171);
        text = 'Conflito (409)';
        icon = Icons.warning_amber_rounded;
        break;
      case RemoteInputStatus.error:
        color = const Color(0xFFEF4444);
        text = 'Erro';
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPcSelector() {
    if (_availablePcs.length <= 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.computer, size: 14, color: amethystAccent),
            const SizedBox(width: 4),
            Text(
              _activePc?.name ?? 'PC',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<SavedPc>(
      key: const Key('pc-selector-button'),
      tooltip: 'Selecionar PC',
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderColor),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.computer, size: 14, color: amethystAccent),
            const SizedBox(width: 4),
            Text(
              _activePc?.name ?? 'PC',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
          ],
        ),
      ),
      itemBuilder: (context) => _availablePcs.map((pc) {
        final isSelected = pc.id == _activePc?.id;
        return PopupMenuItem<SavedPc>(
          value: pc,
          child: Row(
            children: [
              Icon(
                Icons.computer,
                size: 16,
                color: isSelected ? amethystAccent : Colors.white60,
              ),
              const SizedBox(width: 8),
              Text(
                pc.name,
                style: TextStyle(
                  color: isSelected ? amethystAccent : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onSelected: (pc) => _switchPc(pc),
    );
  }

  Widget _buildErrorBanner() {
    if (_statusMessage == null &&
        _status != RemoteInputStatus.locked &&
        _status != RemoteInputStatus.forbidden &&
        _status != RemoteInputStatus.conflict) {
      return const SizedBox.shrink();
    }

    final String message;
    final Color bannerColor;
    final IconData icon;

    if (_status == RemoteInputStatus.locked) {
      bannerColor = const Color(0xFFF87171);
      message = _statusMessage ?? 'Sessão do Windows bloqueada ou sem display ativo. Desbloqueie o PC localmente para habilitar o controle.';
      icon = Icons.lock_outline;
    } else if (_status == RemoteInputStatus.forbidden) {
      bannerColor = const Color(0xFFFBBF24);
      message = _statusMessage ?? 'Dispositivo com permissão somente leitura (ViewerOnly). Controle remoto não permitido.';
      icon = Icons.visibility_outlined;
    } else if (_status == RemoteInputStatus.conflict) {
      bannerColor = const Color(0xFFF87171);
      message = _statusMessage ?? 'Outro dispositivo já está controlando esta sessão.';
      icon = Icons.warning_amber_rounded;
    } else {
      bannerColor = const Color(0xFFEF4444);
      message = _statusMessage ?? 'Ocorreu um erro na sessão remota.';
      icon = Icons.error_outline;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: bannerColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: bannerColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: bannerColor,
            tooltip: 'Tentar reconectar',
            onPressed: _startSession,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackpadArea() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ListenableBuilder(
          listenable: _streamController,
          builder: (context, _) {
            final hasFrame = _streamEnabled && _streamController.latestFrame != null;

            return LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(constraints.maxWidth, constraints.maxHeight);

                return Listener(
                  onPointerDown: (_) => setState(() => _pointerCount++),
                  onPointerUp: (_) => setState(() => _pointerCount = (_pointerCount - 1).clamp(0, 10)),
                  onPointerCancel: (_) => setState(() => _pointerCount = (_pointerCount - 1).clamp(0, 10)),
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent) {
                      _sendMouseScroll(signal.scrollDelta.dx.round(), signal.scrollDelta.dy.round());
                    }
                  },
                  child: GestureDetector(
                    key: const Key('trackpad-gesture-area'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: _directTouchMode
                        ? null
                        : (details) {
                            if (_pointerCount >= 2) {
                              _sendMouseScroll(details.delta.dx.round(), details.delta.dy.round());
                            } else {
                              _sendMouseMove(details.delta.dx, details.delta.dy);
                            }
                          },
                    onTapUp: _directTouchMode
                        ? (details) => _handleDirectTapAt(details.localPosition, containerSize, button: 'left')
                        : null,
                    onSecondaryTapUp: _directTouchMode
                        ? (details) => _handleDirectTapAt(details.localPosition, containerSize, button: 'right')
                        : null,
                    onLongPressStart: _directTouchMode
                        ? (details) {
                            HapticFeedback.mediumImpact();
                            _handleDirectTapAt(details.localPosition, containerSize, button: 'right');
                          }
                        : null,
                    onTap: _directTouchMode ? null : () => _sendMouseClick('left'),
                    onSecondaryTap: _directTouchMode ? null : () => _sendMouseClick('right'),
                    onDoubleTap: _directTouchMode ? null : () => _sendMouseClick('right'),
                    onLongPress: _directTouchMode ? null : () => _sendMouseClick('right'),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: trackpadColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasFrame) ...[
                            Image.memory(
                              _streamController.latestFrame!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                            if (_tapRipplePosition != null)
                              Positioned(
                                left: _tapRipplePosition!.dx - 18,
                                top: _tapRipplePosition!.dy - 18,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: amethystAccent.withValues(alpha: 0.4),
                                      border: Border.all(color: amethystAccent, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: amethystAccent.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ] else ...[
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_streamEnabled && _streamController.isPlaying) ...[
                                    const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: amethystAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aguardando transmissão da tela...',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      Icons.touch_app,
                                      size: 40,
                                      color: amethystAccent.withValues(alpha: 0.35),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Trackpad Tátil',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Arraste para mover · Toque para clique esquerdo\n2 dedos ou duplo toque para clique direito',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          // Indicador de modo e FPS no canto superior direito
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasFrame && _streamController.fps > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF34D5A0).withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      '${_streamController.fps} FPS',
                                      style: const TextStyle(
                                        color: Color(0xFF34D5A0),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  key: const Key('mode-pill-toggle'),
                                  onTap: () {
                                    setState(() {
                                      _directTouchMode = !_directTouchMode;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _directTouchMode
                                            ? const Color(0xFF34D5A0).withValues(alpha: 0.6)
                                            : amethystAccent.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _directTouchMode ? Icons.touch_app : Icons.mouse,
                                          size: 13,
                                          color: _directTouchMode ? const Color(0xFF34D5A0) : amethystAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _directTouchMode ? 'Toque Direto' : 'Trackpad',
                                          style: TextStyle(
                                            color: _directTouchMode ? const Color(0xFF34D5A0) : amethystAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: background,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              key: const Key('left-click-button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: Colors.white,
                side: const BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _sendMouseClick('left'),
              child: const Text(
                'Clique Esquerdo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const Key('toggle-keyboard-button'),
            style: IconButton.styleFrom(
              backgroundColor: _showKeyboardPanel ? amethystAccent : buttonBg,
              foregroundColor: _showKeyboardPanel ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: borderColor),
              ),
              padding: const EdgeInsets.all(14),
            ),
            tooltip: 'Alternar Teclado',
            icon: const Icon(Icons.keyboard, size: 20),
            onPressed: () {
              setState(() {
                _showKeyboardPanel = !_showKeyboardPanel;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              key: const Key('right-click-button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBg,
                foregroundColor: Colors.white,
                side: const BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _sendMouseClick('right'),
              child: const Text(
                'Clique Direito',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardPanel() {
    if (!_showKeyboardPanel) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _shortcuts.map((shortcut) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    key: Key('shortcut-$shortcut'),
                    backgroundColor: buttonBg,
                    side: const BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    label: Text(
                      shortcut,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _sendKey(shortcut),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('remote-text-input'),
                  controller: _textController,
                  focusNode: _textFocusNode,
                  maxLength: 500,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Digite o texto para enviar ao PC...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: trackpadColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: amethystAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('send-text-button'),
                style: IconButton.styleFrom(
                  backgroundColor: amethystAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                tooltip: 'Enviar texto',
                icon: const Icon(Icons.send, size: 18),
                onPressed: _sendText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        title: const Text(
          'Trackpad & Teclado',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('toggle-stream-button'),
            tooltip: _streamEnabled ? 'Pausar vídeo' : 'Transmitir vídeo',
            icon: Icon(
              _streamEnabled ? Icons.videocam : Icons.videocam_off,
              color: _streamEnabled ? const Color(0xFF34D5A0) : Colors.white60,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _streamEnabled = !_streamEnabled;
                if (_streamEnabled) {
                  _startStream();
                } else {
                  _streamController.stop();
                }
              });
            },
          ),
          IconButton(
            key: const Key('toggle-input-mode-button'),
            tooltip: _directTouchMode ? 'Mudar para Trackpad' : 'Mudar para Toque Direto',
            icon: Icon(
              _directTouchMode ? Icons.touch_app : Icons.mouse,
              color: _directTouchMode ? const Color(0xFF34D5A0) : amethystAccent,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _directTouchMode = !_directTouchMode;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildPcSelector(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(child: _buildStatusBadge()),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildErrorBanner(),
            _buildTrackpadArea(),
            _buildKeyboardPanel(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }
}
