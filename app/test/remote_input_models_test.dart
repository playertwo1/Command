import 'package:droiddeck/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteControlSessionInfo', () {
    test('fromJson and toJson roundtrip properly with valid data', () {
      final json = {
        'sessionId': 'sess-123',
        'deviceId': 'dev-456',
        'timeoutSeconds': 60,
        'isActive': true,
      };

      final info = RemoteControlSessionInfo.fromJson(json);

      expect(info.sessionId, 'sess-123');
      expect(info.deviceId, 'dev-456');
      expect(info.timeoutSeconds, 60);
      expect(info.isActive, isTrue);

      final exported = info.toJson();
      expect(exported['sessionId'], 'sess-123');
      expect(exported['deviceId'], 'dev-456');
      expect(exported['timeoutSeconds'], 60);
      expect(exported['isActive'], isTrue);
    });

    test('handles fallback and PascalCase keys cleanly', () {
      final json = {
        'SessionId': 'sess-upper',
        'DeviceId': 'dev-upper',
        'TimeoutSeconds': '45',
        'isActive': false,
      };

      final info = RemoteControlSessionInfo.fromJson(json);

      expect(info.sessionId, 'sess-upper');
      expect(info.deviceId, 'dev-upper');
      expect(info.timeoutSeconds, 45);
      expect(info.isActive, isFalse);
    });

    test('copyWith creates updated instance', () {
      const original = RemoteControlSessionInfo(
        sessionId: 's1',
        deviceId: 'd1',
        timeoutSeconds: 30,
        isActive: true,
      );

      final copy = original.copyWith(isActive: false, timeoutSeconds: 90);

      expect(copy.sessionId, 's1');
      expect(copy.deviceId, 'd1');
      expect(copy.timeoutSeconds, 90);
      expect(copy.isActive, isFalse);
      expect(copy == original, isFalse);
    });
  });

  group('Typed Remote Input Exceptions', () {
    test('RemoteInputLockedException (423)', () {
      const exDefault = RemoteInputLockedException();
      expect(exDefault.message, contains('Sessão do Windows bloqueada'));
      expect(exDefault.toString(), contains('RemoteInputLockedException'));

      const exCustom = RemoteInputLockedException('Custom lock');
      expect(exCustom.message, 'Custom lock');
    });

    test('RemoteInputForbiddenException (403)', () {
      const ex = RemoteInputForbiddenException('No permission');
      expect(ex.message, 'No permission');
      expect(ex.toString(), contains('RemoteInputForbiddenException'));
    });

    test('RemoteInputConflictException (409)', () {
      const ex = RemoteInputConflictException('Session busy', 'device-2');
      expect(ex.message, 'Session busy');
      expect(ex.activeDeviceId, 'device-2');
      expect(ex.toString(), contains('device-2'));
    });

    test('RemoteInputTextTooLargeException (413)', () {
      const ex = RemoteInputTextTooLargeException();
      expect(ex.message, contains('500 caracteres'));
      expect(ex.toString(), contains('RemoteInputTextTooLargeException'));
    });

    test('RemoteInputRateLimitException (429)', () {
      const ex = RemoteInputRateLimitException();
      expect(ex.message, contains('rate limit'));
      expect(ex.toString(), contains('RemoteInputRateLimitException'));
    });
  });
}
