import 'dart:typed_data';

class TransferItem {
  final String name;
  final int sizeBytes;
  final String sha256;
  final DateTime modifiedAtUtc;

  TransferItem({
    required this.name,
    required this.sizeBytes,
    required this.sha256,
    required this.modifiedAtUtc,
  });

  String get fileName => name;
  String get checksumSha256 => sha256;

  factory TransferItem.fromJson(Map<String, dynamic> json) {
    return TransferItem(
      name: json['name'] as String? ?? json['fileName'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? json['checksumSha256'] as String? ?? '',
      modifiedAtUtc: json['modifiedAtUtc'] != null
          ? DateTime.tryParse(json['modifiedAtUtc'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'modifiedAtUtc': modifiedAtUtc.toIso8601String(),
  };

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UploadTransferResult {
  final bool success;
  final String? message;
  final TransferItem? item;

  const UploadTransferResult({
    required this.success,
    this.message,
    this.item,
  });
}

class FileDownloadData {
  final String fileName;
  final Uint8List bytes;
  final String checksumSha256;

  const FileDownloadData({
    required this.fileName,
    required this.bytes,
    required this.checksumSha256,
  });
}
