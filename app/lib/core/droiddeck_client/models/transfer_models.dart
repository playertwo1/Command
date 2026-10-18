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

