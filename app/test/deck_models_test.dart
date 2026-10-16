import 'dart:convert';

import 'package:droiddeck/core/droiddeck_client/models/deck_action.dart';
import 'package:droiddeck/core/droiddeck_client/models/deck_button.dart';
import 'package:droiddeck/core/droiddeck_client/models/deck_profile.dart';
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
  });
}
