import 'package:command/src/services/mobile_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileNotificationService Privacy Sanitization (Regra 4)', () {
    test('mascara caminhos de usuário do Windows', () {
      const raw = r'Arquivo salvo em C:\Users\notefael\Documents\plan.txt';
      final sanitized = MobileNotificationService.sanitizeNotificationText(raw);
      expect(sanitized, contains(r'C:\Users\***'));
      expect(sanitized, isNot(contains('notefael')));
    });

    test('mascara IPs locais privados (192.168.x.y, 10.x.y.z, 172.16.x.y)', () {
      const raw1 = 'Conectado ao PC no IP 192.168.15.22 na porta 4787';
      final s1 = MobileNotificationService.sanitizeNotificationText(raw1);
      expect(s1, contains('192.168.*.***'));
      expect(s1, isNot(contains('192.168.15.22')));

      const raw2 = 'Alerta no servidor 10.0.0.85';
      final s2 = MobileNotificationService.sanitizeNotificationText(raw2);
      expect(s2, contains('10.*.*.***'));
      expect(s2, isNot(contains('10.0.0.85')));

      const raw3 = 'Host em 172.20.10.2';
      final s3 = MobileNotificationService.sanitizeNotificationText(raw3);
      expect(s3, contains('172.*.*.***'));
    });

    test('mascara tokens e senhas', () {
      const raw = 'Erro de autorização: key: secret_12345 inválida';
      final sanitized = MobileNotificationService.sanitizeNotificationText(raw);
      expect(sanitized, contains('key=***'));
      expect(sanitized, isNot(contains('secret_12345')));
    });
  });

  group('MobileNotificationService Channels and Dispatch', () {
    test('dispara alerta crítico sanitizado no canal correto', () {
      final service = MobileNotificationService();

      service.notifyCriticalAlert(
        title: 'CPU 95% em 192.168.1.10',
        message: r'Processo no caminho C:\Users\dev\app.exe está travando',
      );

      expect(service.dispatchedNotifications.length, 1);
      final notif = service.dispatchedNotifications.first;
      expect(notif['channel'], MobileNotificationService.channelCriticalAlerts);
      expect(notif['title'], contains('192.168.*.***'));
      expect(notif['message'], contains(r'C:\Users\***'));
      expect(notif['message'], isNot(contains('dev')));
    });

    test('dispara job concluído no canal de transferências', () {
      final service = MobileNotificationService();

      service.notifyJobCompleted(
        title: 'Download Concluído',
        message: r'Arquivo salvo em C:\Users\lucas\Downloads\foto.png',
      );

      expect(service.dispatchedNotifications.length, 1);
      final notif = service.dispatchedNotifications.first;
      expect(notif['channel'], MobileNotificationService.channelTransferJobs);
      expect(notif['message'], contains(r'C:\Users\***'));
    });

    test('respeita flag notificationsEnabled desativada', () {
      final service = MobileNotificationService()..notificationsEnabled = false;

      service.notifyCriticalAlert(title: 'Alerta', message: 'Mensagem');
      service.notifyJobCompleted(title: 'Job', message: 'Mensagem');

      expect(service.dispatchedNotifications, isEmpty);
    });
  });
}
