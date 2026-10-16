import 'package:companion/core/core.dart';
import 'package:flutter/material.dart';

/// Tema do app: preset, modo claro/escuro, cor de destaque e estilo dos botões.
/// Tudo vale na hora e fica salvo no aparelho.
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  ThemeController get _ctrl => ThemeController.instance;

  void _set(ThemeSettings next) => _ctrl.update(next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aparência'),
        actions: [
          TextButton(
            onPressed: () => _set(const ThemeSettings()),
            child: const Text('Restaurar'),
          ),
        ],
      ),
      body: Watch((context) {
        final s = _ctrl.settings.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const _DeckPreview(),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Layout'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.grid_view),
              title: const Text('Só o deck'),
              subtitle: const Text(
                'Esconde o controle de áudio e abre o deck em tela cheia. '
                'Toque no botão de tela cheia para ver o menu.',
              ),
              value: _ctrl.deckOnly.value,
              onChanged: _ctrl.setDeckOnly,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.vibration),
              title: const Text('Vibrar ao tocar'),
              subtitle: const Text('Também vibra forte quando um timer termina.'),
            ),
            SegmentedButton<Haptics>(
              segments: [
                for (final h in Haptics.values)
                  ButtonSegment(value: h, label: Text(h.label)),
              ],
              selected: {_ctrl.haptics.value},
              onSelectionChanged: (v) => _ctrl.setHaptics(v.first),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Modo'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('Sistema'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Escuro'),
                ),
              ],
              selected: {s.mode},
              onSelectionChanged: (v) => _set(s.copyWith(mode: v.first)),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Tema'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in kThemePresets)
                  _PresetCard(
                    preset: p,
                    selected: p.id == s.presetId,
                    // Trocar de tema volta destaque e estilo para os dele.
                    onTap: () => _set(
                      s.copyWith(
                        presetId: p.id,
                        accent: () => null,
                        tileStyle: () => null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Cor de destaque'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Swatch(
                  color: s.preset.accent,
                  selected: s.accent == null,
                  tooltip: 'Do tema',
                  badge: Icons.auto_awesome,
                  onTap: () => _set(s.copyWith(accent: () => null)),
                ),
                for (final c in kAccentChoices)
                  _Swatch(
                    color: c,
                    selected: s.accent?.toARGB32() == c.toARGB32(),
                    onTap: () => _set(s.copyWith(accent: () => c)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Estilo dos botões'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Do tema (${s.preset.tileStyle.label})'),
                  selected: s.tileStyle == null,
                  onSelected: (_) => _set(s.copyWith(tileStyle: () => null)),
                ),
                for (final st in DeckTileStyle.values)
                  ChoiceChip(
                    label: Text(st.label),
                    selected: s.tileStyle == st,
                    onSelected: (_) => _set(s.copyWith(tileStyle: () => st)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No estilo Moldura e Contorno, a cor de cada botão vira a cor do '
              'ícone e do detalhe do canto.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Uma faixa do deck com botões de exemplo, desenhada com o tema atual.
class _DeckPreview extends StatelessWidget {
  const _DeckPreview();

  @override
  Widget build(BuildContext context) {
    final deck = DeckTheme.of(context);
    Widget tile(
      IconData icon,
      String label,
      Color? color, {
      bool active = false,
    }) {
      return DeckTile(
        color: color,
        active: active,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final tiles = [
      tile(Icons.play_arrow, 'YouTube', const Color(0xFFE53935)),
      tile(Icons.discord, 'Discord', const Color(0xFF5865F2)),
      tile(Icons.mic_off, 'Mute', null, active: true),
      tile(Icons.volume_up, 'Volume', const Color(0xFFFDD835)),
      const DeckEmptyTile(),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: deck.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: AspectRatio(aspectRatio: 1, child: tiles[i])),
          ],
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Mini-amostra sempre no visual escuro do preset, com o estilo de botão dele.
    final sample = buildAppTheme(
      ThemeSettings(presetId: preset.id),
      Brightness.dark,
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: preset.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Theme(
              data: sample,
              child: Row(
                children: [
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DeckTile(
                        color: preset.accent,
                        child: const Icon(Icons.bolt, size: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: AspectRatio(aspectRatio: 1, child: DeckEmptyTile()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              preset.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
    this.badge,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final on = color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
    final swatch = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? Icon(Icons.check, color: on, size: 20)
            : (badge != null ? Icon(badge, color: on, size: 18) : null),
      ),
    );
    return tooltip == null ? swatch : Tooltip(message: tooltip!, child: swatch);
  }
}
