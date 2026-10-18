/// Modelos de dados para Segurança, Controle de Acesso RBAC, Backup Criptografado e Atualizações (Ondas P0, P1 e P2).

class DevicePermissionModel {
  final String deviceId;
  final String role;
  final String updatedAtUtc;

  const DevicePermissionModel({
    required this.deviceId,
    required this.role,
    required this.updatedAtUtc,
  });

  factory DevicePermissionModel.fromJson(Map<String, dynamic> json) {
    return DevicePermissionModel(
      deviceId: (json['deviceId'] ?? json['DeviceId'] ?? '').toString(),
      role: (json['role'] ?? json['Role'] ?? 'operator').toString(),
      updatedAtUtc: (json['updatedAtUtc'] ?? json['UpdatedAtUtc'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'role': role,
      'updatedAtUtc': updatedAtUtc,
    };
  }

  DevicePermissionModel copyWith({
    String? deviceId,
    String? role,
    String? updatedAtUtc,
  }) {
    return DevicePermissionModel(
      deviceId: deviceId ?? this.deviceId,
      role: role ?? this.role,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}

class SecurityAuditEntryModel {
  final String id;
  final String deviceId;
  final String actionType;
  final bool allowed;
  final String? reason;
  final String timestampUtc;

  const SecurityAuditEntryModel({
    required this.id,
    required this.deviceId,
    required this.actionType,
    required this.allowed,
    this.reason,
    required this.timestampUtc,
  });

  factory SecurityAuditEntryModel.fromJson(Map<String, dynamic> json) {
    return SecurityAuditEntryModel(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? json['DeviceId'] ?? '').toString(),
      actionType: (json['actionType'] ?? json['ActionType'] ?? '').toString(),
      allowed: json['allowed'] == true || json['Allowed'] == true,
      reason: json['reason']?.toString() ?? json['Reason']?.toString(),
      timestampUtc: (json['timestampUtc'] ?? json['TimestampUtc'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'actionType': actionType,
      'allowed': allowed,
      if (reason != null) 'reason': reason,
      'timestampUtc': timestampUtc,
    };
  }
}

class EncryptedBackupEnvelopeModel {
  final int formatVersion;
  final String app;
  final String version;
  final String createdAtUtc;
  final String saltBase64;
  final String nonceBase64;
  final String tagBase64;
  final String ciphertextBase64;
  final String plaintextSha256;

  const EncryptedBackupEnvelopeModel({
    this.formatVersion = 1,
    this.app = 'Command',
    this.version = '1.0.0',
    required this.createdAtUtc,
    required this.saltBase64,
    required this.nonceBase64,
    required this.tagBase64,
    required this.ciphertextBase64,
    required this.plaintextSha256,
  });

  factory EncryptedBackupEnvelopeModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 1;
      return 1;
    }

    return EncryptedBackupEnvelopeModel(
      formatVersion: parseInt(json['formatVersion'] ?? json['FormatVersion']),
      app: (json['app'] ?? json['App'] ?? 'Command').toString(),
      version: (json['version'] ?? json['Version'] ?? '1.0.0').toString(),
      createdAtUtc: (json['createdAtUtc'] ?? json['CreatedAtUtc'] ?? '').toString(),
      saltBase64: (json['saltBase64'] ?? json['SaltBase64'] ?? '').toString(),
      nonceBase64: (json['nonceBase64'] ?? json['NonceBase64'] ?? '').toString(),
      tagBase64: (json['tagBase64'] ?? json['TagBase64'] ?? '').toString(),
      ciphertextBase64: (json['ciphertextBase64'] ?? json['CiphertextBase64'] ?? '').toString(),
      plaintextSha256: (json['plaintextSha256'] ?? json['PlaintextSha256'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formatVersion': formatVersion,
      'app': app,
      'version': version,
      'createdAtUtc': createdAtUtc,
      'saltBase64': saltBase64,
      'nonceBase64': nonceBase64,
      'tagBase64': tagBase64,
      'ciphertextBase64': ciphertextBase64,
      'plaintextSha256': plaintextSha256,
    };
  }
}

class EncryptedBackupRestoreResultModel {
  final bool success;
  final int restoredRoutinesCount;
  final int restoredPermissionsCount;
  final String? errorCode;
  final String? errorMessage;

  const EncryptedBackupRestoreResultModel({
    required this.success,
    this.restoredRoutinesCount = 0,
    this.restoredPermissionsCount = 0,
    this.errorCode,
    this.errorMessage,
  });

  factory EncryptedBackupRestoreResultModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return EncryptedBackupRestoreResultModel(
      success: json['success'] == true || json['Success'] == true,
      restoredRoutinesCount: parseInt(json['restoredRoutinesCount'] ?? json['RestoredRoutinesCount']),
      restoredPermissionsCount: parseInt(json['restoredPermissionsCount'] ?? json['RestoredPermissionsCount']),
      errorCode: json['errorCode']?.toString() ?? json['ErrorCode']?.toString(),
      errorMessage: json['errorMessage']?.toString() ?? json['ErrorMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'restoredRoutinesCount': restoredRoutinesCount,
      'restoredPermissionsCount': restoredPermissionsCount,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

class UpdateStatusModel {
  final String currentVersion;
  final String channel;
  final bool updateAvailable;
  final String? latestVersion;
  final bool isVelopackReady;
  final String? binarySha256;
  final String checkedAtUtc;

  const UpdateStatusModel({
    required this.currentVersion,
    required this.channel,
    required this.updateAvailable,
    this.latestVersion,
    this.isVelopackReady = false,
    this.binarySha256,
    required this.checkedAtUtc,
  });

  factory UpdateStatusModel.fromJson(Map<String, dynamic> json) {
    return UpdateStatusModel(
      currentVersion: (json['currentVersion'] ?? json['CurrentVersion'] ?? '').toString(),
      channel: (json['channel'] ?? json['Channel'] ?? 'stable').toString(),
      updateAvailable: json['updateAvailable'] == true || json['UpdateAvailable'] == true,
      latestVersion: json['latestVersion']?.toString() ?? json['LatestVersion']?.toString(),
      isVelopackReady: json['isVelopackReady'] == true || json['IsVelopackReady'] == true,
      binarySha256: json['binarySha256']?.toString() ?? json['BinarySha256']?.toString(),
      checkedAtUtc: (json['checkedAtUtc'] ?? json['CheckedAtUtc'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentVersion': currentVersion,
      'channel': channel,
      'updateAvailable': updateAvailable,
      if (latestVersion != null) 'latestVersion': latestVersion,
      'isVelopackReady': isVelopackReady,
      if (binarySha256 != null) 'binarySha256': binarySha256,
      'checkedAtUtc': checkedAtUtc,
    };
  }
}

class SystemStabilityModel {
  final double workingSetMb;
  final int handleCount;
  final int threadCount;
  final double bridgeUptimeSeconds;
  final String healthStatus;
  final String timestampUtc;

  const SystemStabilityModel({
    required this.workingSetMb,
    required this.handleCount,
    required this.threadCount,
    required this.bridgeUptimeSeconds,
    required this.healthStatus,
    required this.timestampUtc,
  });

  factory SystemStabilityModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return SystemStabilityModel(
      workingSetMb: parseDouble(json['workingSetMb'] ?? json['WorkingSetMb']),
      handleCount: parseInt(json['handleCount'] ?? json['HandleCount']),
      threadCount: parseInt(json['threadCount'] ?? json['ThreadCount']),
      bridgeUptimeSeconds: parseDouble(json['bridgeUptimeSeconds'] ?? json['BridgeUptimeSeconds']),
      healthStatus: (json['healthStatus'] ?? json['HealthStatus'] ?? 'Healthy').toString(),
      timestampUtc: (json['timestampUtc'] ?? json['TimestampUtc'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workingSetMb': workingSetMb,
      'handleCount': handleCount,
      'threadCount': threadCount,
      'bridgeUptimeSeconds': bridgeUptimeSeconds,
      'healthStatus': healthStatus,
      'timestampUtc': timestampUtc,
    };
  }
}
