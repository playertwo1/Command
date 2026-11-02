import 'dart:convert';

import 'package:droiddeck/core/droiddeck_client/models/deck_action.dart';
import 'package:droiddeck/core/droiddeck_client/models/deck_button.dart';
import 'package:droiddeck/core/droiddeck_client/models/deck_profile.dart';
import 'package:droiddeck/src/stream_deck/buttons/button_look.dart';
import 'package:droiddeck/src/stream_deck/buttons/colors.dart';
import 'package:droiddeck/src/stream_deck/layout/grid_placement.dart';
import 'package:droiddeck/src/stream_deck/widgets/editor/look_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final button = DeckButton(
    id: 'b1',
    row: 0,
    column: 1,
    label: 'Cena',
    action: DeckAction(type: 'obs', parameters: {'operation': 'setScene'}),
    longPressAction: DeckAction(type: 'timer', parameters: {'operation': 'reset'}),
    doubleTapAction: DeckAction(type: 'media', parameters: {'command': 'next'}),
  );

  test('copyWith mantém os gestos', () {
    final moved = button.copyWith(row: 2, column: 3);
    expect((moved.row, moved.column), (2, 3));
    expect(moved.longPressAction?.type, 'timer');
    expect(moved.doubleTapAction?.type, 'media');
  });

  test('actionFor escolhe a ação do gesto', () {
    expect(button.actionFor('tap')?.type, 'obs');
    expect(button.actionFor('longPress')?.type, 'timer');
    expect(button.actionFor('doubleTap')?.type, 'media');
  });

  test('gestos e apps do perfil vão e voltam no JSON', () {
    final profile = DeckProfile(
        id: 'p', name: 'Live', buttons: [button], autoSwitchApps: ['obs64']);
    // Ida e volta como no cache offline e na API (jsonEncode chama os toJson aninhados).
    final json = jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>;
    final back = DeckProfile.fromJson(json);
    expect(back.autoSwitchApps, ['obs64']);
    expect(back.buttons.single.longPressAction?.parameters['operation'], 'reset');
    expect(back.buttons.single.doubleTapAction?.type, 'media');
  });

  test('copyWith do perfil mantém os apps', () {
    final profile = DeckProfile(id: 'p', autoSwitchApps: ['Code']);
    expect(profile.copyWith(name: 'Dev').autoSwitchApps, ['Code']);
    expect(profile.copyWith(name: 'Dev').useCustomGrid, isFalse);
  });

  test('grade fixa respeita 2×2 a 8×6 e a automática continua pela tela', () {
    final fixed = fitDeckGrid(width: 1000, height: 900, customColumns: 20, customRows: 1);
    expect(fixed.columns, 8);
    expect(fixed.rows, 2);

    final auto = fitDeckGrid(width: 400, height: 700);
    expect(auto.columns, inInclusiveRange(1, 20));
    expect(auto.rows, inInclusiveRange(1, 20));

    final profile = DeckProfile(id: 'p', rows: 6, columns: 8, useCustomGrid: true);
    final json = jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>;
    expect(DeckProfile.fromJson(json).useCustomGrid, isTrue);
    expect(DeckProfile.fromJson({'id': 'old', 'name': 'Antigo'}).useCustomGrid, isFalse);
  });

  test('HEX livre aceita cor com opacidade', () {
    expect(colorToHex(const Color(0xFFA78BFA)), '#A78BFA');
    expect(colorToHex(const Color(0x80A78BFA)), '#80A78BFA');
    expect(parseHexColor('#80A78BFA')?.toARGB32(), 0x80A78BFA);
    expect(parseHexColor('vermelho'), isNull);
  });

  test('visual do botão e fundo do perfil sobrevivem ao JSON', () {
    final button = DeckButton(
      id: 'b',
      row: 0,
      column: 0,
      label: 'CPU',
      hideLabel: true,
      labelFontSize: 8,
      labelAlign: 'left',
      cornerRadius: 40,
      borderWidth: 2,
      haptic: 'light',
      dynamicType: 'temp_monitor',
    );
    final back = DeckButton.fromJson(jsonDecode(jsonEncode(button.toJson())) as Map<String, dynamic>);
    expect(back.hideLabel, isTrue);
    expect(back.labelFontSize, 8);
    expect(back.cornerRadius, 40);
    expect(back.haptic, 'light');
    expect(back.dynamicType, 'temp_monitor');

    final bytes = utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"></svg>');
    expect(buttonImageKind(bytes), ButtonImageKind.svg);
    expect(buttonImageKind([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]), ButtonImageKind.gif);
  });

  test('espaço da grade fica entre 4 e 24', () {
    final tight = fitDeckGrid(width: 400, height: 700, spacing: 1);
    expect(tight.spacing, 4);
    final wide = fitDeckGrid(width: 400, height: 700, spacing: 40);
    expect(wide.spacing, 24);
  });

  testWidgets('campo HEX aplica a cor digitada', (tester) async {
    Color? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HexColorField(
          color: const Color(0xFF112233),
          onChanged: (color) => chosen = color,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '#A78BFA');
    await tester.pump();
    expect(chosen?.toARGB32(), 0xFFA78BFA);
  });
}
