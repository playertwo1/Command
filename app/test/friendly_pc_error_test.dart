import 'package:dio/dio.dart';
import 'package:droiddeck/src/home/status_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final req = RequestOptions(path: '/api/v1/services');
  DioException withStatus(int code, [Object? data]) => DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: code, data: data),
      );

  test('sem resposta vira orientação de rede, sem texto do Dio', () {
    final msg = friendlyPcError(
        DioException(requestOptions: req, type: DioExceptionType.connectionError));
    expect(msg, contains('O PC não respondeu'));
    expect(msg, isNot(contains('DioException')));
  });

  test('401 pede novo pareamento', () {
    expect(friendlyPcError(withStatus(401)), contains('Pareie de novo'));
  });

  test('403 explica falta de permissão', () {
    expect(friendlyPcError(withStatus(403)), contains('permissão'));
  });

  test('erro do servidor usa a mensagem do corpo', () {
    expect(friendlyPcError(withStatus(500, {'error': 'Falhou X'})), 'Falhou X');
    expect(friendlyPcError(withStatus(500)), contains('HTTP 500'));
  });
}
