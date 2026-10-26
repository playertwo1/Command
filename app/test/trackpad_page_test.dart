import 'package:droiddeck/core/core.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/remote_input/remote_input_card.dart';
import 'package:droiddeck/src/remote_input/trackpad_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockRemoteInputClient extends DroidDeckClient {
  MockRemoteInputClient({super.baseUrl = 'https://test.deck'});

  final List<String> calls = [];
  final List<Map<String, dynamic>> moveCalls = [];
  final List<Map<String, dynamic>> clickCalls = [];
  final List<Map<String, dynamic>> scrollCalls = [];
  final List<String> keyCalls = [];
  final List<String> textCalls = [];

  bool throwOnStart = false;
  Exception? startException;

  @override
  Future<RemoteControlSessionInfo> startRemoteInputSession({String? deviceId}) async {
    calls.add('startRemoteInputSession');
    if (throwOnStart && startException != null) {
      throw startException!;
    }
    return RemoteControlSessionInfo(
      sessionId: 'sess-test',
      deviceId: deviceId ?? 'dev-test',
      timeoutSeconds: 60,
      isActive: true,
    );
  }

  @override
  Future<void> endRemoteInputSession({String? deviceId}) async {
    calls.add('endRemoteInputSession');
  }

  @override
  Future<void> sendMouseMove(double dx, double dy, {String? deviceId}) async {
    calls.add('sendMouseMove');
    moveCalls.add({'dx': dx, 'dy': dy});
  }

  @override
  Future<void> sendMouseClick(
    String button, {
    String action = 'click',
    double? normalizedX,
    double? normalizedY,
    String? deviceId,
  }) async {
    calls.add('sendMouseClick');
    final map = <String, dynamic>{'button': button, 'action': action};
    if (normalizedX != null) map['normalizedX'] = normalizedX;
    if (normalizedY != null) map['normalizedY'] = normalizedY;
    clickCalls.add(map);
  }

  @override
  Future<void> sendMouseScroll(int deltaX, int deltaY, {String? deviceId}) async {
    calls.add('sendMouseScroll');
    scrollCalls.add({'deltaX': deltaX, 'deltaY': deltaY});
  }

  @override
  Future<void> sendKeyInput(String key, {String? deviceId}) async {
    calls.add('sendKeyInput');
    keyCalls.add(key);
  }

  @override
  Future<void> sendTextInput(String text, {String? deviceId}) async {
    calls.add('sendTextInput');
    textCalls.add(text);
  }
}

void main() {
  const pcA = SavedPc(id: 'pc-1', name: 'Desktop Alpha', ip: '192.168.1.10', port: '4787');
  const pcB = SavedPc(id: 'pc-2', name: 'Laptop Beta', ip: '192.168.1.20', port: '4787');

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('TrackpadPage UI & Gestures', () {
    testWidgets('renders trackpad page, buttons, and connects on init', (tester) async {
      final client = MockRemoteInputClient();

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            client: client,
            initialPc: pcA,
            availablePcs: const [pcA],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trackpad & Teclado'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(find.text('Desktop Alpha'), findsOneWidget);
      expect(find.byKey(const Key('trackpad-gesture-area')), findsOneWidget);
      expect(find.byKey(const Key('left-click-button')), findsOneWidget);
      expect(find.byKey(const Key('right-click-button')), findsOneWidget);
      expect(find.byKey(const Key('toggle-keyboard-button')), findsOneWidget);

      expect(client.calls, contains('startRemoteInputSession'));
    });

    testWidgets('mouse clicks via bottom buttons and trackpad tap', (tester) async {
      final client = MockRemoteInputClient();

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            client: client,
            initialPc: pcA,
            availablePcs: const [pcA],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clique esquerdo pelo botão inferior
      await tester.tap(find.byKey(const Key('left-click-button')));
      await tester.pump();
      expect(client.clickCalls.last, {'button': 'left', 'action': 'click'});

      // Clique direito pelo botão inferior
      await tester.tap(find.byKey(const Key('right-click-button')));
      await tester.pump();
      expect(client.clickCalls.last, {'button': 'right', 'action': 'click'});

      // Toque simples no trackpad -> clique esquerdo
      await tester.tap(find.byKey(const Key('trackpad-gesture-area')));
      await tester.pumpAndSettle();
      expect(client.clickCalls.last, {'button': 'left', 'action': 'click'});

      // Duplo toque no trackpad -> clique direito
      await tester.tap(find.byKey(const Key('trackpad-gesture-area')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('trackpad-gesture-area')));
      await tester.pumpAndSettle();
      expect(client.clickCalls.last, {'button': 'right', 'action': 'click'});
    });

    testWidgets('drag gesture on trackpad sends mouse move deltas', (tester) async {
      final client = MockRemoteInputClient();

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            client: client,
            initialPc: pcA,
            availablePcs: const [pcA],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byKey(const Key('trackpad-gesture-area')), const Offset(25, -15));
      await tester.pumpAndSettle();

      expect(client.moveCalls, isNotEmpty);
      expect(client.moveCalls.any((call) => (call['dx'] as double) > 0), isTrue);
    });

    testWidgets('virtual keyboard panel shortcuts and text input', (tester) async {
      final client = MockRemoteInputClient();

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            client: client,
            initialPc: pcA,
            availablePcs: const [pcA],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Painel inicialmente oculto
      expect(find.byKey(const Key('shortcut-Esc')), findsNothing);

      // Alterna exibição do teclado virtual
      await tester.tap(find.byKey(const Key('toggle-keyboard-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shortcut-Esc')), findsOneWidget);
      expect(find.byKey(const Key('shortcut-Tab')), findsOneWidget);
      expect(find.byKey(const Key('shortcut-Ctrl+C')), findsOneWidget);
      expect(find.byKey(const Key('shortcut-Enter')), findsOneWidget);

      // Dispara atalho Esc
      await tester.tap(find.byKey(const Key('shortcut-Esc')));
      await tester.pump();
      expect(client.keyCalls, contains('Esc'));

      // Dispara atalho Ctrl+C
      await tester.tap(find.byKey(const Key('shortcut-Ctrl+C')));
      await tester.pump();
      expect(client.keyCalls, contains('Ctrl+C'));

      // Digita texto no campo e envia
      await tester.enterText(find.byKey(const Key('remote-text-input')), 'Hello PC');
      await tester.pump();

      await tester.tap(find.byKey(const Key('send-text-button')));
      await tester.pump();

      expect(client.textCalls, contains('Hello PC'));
      expect(find.text('Hello PC'), findsNothing); // limpo após envio
    });

    testWidgets('switching target PC manages remote session lifecycle', (tester) async {
      final clientA = MockRemoteInputClient(baseUrl: 'https://pc-a.local');
      final clientB = MockRemoteInputClient(baseUrl: 'https://pc-b.local');

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            initialPc: pcA,
            availablePcs: const [pcA, pcB],
            clientForPc: (pc) => pc.id == 'pc-1' ? clientA : clientB,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(clientA.calls, contains('startRemoteInputSession'));
      expect(find.text('Desktop Alpha'), findsOneWidget);

      // Abre menu de PCs e seleciona Laptop Beta
      await tester.tap(find.byKey(const Key('pc-selector-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laptop Beta').last);
      await tester.pumpAndSettle();

      expect(clientA.calls, contains('endRemoteInputSession'));
      expect(clientB.calls, contains('startRemoteInputSession'));
      expect(find.text('Laptop Beta'), findsOneWidget);
    });

    testWidgets('locked session displays 423 banner and badge', (tester) async {
      final client = MockRemoteInputClient();
      client.throwOnStart = true;
      client.startException = const RemoteInputLockedException('Sessão do Windows bloqueada.');

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            client: client,
            initialPc: pcA,
            availablePcs: const [pcA],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bloqueado (423)'), findsOneWidget);
      expect(find.text('Sessão do Windows bloqueada.'), findsOneWidget);
    });

    testWidgets('forbidden session displays 403 banner and badge', (tester) async {
      final client = MockRemoteInputClient();
      client.throwOnStart = true;
      client.startException = const RemoteInputForbiddenException('Permissão insuficiente (ViewerOnly).');

      await tester.pumpWidget(
        buildTestableWidget(
          TrackpadPage(
            client: client,
            initialPc: pcA,
            availablePcs: const [pcA],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ViewerOnly (403)'), findsOneWidget);
      expect(find.text('Permissão insuficiente (ViewerOnly).'), findsOneWidget);
    });
  });

  group('RemoteInputCard Widget', () {
    testWidgets('renders RemoteInputCard and triggers onOpenTrackpad', (tester) async {
      bool opened = false;

      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(
            body: RemoteInputCard(
              targetPc: pcA,
              onOpenTrackpad: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trackpad & Teclado Remoto'), findsOneWidget);
      expect(find.text('Alvo: Desktop Alpha'), findsOneWidget);
      expect(find.byKey(const Key('open-trackpad-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-trackpad-button')));
      await tester.pump();

      expect(opened, isTrue);
    });
  });
}
