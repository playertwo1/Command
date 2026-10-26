using System;
using System.Collections.Generic;

namespace DroidDeck.Models
{
    public class TransferItemDto
    {
        public string Name { get; set; } = string.Empty;
        public long SizeBytes { get; set; }
        public string Sha256 { get; set; } = string.Empty;
        public DateTime ModifiedAtUtc { get; set; }
    }

    public class UploadTransferResult
    {
        public bool Success { get; set; }
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public TransferItemDto? Item { get; set; }
    }

    public class ChunkUploadResult
    {
        public bool Success { get; set; }
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public string UploadId { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public long BytesReceived { get; set; }
        public bool IsComplete { get; set; }
        public TransferItemDto? Item { get; set; }
    }

    public class ResumableUploadStatusResult
    {
        public bool Exists { get; set; }
        public string UploadId { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public long BytesReceived { get; set; }
        public long TotalSize { get; set; }
        public bool IsComplete { get; set; }
    }

    public class FileDownloadResult
    {
        public bool Success { get; set; }
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public System.IO.Stream? Stream { get; set; }
        public string FileName { get; set; } = string.Empty;
        public string ContentType { get; set; } = "application/octet-stream";
        public long SizeBytes { get; set; }
        public string Sha256 { get; set; } = string.Empty;
        public long Offset { get; set; }
        public long ChunkLength { get; set; }
        public bool IsChunked { get; set; }
    }

    public class DirectoryItemDto
    {
        public string Name { get; set; } = string.Empty;
        public string RelativePath { get; set; } = string.Empty;
        public long SizeBytes { get; set; }
        public DateTime ModifiedAtUtc { get; set; }
        public string Extension { get; set; } = string.Empty;
        public bool IsDirectory { get; set; }
    }

    public class DirectoryBrowseResult
    {
        public bool Success { get; set; }
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public string RootId { get; set; } = string.Empty;
        public string CurrentPath { get; set; } = string.Empty;
        public List<DirectoryItemDto> Items { get; set; } = new();
    }
}
