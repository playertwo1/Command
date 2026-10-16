import 'package:droiddeck/src/stream_deck/actions/action_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final obs = ActionSchema.fromJson({
    'type': 'obs',
    'title': 'OBS Studio',
    'icon': 'videocam',
    'category': 'Streaming',
    'stateful': true,
    'settings': 'obs',
    'stateEvent': 'ReceiveObsState',
    'fields': [
      {
        'key': 'operation',
        'label': 'Ação',
        'kind': 'select',
        'default': 'setScene',
        'options': [
          {'value': 'setScene', 'label': 'Trocar de cena'},
          {'value': 'toggleRecord', 'label': 'Gravar'},
        ],
      },
      {
        'key': 'scene',
        'label': 'Cena',
        'kind': 'select',
        'optionsSource': '/api/obs/scenes',
        'visibleWhen': {
          'operation': ['setScene']
        },
      },
    ],
  });

  test('lê o schema do servidor', () {
    expect(obs.type, 'obs');
    expect(obs.stateful, isTrue);
    expect(obs.stateEvent, 'ReceiveObsState');
    expect(obs.fields, hasLength(2));
    expect(obs.fields.first.options.map((o) => o.value),
        ['setScene', 'toggleRecord']);
  });

  test('valores padrão de um botão novo', () {
    expect(obs.defaults(), {'operation': 'setScene'});
  });

  test('campo condicional aparece só com o valor certo', () {
    final scene = obs.fields[1];
    expect(scene.isVisible({'operation': 'setScene'}), isTrue);
    expect(scene.isVisible({'operation': 'toggleRecord'}), isFalse);
    expect(scene.isVisible({}), isFalse);
  });

  test('opções aceitam string, {value,label} e {name}', () {
    expect(FieldOption.fromJson('Cena 1').value, 'Cena 1');
    final full = FieldOption.fromJson({'value': 'id1', 'label': 'Fone'});
    expect((full.value, full.label), ('id1', 'Fone'));
    final obsInput = FieldOption.fromJson({'name': 'Mic/Aux'});
    expect((obsInput.value, obsInput.label), ('Mic/Aux', 'Mic/Aux'));
  });

  test('ícone desconhecido cai no genérico', () {
    expect(actionIcon('nao-existe'), actionIcon('extension'));
  });

  test('catálogo embutido cobre os tipos dos servidores antigos', () {
    final types = fallbackActionCatalog.map((s) => s.type).toSet();
    expect(
        types,
        containsAll([
          'hotkey', 'launch_app', 'media', 'mixer', 'multi', 'discord', //
          'obs', 'soundboard', 'tuya', 'open_profile', 'back',
        ]));
  });
}
