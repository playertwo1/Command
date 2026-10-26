// Modelos e exceções de controle remoto (Fase R1 - Trackpad e Teclado).

class RemoteControlSessionInfo {
  final String sessionId;
  final String deviceId;
  final int timeoutSeconds;
  final bool isActive;

  const RemoteControlSessionInfo({
    this.sessionId = '',
    this.deviceId = '',
    this.timeoutSeconds = 60,
    this.isActive = true,
  });

  factory RemoteControlSessionInfo.fromJson(Map<String, dynamic> json) {
    int parseTimeout(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 60;
      return 60;
    }

    return RemoteControlSessionInfo(
      sessionId: (json['sessionId'] ?? json['SessionId'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? json['DeviceId'] ?? '').toString(),
      timeoutSeconds: parseTimeout(json['timeoutSeconds'] ?? json['TimeoutSeconds']),
      isActive: json['isActive'] != null ? json['isActive'] == true : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceId': deviceId,
      'timeoutSeconds': timeoutSeconds,
      'isActive': isActive,
    };
  }

  RemoteControlSessionInfo copyWith({
    String? sessionId,
    String? deviceId,
    int? timeoutSeconds,
    bool? isActive,
  }) {
    return RemoteControlSessionInfo(
      sessionId: sessionId ?? this.sessionId,
      deviceId: deviceId ?? this.deviceId,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteControlSessionInfo &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          deviceId == other.deviceId &&
          timeoutSeconds == other.timeoutSeconds &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      sessionId.hashCode ^
      deviceId.hashCode ^
      timeoutSeconds.hashCode ^
      isActive.hashCode;

  @override
  String toString() =>
      'RemoteControlSessionInfo(sessionId: $sessionId, deviceId: $deviceId, timeoutSeconds: $timeoutSeconds, isActive: $isActive)';
}

/// Sessão remota bloqueada pelo Windows ou sem display interativo ativo (HTTP 423).
class RemoteInputLockedException implements Exception {
  final String message;
  const RemoteInputLockedException([this.message = 'Sessão do Windows bloqueada ou sem display ativo.']);

  @override
  String toString() => 'RemoteInputLockedException: $message';
}

/// Dispositivo sem permissão para controle remoto (ViewerOnly) (HTTP 403).
class RemoteInputForbiddenException implements Exception {
  final String message;
  const RemoteInputForbiddenException([this.message = 'Dispositivo sem permissão para controle remoto (ViewerOnly).']);

  @override
  String toString() => 'RemoteInputForbiddenException: $message';
}

/// Conflito de controle: outro dispositivo já possui a sessão ativa (HTTP 409).
class RemoteInputConflictException implements Exception {
  final String message;
  final String? activeDeviceId;
  const RemoteInputConflictException([
    this.message = 'Outro dispositivo já está controlando esta sessão.',
    this.activeDeviceId,
  ]);

  @override
  String toString() =>
      'RemoteInputConflictException: $message${activeDeviceId != null ? ' (ativo: $activeDeviceId)' : ''}';
}

/// Texto enviado excede o limite máximo permitido de 500 caracteres (HTTP 413).
class RemoteInputTextTooLargeException implements Exception {
  final String message;
  const RemoteInputTextTooLargeException([
    this.message = 'Texto excede o limite máximo permitido de 500 caracteres.',
  ]);

  @override
  String toString() => 'RemoteInputTextTooLargeException: $message';
}

/// Taxa de eventos de entrada remota excedeu o limite seguro (HTTP 429).
class RemoteInputRateLimitException implements Exception {
  final String message;
  const RemoteInputRateLimitException([
    this.message = 'Taxa de eventos remotos excedeu o limite seguro (rate limit).',
  ]);

  @override
  String toString() => 'RemoteInputRateLimitException: $message';
}
