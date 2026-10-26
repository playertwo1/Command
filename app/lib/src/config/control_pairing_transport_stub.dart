import 'control_pairing_credential.dart';
import 'control_pairing_qr.dart';

Future<ControlPairingCredential> exchangeControlPairingTicket(
  ControlPairingQr qr,
) => throw UnsupportedError('Secure control pairing requires dart:io.');
