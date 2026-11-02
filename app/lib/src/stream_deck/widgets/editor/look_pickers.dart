import 'dart:convert';

import 'package:droiddeck/core/core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../buttons/button_icons.dart';
import '../../buttons/button_look.dart';
import '../../buttons/colors.dart';

/// PNG, JPG, GIF animado ou SVG. Acima de 512 KiB devolve null.
Future<String?> pickButtonImage() async {
  const group = XTypeGroup(
    label: 'Imagem',
    extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > 512 * 1024) return null;
  final kind = buttonImageKind(bytes);
  if (kind == ButtonImageKind.raster && bytes.length > 256 * 1024) return null;
  return base64Encode(bytes);
}

/// Grade com os ícones embutidos; o primeiro quadrado é "sem ícone".
class IconGrid extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  final double spacing;

  const IconGrid({
    super.key,
    required this.selected,
    required this.onSelect,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(String? name) {
      final isSelected = selected == name;
      return InkWell(
        onTap: () => onSelect(name),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.3)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? scheme.primary : scheme.outlineVariant),
          ),
          child: name == null
              ? Icon(Icons.block, color: scheme.onSurfaceVariant)
              : Icon(buttonIconData(name), color: scheme.onSurface),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: spacing, runSpacing: spacing, children: [option(null)]),
        for (final entry in iconCategories.entries) ...[
          const SizedBox(height: 8),
          Text(tr(entry.key), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: entry.value.map(option).toList(),
          ),
        ],
      ],
    );
  }
}

/// Prévia de uma imagem escolhida para o botão, com o "remover".
class ImagePreview extends StatelessWidget {
  final String base64;
  final VoidCallback onRemove;
  final double size;

  const ImagePreview({
    super.key,
    required this.base64,
    required this.onRemove,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(base64),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
              ),
            ),
          ),
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(tr('Remover imagem')),
          ),
        ],
      ),
    );
  }
}

/// Campo livre de cor. A paleta continua ao lado; aqui entra qualquer HEX.
class HexColorField extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const HexColorField({super.key, required this.color, required this.onChanged});

  @override
  State<HexColorField> createState() => _HexColorFieldState();
}

class _HexColorFieldState extends State<HexColorField> {
  late final TextEditingController _hex = TextEditingController(text: colorToHex(widget.color));

  @override
  void didUpdateWidget(HexColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = parseHexColor(_hex.text);
    if (shown?.toARGB32() != widget.color.toARGB32()) {
      _hex.text = colorToHex(widget.color);
    }
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _apply(String raw) {
    final parsed = parseHexColor(raw.trim());
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final alpha = widget.color.a.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _hex,
          decoration: InputDecoration(
            labelText: tr('Cor HEX'),
            hintText: '#A78BFA',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: _apply,
          onChanged: _apply,
        ),
        Row(
          children: [
            Text(tr('Opacidade'), style: const TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: alpha,
                onChanged: (value) => widget.onChanged(widget.color.withValues(alpha: value)),
              ),
            ),
            Text('${(alpha * 100).round()}%'),
          ],
        ),
      ],
    );
  }
}

/// Cores prontas para o fundo e para o estado ativo.
class ColorRow extends StatelessWidget {
  static final List<Color> palette = [
    Colors.grey[800]!,
    Colors.red[900]!,
    Colors.blue[900]!,
    Colors.green[900]!,
    Colors.orange[900]!,
    Colors.purple[900]!,
    Colors.black,
  ];

  final Color selected;
  final ValueChanged<Color> onSelect;

  const ColorRow({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: palette
          .map((c) => InkWell(
                onTap: () => onSelect(c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected == c ? Border.all(color: Colors.white, width: 2) : null,
                    boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

/// Como o botão fica desligado x ativo, com as cores escolhidas e o estilo do tema.
class ActivePreview extends StatelessWidget {
  final Color color;
  final Color activeColor;

  /// (ícone desligado, ícone ativo).
  final (IconData, IconData) icons;

  const ActivePreview({
    super.key,
    required this.color,
    required this.activeColor,
    required this.icons,
  });

  /// Ícones da prévia conforme a ação — espelha o deck.
  static (IconData, IconData) iconsFor(DeckAction? action) => switch (action?.type) {
        'discord' => action?.parameters['operation'] == 'toggleDeafen'
            ? (Icons.headset_mic, Icons.headset_off)
            : (Icons.mic, Icons.mic_off),
        'obs' => (Icons.fiber_manual_record_outlined, Icons.fiber_manual_record),
        'tuya' || 'homeassistant' => (Icons.lightbulb_outline, Icons.lightbulb),
        'timer' => (Icons.hourglass_bottom, Icons.alarm),
        'windows' => (Icons.headphones, Icons.headphones),
        _ => (Icons.volume_up, Icons.volume_off),
      };

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget chip(String label, bool active, IconData icon) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: DeckTile(
                color: color,
                active: active,
                activeColor: activeColor,
                child: Icon(icon, size: 26),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: muted)),
          ],
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: DeckTheme.of(context).background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          chip(tr('Desligado'), false, icons.$1),
          Icon(Icons.arrow_forward, color: muted, size: 20),
          chip(tr('Ativo'), true, icons.$2),
        ],
      ),
    );
  }
}
