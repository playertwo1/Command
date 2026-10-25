import 'package:droiddeck/src/connection/pc_connections.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:droiddeck/src/home/pc_dashboard_card.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conexão falsa: registra init/dispose sem abrir rede.
class _FakeSignalR extends SignalRService {
  String? url;
  String? key;
  bool disposed = false;
  bool failInit = false;
  int initCount = 0;

  @override
  Future<void> init(String baseUrl, {String? apiKey}) async {
    initCount++;
    disposed = false;
    url = baseUrl;
    key = apiKey;
    connectionStatus.value = failInit ? 'Disconnected' : 'Connected';
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late _FakeSignalR primary;
  late List<_FakeSignalR> created;
  late PcConnections conns;
  late SavedPc a, b, c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    a = await PcStore.upsert(ip: '10.0.0.1', port: '4787', apiKey: 'ka');
    b = await PcStore.upsert(ip: '10.0.0.2', port: '4787', apiKey: 'kb');
    c = await PcStore.upsert(ip: '10.0.0.3', port: '4787', apiKey: 'kc');
    await PcStore.select(a);
    primary = _FakeSignalR();
    created = [];
    conns = PcConnections(
      primary,
      factory: () {
        final s = _FakeSignalR();
        created.add(s);
        return s;
      },
    );
  });

  test('o segundo PC tem conexão própria, com a sua chave', () async {
    await conns.connectSecondary(b);
    expect(created, hasLength(1));
    expect(created.single.url, b.baseUrl);
    expect(created.single.key, 'kb');
    expect(conns.forPc(a.id), same(primary));
    expect(conns.forPc(b.id), same(created.single));
    expect(conns.forPc(c.id), isNull);
  });

  testWidgets('painel acompanha a conexão paralela aberta após renderizar', (
    tester,
  ) async {
    primary.connectionStatus.value = 'Connected';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Watch(
            (context) => PcDashboardCard(
              primaryPc: a,
              secondaryPc: conns.secondaryPc ?? b,
              primaryConnection: primary,
              secondaryConnection: conns.secondary,
              targetPcId: a.id,
              onTargetSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Online'), findsOneWidget);
    await conns.connectSecondary(b);
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsNWidgets(2));
    await conns.disconnectSecondary();
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsOneWidget);
  });

  test(
    'nunca há 3 conexões: um novo segundo PC substitui o anterior',
    () async {
      await conns.connectSecondary(b);
      await conns.connectSecondary(c);
      expect(created.first.disposed, isTrue);
      expect(conns.secondaryPc?.id, c.id);
      expect(conns.forPc(b.id), isNull);
    },
  );

  test('o PC em foco não pode virar o segundo PC', () async {
    expect(() => conns.connectSecondary(a), throwsArgumentError);
  });

  test('remover o segundo PC não mexe na conexão em foco', () async {
    await conns.connectSecondary(b);
    await conns.onPcRemoved(b.id);
    expect(created.single.disposed, isTrue);
    expect(primary.disposed, isFalse);
    expect(conns.secondary, isNull);
  });

  test('a queda do segundo PC não afeta o PC em foco', () async {
    primary.connectionStatus.value = 'Connected';
    await conns.connectSecondary(b);
    created.single.connectionStatus.value = 'Disconnected';
    expect(primary.connectionStatus.value, 'Connected');
  });

  test('focar o segundo PC reabre o anterior com a própria chave', () async {
    await conns.connectSecondary(b);
    final previous = await PcStore.current();
    await PcStore.select(b);
    await conns.onFocusChanged(previous);
    expect(conns.secondaryPc?.id, a.id);
    expect(created.last.url, a.baseUrl);
    expect(created.last.key, 'ka');
    await PcStore.select(a);
    await conns.onFocusChanged(b);
    expect(conns.secondaryPc?.id, b.id);
    expect(created.last.key, 'kb');
  });

  test('o segundo PC salvo é reaberto na abertura do app', () async {
    await conns.connectSecondary(b);
    final reopened = PcConnections(
      primary,
      factory: () {
        final s = _FakeSignalR();
        created.add(s);
        return s;
      },
    );
    await reopened.restore();
    expect(reopened.secondaryPc?.id, b.id);
  });

  test('trocar sem paralelo prévio mantém o PC anterior conectado', () async {
    await PcStore.select(b);
    await conns.onFocusChanged(a);
    expect(conns.secondaryPc?.id, a.id);
    expect(conns.forPc(a.id)?.connectionStatus.value, 'Connected');
    expect(created.single.key, 'ka');
    expect(conns.forPc(b.id), same(primary));
  });

  test(
    'abertura recupera os dois PCs pareados sem opção manual prévia',
    () async {
      await PcStore.remove(c.id);
      await conns.restore();
      expect(conns.secondaryPc?.id, b.id);
      expect(created.single.key, 'kb');
    },
  );

  test(
    'desconexão paralela explícita é respeitada na próxima abertura',
    () async {
      await PcStore.remove(c.id);
      await conns.connectSecondary(b);
      await conns.disconnectSecondary();
      await conns.restore();
      expect(conns.secondaryPc, isNull);
      expect(created, hasLength(1));
      await PcStore.select(b);
      await conns.onFocusChanged(a);
      expect(conns.secondaryPc, isNull);
      expect(created, hasLength(1));
    },
  );

  test('não escolhe automaticamente entre mais de dois PCs pareados', () async {
    await conns.restore();
    expect(conns.secondaryPc, isNull);
  });

  test(
    'trocar para um terceiro mantém apenas o paralelo já escolhido',
    () async {
      await conns.connectSecondary(b);
      await PcStore.select(c);
      await conns.onFocusChanged(a);
      expect(conns.secondaryPc?.id, b.id);
      expect(created, hasLength(1));
      expect(conns.forPc(a.id), isNull);
    },
  );

  test(
    'suspende os dois hubs em background e reconecta os mesmos PCs ao retomar',
    () async {
      await conns.connectSecondary(b);
      final secondary = created.single;
      await conns.suspend();
      expect(primary.disposed, isTrue);
      expect(secondary.disposed, isTrue);
      expect(conns.secondaryPc?.id, b.id);

      await conns.resume();
      expect(primary.initCount, 1);
      expect(primary.url, a.baseUrl);
      expect(secondary.initCount, 2);
      expect(secondary.url, b.baseUrl);
      expect(conns.secondaryPc?.id, b.id);
    },
  );

  test('não abre conexão paralela nova enquanto o app está suspenso', () async {
    await conns.suspend();
    await conns.connectSecondary(b);
    expect(created.single.initCount, 0);
    await conns.resume();
    expect(created.single.initCount, 1);
  });
}
