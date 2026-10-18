import 'package:flutter/material.dart';
import 'package:droiddeck/core/i18n/i18n.dart';
import 'desktop_stream_controller.dart';

class DesktopLiveStreamViewer extends StatelessWidget {
  final DesktopStreamController controller;
  final String baseUrl;
  final String? apiKey;

  const DesktopLiveStreamViewer({
    super.key,
    required this.controller,
    required this.baseUrl,
    this.apiKey,
  });

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DesktopFullScreenViewerPage(
          controller: controller,
          baseUrl: baseUrl,
          apiKey: apiKey,
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
                          tooltip: tr('Tela Cheia'),
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
                      ],
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

class DesktopFullScreenViewerPage extends StatelessWidget {
  final DesktopStreamController controller;
  final String baseUrl;
  final String? apiKey;

  const DesktopFullScreenViewerPage({
    super.key,
    required this.controller,
    required this.baseUrl,
    this.apiKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 6.0,
                    child: controller.latestFrame != null
                        ? Image.memory(
                            controller.latestFrame!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (controller.isPlaying)
                                const CircularProgressIndicator(color: Color(0xFFA78BFA))
                              else
                                const Icon(Icons.tv_off, size: 48, color: Colors.white38),
                              const SizedBox(height: 12),
                              Text(
                                controller.isPlaying ? 'Carregando stream...' : 'Transmissão pausada',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                  ),
                ),
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
                          if (controller.isPlaying)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF34D5A0)),
                              ),
                              child: Text(
                                '${controller.fps} FPS',
                                style: const TextStyle(
                                  color: Color(0xFF34D5A0),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: Icon(
                                controller.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
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
                    ],
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
