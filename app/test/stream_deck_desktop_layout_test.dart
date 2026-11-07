import 'package:command/core/core.dart';
import 'package:command/src/stream_deck/widgets/button_property_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection changes reset unsaved panel state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _PanelHarness()));

    await tester.enterText(find.byType(TextField).first, 'Rascunho A');
    await tester.tap(find.byKey(const ValueKey('select-0-1')));
    await tester.pumpAndSettle();
    expect(_labelText(tester), 'Botão B');

    await tester.tap(find.byKey(const ValueKey('select-0-2')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rascunho novo');
    await tester.tap(find.byKey(const ValueKey('select-0-3')));
    await tester.pumpAndSettle();
    expect(_labelText(tester), isEmpty);
  });
}

String _labelText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

class _PanelHarness extends StatefulWidget {
  const _PanelHarness();

  @override
  State<_PanelHarness> createState() => _PanelHarnessState();
}

class _PanelHarnessState extends State<_PanelHarness> {
  final _buttons = [
    DeckButton(id: 'a', row: 0, column: 0, label: 'Botão A'),
    DeckButton(id: 'b', row: 0, column: 1, label: 'Botão B'),
    DeckButton(id: '', row: 0, column: 2, label: ''),
    DeckButton(id: '', row: 0, column: 3, label: ''),
  ];
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final button = _buttons[_selected];
    return Scaffold(
      body: Column(
        children: [
          Wrap(
            children: [
              for (var i = 0; i < _buttons.length; i++)
                TextButton(
                  key: ValueKey('select-0-$i'),
                  onPressed: () => setState(() => _selected = i),
                  child: Text('Selecionar $i'),
                ),
            ],
          ),
          Expanded(
            child: ButtonPropertyPanel(
              key: ButtonPropertyPanel.stateKeyFor(button),
              button: button,
              onSave: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}
