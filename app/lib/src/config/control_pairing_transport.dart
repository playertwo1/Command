import 'control_pairing_credential.dart';
import 'control_pairing_qr.dart';
import 'control_pairing_transport_stub.dart'
    if (dart.library.io) 'control_pairing_transport_io.dart'
    as transport;

Future<ControlPairingCredential> exchangeControlPairingTicket(
  ControlPairingQr qr,
) => transport.exchangeControlPairingTicket(qr);
