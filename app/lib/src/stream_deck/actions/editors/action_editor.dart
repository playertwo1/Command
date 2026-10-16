import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/editors/discord_action_editor.dart';
import 'package:companion/src/stream_deck/actions/editors/mixer_action_editor.dart';
import 'package:companion/src/stream_deck/actions/editors/multi_action_editor.dart';
import 'package:companion/src/stream_deck/actions/editors/open_profile_action_editor.dart';
import 'package:companion/src/stream_deck/actions/editors/soundboard_action_editor.dart';
import 'package:companion/src/stream_deck/actions/editors/tuya_action_editor.dart';
import 'package:flutter/material.dart';

/// O que toda tela própria de ação recebe do painel.
class ActionEditorArgs {
  /// Parâmetros salvos no botão (vazio num botão novo).
  final Map<String, String> initial;

  /// Chamado a cada mudança com o conjunto completo de parâmetros.
  final ValueChanged<Map<String, String>> onChanged;

  /// Sugere um rótulo para o botão (ex.: nome do som escolhido), se ele estiver vazio.
  final ValueChanged<String> suggestLabel;

  /// Editando de fora do PC (celular): sem tipos que executam código.
  final bool remote;

  final List<DeckProfile> profiles;

  const ActionEditorArgs({
    required this.initial,
    required this.onChanged,
    required this.suggestLabel,
    required this.remote,
    this.profiles = const [],
  });
}

/// Tela própria pelo nome que o schema dá em `editor`. Null = nome desconhecido
/// (app mais antigo que o PC): o painel cai no formulário do schema.
Widget? buildCustomActionEditor(String editor, ActionEditorArgs args) {
  switch (editor) {
    case 'discord':
      return DiscordActionEditor(args: args);
    case 'mixer':
      return MixerActionEditor(args: args);
    case 'multi':
      return MultiActionEditor(args: args);
    case 'open_profile':
      return OpenProfileActionEditor(args: args);
    case 'soundboard':
      return SoundboardActionEditor(args: args);
    case 'tuya':
      return TuyaActionEditor(args: args);
  }
  return null;
}

/// Texto auxiliar pequeno, no tom secundário do tema.
class EditorHint extends StatelessWidget {
  final String text;

  const EditorHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
