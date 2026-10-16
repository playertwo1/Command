import 'dart:convert';

import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/actions/action_catalog.dart';
import 'package:companion/src/stream_deck/actions/action_schema.dart';
import 'package:companion/src/stream_deck/actions/editors/action_editor.dart';
import 'package:companion/src/stream_deck/actions/schema_action_form.dart';
import 'package:flutter/material.dart';

/// Escolha de uma ação: o tipo (agrupado por categoria) e os campos dele. Um botão tem
/// uma destas para o toque e, opcionalmente, para o toque longo e o toque duplo.
///
/// Os campos vêm do catálogo do PC (GET /api/actions/schema): tipos simples viram um
/// formulário gerado ([SchemaActionForm]); os que precisam de tela própria (Discord,
/// Tuya, soundboard...) ficam em actions/editors/.
class ActionPicker extends StatefulWidget {
  final DeckAction? initial;

  /// Nova ação a cada mudança; null = "Nenhuma".
  final ValueChanged<DeckAction?> onChanged;

  /// Editando de fora do PC (celular): sem tipos que executam código.
  final bool remote;
  final List<DeckProfile> profiles;
  final ValueChanged<String> suggestLabel;
  final ValueChanged<String> suggestIcon;
  /// Rótulo do seletor; null = "Ação".
  final String? label;

  const ActionPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.remote,
    required this.suggestLabel,
    required this.suggestIcon,
    this.profiles = const [],
    this.label,
  });

  /// Abrir app, atalho, ativar janela e HTTP executam código (ou acessam a rede) a
  /// partir do PC. O backend só aceita criá-los ou alterá-los pelo configurador em
  /// localhost (ActionPolicy): no celular o seletor não oferece esses tipos e trava a
  /// ação dos botões que já os têm — o botão continua funcionando.
  static const privilegedTypes = {
    'hotkey',
    'launch_app',
    'launchApp',
    'activatewindow',
    'http',
  };

  static bool isPrivilegedType(String type) =>
      privilegedTypes.contains(type) ||
      (ActionCatalog.instance.find(type)?.privileged ?? false);

  static bool isPrivileged(DeckAction? action) {
    if (action == null) return false;
    if (isPrivilegedType(action.type)) return true;
    if (action.type != 'multi') return false;
    try {
      final steps = jsonDecode(action.parameters['steps'] ?? '[]') as List;
      return steps.any((s) => isPrivilegedType('${(s as Map)['type']}'));
    } catch (_) {
      return true;
    }
  }

  @override
  State<ActionPicker> createState() => _ActionPickerState();
}

class _ActionPickerState extends State<ActionPicker> {
  final _catalog = ActionCatalog.instance;
  late String _type;
  late Map<String, String> _params;
  late final bool _locked =
      widget.remote && ActionPicker.isPrivileged(widget.initial);

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _type = a == null || a.type == 'none'
        ? 'none'
        : (a.type == 'launchApp' ? 'launch_app' : a.type);
    _params = Map<String, String>.from(a?.parameters ?? const {});
  }

  void _emit() {
    if (_locked) return; // a ação travada segue como está
    widget.onChanged(
        _type == 'none' ? null : DeckAction(type: _type, parameters: Map.of(_params)));
  }

  void _selectType(String type) {
    setState(() {
      if (type != _type) _params = {};
      _type = type;
    });
    _emit();
  }

  void _setParams(Map<String, String> p) {
    setState(() => _params = p);
    _emit();
  }

  List<ActionSchema> get _available => _catalog.schemas.value
      .where((s) => !widget.remote || _locked || !s.privileged)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      _catalog.schemas.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_locked) ...[
            _lockedNotice(),
            const SizedBox(height: 16),
          ],
          _typePicker(context),
          const SizedBox(height: 16),
          _editor(),
        ],
      );
    });
  }

  /// Seletor de tipo agrupado por categoria.
  Widget _typePicker(BuildContext context) {
    final schemas = _available;
    final categories = <String, List<ActionSchema>>{};
    for (final s in schemas) {
      categories.putIfAbsent(s.category, () => []).add(s);
    }
    final known = schemas.any((s) => s.type == _type);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'none', child: Text(tr('Nenhuma'))),
      for (final entry in categories.entries) ...[
        DropdownMenuItem<String>(
          enabled: false,
          value: '__${entry.key}',
          child: Text(entry.key.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: muted)),
        ),
        for (final s in entry.value)
          DropdownMenuItem(
            value: s.type,
            child: Row(
              children: [
                Icon(s.iconData, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(s.title, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      // Tipo que este PC não anuncia (botão de uma versão mais nova/antiga).
      if (!known && _type != 'none')
        DropdownMenuItem(value: _type, child: Text(tr('{type} (desconhecido)', {'type': _type}))),
    ];

    return DropdownButtonFormField<String>(
      value: _type,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.label ?? tr('Ação'),
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: _locked
          ? null
          : (val) {
              if (val != null && !val.startsWith('__')) _selectType(val);
            },
    );
  }

  /// Campos do tipo escolhido: tela própria ou formulário gerado pelo schema.
  Widget _editor() {
    final schema = _catalog.find(_type);
    if (_locked || schema == null) return const SizedBox.shrink();

    // A chave pelo tipo recria o editor (e o estado dele) ao trocar de tipo.
    final key = ValueKey('editor_${schema.type}');
    final args = ActionEditorArgs(
      initial: _params,
      onChanged: _setParams,
      suggestLabel: widget.suggestLabel,
      suggestIcon: widget.suggestIcon,
      remote: widget.remote,
      profiles: widget.profiles,
    );

    final custom = schema.editor != null
        ? buildCustomActionEditor(schema.editor!, args)
        : null;
    if (custom != null) return KeyedSubtree(key: key, child: custom);

    if (schema.fields.isEmpty) {
      return schema.description != null
          ? EditorHint(schema.description!)
          : const SizedBox.shrink();
    }
    return SchemaActionForm(
      key: key,
      schema: schema,
      initial: _params,
      onChanged: _setParams,
    );
  }

  /// Aviso no lugar dos campos de uma ação que só pode mudar no PC.
  Widget _lockedNotice() {
    final a = widget.initial!;
    final String summary;
    switch (a.type) {
      case 'hotkey':
        summary = tr('Atalho: {keys}', {'keys': a.parameters['keys'] ?? ''});
      case 'launch_app':
      case 'launchApp':
        summary = tr('Abre: {path}', {'path': a.parameters['path'] ?? ''});
      case 'http':
        summary = tr('Requisição: {url}', {'url': a.parameters['url'] ?? ''});
      case 'multi':
        summary = tr('Multi-ação');
      default:
        summary = _catalog.find(a.type)?.title ?? a.type;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  tr('Ações que abrem programas, enviam atalhos ou fazem requisições '
                      'só podem ser alteradas no configurador do PC (http://localhost:4787). '
                      'Aqui você pode mudar o nome, o ícone e as cores.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
