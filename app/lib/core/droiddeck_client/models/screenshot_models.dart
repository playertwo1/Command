class ScreenshotInfo {
  final String id;
  final String requestId;
  final int width;
  final int height;
  final int sizeBytes;
  final DateTime createdAtUtc;
  final DateTime expiresAtUtc;

  const ScreenshotInfo({
    required this.id,
    required this.requestId,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.createdAtUtc,
    required this.expiresAtUtc,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);

  factory ScreenshotInfo.fromJson(Map<String, dynamic> json) {
    return ScreenshotInfo(
      id: json['id'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      createdAtUtc: DateTime.tryParse(json['createdAtUtc'] as String? ?? '') ??
          DateTime.now().toUtc(),
      expiresAtUtc: DateTime.tryParse(json['expiresAtUtc'] as String? ?? '') ??
          DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'width': width,
        'height': height,
        'sizeBytes': sizeBytes,
        'createdAtUtc': createdAtUtc.toIso8601String(),
        'expiresAtUtc': expiresAtUtc.toIso8601String(),
      };
}
