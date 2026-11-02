using System;
using System.Text.Json.Serialization;

namespace DroidDeck.Models
{
    public class NetworkWakeInfoDto
    {
        [JsonPropertyName("hostName")]
        public string HostName { get; set; } = string.Empty;

        [JsonPropertyName("macAddress")]
        public string MacAddress { get; set; } = string.Empty; // Formato: "AA:BB:CC:DD:EE:FF"

        [JsonPropertyName("localIp")]
        public string LocalIp { get; set; } = string.Empty;

        [JsonPropertyName("wolPort")]
        public int WolPort { get; set; } = 9;

        [JsonPropertyName("supportsWakeOnLan")]
        public bool SupportsWakeOnLan { get; set; } = true;
    }

    public class PowerActionRequest
    {
        [JsonPropertyName("action")]
        public string Action { get; set; } = string.Empty; // lock, sleep, shutdown ou restart

        [JsonPropertyName("confirmed")]
        public bool Confirmed { get; set; }

        [JsonPropertyName("requestId")]
        public string? RequestId { get; set; }
    }

    public class PowerActionResultDto
    {
        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("action")]
        public string Action { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = "aborted"; // "succeeded", "failed", "aborted"

        [JsonPropertyName("jobId")]
        public string? JobId { get; set; }

        [JsonPropertyName("errorCode")]
        public string? ErrorCode { get; set; }

        [JsonPropertyName("errorMessage")]
        public string? ErrorMessage { get; set; }

        [JsonPropertyName("timestampUtc")]
        public DateTime TimestampUtc { get; set; } = DateTime.UtcNow;
    }
}
