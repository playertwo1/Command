import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'control_pairing_credential.dart';
import 'control_certificate_pin.dart';
import 'control_pairing_qr.dart';

Future<ControlPairingCredential> exchangeControlPairingTicket(
  ControlPairingQr qr,
) async {
  final uri = Uri(
    scheme: 'https',
    host: qr.ip,
    port: qr.port,
    path: '/api/v1/pairing/exchange',
  );
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      followRedirects: false,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()
          ..badCertificateCallback = (certificate, host, port) =>
              host.toLowerCase() == qr.ip.toLowerCase() && port == qr.port,
    validateCertificate: (certificate, host, port) =>
        certificate != null &&
        host.toLowerCase() == qr.ip.toLowerCase() &&
        port == qr.port &&
        matchesControlCertificatePin(certificate.der, qr.pin),
  );

  try {
    final response = await dio.postUri<Map<String, dynamic>>(
      uri,
      data: {'ticket': qr.ticket},
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = response.data;
    final deviceId = data?['deviceId'];
    final credential = data?['credential'];
    if (deviceId is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(deviceId) ||
        credential is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(credential)) {
      throw const FormatException('Invalid pairing response.');
    }
    return ControlPairingCredential(deviceId: deviceId, credential: credential);
  } finally {
    dio.close(force: true);
  }
}
