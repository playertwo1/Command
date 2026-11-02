import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Dispositivo Command descoberto na rede local via mDNS / DNS-SD ou UDP broadcast.
class DiscoveredCommandDevice {
  final String name;
  final String ip;
  final int port;
  final int? controlPort;
  final String? certPin;
  final String? id;

  const DiscoveredCommandDevice({
    required this.name,
    required this.ip,
    this.port = 4787,
    this.controlPort = 4788,
    this.certPin,
    this.id,
  });

  String get baseUrl => 'http://$ip:$port';
  String get controlBaseUrl => 'https://$ip:${controlPort ?? 4788}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredCommandDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port &&
          (id != null && other.id != null ? id == other.id : true);

  @override
  int get hashCode => Object.hash(ip, port, id);

  @override
  String toString() =>
      'DiscoveredCommandDevice(name: $name, ip: $ip:$port, controlPort: $controlPort, certPin: $certPin, id: $id)';
}

/// Serviço de descoberta mDNS (_command._tcp) e reconexão (D0.1/D0.2).
class MdnsDiscoveryService {
  static const String serviceType = '_command._tcp.local';
  static const int mdnsPort = 5353;
  static const int legacyDiscoveryPort = 7573;
  static final InternetAddress mdnsMulticastIpv4 = InternetAddress('224.0.0.251');

  /// Descobre dispositivos Command anunciados via mDNS ou fallback UDP.
  Future<List<DiscoveredCommandDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 4),
    RawDatagramSocket? socketOverride,
  }) async {
    final Map<String, DiscoveredCommandDevice> devicesByEndpoint = {};
    RawDatagramSocket? socket;

    try {
      socket = socketOverride ??
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final queryPacket = buildMdnsQuery(serviceType);

      // 1. Envia query mDNS via Multicast (224.0.0.251:5353)
      try {
        socket.send(queryPacket, mdnsMulticastIpv4, mdnsPort);
      } catch (e) {
        debugPrint('[mDNS] Falha ao enviar multicast mDNS: $e');
      }

      // 2. Envia também broadcast para a sub-rede e porta legado 7573 como fallback de conectividade
      final networkInfo = NetworkInfo();
      String? wifiIp;
      try {
        wifiIp = await networkInfo.getWifiIP();
      } catch (_) {}

      final broadcastTargets = <String>{'255.255.255.255'};
      if (wifiIp != null && wifiIp.contains('.')) {
        final lastDot = wifiIp.lastIndexOf('.');
        if (lastDot != -1) {
          broadcastTargets.add('${wifiIp.substring(0, lastDot)}.255');
        }
      }

      final legacyPayload = utf8.encode('DroidDeckDiscoveryRequest');
      for (final target in broadcastTargets) {
        try {
          socket.send(legacyPayload, InternetAddress(target), legacyDiscoveryPort);
          // Também envia query mDNS em broadcast caso o switch descarte multicast puro
          socket.send(queryPacket, InternetAddress(target), mdnsPort);
        } catch (_) {}
      }

      final completer = Completer<List<DiscoveredCommandDevice>>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            final parsed = parseDatagram(datagram);
            if (parsed != null) {
              devicesByEndpoint['${parsed.ip}:${parsed.port}'] = parsed;
            }
          }
        }
      });

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(devicesByEndpoint.values.toList());
        }
      });

      final result = await completer.future;
      return result;
    } catch (e) {
      debugPrint('[Discovery] Erro na busca de dispositivos: $e');
      return devicesByEndpoint.values.toList();
    } finally {
      if (socketOverride == null) {
        try {
          socket?.close();
        } catch (_) {}
      }
    }
  }

  /// Constrói um pacote de consulta DNS padrão para PTR com o bit QU (unicast response) ativo.
  static Uint8List buildMdnsQuery(String name) {
    final buffer = BytesBuilder();

    // Cabeçalho DNS (12 bytes)
    buffer.add([0x00, 0x01]); // Transaction ID
    buffer.add([0x00, 0x00]); // Flags: Standard Query
    buffer.add([0x00, 0x01]); // QDCOUNT: 1
    buffer.add([0x00, 0x00]); // ANCOUNT: 0
    buffer.add([0x00, 0x00]); // NSCOUNT: 0
    buffer.add([0x00, 0x00]); // ARCOUNT: 0

    // Question Name
    writeDnsName(buffer, name);

    // QTYPE: PTR (12)
    buffer.add([0x00, 0x0C]);

    // QCLASS: IN (1) com QU bit (0x8001 para unicast response)
    buffer.add([0x80, 0x01]);

    return buffer.toBytes();
  }

  /// Analisa um datagrama recebido (mDNS ou JSON legado).
  static DiscoveredCommandDevice? parseDatagram(Datagram datagram) {
    final data = datagram.data;
    if (data.length < 4) return null;

    // 1. Tenta decodificar como resposta JSON de broadcast legado
    try {
      if (data[0] == 0x7B) {
        // Começa com '{'
        final text = utf8.decode(data);
        final json = jsonDecode(text) as Map<String, dynamic>;
        final ip = (json['ip'] as String?) ?? datagram.address.address;
        final name = (json['name'] as String?) ?? 'PC';
        return DiscoveredCommandDevice(
          name: name,
          ip: ip,
          port: 4787,
          controlPort: 4788,
          id: name,
        );
      }
    } catch (_) {}

    // 2. Tenta decodificar como pacote de resposta DNS mDNS
    try {
      return parseMdnsResponse(data, datagram.address.address);
    } catch (_) {
      return null;
    }
  }

  /// Decodifica registros mDNS de resposta (PTR, SRV, TXT, A).
  static DiscoveredCommandDevice? parseMdnsResponse(Uint8List bytes, String fallbackIp) {
    if (bytes.length < 12) return null;

    final reader = _ByteReader(bytes);
    final _ = reader.readUint16(); // id
    final flags = reader.readUint16();
    final qdCount = reader.readUint16();
    final anCount = reader.readUint16();
    final nsCount = reader.readUint16();
    final arCount = reader.readUint16();

    // Deve ser uma resposta (QR bit = 1)
    if ((flags & 0x8000) == 0) return null;

    // Pula questões se houver
    for (int i = 0; i < qdCount && !reader.isEof; i++) {
      reader.readDnsName();
      reader.skip(4); // QTYPE + QCLASS
    }

    String? foundName;
    int foundPort = 4787;
    int? foundControlPort;
    String? foundCertPin;
    String? foundId;
    String? foundIp;

    final allRecordsCount = anCount + nsCount + arCount;
    for (int i = 0; i < allRecordsCount && !reader.isEof; i++) {
      reader.readDnsName();
      if (reader.remaining < 10) break;

      final type = reader.readUint16();
      final _ = reader.readUint16(); // class
      final _ = reader.readUint32(); // ttl
      final rdLength = reader.readUint16();

      if (reader.remaining < rdLength) break;
      final recordBytes = reader.readBytes(rdLength);

      if (type == 12) {
        // PTR
        final target = readNameFromBytes(recordBytes);
        if (target.contains('._command._tcp')) {
          foundName = target.split('.').first;
        }
      } else if (type == 33) {
        // SRV: priority (2), weight (2), port (2), target
        if (recordBytes.length >= 6) {
          foundPort = (recordBytes[4] << 8) | recordBytes[5];
        }
      } else if (type == 16) {
        // TXT: pares chave=valor
        final txtMap = decodeTxtRecord(recordBytes);
        if (txtMap.containsKey('name')) foundName = txtMap['name'];
        if (txtMap.containsKey('id')) foundId = txtMap['id'];
        if (txtMap.containsKey('port')) {
          foundPort = int.tryParse(txtMap['port']!) ?? foundPort;
        }
        if (txtMap.containsKey('controlPort')) {
          foundControlPort = int.tryParse(txtMap['controlPort']!);
        }
        if (txtMap.containsKey('certPin')) {
          foundCertPin = txtMap['certPin'];
        }
      } else if (type == 1) {
        // A (IPv4)
        if (recordBytes.length == 4) {
          foundIp = recordBytes.join('.');
        }
      }
    }

    // Se encontrou algo relacionado ao serviço command
    if (foundName != null || foundCertPin != null || foundId != null) {
      return DiscoveredCommandDevice(
        name: foundName ?? 'PC',
        ip: foundIp ?? fallbackIp,
        port: foundPort,
        controlPort: foundControlPort ?? 4788,
        certPin: foundCertPin,
        id: foundId ?? foundName,
      );
    }

    return null;
  }

  static void writeDnsName(BytesBuilder buffer, String name) {
    final labels = name.split('.');
    for (final label in labels) {
      if (label.isEmpty) continue;
      final bytes = utf8.encode(label);
      buffer.addByte(bytes.length);
      buffer.add(bytes);
    }
    buffer.addByte(0);
  }

  static String readNameFromBytes(Uint8List bytes) {
    final parts = <String>[];
    int offset = 0;
    while (offset < bytes.length) {
      final len = bytes[offset++];
      if (len == 0) break;
      if (offset + len > bytes.length) break;
      parts.add(utf8.decode(bytes.sublist(offset, offset + len)));
      offset += len;
    }
    return parts.join('.');
  }

  static Map<String, String> decodeTxtRecord(Uint8List data) {
    final dict = <String, String>{};
    int offset = 0;
    while (offset < data.length) {
      final len = data[offset++];
      if (offset + len > data.length) break;
      final text = utf8.decode(data.sublist(offset, offset + len));
      offset += len;

      final eq = text.indexOf('=');
      if (eq > 0) {
        final key = text.substring(0, eq).trim();
        final val = text.substring(eq + 1).trim();
        dict[key] = val;
      }
    }
    return dict;
  }
}

class _ByteReader {
  final Uint8List _bytes;
  int _offset = 0;

  _ByteReader(this._bytes);

  bool get isEof => _offset >= _bytes.length;
  int get remaining => _bytes.length - _offset;

  void skip(int count) {
    _offset += count;
  }

  int readUint16() {
    if (remaining < 2) return 0;
    final val = (_bytes[_offset] << 8) | _bytes[_offset + 1];
    _offset += 2;
    return val;
  }

  int readUint32() {
    if (remaining < 4) return 0;
    final val = (_bytes[_offset] << 24) |
        (_bytes[_offset + 1] << 16) |
        (_bytes[_offset + 2] << 8) |
        _bytes[_offset + 3];
    _offset += 4;
    return val;
  }

  Uint8List readBytes(int length) {
    if (remaining < length) length = remaining;
    final slice = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return slice;
  }

  String readDnsName() {
    final parts = <String>[];
    int jumpCount = 0;
    int? returnOffset;

    while (_offset < _bytes.length) {
      final len = _bytes[_offset++];
      if (len == 0) break;

      // Ponteiro DNS (0xC0)
      if ((len & 0xC0) == 0xC0) {
        if (_offset >= _bytes.length) break;
        final b2 = _bytes[_offset++];
        final pointer = ((len & 0x3F) << 8) | b2;

        returnOffset ??= _offset;
        if (jumpCount++ > 10) break; // loop guard
        _offset = pointer;
        continue;
      }

      if (_offset + len > _bytes.length) break;
      parts.add(utf8.decode(_bytes.sublist(_offset, _offset + len)));
      _offset += len;
    }

    if (returnOffset != null) {
      _offset = returnOffset;
    }

    return parts.join('.');
  }
}
