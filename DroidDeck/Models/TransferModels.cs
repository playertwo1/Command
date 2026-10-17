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
    }
}
