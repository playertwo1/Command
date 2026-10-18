import 'dart:io';
import 'dart:typed_data';

/// Serviço para construção e envio de pacotes Wake-on-LAN (Magic Packet UDP) (Onda v0.6 - W0).
class WakeOnLanService {
  /// Converte string de MAC ("AA:BB:CC:DD:EE:FF" ou "AA-BB-CC-DD-EE-FF") em 6 bytes.
  /// Lança [FormatException] se o endereço não for válido.
  static List<int> parseMacAddress(String mac) {
    final clean = mac.trim();
    final parts = clean.contains(':')
        ? clean.split(':')
        : clean.contains('-')
            ? clean.split('-')
            : <String>[];

    if (parts.length != 6) {
      throw FormatException('Endereço MAC inválido (deve conter 6 octetos hexadecimais): "$mac"');
    }

    final bytes = <int>[];
    for (final part in parts) {
      if (part.isEmpty || part.length > 2) {
        throw FormatException('Octeto inválido "$part" no MAC "$mac"');
      }
      final byteVal = int.tryParse(part, radix: 16);
      if (byteVal == null || byteVal < 0 || byteVal > 255) {
        throw FormatException('Valor hex inválido "$part" no MAC "$mac"');
      }
      bytes.add(byteVal);
    }

    return bytes;
  }

  /// Constrói o Magic Packet padrão IEEE (102 bytes = 6x 0xFF + 16x MAC).
  static Uint8List buildMagicPacket(String macAddress) {
    final macBytes = parseMacAddress(macAddress);

    // 6 bytes com 0xFF seguidos de 16 repetições do MAC (6 + 16 * 6 = 102 bytes)
    final packet = Uint8List(102);

    for (int i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }

    for (int i = 0; i < 16; i++) {
      final offset = 6 + (i * 6);
      for (int j = 0; j < 6; j++) {
        packet[offset + j] = macBytes[j];
      }
    }

    return packet;
  }

  /// Dispara o pacote Wake-on-LAN via broadcast UDP na rede local.
  static Future<bool> sendWakeOnLan({
    required String macAddress,
    String broadcastIp = '255.255.255.255',
    int port = 9,
  }) async {
    final packet = buildMagicPacket(macAddress);
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final targetAddress = InternetAddress(broadcastIp);
      final sentBytes = socket.send(packet, targetAddress, port);
      return sentBytes == packet.length;
    } catch (_) {
      return false;
    } finally {
      socket?.close();
    }
  }
}
