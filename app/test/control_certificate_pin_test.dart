import 'package:crypto/crypto.dart';
import 'package:command/src/config/control_certificate_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts only the SHA-256 pin of the exact DER bytes', () {
    final certificateDer = <int>[0x30, 0x03, 0x02, 0x01, 0x01];
    final pin = sha256.convert(certificateDer).toString();
    final wrongPin = '${pin.substring(1)}${pin.endsWith('0') ? '1' : '0'}';

    expect(matchesControlCertificatePin(certificateDer, pin), isTrue);
    expect(matchesControlCertificatePin(certificateDer, wrongPin), isFalse);
    expect(matchesControlCertificatePin(null, pin), isFalse);
  });
}
