import 'package:command/src/connection/constants.dart';
import 'package:command/src/connection/pc_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('migra o PC único das versões antigas, com o deck guardado', () async {
    SharedPreferences.setMockInitialValues({
      Constants.ipAddrKey: '192.168.0.10',
      Constants.portKey: '4787',
      Constants.apiKeyKey: 'abc',
      'deck_cache': '[deck]',
    });
    final list = await PcStore.load();
    expect(list, hasLength(1));
    expect(list.single.ip, '192.168.0.10');
    expect(list.single.apiKey, 'abc');
    expect(PcStore.currentId, list.single.id);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PcStore.scoped('deck_cache')), '[deck]');
  });

  test('parear outro PC acrescenta; o mesmo IP atualiza a chave', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await PcStore.upsert(ip: '10.0.0.1', port: '4787', apiKey: 'k1');
    final b = await PcStore.upsert(ip: '10.0.0.2', port: '4787', apiKey: 'k2');
    expect(PcStore.currentId, b.id);
    final again = await PcStore.upsert(
      ip: '10.0.0.1',
      port: '4787',
      apiKey: 'k3',
    );
    expect(again.id, a.id);
    final list = await PcStore.load();
    expect(list, hasLength(2));
    expect(list.firstWhere((p) => p.id == a.id).apiKey, 'k3');
    // O PC em uso vai para as chaves de conexão que o app lê ao abrir.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(Constants.ipAddrKey), '10.0.0.1');
    expect(prefs.getString(Constants.apiKeyKey), 'k3');
  });

  test('esquecer o PC em uso passa para o próximo', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await PcStore.upsert(ip: '10.0.0.1', port: '4787', apiKey: 'k1');
    final b = await PcStore.upsert(ip: '10.0.0.2', port: '4787', apiKey: 'k2');
    await PcStore.remove(b.id);
    expect(PcStore.currentId, a.id);
    expect((await PcStore.load()).map((p) => p.id), [a.id]);
    await PcStore.rename(a.id, 'Notebook');
    expect((await PcStore.current())!.name, 'Notebook');
  });

  test(
    'credencial de controle fica no armazenamento seguro e sobrevive a upsert',
    () async {
      SharedPreferences.setMockInitialValues({});
      final pc = await PcStore.upsert(
        ip: '10.0.0.8',
        port: '4787',
        apiKey: 'legacy-key',
      );
      const credential = 'secure-control-token-that-never-goes-in-json';
      final pin = List.filled(64, 'a').join();
      await PcStore.setControlCredential(
        pcId: pc.id,
        deviceId: 'a1b2c3d4-e5f6-47a8-9123-1234567890ab',
        certificatePin: pin,
        credential: credential,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pcs'), isNot(contains(credential)));
      final updated = await PcStore.upsert(
        ip: '10.0.0.8',
        port: '4787',
        apiKey: 'rotated-legacy-key',
      );
      expect(updated.controlCredential, credential);
      expect(updated.controlDeviceId, 'a1b2c3d4-e5f6-47a8-9123-1234567890ab');
      expect(updated.controlCertificatePin, pin);
      expect((await PcStore.load()).single.controlCredential, credential);

      await PcStore.remove(pc.id);
      expect((await PcStore.load()), isEmpty);
      expect(prefs.getString('pcs'), isNot(contains(credential)));
      expect(
        await const FlutterSecureStorage().read(
          key: 'command_control_credential_${pc.id}',
        ),
        isNull,
      );
    },
  );
}
