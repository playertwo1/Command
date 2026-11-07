import 'package:command/src/config/control_pairing_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the control-pair URI and normalizes the certificate pin', () {
    final uppercasePin = List.filled(64, 'A').join();
    final qr = ControlPairingQr.tryParse(
      'droiddeck://control-pair?ip=192.168.1.8&port=4788&ticket=Abc_123-def45678901234567890&pin=$uppercasePin',
    );

    expect(qr, isNotNull);
    expect(qr!.ip, '192.168.1.8');
    expect(qr.port, 4788);
    expect(qr.ticket, 'Abc_123-def45678901234567890');
    expect(qr.pin, List.filled(64, 'a').join());
  });

  test('rejects wrong scheme, port, malformed pin and duplicate parameters', () {
    const ticket = 'Abc_123-def45678901234567890';
    const pin =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    expect(
      ControlPairingQr.tryParse(
        'http://control-pair?ip=192.168.1.8&port=4788&ticket=$ticket&pin=$pin',
      ),
      isNull,
    );
    expect(
      ControlPairingQr.tryParse(
        'droiddeck://control-pair?ip=192.168.1.8&port=4787&ticket=$ticket&pin=$pin',
      ),
      isNull,
    );
    expect(
      ControlPairingQr.tryParse(
        'droiddeck://control-pair?ip=192.168.1.8&port=4788&ticket=$ticket&pin=bad',
      ),
      isNull,
    );
    expect(
      ControlPairingQr.tryParse(
        'droiddeck://control-pair?ip=192.168.1.8&ip=192.168.1.9&port=4788&ticket=$ticket&pin=$pin',
      ),
      isNull,
    );
  });
}
