using System;
using System.Text.Json.Serialization;

namespace Command.Models
{
    /// <summary>
    /// Configuração interna de um aplicativo ou projeto na allowlist.
    /// Caminhos e executáveis reais nunca são expostos ao cliente remoto.
    /// </summary>
    public class AppCatalogItem
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public string Description { get; set; } = "";
        public string Icon { get; set; } = "apps";
        public bool CanKill { get; set; } = false;
        public string Executable { get; set; } = "";
        public string? Arguments { get; set; }
        public string ProcessName { get; set; } = "";
    }

    /// <summary>
    /// Resumo seguro enviado aos clientes remotos (sem caminhos de arquivo).
    /// </summary>
    public class AppSummaryDto
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("name")]
        public string Name { get; set; } = "";

        [JsonPropertyName("description")]
        public string Description { get; set; } = "";

        [JsonPropertyName("icon")]
        public string Icon { get; set; } = "apps";

        [JsonPropertyName("canKill")]
        public bool CanKill { get; set; }

        [JsonPropertyName("isRunning")]
        public bool IsRunning { get; set; }

        [JsonPropertyName("processId")]
        public int? ProcessId { get; set; }

        [JsonPropertyName("startTimeUtc")]
        public DateTime? StartTimeUtc { get; set; }
    }

    public class LaunchAppRequest
    {
        [JsonPropertyName("requestId")]
        public string RequestId { get; set; } = "";

        [JsonPropertyName("deviceId")]
        public string? DeviceId { get; set; }
    }

    public class KillAppRequest
    {
        [JsonPropertyName("requestId")]
        public string RequestId { get; set; } = "";

        [JsonPropertyName("confirmed")]
        public bool Confirmed { get; set; }

        [JsonPropertyName("processId")]
        public int? ProcessId { get; set; }

        [JsonPropertyName("startTimeUtc")]
        public DateTime? StartTimeUtc { get; set; }

        [JsonPropertyName("deviceId")]
        public string? DeviceId { get; set; }
    }

    public class CommandJob
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = Guid.NewGuid().ToString("N");

        [JsonPropertyName("requestId")]
        public string RequestId { get; set; } = "";

        [JsonPropertyName("actionType")]
        public string ActionType { get; set; } = "";

        [JsonPropertyName("targetId")]
        public string TargetId { get; set; } = "";

        [JsonPropertyName("status")]
        public string Status { get; set; } = "accepted"; // accepted, running, succeeded, failed, cancelled, unknown

        [JsonPropertyName("createdAtUtc")]
        public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;

        [JsonPropertyName("completedAtUtc")]
        public DateTime? CompletedAtUtc { get; set; }

        [JsonPropertyName("errorMessage")]
        public string? ErrorMessage { get; set; }

        [JsonPropertyName("deviceId")]
        public string? DeviceId { get; set; }

        [JsonIgnore]
        public string? PayloadFingerprint { get; set; }
    }

    public class AppOperationResult
    {
        public bool Success { get; set; }
        public string? ErrorMessage { get; set; }
        public int? ProcessId { get; set; }
    }
}
