class AllowedApp {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool canKill;
  final bool isRunning;
  final int? processId;
  final DateTime? startTimeUtc;

  const AllowedApp({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.canKill,
    required this.isRunning,
    this.processId,
    this.startTimeUtc,
  });

  factory AllowedApp.fromJson(Map<String, dynamic> json) {
    return AllowedApp(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'apps',
      canKill: json['canKill'] as bool? ?? false,
      isRunning: json['isRunning'] as bool? ?? false,
      processId: json['processId'] as int?,
      startTimeUtc: json['startTimeUtc'] != null
          ? DateTime.tryParse(json['startTimeUtc'] as String)
          : null,
    );
  }
}

class CommandJob {
  final String id;
  final String requestId;
  final String actionType;
  final String targetId;
  final String status;
  final DateTime createdAtUtc;
  final DateTime? completedAtUtc;
  final String? errorMessage;
  final String? deviceId;

  const CommandJob({
    required this.id,
    required this.requestId,
    required this.actionType,
    required this.targetId,
    required this.status,
    required this.createdAtUtc,
    this.completedAtUtc,
    this.errorMessage,
    this.deviceId,
  });

  factory CommandJob.fromJson(Map<String, dynamic> json) {
    return CommandJob(
      id: json['id'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      createdAtUtc: json['createdAtUtc'] != null
          ? (DateTime.tryParse(json['createdAtUtc'] as String) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      completedAtUtc: json['completedAtUtc'] != null
          ? DateTime.tryParse(json['completedAtUtc'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
      deviceId: json['deviceId'] as String?,
    );
  }
}
