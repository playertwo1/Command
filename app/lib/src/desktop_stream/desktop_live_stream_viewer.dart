import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:command/core/i18n/i18n.dart';
import 'package:command/core/command_client/command_client.dart';
import 'desktop_stream_controller.dart';
import 'screen_coordinate_mapper.dart';

class DesktopLiveStreamViewer extends StatelessWidget {
  final DesktopStreamController controller;
  final String baseUrl;
  final String? apiKey;
  final CommandClient? client;

  const DesktopLiveStreamViewer({
    super.key,
    required this.controller,
    required this.baseUrl,
    this.apiKey,
    this.client,
  });

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DesktopFullScreenViewerPage(
          controller: controller,
          baseUrl: baseUrl,
          apiKey: apiKey,
          client: client,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.videocam_outlined, size: 20, color: Color(0xFFA78BFA)),
                        const SizedBox(width: 8),
                        Text(
                          tr('Tela ao Vivo'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (controller.isPlaying) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34D5A0).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF34D5A0).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF34D5A0),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${controller.fps} FPS',
                                  style: const TextStyle(
                                    color: Color(0xFF34D5A0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        PopupMenuButton<StreamQualityPreset>(
                          tooltip: tr('Qualidade do Stream'),
                          icon: const Icon(Icons.tune, size: 20),
                          onSelected: (preset) {
                            controller.setPreset(preset);
                            if (controller.isPlaying) {
                              controller.start(baseUrl: baseUrl, apiKey: apiKey);
                            }
                          },
                          itemBuilder: (context) => [
                            for (final preset in StreamQualityPreset.values)
                              PopupMenuItem(
                                value: preset,
                                child: Row(
                                  children: [
                                    if (preset == controller.preset)
                                      const Icon(Icons.check, size: 16, color: Color(0xFFA78BFA))
                                    else
                                      const SizedBox(width: 16),
                                    const SizedBox(width: 8),
                                    Text(preset.label),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen, size: 22),
                          tooltip: tr('Tela Cheia com Toque'),
                          onPressed: () => _openFullscreen(context),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr('Transmissão contínua em tempo real do monitor principal'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),

                // Caixa de erro, se houver
                if (controller.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            controller.errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFF87171),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Área do Vídeo/Frame
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: GestureDetector(
                    onTap: controller.isPlaying ? () => _openFullscreen(context) : null,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (controller.latestFrame != null)
                            Image.memory(
                              controller.latestFrame!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          else if (controller.isPlaying)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: Color(0xFFA78BFA)),
                                const SizedBox(height: 12),
                                Text(
                                  tr('Conectando ao stream do PC...'),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            )
                          else
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.tv_off, size: 40, color: Colors.white38),
                                const SizedBox(height: 8),
                                Text(
                                  tr('Transmissão pausada'),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          if (controller.latestFrame != null)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.touch_app, size: 14, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                      tr('Toque para tela cheia'),
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Barra de Ação
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.isPlaying
                          ? const Color(0xFFF87171).withValues(alpha: 0.15)
                          : const Color(0xFFA78BFA),
                      foregroundColor: controller.isPlaying ? const Color(0xFFF87171) : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow, size: 20),
                    label: Text(
                      controller.isPlaying ? tr('Pausar Transmissão') : tr('Assistir Tela ao Vivo'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (controller.isPlaying) {
                        controller.stop();
                      } else {
                        controller.start(baseUrl: baseUrl, apiKey: apiKey);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DesktopFullScreenViewerPage extends StatefulWidget {
  final DesktopStreamController controller;
  final String baseUrl;
  final String? apiKey;
  final CommandClient? client;

  const DesktopFullScreenViewerPage({
    super.key,
    required this.controller,
    required this.baseUrl,
    this.apiKey,
    this.client,
  });

  @override
  State<DesktopFullScreenViewerPage> createState() => _DesktopFullScreenViewerPageState();
}

class _DesktopFullScreenViewerPageState extends State<DesktopFullScreenViewerPage> {
  bool _touchToClickEnabled = true;
  Offset? _tapRipplePosition;
  Timer? _rippleTimer;
  String? _statusBannerMessage;
  Color _statusBannerColor = const Color(0xFFF87171);
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    _initSessionIfNeeded();
  }

  Future<void> _initSessionIfNeeded() async {
    if (widget.client != null && _touchToClickEnabled) {
      try {
        await widget.client!.startRemoteInputSession();
        _sessionStarted = true;
      } on RemoteInputLockedException catch (e) {
        _setStatusMessage(e.message, isError: true);
      } on RemoteInputForbiddenException catch (e) {
        _setStatusMessage(e.message, isError: true);
      } on RemoteInputConflictException catch (e) {
        _setStatusMessage(e.message, isError: true);
      } catch (_) {}
    }
  }

  void _setStatusMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _statusBannerMessage = message;
      _statusBannerColor = isError ? const Color(0xFFF87171) : const Color(0xFF34D5A0);
    });
  }

  void _clearStatusMessage() {
    if (_statusBannerMessage != null && mounted) {
      setState(() {
        _statusBannerMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _rippleTimer?.cancel();
    // R2.1: Encerrar stream ao sair da tela
    widget.controller.stop();
    if (_sessionStarted && widget.client != null) {
      widget.client!.endRemoteInputSession().catchError((_) => null);
    }
    super.dispose();
  }

  Future<void> _handleTapAt(Offset localPosition, Size containerSize, {String button = 'left'}) async {
    if (!_touchToClickEnabled) return;

    final client = widget.client;
    if (client == null) {
      _setStatusMessage(tr('Cliente de controle não configurado.'), isError: true);
      return;
    }

    final norm = ScreenCoordinateMapper.mapContainerToNormalized(
      localPosition: localPosition,
      containerSize: containerSize,
      imageAspectRatio: widget.controller.aspectRatio,
    );

    if (norm == null) {
      // Toque ocorreu na barra preta (letterbox/pillarbox)
      return;
    }

    // Feedback visual animado na coordenada exata do toque
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
      await client.sendMouseClick(
        button,
        normalizedX: norm.dx,
        normalizedY: norm.dy,
      );
      _clearStatusMessage();
    } on RemoteInputLockedException catch (e) {
      _setStatusMessage(e.message, isError: true);
    } on RemoteInputForbiddenException catch (e) {
      _setStatusMessage(e.message, isError: true);
    } on RemoteInputConflictException catch (e) {
      _setStatusMessage(e.message, isError: true);
    } catch (e) {
      _setStatusMessage('${tr("Falha ao enviar clique")}: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return Stack(
              children: [
                Center(
                  child: widget.controller.latestFrame != null
                      ? (_touchToClickEnabled
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
                                return GestureDetector(
                                  key: const ValueKey('desktop_preview_gesture_detector'),
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) {
                                    _handleTapAt(details.localPosition, containerSize, button: 'left');
                                  },
                                  onSecondaryTapUp: (details) {
                                    _handleTapAt(details.localPosition, containerSize, button: 'right');
                                  },
                                  onLongPressStart: (details) {
                                    HapticFeedback.mediumImpact();
                                    _handleTapAt(details.localPosition, containerSize, button: 'right');
                                  },
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        widget.controller.latestFrame!,
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
                                                color: const Color(0xFFA78BFA).withValues(alpha: 0.4),
                                                border: Border.all(color: const Color(0xFFA78BFA), width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFA78BFA).withValues(alpha: 0.6),
                                                    blurRadius: 10,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 6.0,
                              child: Image.memory(
                                widget.controller.latestFrame!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.controller.isPlaying)
                              const CircularProgressIndicator(color: Color(0xFFA78BFA))
                            else
                              const Icon(Icons.tv_off, size: 48, color: Colors.white38),
                            const SizedBox(height: 12),
                            Text(
                              widget.controller.isPlaying
                                  ? tr('Carregando stream...')
                                  : tr('Transmissão pausada'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                ),

                // Barra superior de ações
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.controller.isPlaying)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF34D5A0)),
                              ),
                              child: Text(
                                '${widget.controller.fps} FPS',
                                style: const TextStyle(
                                  color: Color(0xFF34D5A0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),

                          // Alternador de Modo: Toque para Clicar vs Zoom/Navegação
                          CircleAvatar(
                            backgroundColor: _touchToClickEnabled
                                ? const Color(0xFFA78BFA).withValues(alpha: 0.3)
                                : Colors.black54,
                            child: IconButton(
                              key: const ValueKey('desktop_mode_toggle_button'),
                              icon: Icon(
                                _touchToClickEnabled ? Icons.touch_app : Icons.pan_tool_outlined,
                                color: _touchToClickEnabled ? const Color(0xFFA78BFA) : Colors.white70,
                                size: 20,
                              ),
                              tooltip: _touchToClickEnabled
                                  ? tr('Toque-para-clicar ativo')
                                  : tr('Zoom/Navegação ativo'),
                              onPressed: () {
                                setState(() {
                                  _touchToClickEnabled = !_touchToClickEnabled;
                                });
                                if (_touchToClickEnabled) {
                                  _initSessionIfNeeded();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Menu de qualidade
                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: PopupMenuButton<StreamQualityPreset>(
                              tooltip: tr('Qualidade'),
                              icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                              onSelected: (preset) {
                                widget.controller.setPreset(preset);
                                if (widget.controller.isPlaying) {
                                  widget.controller.start(baseUrl: widget.baseUrl, apiKey: widget.apiKey);
                                }
                              },
                              itemBuilder: (context) => [
                                for (final preset in StreamQualityPreset.values)
                                  PopupMenuItem(
                                    value: preset,
                                    child: Row(
                                      children: [
                                        if (preset == widget.controller.preset)
                                          const Icon(Icons.check, size: 16, color: Color(0xFFA78BFA))
                                        else
                                          const SizedBox(width: 16),
                                        const SizedBox(width: 8),
                                        Text(preset.label),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: Icon(
                                widget.controller.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (widget.controller.isPlaying) {
                                  widget.controller.stop();
                                } else {
                                  widget.controller.start(baseUrl: widget.baseUrl, apiKey: widget.apiKey);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Mensagem de bloqueio / erro em banner
                if (_statusBannerMessage != null)
                  Positioned(
                    top: 68,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _statusBannerColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _statusBannerColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18, color: _statusBannerColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusBannerMessage!,
                              style: TextStyle(
                                color: _statusBannerColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Legenda de instrução de toque na base
                if (_touchToClickEnabled && widget.controller.latestFrame != null)
                  Positioned(
                    bottom: 16,
                    left: 24,
                    right: 24,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app, size: 16, color: Color(0xFFA78BFA)),
                            const SizedBox(width: 8),
                            Text(
                              tr('Toque: Clique esquerdo | Toque longo: Direito'),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
