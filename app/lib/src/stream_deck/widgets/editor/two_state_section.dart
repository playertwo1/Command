import 'package:companion/core/core.dart';
import 'package:flutter/material.dart';

import 'look_pickers.dart';

/// O que a seção "Dois estados" edita.
class TwoStateValue {
  final bool toggle;
  final DeckAction? activeAction;
  final String activeLabel;
  final String? activeIcon;
  final String? activeIconBase64;

  const TwoStateValue({
    this.toggle = false,
    this.activeAction,
    this.activeLabel = '',
    this.activeIcon,
    this.activeIconBase64,
  });

  factory TwoStateValue.of(DeckButton b) => TwoStateValue(
        toggle: b.toggle,
        activeAction: b.activeAction,
        activeLabel: b.activeLabel ?? '',
        activeIcon: b.activeIconName,
        activeIconBase64: b.activeIconBase64,
      );

  bool get used =>
      toggle || activeLabel.isNotEmpty || activeIcon != null || activeIconBase64 != null;

  TwoStateValue copyWith({
    bool? toggle,
    DeckAction? Function()? activeAction,
    String? activeLabel,
    String? Function()? activeIcon,
    String? Function()? activeIconBase64,
  }) =>
      TwoStateValue(
        toggle: toggle ?? this.toggle,
        activeAction: activeAction != null ? activeAction() : this.activeAction,
        activeLabel: activeLabel ?? this.activeLabel,
        activeIcon: activeIcon != null ? activeIcon() : this.activeIcon,
        activeIconBase64: activeIconBase64 != null ? activeIconBase64() : this.activeIconBase64,
      );
}

/// "Dois estados": liga/desliga a cada toque, ação do estado ligado e o visual quando ativo.
class TwoStateSection extends StatefulWidget {
  final TwoStateValue value;
  final ValueChanged<TwoStateValue> onChanged;

  /// A ação do botão já reflete um estado próprio (mudo, gravação, lâmpada...).
  final bool statefulAction;

  /// Monta o seletor de ação (o mesmo dos gestos).
  final Widget Function(String label, DeckAction? initial, ValueChanged<DeckAction?> onChanged)
      actionPicker;

  const TwoStateSection({
    super.key,
    required this.value,
    required this.onChanged,
    required this.statefulAction,
    required this.actionPicker,
  });

  @override
  State<TwoStateSection> createState() => _TwoStateSectionState();
}

class _TwoStateSectionState extends State<TwoStateSection> {
  late final _label = TextEditingController(text: widget.value.activeLabel);

  TwoStateValue get v => widget.value;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await pickButtonImage();
    if (image != null) {
      widget.onChanged(v.copyWith(activeIconBase64: () => image, activeIcon: () => null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final stateful = widget.statefulAction;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: v.used,
        shape: const Border(),
        leading: const Icon(Icons.toggle_on_outlined),
        title: Text(tr('Dois estados')),
        subtitle: Text(
          v.toggle
              ? tr('Liga e desliga a cada toque')
              : (stateful ? tr('Visual quando ativo') : tr('Opcional')),
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Alternar a cada toque')),
            subtitle: Text(
              stateful
                  ? tr('Esta ação já mostra o próprio estado; ligue só se quiser um '
                      'liga/desliga separado, guardado no PC.')
                  : tr('O botão fica ligado num toque e desligado no seguinte. O estado '
                      'fica no PC e aparece igual em todos os celulares.'),
              style: hint,
            ),
            value: v.toggle,
            onChanged: (t) => widget.onChanged(v.copyWith(toggle: t)),
          ),
          if (v.toggle) ...[
            const SizedBox(height: 8),
            widget.actionPicker(tr('Ação quando ligado'), v.activeAction,
                (a) => widget.onChanged(v.copyWith(activeAction: () => a))),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr('Roda no toque que desliga o botão. Sem ela, o mesmo toque roda sempre.'),
                style: hint,
              ),
            ),
          ],
          if (v.toggle || stateful) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: tr('Rótulo quando ativo'),
                hintText: tr('Vazio = o mesmo rótulo'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (t) => widget.onChanged(v.copyWith(activeLabel: t)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('Ícone quando ativo'), style: const TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_file),
                  label: Text(tr('Imagem')),
                ),
              ],
            ),
            if (v.activeIconBase64 != null)
              ImagePreview(
                base64: v.activeIconBase64!,
                size: 48,
                onRemove: () => widget.onChanged(v.copyWith(activeIconBase64: () => null)),
              ),
            const SizedBox(height: 8),
            IconGrid(
              selected: v.activeIcon,
              spacing: 8,
              onSelect: (name) => widget.onChanged(v.copyWith(
                activeIcon: () => name,
                activeIconBase64: name != null ? () => null : null,
              )),
            ),
          ],
        ],
      ),
    );
  }
}
