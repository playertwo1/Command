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

class DirectoryBrowseItem {
  final String name;
  final String relativePath;
  final int sizeBytes;
  final DateTime modifiedAtUtc;
  final String extension;
  final bool isDirectory;

  const DirectoryBrowseItem({
    required this.name,
    required this.relativePath,
    required this.sizeBytes,
    required this.modifiedAtUtc,
    required this.extension,
    required this.isDirectory,
  });

  factory DirectoryBrowseItem.fromJson(Map<String, dynamic> json) {
    return DirectoryBrowseItem(
      name: json['name'] as String? ?? '',
      relativePath: json['relativePath'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      modifiedAtUtc: json['modifiedAtUtc'] != null
          ? DateTime.tryParse(json['modifiedAtUtc'].toString())?.toUtc() ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
      extension: json['extension'] as String? ?? '',
      isDirectory: json['isDirectory'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'relativePath': relativePath,
    'sizeBytes': sizeBytes,
    'modifiedAtUtc': modifiedAtUtc.toIso8601String(),
    'extension': extension,
    'isDirectory': isDirectory,
  };

  String get formattedSize {
    if (isDirectory) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DirectoryBrowseResult {
  final String rootId;
  final String currentPath;
  final List<DirectoryBrowseItem> items;

  const DirectoryBrowseResult({
    required this.rootId,
    required this.currentPath,
    required this.items,
  });

  factory DirectoryBrowseResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return DirectoryBrowseResult(
      rootId: json['rootId'] as String? ?? '',
      currentPath: json['currentPath'] as String? ?? '',
      items: list.map((e) => DirectoryBrowseItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ChunkUploadResponse {
  final bool success;
  final String errorCode;
  final String errorMessage;
  final String uploadId;
  final String fileName;
  final int bytesReceived;
  final bool isComplete;
  final TransferItem? item;

  const ChunkUploadResponse({
    required this.success,
    this.errorCode = '',
    this.errorMessage = '',
    this.uploadId = '',
    this.fileName = '',
    this.bytesReceived = 0,
    this.isComplete = false,
    this.item,
  });

  factory ChunkUploadResponse.fromJson(Map<String, dynamic> json) {
    return ChunkUploadResponse(
      success: json['success'] as bool? ?? false,
      errorCode: json['errorCode'] as String? ?? '',
      errorMessage: json['errorMessage'] as String? ?? '',
      uploadId: json['uploadId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      isComplete: json['isComplete'] as bool? ?? false,
      item: json['item'] != null ? TransferItem.fromJson(json['item'] as Map<String, dynamic>) : null,
    );
  }
}

class ResumableUploadStatus {
  final bool exists;
  final String uploadId;
  final String fileName;
  final int bytesReceived;
  final int totalSize;
  final bool isComplete;

  const ResumableUploadStatus({
    required this.exists,
    required this.uploadId,
    required this.fileName,
    required this.bytesReceived,
    required this.totalSize,
    required this.isComplete,
  });

  factory ResumableUploadStatus.fromJson(Map<String, dynamic> json) {
    return ResumableUploadStatus(
      exists: json['exists'] as bool? ?? false,
      uploadId: json['uploadId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      bytesReceived: (json['bytesReceived'] as num?)?.toInt() ?? 0,
      totalSize: (json['totalSize'] as num?)?.toInt() ?? 0,
      isComplete: json['isComplete'] as bool? ?? false,
    );
  }
}

