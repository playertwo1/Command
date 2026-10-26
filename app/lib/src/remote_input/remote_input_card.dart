import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/remote_input/trackpad_page.dart';
import 'package:flutter/material.dart';

/// Card elegante no tema Ametista para acesso rápido ao Trackpad e Teclado Remoto (Fase R1).
class RemoteInputCard extends StatelessWidget {
  final DroidDeckClient? client;
  final SavedPc? targetPc;
  final VoidCallback? onOpenTrackpad;

  const RemoteInputCard({
    super.key,
    this.client,
    this.targetPc,
    this.onOpenTrackpad,
  });

  static const Color amethystAccent = Color(0xFFA78BFA);
  static const Color cardBg = Color(0xFF161424);
  static const Color buttonBg = Color(0xFF1E1B2E);
  static const Color borderColor = Color(0xFF2E2A4A);

  @override
  Widget build(BuildContext context) {
    final pcName = targetPc?.name ?? 'PC selecionado';

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: amethystAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mouse,
                    color: amethystAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trackpad & Teclado Remoto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alvo: $pcName',
                        style: const TextStyle(
                          color: amethystAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Controle o cursor do mouse, cliques esquerdo/direito, atalhos do teclado e envio de texto sem fios com proteção contra bloqueio.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('open-trackpad-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.touch_app, color: amethystAccent, size: 20),
                label: const Text(
                  'Abrir Trackpad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onPressed: () {
                  if (onOpenTrackpad != null) {
                    onOpenTrackpad!();
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TrackpadPage(
                          client: client,
                          initialPc: targetPc,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
