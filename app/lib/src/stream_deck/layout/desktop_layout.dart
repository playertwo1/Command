import 'package:companion/src/stream_deck/stream_deck_controller.dart';
import 'package:companion/src/stream_deck/widgets/button_property_panel.dart';
import 'package:companion/src/stream_deck/widgets/dynamic_deck_button.dart';
import 'package:companion/src/services/signalr_service.dart';
import 'package:companion/src/config/appearance_settings_page.dart';
import 'package:companion/src/config/integrations_page.dart';
import 'package:companion/core/core.dart';
import 'package:companion/src/stream_deck/widgets/profile_settings_dialog.dart';
import 'package:companion/src/stream_deck/backup/backup_buttons.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class SteamDeckDesktopLayout extends StatefulWidget {
  final StreamDeckController controller;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;

  const SteamDeckDesktopLayout({
    super.key,
    required this.controller,
    required this.onToggleFullscreen,
    required this.isFullscreen,
  });

  @override
  State<SteamDeckDesktopLayout> createState() => _SteamDeckDesktopLayoutState();
}

class _SteamDeckDesktopLayoutState extends State<SteamDeckDesktopLayout> {
  DeckButton? _selectedButton;

  @override
  Widget build(BuildContext context) {
    final profiles = widget.controller.profiles.watch(context);
    final currentProfile = widget.controller.currentProfile.watch(context);
    final isLoading = widget.controller.isLoading.watch(context);

    if (isLoading && profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Row(
        children: [
          // Left Sidebar: Profiles
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(tr('PERFIS'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      final isSelected = profile.id == currentProfile?.id;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor:
                            Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        title: Text(profile.name),
                        trailing: IconButton(
                          icon: Icon(Icons.delete,
                              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          tooltip: tr('Excluir perfil'),
                          onPressed: () => _deleteProfile(profile),
                        ),
                        onTap: () {
                          widget.controller.switchProfile(profile.id);
                          setState(() {
                            _selectedButton = null;
                          });
                        },
                      );
                    },
                  ),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: _createNewProfile,
                    icon: Icon(Icons.add),
                    label: Text(tr('Novo perfil')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 40),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IntegrationsPage()),
                    ),
                    icon: const Icon(Icons.extension_outlined, size: 18),
                    label: Text(tr('Integrações')),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 36),
                      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                BackupButtons(
                  dense: true,
                  onImported: widget.controller.loadProfiles,
                ),
              ],
            ),
          ),

          // Center: Grid
          Expanded(
            child: Container(
              color: DeckTheme.of(context).background,
              child: Stack(
                children: [
                  Center(
                    child: currentProfile == null
                        ? Text(tr('Nenhum perfil selecionado'))
                        : _buildDeckGrid(currentProfile),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      children: [
                        // SIGNALR DEBUG INDICATOR
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Builder(builder: (context) {
                            final status = Injector.get<SignalRService>()
                                .connectionStatus
                                .watch(context);
                            final debugData = Injector.get<SignalRService>()
                                .lastDebugData
                                .watch(context); // Watch debug signal
                            Color color = Colors.grey;
                            if (status == "Connected") color = Colors.green;
                            if (status.startsWith("Conn Error"))
                              color = Colors.red;
                            return Tooltip(
                              message: "$status\n$debugData", // Show Data
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                            );
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.extension_outlined),
                          tooltip: tr('Integrações'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const IntegrationsPage()),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.palette_outlined),
                          tooltip: tr('Aparência'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AppearanceSettingsPage()),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit),
                          tooltip: tr('Perfil (nome e troca automática)'),
                          onPressed: () => _renameProfile(currentProfile),
                        ),
                        IconButton(
                          icon: Icon(widget.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen),
                          tooltip: widget.isFullscreen
                              ? tr('Sair da tela cheia')
                              : tr('Tela cheia'),
                          onPressed: widget.onToggleFullscreen,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          // Right Sidebar: Properties
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border(left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: _selectedButton == null
                ? Center(child: Text(tr('Selecione um botão para editar')))
                : ButtonPropertyPanel(
                    key: ValueKey(_selectedButton!
                        .id), // Force rebuild on selection change
                    button: _selectedButton!,
                    profiles: profiles,
                    onSave: (btn) {
                      widget.controller.updateButton(btn);
                      // Update local selection to reflect changes
                      setState(() {
                        _selectedButton = btn;
                      });
                    },
                    onCancel: () {
                      setState(() {
                        _selectedButton = null;
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckGrid(DeckProfile profile) {
    // A grade é definida pelo celular (quantos botões cabem na tela) e reportada
    // ao PC. Aqui só exibimos essa grade — não há seletor de tamanho.
    final lay = Injector.get<SignalRService>().deckLayout.watch(context);
    final cols = (lay['columns'] ?? 5);
    final rows = (lay['rows'] ?? 3);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(
            tr('Grade do celular: {cols} × {rows} (definida pelo aparelho)  ·  arraste para mover/trocar',
                {'cols': cols, 'rows': rows}),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 800, // Constrain width for desktop
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: rows * cols,
                itemBuilder: (context, index) {
                  final row = index ~/ cols;
                  final col = index % cols;
                  final existingButton = profile.buttons.firstWhereOrNull(
                    (b) => b.row == row && b.column == col,
                  );
                  return _buildSlot(row, col, existingButton);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(int row, int col, DeckButton? existing) {
    final isSelectedPos =
        _selectedButton?.row == row && _selectedButton?.column == col;

    void select(DeckButton b) => setState(() => _selectedButton = b);

    return DragTarget<DeckButton>(
      onWillAcceptWithDetails: (d) => d.data.row != row || d.data.column != col,
      onAcceptWithDetails: (d) {
        widget.controller.moveButton(d.data, row, col);
        setState(() => _selectedButton = null);
      },
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        final decoration = BoxDecoration(
          border: Border.all(
            color: highlight
                ? Colors.greenAccent
                : (isSelectedPos ? Theme.of(context).colorScheme.primary : Colors.transparent),
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        );

        // Slot vazio: a própria célula (InkWell) seleciona/cria um botão novo.
        if (existing == null) {
          return InkWell(
            onTap: () => select(
                DeckButton(id: '', row: row, column: col, label: '', action: null)),
            child: Container(
              decoration: decoration,
              child: const DeckEmptyTile(),
            ),
          );
        }

        // Botão existente: o PRÓPRIO botão trata o toque (seleciona para editar),
        // já que ele tem gesto interno. Fica arrastável para mover/trocar.
        final buttonWidget = Container(
          decoration: decoration,
          child: DynamicDeckButton(
            button: existing,
            onTap: () => select(existing),
            onLongPress: () => select(existing),
          ),
        );

        return Draggable<DeckButton>(
          data: existing,
          feedback: SizedBox(
            width: 90,
            height: 90,
            child: Opacity(
              opacity: 0.85,
              child: DynamicDeckButton(
                  button: existing, onTap: () {}, onLongPress: () {}),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: buttonWidget),
          child: buttonWidget,
        );
      },
    );
  }

  void _createNewProfile() {
    // Basic dialog for new profile
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Novo perfil')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: tr('Nome do perfil')),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                // Create profile logic
                // We don't have createProfile in controller yet, mimicking app.js logic
                // Ideally controller should handle this.
                // For now, let's just make a dummy profile and save it if controller allows.
                final newProfile = DeckProfile(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text,
                  rows: 3,
                  columns: 5,
                );
                widget.controller.updateProfileFull(
                    newProfile); // This acts as create/update
                Navigator.pop(ctx);
              }
            },
            child: Text(tr('Criar')),
          ),
        ],
      ),
    );
  }

  void _deleteProfile(DeckProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Excluir perfil?')),
        content: Text(tr(
            'Excluir "{name}"? Não dá para desfazer.', {'name': profile.name})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancelar'))),
          TextButton(
            onPressed: () {
              widget.controller.deleteProfile(profile.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(tr('Excluir')),
          ),
        ],
      ),
    );
  }

  void _renameProfile(DeckProfile? profile) {
    if (profile == null) return;
    ProfileSettingsDialog.show(
        context, profile, widget.controller.updateProfileFull);
  }
}
