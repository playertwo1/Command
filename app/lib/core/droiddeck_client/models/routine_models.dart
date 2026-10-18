/// Modelos de dados para Rotinas, Modos de Ambiente e Macros Encadeadas (Onda v0.5 - M1/M2)
class RoutineStepData {
  final String stepId;
  final String actionType;
  final String targetId;
  final int delayMs;
  final bool continueOnError;

  const RoutineStepData({
    required this.stepId,
    required this.actionType,
    required this.targetId,
    this.delayMs = 0,
    this.continueOnError = false,
  });

  factory RoutineStepData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return RoutineStepData(
      stepId: (json['stepId'] ?? json['StepId'] ?? '').toString(),
      actionType: (json['actionType'] ?? json['ActionType'] ?? '').toString(),
      targetId: (json['targetId'] ?? json['TargetId'] ?? '').toString(),
      delayMs: parseInt(json['delayMs'] ?? json['DelayMs'] ?? json['delayAfterMs'] ?? json['DelayAfterMs']),
      continueOnError: json['continueOnError'] == true || json['ContinueOnError'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepId': stepId,
      'actionType': actionType,
      'targetId': targetId,
      'delayMs': delayMs,
      'continueOnError': continueOnError,
    };
  }

  RoutineStepData copyWith({
    String? stepId,
    String? actionType,
    String? targetId,
    int? delayMs,
    bool? continueOnError,
  }) {
    return RoutineStepData(
      stepId: stepId ?? this.stepId,
      actionType: actionType ?? this.actionType,
      targetId: targetId ?? this.targetId,
      delayMs: delayMs ?? this.delayMs,
      continueOnError: continueOnError ?? this.continueOnError,
    );
  }
}

class RoutineDefinitionData {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isPreset;
  final bool requiresConfirmation;
  final List<RoutineStepData> steps;

  const RoutineDefinitionData({
    required this.id,
    required this.name,
    required this.description,
    this.icon = 'auto_mode',
    this.isPreset = false,
    this.requiresConfirmation = true,
    this.steps = const [],
  });

  factory RoutineDefinitionData.fromJson(Map<String, dynamic> json) {
    List<RoutineStepData> parseSteps(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(RoutineStepData.fromJson)
            .toList();
      }
      return const [];
    }

    return RoutineDefinitionData(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      description: (json['description'] ?? json['Description'] ?? '').toString(),
      icon: (json['icon'] ?? json['Icon'] ?? 'auto_mode').toString(),
      isPreset: json['isPreset'] == true || json['IsPreset'] == true,
      requiresConfirmation: json['requiresConfirmation'] != false && json['RequiresConfirmation'] != false,
      steps: parseSteps(json['steps'] ?? json['Steps']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'isPreset': isPreset,
      'requiresConfirmation': requiresConfirmation,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }

  RoutineDefinitionData copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    bool? isPreset,
    bool? requiresConfirmation,
    List<RoutineStepData>? steps,
  }) {
    return RoutineDefinitionData(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isPreset: isPreset ?? this.isPreset,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      steps: steps ?? this.steps,
    );
  }
}

class RoutineStepResultData {
  final String stepId;
  final String actionType;
  final String targetId;
  final String status;
  final String? jobId;
  final String? errorMessage;
  final int durationMs;

  const RoutineStepResultData({
    required this.stepId,
    required this.actionType,
    required this.targetId,
    required this.status,
    this.jobId,
    this.errorMessage,
    this.durationMs = 0,
  });

  factory RoutineStepResultData.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return RoutineStepResultData(
      stepId: (json['stepId'] ?? json['StepId'] ?? '').toString(),
      actionType: (json['actionType'] ?? json['ActionType'] ?? '').toString(),
      targetId: (json['targetId'] ?? json['TargetId'] ?? '').toString(),
      status: (json['status'] ?? json['Status'] ?? 'unknown').toString(),
      jobId: json['jobId']?.toString() ?? json['JobId']?.toString(),
      errorMessage: json['errorMessage']?.toString() ?? json['ErrorMessage']?.toString(),
      durationMs: parseInt(json['durationMs'] ?? json['DurationMs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepId': stepId,
      'actionType': actionType,
      'targetId': targetId,
      'status': status,
      if (jobId != null) 'jobId': jobId,
      if (errorMessage != null) 'errorMessage': errorMessage,
      'durationMs': durationMs,
    };
  }
}

class RoutineExecutionResult {
  final String routineId;
  final String routineName;
  final String overallStatus;
  final List<RoutineStepResultData> stepResults;

  const RoutineExecutionResult({
    required this.routineId,
    required this.routineName,
    required this.overallStatus,
    this.stepResults = const [],
  });

  factory RoutineExecutionResult.fromJson(Map<String, dynamic> json) {
    List<RoutineStepResultData> parseResults(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(RoutineStepResultData.fromJson)
            .toList();
      }
      return const [];
    }

    return RoutineExecutionResult(
      routineId: (json['routineId'] ?? json['RoutineId'] ?? '').toString(),
      routineName: (json['routineName'] ?? json['RoutineName'] ?? '').toString(),
      overallStatus: (json['overallStatus'] ?? json['OverallStatus'] ?? 'unknown').toString(),
      stepResults: parseResults(json['stepResults'] ?? json['StepResults']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routineId': routineId,
      'routineName': routineName,
      'overallStatus': overallStatus,
      'stepResults': stepResults.map((r) => r.toJson()).toList(),
    };
  }
}
