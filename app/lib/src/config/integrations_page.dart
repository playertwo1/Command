import 'package:flutter/material.dart';

import 'account_integration_page.dart';
import 'discord_settings_page.dart';
import 'obs_settings_page.dart';
import 'soundboard_settings_page.dart';
import 'tuya_settings_page.dart';

/// Lista de todas as integrações, com o atalho para a tela de cada uma.
class IntegrationsPage extends StatelessWidget {
  const IntegrationsPage({super.key});

  /// Tela de configuração pela chave usada no schema (`settings`).
  static Widget? pageFor(String? key) => switch (key) {
        'obs' => const ObsSettingsPage(),
        'discord' => const DiscordSettingsPage(),
        'tuya' => const TuyaSettingsPage(),
        'soundboard' => const SoundboardSettingsPage(),
        'homeassistant' => const AccountIntegrationPage(spec: homeAssistantSpec),
        'spotify' => const AccountIntegrationPage(spec: spotifySpec),
        'twitch' => const AccountIntegrationPage(spec: twitchSpec),
        'youtube' => const AccountIntegrationPage(spec: youTubeSpec),
        _ => null,
      };

  static const _entries = [
    ('discord', Icons.headset_mic, 'Discord', 'Mute, canais de voz, volume por usuário'),
    ('obs', Icons.videocam, 'OBS Studio', 'Cenas, gravação, transmissão, fontes'),
    ('twitch', Icons.sensors, 'Twitch', 'Marcador, clipe, anúncio, chat e enquete'),
    ('youtube', Icons.smart_display_outlined, 'YouTube', 'Chat da live e espectadores'),
    ('spotify', Icons.music_note, 'Spotify', 'Player, curtir, playlists e capa no botão'),
    ('soundboard', Icons.library_music, 'Soundboard', 'Sons do MyInstants: saída e volume'),
    ('homeassistant', Icons.home_outlined, 'Home Assistant', 'Luzes, cenas, scripts e sensores'),
    ('tuya', Icons.lightbulb_outline, 'Casa inteligente (Tuya)', 'Smart Life, Nova Digital e outras marcas'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrações')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            children: [
              for (final (key, icon, title, subtitle) in _entries)
                ListTile(
                  leading: Icon(icon),
                  title: Text(title),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => pageFor(key)!)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
