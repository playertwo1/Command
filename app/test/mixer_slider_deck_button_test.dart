import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/stream_deck/widgets/editor/info_section.dart';
import 'package:droiddeck/src/stream_deck/widgets/mixer_slider_deck_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final getIt = GetIt.I;
  late _MixerClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'pc_current': 'pc-1'});
    PcStore.currentId = null;
    if (getIt.isRegistered<DroidDeckClient>()) {
      await getIt.unregister<DroidDeckClient>();
    }
    client = _MixerClient();
    getIt.registerSingleton<DroidDeckClient>(client);
  });

  tearDown(() async {
    PcStore.currentId = null;
    if (getIt.isRegistered<DroidDeckClient>()) {
      await getIt.unregister<DroidDeckClient>();
    }
  });

  testWidgets('settings select input and output devices explicitly', (
    tester,
  ) async {
    final published = <Map<String, String>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MixerSliderSettings(
            parameters: const {},
            onChanged: published.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(2));

    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrada (microfone)').last);
    await tester.pumpAndSettle();
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Microfone USB').last);
    await tester.pumpAndSettle();

    expect(published.last, {'deviceKind': 'input', 'deviceId': 'mic-usb'});
    expect(client.listOutputsCalls, 1);
    expect(client.listInputsCalls, 1);

    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saída (alto-falante/fone)').last);
    await tester.pumpAndSettle();
    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alto-falante USB').last);
    await tester.pumpAndSettle();

    expect(published.last, {'deviceKind': 'output', 'deviceId': 'speaker-usb'});
  });

  testWidgets(
    'output slider exposes percentage and writes bounded volume to selected PC',
    (tester) async {
      await tester.pumpWidget(
        _sliderApp(kind: 'output', deviceId: 'speaker-usb'),
      );
      await tester.pumpAndSettle();

      expect(client.getOutputIds, ['speaker-usb']);
      expect(client.getInputIds, isEmpty);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, 0);
      expect(slider.max, 100);
      expect(slider.divisions, 100);
      expect(slider.semanticFormatterCallback?.call(45), '45%');
      expect(slider.semanticFormatterCallback?.call(100), '100%');

      await tester.drag(find.byType(Slider), const Offset(1000, 0));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(client.outputWrites, [
        const _MixerWrite(deviceId: 'speaker-usb', volume: 100),
      ]);

      // A change of selected PC invalidates this widget's captured owner.
      PcStore.currentId = 'pc-2';
      await tester.drag(find.byType(Slider), const Offset(-1000, 0));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(client.outputWrites, hasLength(1));
    },
  );

  testWidgets('input slider routes its value to the selected microphone', (
    tester,
  ) async {
    await tester.pumpWidget(_sliderApp(kind: 'input', deviceId: 'mic-usb'));
    await tester.pumpAndSettle();

    expect(client.getInputIds, ['mic-usb']);
    expect(client.getOutputIds, isEmpty);
    expect(find.byType(Slider), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(client.inputWrites, [
      const _MixerWrite(deviceId: 'mic-usb', volume: 0),
    ]);
  });
}

Widget _sliderApp({required String kind, required String deviceId}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 220,
          child: MixerSliderDeckButton(
            button: DeckButton(
              id: 'mixer-button',
              row: 0,
              column: 0,
              dynamicType: 'mixer_slider',
              dynamicParameters: {'deviceKind': kind, 'deviceId': deviceId},
              label: 'Volume',
            ),
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );

class _MixerClient extends DroidDeckClient {
  _MixerClient() : super(baseUrl: 'http://127.0.0.1');

  int listOutputsCalls = 0;
  int listInputsCalls = 0;
  final getOutputIds = <String>[];
  final getInputIds = <String>[];
  final outputWrites = <_MixerWrite>[];
  final inputWrites = <_MixerWrite>[];

  static final _speaker = _entity('speaker-usb', 'Alto-falante USB', 45);
  static final _microphone = _entity('mic-usb', 'Microfone USB', 63);

  @override
  Future<List<MixerEntity>> getOutputs() async {
    listOutputsCalls++;
    return [_speaker];
  }

  @override
  Future<List<MixerEntity>> getInputs() async {
    listInputsCalls++;
    return [_microphone];
  }

  @override
  Future<MixerEntity> getOutput(String id) async {
    getOutputIds.add(id);
    return _speaker;
  }

  @override
  Future<MixerEntity> getInput(String id) async {
    getInputIds.add(id);
    return _microphone;
  }

  @override
  Future<MixerMaster> setOutput(String id, MixerData data) async {
    outputWrites.add(_MixerWrite(deviceId: id, volume: data.volume!));
    return MixerMaster(volume: data.volume!, mute: false);
  }

  @override
  Future<MixerMaster> setInput(String id, MixerData data) async {
    inputWrites.add(_MixerWrite(deviceId: id, volume: data.volume!));
    return MixerMaster(volume: data.volume!, mute: false);
  }
}

MixerEntity _entity(String id, String title, int volume) => MixerEntity(
  device: MixerMaster(id: id, title: title, volume: volume, mute: false),
  config: MixerConfig(enabled: true),
  id: id,
  volume: volume,
  mute: false,
);

class _MixerWrite {
  const _MixerWrite({required this.deviceId, required this.volume});

  final String deviceId;
  final int volume;

  @override
  bool operator ==(Object other) =>
      other is _MixerWrite &&
      other.deviceId == deviceId &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(deviceId, volume);

  @override
  String toString() => '_MixerWrite($deviceId, $volume)';
}
