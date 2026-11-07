/// Modelos de dados para energia, sessão e Wake-on-LAN (Onda v0.6 - W0/W1)
class NetworkWakeInfo {
  final String hostName;
  final String macAddress;
  final String localIp;
  final int wolPort;
  final bool supportsWakeOnLan;

  const NetworkWakeInfo({
    required this.hostName,
    required this.macAddress,
    required this.localIp,
    this.wolPort = 9,
    this.supportsWakeOnLan = true,
  });

  factory NetworkWakeInfo.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 9;
      return 9;
    }

    return NetworkWakeInfo(
      hostName: (json['hostName'] ?? json['HostName'] ?? '').toString(),
      macAddress: (json['macAddress'] ?? json['MacAddress'] ?? '').toString(),
      localIp: (json['localIp'] ?? json['LocalIp'] ?? '').toString(),
      wolPort: parseInt(json['wolPort'] ?? json['WolPort']),
      supportsWakeOnLan: json['supportsWakeOnLan'] != false && json['SupportsWakeOnLan'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hostName': hostName,
      'macAddress': macAddress,
      'localIp': localIp,
      'wolPort': wolPort,
      'supportsWakeOnLan': supportsWakeOnLan,
    };
  }

  NetworkWakeInfo copyWith({
    String? hostName,
    String? macAddress,
    String? localIp,
    int? wolPort,
    bool? supportsWakeOnLan,
  }) {
    return NetworkWakeInfo(
      hostName: hostName ?? this.hostName,
      macAddress: macAddress ?? this.macAddress,
      localIp: localIp ?? this.localIp,
      wolPort: wolPort ?? this.wolPort,
      supportsWakeOnLan: supportsWakeOnLan ?? this.supportsWakeOnLan,
    );
  }
}

class PowerActionResult {
  final bool success;
  final String action;
  final String status;
  final String? jobId;
  final String? errorCode;
  final String? errorMessage;

  const PowerActionResult({
    required this.success,
    required this.action,
    required this.status,
    this.jobId,
    this.errorCode,
    this.errorMessage,
  });

  factory PowerActionResult.fromJson(Map<String, dynamic> json) {
    return PowerActionResult(
      success: json['success'] == true || json['Success'] == true,
      action: (json['action'] ?? json['Action'] ?? '').toString(),
      status: (json['status'] ?? json['Status'] ?? 'unknown').toString(),
      jobId: json['jobId']?.toString() ?? json['JobId']?.toString(),
      errorCode: json['errorCode']?.toString() ?? json['ErrorCode']?.toString(),
      errorMessage: json['errorMessage']?.toString() ?? json['ErrorMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'action': action,
      'status': status,
      if (jobId != null) 'jobId': jobId,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}
