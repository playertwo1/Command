using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace DroidDeck.Models
{
    public class HermesConfigDto
    {
        [JsonPropertyName("enabled")]
        public bool Enabled { get; set; }

        [JsonPropertyName("endpointUrl")]
        public string EndpointUrl { get; set; } = string.Empty;

        [JsonPropertyName("modelName")]
        public string ModelName { get; set; } = "gemini-3.8-flash";

        [JsonPropertyName("hasApiKey")]
        public bool HasApiKey { get; set; }
    }

    public class HermesUpdateConfigRequest
    {
        [JsonPropertyName("enabled")]
        public bool Enabled { get; set; }

        [JsonPropertyName("endpointUrl")]
        public string? EndpointUrl { get; set; }

        [JsonPropertyName("modelName")]
        public string? ModelName { get; set; }

        [JsonPropertyName("apiKey")]
        public string? ApiKey { get; set; }
    }

    public class HermesSuggestedActionDto
    {
        [JsonPropertyName("actionType")]
        public string ActionType { get; set; } = string.Empty;

        [JsonPropertyName("targetId")]
        public string TargetId { get; set; } = string.Empty;

        [JsonPropertyName("title")]
        public string Title { get; set; } = string.Empty;

        [JsonPropertyName("reason")]
        public string Reason { get; set; } = string.Empty;

        [JsonPropertyName("requiresConfirmation")]
        public bool RequiresConfirmation { get; set; } = true;
    }

    public class HermesAnalyzeRequest
    {
        [JsonPropertyName("prompt")]
        public string Prompt { get; set; } = string.Empty;

        [JsonPropertyName("includeTelemetry")]
        public bool IncludeTelemetry { get; set; } = true;

        [JsonPropertyName("includeTopProcesses")]
        public bool IncludeTopProcesses { get; set; } = true;

        [JsonPropertyName("screenshotId")]
        public string? ScreenshotId { get; set; }

        [JsonPropertyName("requestId")]
        public string? RequestId { get; set; }
    }

    public class HermesAnalyzeResponse
    {
        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("reply")]
        public string Reply { get; set; } = string.Empty;

        [JsonPropertyName("sanitizedContextSummary")]
        public string SanitizedContextSummary { get; set; } = string.Empty;

        [JsonPropertyName("suggestedActions")]
        public List<HermesSuggestedActionDto> SuggestedActions { get; set; } = new();

        [JsonPropertyName("errorCode")]
        public string? ErrorCode { get; set; }

        [JsonPropertyName("errorMessage")]
        public string? ErrorMessage { get; set; }

        [JsonPropertyName("timestampUtc")]
        public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
    }

    /// <summary>
    /// Alias/classe de compatibilidade para respostas de processos do topo
    /// </summary>
    public class TopProcessesResponse : TopProcessesResponseDto
    {
    }
}
