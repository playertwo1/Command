import 'package:crypto/crypto.dart';

bool matchesControlCertificatePin(
  List<int>? certificateDer,
  String expectedPin,
) =>
    certificateDer != null &&
    sha256.convert(certificateDer).toString() == expectedPin;
