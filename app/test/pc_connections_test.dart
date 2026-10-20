import 'package:droiddeck/src/connection/pc_connections.dart';
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/services/signalr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Conexão falsa: registra init/dispose sem abrir rede.
class _FakeSignalR extends SignalRService {
  String? url;
  String? key;
  bool disposed = false;
  bool failInit = false;

  @override
  Future<void> init(String baseUrl, {String? apiKey}) async {
    url = baseUrl;
    key = apiKey;
    if (failInit) connectionStatus.value = 'Disconnected';
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
    conns = PcConnections(primary, factory: () {
      final s = _FakeSignalR();
      created.add(s);
      return s;
    });
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

  test('nunca há 3 conexões: um novo segundo PC substitui o anterior', () async {
    await conns.connectSecondary(b);
    await conns.connectSecondary(c);
    expect(created.first.disposed, isTrue);
    expect(conns.secondaryPc?.id, c.id);
    expect(conns.forPc(b.id), isNull);
  });

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

  test('focar o segundo PC troca os papéis sem desconectar nenhum', () async {
    await conns.connectSecondary(b);
    final previous = await PcStore.current();
    await PcStore.select(b);
    await conns.onFocusChanged(previous);
    expect(conns.secondaryPc?.id, a.id);
    expect(created.last.url, a.baseUrl);
  });

  test('o segundo PC salvo é reaberto na abertura do app', () async {
    await conns.connectSecondary(b);
    final reopened = PcConnections(primary, factory: () {
      final s = _FakeSignalR();
      created.add(s);
      return s;
    });
    await reopened.restore();
    expect(reopened.secondaryPc?.id, b.id);
  });
}
