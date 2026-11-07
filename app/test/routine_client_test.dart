import 'package:command/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'executeRoutine envia X-Device-Id no header, sem query de identidade',
    () async {
      final dio = Dio();
      final client = CommandClient(baseUrl: 'https://bridge.test', dio: dio);
      RequestOptions? request;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'routineId': 'routine-1',
                  'routineName': 'Routine',
                  'overallStatus': 'succeeded',
                  'stepResults': [],
                },
              ),
            );
          },
        ),
      );

      await client.executeRoutine('routine-1', deviceId: 'profile-123');

      expect(request!.headers['X-Device-Id'], 'profile-123');
      expect(request!.queryParameters, {'confirmed': true});
    },
  );
}
