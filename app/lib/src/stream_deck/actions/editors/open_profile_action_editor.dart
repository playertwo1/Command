import 'package:companion/src/stream_deck/actions/editors/action_editor.dart';
import 'package:flutter/material.dart';

class OpenProfileActionEditor extends StatefulWidget {
  final ActionEditorArgs args;

  const OpenProfileActionEditor({super.key, required this.args});

  @override
  State<OpenProfileActionEditor> createState() =>
      _OpenProfileActionEditorState();
}

class _OpenProfileActionEditorState extends State<OpenProfileActionEditor> {
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _profileId = widget.args.initial['profileId'];
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.args.profiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: profiles.any((p) => p.id == _profileId) ? _profileId : null,
          decoration: const InputDecoration(
            labelText: 'Abrir pasta/perfil',
            border: OutlineInputBorder(),
          ),
          items: profiles
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
              .toList(),
          onChanged: (val) {
            setState(() => _profileId = val);
            widget.args.onChanged({if (val != null) 'profileId': val});
          },
        ),
        const EditorHint(
            'Ao tocar, abre esse perfil como uma pasta (use um botão Voltar para retornar).'),
      ],
    );
  }
}
