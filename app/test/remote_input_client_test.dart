import 'package:command/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandClient Remote Input Methods', () {
    late Dio dio;
    late CommandClient client;
    RequestOptions? lastRequest;

    setUp(() {
      dio = Dio();
      client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      lastRequest = null;
    });

    test('startRemoteInputSession sends POST to /api/v1/input/session/start', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'sessionId': 'session-abc',
                  'deviceId': 'mobile-dev',
                  'timeoutSeconds': 60,
                  'isActive': true,
                },
              ),
            );
          },
        ),
      );

      final session = await client.startRemoteInputSession(deviceId: 'mobile-dev');

      expect(lastRequest!.path, '/api/v1/input/session/start');
      expect(lastRequest!.method, 'POST');
      expect(lastRequest!.headers['X-Device-Id'], 'mobile-dev');
      expect(session.sessionId, 'session-abc');
      expect(session.deviceId, 'mobile-dev');
    });

    test('endRemoteInputSession sends POST to /api/v1/input/session/end', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
                data: null,
              ),
            );
          },
        ),
      );

      await client.endRemoteInputSession();

      expect(lastRequest!.path, '/api/v1/input/session/end');
      expect(lastRequest!.method, 'POST');
    });

    test('getRemoteInputSession sends GET to /api/v1/input/session', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'isActive': true,
                  'sessionId': 'sess-live',
                  'deviceId': 'device-live',
                },
              ),
            );
          },
        ),
      );

      final session = await client.getRemoteInputSession();

      expect(lastRequest!.path, '/api/v1/input/session');
      expect(lastRequest!.method, 'GET');
      expect(session.isActive, isTrue);
      expect(session.sessionId, 'sess-live');
    });

    test('sendMouseMove sends dx and dy to /api/v1/input/move', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
              ),
            );
          },
        ),
      );

      await client.sendMouseMove(15.5, -7.2);

      expect(lastRequest!.path, '/api/v1/input/move');
      expect(lastRequest!.data, {'dx': 15.5, 'dy': -7.2});
    });

    test('sendMouseClick sends button and action to /api/v1/input/click', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
              ),
            );
          },
        ),
      );

      await client.sendMouseClick('right', action: 'down');

      expect(lastRequest!.path, '/api/v1/input/click');
      expect(lastRequest!.data, {'button': 'right', 'action': 'down'});
    });

    test('sendMouseScroll sends deltaX and deltaY to /api/v1/input/scroll', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
              ),
            );
          },
        ),
      );

      await client.sendMouseScroll(0, -120);

      expect(lastRequest!.path, '/api/v1/input/scroll');
      expect(lastRequest!.data, {'deltaX': 0, 'deltaY': -120});
    });

    test('sendKeyInput sends key to /api/v1/input/key', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
              ),
            );
          },
        ),
      );

      await client.sendKeyInput('Ctrl+C');

      expect(lastRequest!.path, '/api/v1/input/key');
      expect(lastRequest!.data, {'key': 'Ctrl+C'});
    });

    test('sendTextInput sends text to /api/v1/input/text', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            lastRequest = options;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
              ),
            );
          },
        ),
      );

      await client.sendTextInput('Command Mobile R1');

      expect(lastRequest!.path, '/api/v1/input/text');
      expect(lastRequest!.data, {'text': 'Command Mobile R1'});
    });
  });

  group('CommandClient Exception Mapping', () {
    void setupErrorResponse(Dio dio, int statusCode, Map<String, dynamic> body) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: statusCode,
                  data: body,
                ),
              ),
            );
          },
        ),
      );
    }

    test('HTTP 423 throws RemoteInputLockedException', () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      setupErrorResponse(dio, 423, {'error': 'SESSION_LOCKED'});

      expect(
        () => client.startRemoteInputSession(),
        throwsA(isA<RemoteInputLockedException>().having((e) => e.message, 'message', 'SESSION_LOCKED')),
      );
    });

    test('HTTP 403 throws RemoteInputForbiddenException', () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      setupErrorResponse(dio, 403, {'error': 'INSUFFICIENT_DEVICE_ROLE'});

      expect(
        () => client.sendMouseMove(1, 1),
        throwsA(isA<RemoteInputForbiddenException>().having((e) => e.message, 'message', 'INSUFFICIENT_DEVICE_ROLE')),
      );
    });

    test('HTTP 409 throws RemoteInputConflictException', () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      setupErrorResponse(dio, 409, {
        'error': 'SESSION_ALREADY_ACTIVE',
        'activeDeviceId': 'laptop-01',
      });

      expect(
        () => client.startRemoteInputSession(),
        throwsA(
          isA<RemoteInputConflictException>()
              .having((e) => e.message, 'message', 'SESSION_ALREADY_ACTIVE')
              .having((e) => e.activeDeviceId, 'activeDeviceId', 'laptop-01'),
        ),
      );
    });

    test('HTTP 413 throws RemoteInputTextTooLargeException', () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      setupErrorResponse(dio, 413, {'error': 'TEXT_EXCEEDS_500_CHARS_LIMIT'});

      expect(
        () => client.sendTextInput('very long text'),
        throwsA(isA<RemoteInputTextTooLargeException>().having((e) => e.message, 'message', 'TEXT_EXCEEDS_500_CHARS_LIMIT')),
      );
    });

    test('HTTP 429 throws RemoteInputRateLimitException', () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      setupErrorResponse(dio, 429, {'error': 'RATE_LIMIT_EXCEEDED'});

      expect(
        () => client.sendKeyInput('Enter'),
        throwsA(isA<RemoteInputRateLimitException>().having((e) => e.message, 'message', 'RATE_LIMIT_EXCEEDED')),
      );
    });

    test('Other HTTP errors (500) rethrow original DioException', () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://test.deck', dio: dio);
      setupErrorResponse(dio, 500, {'error': 'INTERNAL_ERROR'});

      expect(
        () => client.sendMouseMove(0, 0),
        throwsA(isA<DioException>()),
      );
    });
  });
}
