/// Serviço de notificações locais com sanitização defensiva de privacidade (Onda v0.6 - W2 / Regra 4).
class MobileNotificationService {
  bool notificationsEnabled = true;
  final List<Map<String, String>> dispatchedNotifications = [];

  static const String channelCriticalAlerts = 'command_critical_alerts';
  static const String channelTransferJobs = 'command_transfer_jobs';

  /// Sanitiza dados privados (caminhos de usuário, IPs privados e tokens) antes de exibir em notificações.
  static String sanitizeNotificationText(String input) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // 1. Mascara caminhos de usuários do Windows (C:\Users\<nome>\...)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'[A-Za-z]:\\Users\\[^\s\\]+', caseSensitive: false),
      (m) => r'C:\Users\***',
    );

    // 2. Mascara IPs privados 192.168.x.y
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b192\.168\.\d{1,3}\.\d{1,3}\b'),
      (m) => '192.168.*.***',
    );

    // 3. Mascara IPs privados 10.x.y.z
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b10\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
      (m) => '10.*.*.***',
    );

    // 4. Mascara IPs privados 172.16.x.y - 172.31.x.y
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'\b172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}\b'),
      (m) => '172.*.*.***',
    );

    // 5. Mascara tokens, chaves ou senhas
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(key|token|password|secret|bearer)\s*[:=]\s*[^\s,]+', caseSensitive: false),
      (m) => '${m.group(1)}=***',
    );

    return sanitized;
  }

  /// Dispara notificação de alerta crítico (temperatura, recursos) sanitizada.
  void notifyCriticalAlert({
    required String title,
    required String message,
  }) {
    if (!notificationsEnabled) return;

    dispatchedNotifications.add({
      'channel': channelCriticalAlerts,
      'title': sanitizeNotificationText(title),
      'message': sanitizeNotificationText(message),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Dispara notificação de conclusão de transferência de arquivo ou rotina.
  void notifyJobCompleted({
    required String title,
    required String message,
  }) {
    if (!notificationsEnabled) return;

    dispatchedNotifications.add({
      'channel': channelTransferJobs,
      'title': sanitizeNotificationText(title),
      'message': sanitizeNotificationText(message),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Limpa histórico de notificações em memória.
  void clearHistory() {
    dispatchedNotifications.clear();
  }
}
