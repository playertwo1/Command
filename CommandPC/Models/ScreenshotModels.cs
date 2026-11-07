using System;
using System.Text.Json.Serialization;

namespace Command.Models
{
    public class CaptureScreenshotRequest
    {
        [JsonPropertyName("requestId")]
        public string RequestId { get; set; } = "";

        [JsonPropertyName("deviceId")]
        public string? DeviceId { get; set; }
    }

    public class ScreenshotInfoDto
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("requestId")]
        public string RequestId { get; set; } = "";

        [JsonPropertyName("width")]
        public int Width { get; set; }

        [JsonPropertyName("height")]
        public int Height { get; set; }

        [JsonPropertyName("sizeBytes")]
        public long SizeBytes { get; set; }

        [JsonPropertyName("createdAtUtc")]
        public DateTime CreatedAtUtc { get; set; }

        [JsonPropertyName("expiresAtUtc")]
        public DateTime ExpiresAtUtc { get; set; }

        [JsonPropertyName("isExpired")]
        public bool IsExpired => DateTime.UtcNow > ExpiresAtUtc;
    }

    public class ScreenshotMetadata
    {
        public string Id { get; set; } = "";
        public string RequestId { get; set; } = "";
        public string? DeviceId { get; set; }
        public DateTime CreatedAtUtc { get; set; }
        public DateTime ExpiresAtUtc { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        public long FileSizeBytes { get; set; }
        public string FilePath { get; set; } = "";
    }

    public class ScreenshotCaptureResult
    {
        public bool Success { get; set; }
        public string? ErrorCode { get; set; }
        public string? ErrorMessage { get; set; }
        public ScreenshotMetadata? Metadata { get; set; }

        public static ScreenshotCaptureResult Ok(ScreenshotMetadata metadata) =>
            new() { Success = true, Metadata = metadata };

        public static ScreenshotCaptureResult Fail(string errorCode, string errorMessage) =>
            new() { Success = false, ErrorCode = errorCode, ErrorMessage = errorMessage };
    }

    public enum ScreenshotFileStatus
    {
        Found,
        NotFound,
        Expired,
        Forbidden
    }

    public class ScreenshotFileResult
    {
        public ScreenshotFileStatus Status { get; set; }
        public string? FilePath { get; set; }
        public string? ContentType { get; set; }
        public string? ErrorMessage { get; set; }
        public ScreenshotMetadata? Metadata { get; set; }

        public static ScreenshotFileResult FoundFile(string filePath, string contentType, ScreenshotMetadata metadata) =>
            new() { Status = ScreenshotFileStatus.Found, FilePath = filePath, ContentType = contentType, Metadata = metadata };

        public static ScreenshotFileResult Expired(string message = "Captura de tela expirada após 10 minutos.") =>
            new() { Status = ScreenshotFileStatus.Expired, ErrorMessage = message };

        public static ScreenshotFileResult NotFound(string message = "Captura de tela não encontrada.") =>
            new() { Status = ScreenshotFileStatus.NotFound, ErrorMessage = message };

        public static ScreenshotFileResult Forbidden(string message = "Acesso negado: captura pertence a outro dispositivo.") =>
            new() { Status = ScreenshotFileStatus.Forbidden, ErrorMessage = message };
    }
}
