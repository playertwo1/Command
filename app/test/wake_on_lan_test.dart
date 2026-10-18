import 'dart:typed_data';
import 'package:droiddeck/src/services/wake_on_lan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WakeOnLanService MAC parsing', () {
    test('converte MAC válido com dois-pontos ou hífens em 6 bytes', () {
      final macColon = WakeOnLanService.parseMacAddress('AA:BB:CC:DD:EE:FF');
      expect(macColon, [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);

      final macHyphen = WakeOnLanService.parseMacAddress('00-11-22-33-44-55');
      expect(macHyphen, [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]);

      final macLower = WakeOnLanService.parseMacAddress('1a:2b:3c:4d:5e:6f');
      expect(macLower, [0x1A, 0x2B, 0x3C, 0x4D, 0x5E, 0x6F]);
    });

    test('rejeita formatos inválidos com FormatException', () {
      expect(() => WakeOnLanService.parseMacAddress(''), throwsA(isA<FormatException>()));
      expect(() => WakeOnLanService.parseMacAddress('AA:BB:CC:DD:EE'), throwsA(isA<FormatException>()));
      expect(() => WakeOnLanService.parseMacAddress('AA:BB:CC:DD:EE:FF:00'), throwsA(isA<FormatException>()));
      expect(() => WakeOnLanService.parseMacAddress('GG:HH:II:JJ:KK:LL'), throwsA(isA<FormatException>()));
      expect(() => WakeOnLanService.parseMacAddress('not-a-mac'), throwsA(isA<FormatException>()));
    });
  });

  group('WakeOnLanService Magic Packet Builder', () {
    test('constrói pacote com exatamente 102 bytes e formato IEEE', () {
      final packet = WakeOnLanService.buildMagicPacket('AA:BB:CC:DD:EE:FF');

      expect(packet, isA<Uint8List>());
      expect(packet.length, 102);

      // Primeiros 6 bytes devem ser 0xFF
      for (int i = 0; i < 6; i++) {
        expect(packet[i], 0xFF, reason: 'Byte $i deve ser 0xFF');
      }

      // 16 repetições do MAC
      final expectedMac = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF];
      for (int repetition = 0; repetition < 16; repetition++) {
        final offset = 6 + (repetition * 6);
        for (int j = 0; j < 6; j++) {
          expect(
            packet[offset + j],
            expectedMac[j],
            reason: 'Repetição $repetition byte $j deve corresponder ao MAC',
          );
        }
      }
    });

    test('constrói corretamente para MAC com hífens', () {
      final packet = WakeOnLanService.buildMagicPacket('00-1A-2B-3C-4D-5E');
      expect(packet.length, 102);
      expect(packet.sublist(0, 6), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
      expect(packet.sublist(6, 12), [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E]);
      expect(packet.sublist(96, 102), [0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E]);
    });
  });
}
