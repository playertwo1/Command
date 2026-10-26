import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:droiddeck/src/connection/pc_store.dart';
import 'package:droiddeck/src/services/mdns_discovery_service.dart';
import 'package:droiddeck/src/connection/reconnection_fallback_service.dart';

class MockProbeHttpClient extends http.BaseClient {
  final Map<String, int> responses;

  MockProbeHttpClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final host = request.url.host;
    final statusCode = responses[host] ?? 404;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"status":"ok"}')),
      statusCode,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PcStore.currentId = null;
  });

  group('MdnsDiscoveryService Tests', () {
    test('buildMdnsQuery creates valid DNS query packet with QU bit', () {
      final packet = MdnsDiscoveryService.buildMdnsQuery('_command._tcp.local');
      expect(packet.length, greaterThan(12));

      // Transaction ID = 0x0001
      expect(packet[0], equals(0x00));
      expect(packet[1], equals(0x01));

      // Flags = 0x0000
      expect(packet[2], equals(0x00));
      expect(packet[3], equals(0x00));

      // QDCOUNT = 1
      expect(packet[4], equals(0x00));
      expect(packet[5], equals(0x01));

      // QCLASS no final deve ter bit 0x8001
      final lastTwo = (packet[packet.length - 2] << 8) | packet[packet.length - 1];
      expect(lastTwo, equals(0x8001));
    });

    test('decodeTxtRecord parses key-value pairs accurately', () {
      final builder = BytesBuilder();
      void addEntry(String kv) {
        final b = utf8.encode(kv);
        builder.addByte(b.length);
        builder.add(b);
      }

      addEntry('txtvers=1');
      addEntry('name=Desktop-PC');
      addEntry('port=4787');
      addEntry('controlPort=4788');
      addEntry('certPin=1234567890abcdef');

      final dict = MdnsDiscoveryService.decodeTxtRecord(builder.toBytes());
      expect(dict['txtvers'], equals('1'));
      expect(dict['name'], equals('Desktop-PC'));
      expect(dict['port'], equals('4787'));
      expect(dict['controlPort'], equals('4788'));
      expect(dict['certPin'], equals('1234567890abcdef'));
    });

    test('parseMdnsResponse extracts DiscoveredCommandDevice with complete records', () {
      final builder = BytesBuilder();

      // Header: ID=1, Flags=0x8400 (Response + Auth), QD=0, AN=2, NS=0, AR=1
      builder.add([0x00, 0x01]);
      builder.add([0x84, 0x00]);
      builder.add([0x00, 0x00]); // QD=0
      builder.add([0x00, 0x02]); // AN=2
      builder.add([0x00, 0x00]); // NS=0
      builder.add([0x00, 0x01]); // AR=1

      // AN1: PTR _command._tcp.local -> MyPC._command._tcp.local
      MdnsDiscoveryService.writeDnsName(builder, '_command._tcp.local');
      builder.add([0x00, 0x0C]); // Type PTR (12)
      builder.add([0x00, 0x01]); // Class IN
      builder.add([0x00, 0x00, 0x00, 0x78]); // TTL 120s
      final targetBytes = BytesBuilder();
      MdnsDiscoveryService.writeDnsName(targetBytes, 'MyPC._command._tcp.local');
      final targetData = targetBytes.toBytes();
      builder.add([0x00, targetData.length]);
      builder.add(targetData);

      // AN2: TXT record
      MdnsDiscoveryService.writeDnsName(builder, 'MyPC._command._tcp.local');
      builder.add([0x00, 0x10]); // Type TXT (16)
      builder.add([0x80, 0x01]); // Class IN + cache-flush
      builder.add([0x00, 0x00, 0x00, 0x78]); // TTL
      final txtBuilder = BytesBuilder();
      final txtEntries = [
        'txtvers=1',
        'name=MyPC',
        'id=PC-UUID-1',
        'port=4787',
        'controlPort=4788',
        'certPin=fedcba0987654321',
      ];
      for (final e in txtEntries) {
        final b = utf8.encode(e);
        txtBuilder.addByte(b.length);
        txtBuilder.add(b);
      }
      final txtData = txtBuilder.toBytes();
      builder.add([0x00, txtData.length]);
      builder.add(txtData);

      // AR1: A record (192.168.1.150)
      MdnsDiscoveryService.writeDnsName(builder, 'MyPC.local');
      builder.add([0x00, 0x01]); // Type A (1)
      builder.add([0x80, 0x01]); // Class IN
      builder.add([0x00, 0x00, 0x00, 0x78]);
      builder.add([0x00, 0x04]); // len 4
      builder.add([192, 168, 1, 150]);

      final device = MdnsDiscoveryService.parseMdnsResponse(builder.toBytes(), '10.0.0.1');
      expect(device, isNotNull);
      expect(device!.name, equals('MyPC'));
      expect(device.ip, equals('192.168.1.150'));
      expect(device.port, equals(4787));
      expect(device.controlPort, equals(4788));
      expect(device.certPin, equals('fedcba0987654321'));
      expect(device.id, equals('PC-UUID-1'));
    });

    test('parseDatagram parses legacy UDP broadcast JSON', () {
      final json = utf8.encode('{"ip":"192.168.0.55","name":"Legacy-PC"}');
      final datagram = Datagram(json, InternetAddress('192.168.0.55'), 7573);

      final device = MdnsDiscoveryService.parseDatagram(datagram);
      expect(device, isNotNull);
      expect(device!.name, equals('Legacy-PC'));
      expect(device.ip, equals('192.168.0.55'));
      expect(device.port, equals(4787));
    });
  });

  group('PcStore D0.2 Identity-Validated IP Update Tests', () {
    test('updateIpIfIdentityMatches updates IP when certPin matches strictly', () async {
      final pc = await PcStore.upsert(
        name: 'Work-PC',
        ip: '192.168.1.10',
        port: '4787',
      );
      await PcStore.setControlCredential(
        pcId: pc.id,
        deviceId: 'dev-1',
        certificatePin: 'pin-abc-123',
        credential: 'cred-token',
      );

      final updated = await PcStore.updateIpIfIdentityMatches(
        pcId: pc.id,
        newIp: '192.168.1.88',
        certPin: 'pin-abc-123',
      );

      expect(updated, isTrue);
      final currentList = await PcStore.load();
      expect(currentList.first.ip, equals('192.168.1.88'));
    });

    test('updateIpIfIdentityMatches rejects update when certPin diverges', () async {
      final pc = await PcStore.upsert(
        name: 'Work-PC',
        ip: '192.168.1.10',
        port: '4787',
      );
      await PcStore.setControlCredential(
        pcId: pc.id,
        deviceId: 'dev-1',
        certificatePin: 'pin-abc-123',
        credential: 'cred-token',
      );

      final updated = await PcStore.updateIpIfIdentityMatches(
        pcId: pc.id,
        newIp: '192.168.1.99',
        certPin: 'pin-DIVERGENTE-FAKE',
      );

      expect(updated, isFalse);
      final currentList = await PcStore.load();
      expect(currentList.first.ip, equals('192.168.1.10')); // Preservado
    });

    test('updateIpIfIdentityMatches rejects update when target has no certPin', () async {
      final pc = await PcStore.upsert(
        name: 'Legacy-PC',
        ip: '192.168.1.10',
        port: '4787',
      );

      final updated = await PcStore.updateIpIfIdentityMatches(
        pcId: pc.id,
        newIp: '192.168.1.99',
        certPin: 'pin-qualquer',
      );

      expect(updated, isFalse);
    });
  });

  group('ReconnectionFallbackService D0.3 Tests', () {
    test('isTailscaleIp identifies 100.64.0.0/10 CGNAT subnet accurately', () {
      expect(ReconnectionFallbackService.isTailscaleIp('100.64.0.1'), isTrue);
      expect(ReconnectionFallbackService.isTailscaleIp('100.100.5.20'), isTrue);
      expect(ReconnectionFallbackService.isTailscaleIp('100.127.255.254'), isTrue);
      expect(ReconnectionFallbackService.isTailscaleIp('100.128.0.1'), isFalse);
      expect(ReconnectionFallbackService.isTailscaleIp('192.168.1.10'), isFalse);
      expect(ReconnectionFallbackService.isTailscaleIp('10.0.0.5'), isFalse);
    });

    test('getCandidates prioritizes mDNS LAN -> current LAN -> Tailscale without duplicates', () async {
      const pc = SavedPc(
        id: 'pc-target',
        name: 'TargetPC',
        ip: '192.168.1.20',
        port: '4787',
        controlCertificatePin: 'cert-123',
      );

      const discovered = [
        DiscoveredCommandDevice(
          name: 'TargetPC',
          ip: '192.168.1.55', // Novo IP via DHCP
          certPin: 'cert-123',
        ),
      ];

      final service = ReconnectionFallbackService();
      final candidates = await service.getCandidates(pc, discoveredDevices: discovered);

      expect(candidates, equals(['192.168.1.55', '192.168.1.20']));
      expect(candidates.toSet().length, equals(candidates.length)); // Sem duplicatas
    });

    test('resolveWorkingAddress picks first responding candidate and updates PcStore', () async {
      final pc = await PcStore.upsert(
        name: 'TargetPC',
        ip: '192.168.1.20',
        port: '4787',
      );
      await PcStore.setControlCredential(
        pcId: pc.id,
        deviceId: 'dev-1',
        certificatePin: 'cert-pin-target',
        credential: 'cred-1',
      );
      final targetPc = (await PcStore.load()).first;

      // Simula: IP antigo (192.168.1.20) está offline (503/timeout), novo IP (192.168.1.55) responde 200
      final mockHttp = MockProbeHttpClient({
        '192.168.1.55': 200,
        '192.168.1.20': 503,
      });

      const discovered = [
        DiscoveredCommandDevice(
          name: 'TargetPC',
          ip: '192.168.1.55',
          certPin: 'cert-pin-target',
        ),
      ];

      final service = ReconnectionFallbackService(httpClient: mockHttp);
      final workingIp = await service.resolveWorkingAddress(targetPc, discoveredDevices: discovered);

      expect(workingIp, equals('192.168.1.55'));
      final refreshedList = await PcStore.load();
      expect(refreshedList.first.ip, equals('192.168.1.55'));
    });
  });
}
