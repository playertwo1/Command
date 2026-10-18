/// Modelos de dados para o módulo Hermes IA (Onda v0.4)
class HermesConfigData {
  final bool enabled;
  final String endpointUrl;
  final String modelName;
  final bool hasApiKey;

  const HermesConfigData({
    required this.enabled,
    required this.endpointUrl,
    required this.modelName,
    required this.hasApiKey,
  });

  factory HermesConfigData.fromJson(Map<String, dynamic> json) {
    return HermesConfigData(
      enabled: json['enabled'] == true || json['Enabled'] == true,
      endpointUrl: (json['endpointUrl'] ?? json['EndpointUrl'] ?? '').toString(),
      modelName: (json['modelName'] ?? json['ModelName'] ?? '').toString(),
      hasApiKey: json['hasApiKey'] == true || json['HasApiKey'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'endpointUrl': endpointUrl,
      'modelName': modelName,
      'hasApiKey': hasApiKey,
    };
  }

  HermesConfigData copyWith({
    bool? enabled,
    String? endpointUrl,
    String? modelName,
    bool? hasApiKey,
  }) {
    return HermesConfigData(
      enabled: enabled ?? this.enabled,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      modelName: modelName ?? this.modelName,
      hasApiKey: hasApiKey ?? this.hasApiKey,
    );
  }
}

class HermesSuggestedAction {
  final String actionType;
  final String targetId;
  final String title;
  final String reason;
  final bool requiresConfirmation;

  const HermesSuggestedAction({
    required this.actionType,
    required this.targetId,
    required this.title,
    required this.reason,
    this.requiresConfirmation = true,
  });

  factory HermesSuggestedAction.fromJson(Map<String, dynamic> json) {
    return HermesSuggestedAction(
      actionType: (json['actionType'] ?? json['ActionType'] ?? '').toString(),
      targetId: (json['targetId'] ?? json['TargetId'] ?? '').toString(),
      title: (json['title'] ?? json['Title'] ?? '').toString(),
      reason: (json['reason'] ?? json['Reason'] ?? '').toString(),
      requiresConfirmation: json['requiresConfirmation'] != false && json['RequiresConfirmation'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionType': actionType,
      'targetId': targetId,
      'title': title,
      'reason': reason,
      'requiresConfirmation': requiresConfirmation,
    };
  }
}

class HermesAnalyzeResult {
  final bool success;
  final String reply;
  final String sanitizedContextSummary;
  final List<HermesSuggestedAction> suggestedActions;
  final String? errorCode;
  final String? errorMessage;

  const HermesAnalyzeResult({
    required this.success,
    required this.reply,
    required this.sanitizedContextSummary,
    this.suggestedActions = const [],
    this.errorCode,
    this.errorMessage,
  });

  factory HermesAnalyzeResult.fromJson(Map<String, dynamic> json) {
    List<HermesSuggestedAction> parseActions(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(HermesSuggestedAction.fromJson)
            .toList();
      }
      return const [];
    }

    return HermesAnalyzeResult(
      success: json['success'] == true || json['Success'] == true,
      reply: (json['reply'] ?? json['Reply'] ?? '').toString(),
      sanitizedContextSummary: (json['sanitizedContextSummary'] ?? json['SanitizedContextSummary'] ?? '').toString(),
      suggestedActions: parseActions(json['suggestedActions'] ?? json['SuggestedActions']),
      errorCode: json['errorCode']?.toString() ?? json['ErrorCode']?.toString(),
      errorMessage: json['errorMessage']?.toString() ?? json['ErrorMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'reply': reply,
      'sanitizedContextSummary': sanitizedContextSummary,
      'suggestedActions': suggestedActions.map((a) => a.toJson()).toList(),
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}
