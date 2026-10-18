using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace DroidDeck.Models
{
    public class RoutineStepDto
    {
        [JsonPropertyName("stepId")]
        public string StepId { get; set; } = Guid.NewGuid().ToString("N");

        [JsonPropertyName("actionType")]
        public string ActionType { get; set; } = string.Empty; // "app.launch", "app.kill", "screenshot.capture", "delay"

        [JsonPropertyName("targetId")]
        public string TargetId { get; set; } = string.Empty; // "obsidian", "orbit", "test_notepad", "primary"

        [JsonPropertyName("delayMs")]
        public int DelayMs { get; set; } = 500;

        [JsonPropertyName("continueOnError")]
        public bool ContinueOnError { get; set; } = false;
    }

    public class RoutineDefinitionDto
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = string.Empty;

        [JsonPropertyName("name")]
        public string Name { get; set; } = string.Empty;

        [JsonPropertyName("description")]
        public string Description { get; set; } = string.Empty;

        [JsonPropertyName("icon")]
        public string Icon { get; set; } = "bolt";

        [JsonPropertyName("isPreset")]
        public bool IsPreset { get; set; } = false;

        [JsonPropertyName("requiresConfirmation")]
        public bool RequiresConfirmation { get; set; } = true;

        [JsonPropertyName("steps")]
        public List<RoutineStepDto> Steps { get; set; } = new();
    }

    public class RoutineStepResultDto
    {
        [JsonPropertyName("stepId")]
        public string StepId { get; set; } = string.Empty;

        [JsonPropertyName("actionType")]
        public string ActionType { get; set; } = string.Empty;

        [JsonPropertyName("targetId")]
        public string TargetId { get; set; } = string.Empty;

        [JsonPropertyName("status")]
        public string Status { get; set; } = "skipped"; // "succeeded", "failed", "skipped"

        [JsonPropertyName("jobId")]
        public string? JobId { get; set; }

        [JsonPropertyName("errorMessage")]
        public string? ErrorMessage { get; set; }

        [JsonPropertyName("durationMs")]
        public long DurationMs { get; set; }
    }

    public class RoutineExecutionResponse
    {
        [JsonPropertyName("routineId")]
        public string RoutineId { get; set; } = string.Empty;

        [JsonPropertyName("routineName")]
        public string RoutineName { get; set; } = string.Empty;

        [JsonPropertyName("overallStatus")]
        public string OverallStatus { get; set; } = "aborted"; // "succeeded", "partial_failure", "failed", "aborted"

        [JsonPropertyName("stepResults")]
        public List<RoutineStepResultDto> StepResults { get; set; } = new();

        [JsonPropertyName("startedAtUtc")]
        public DateTime StartedAtUtc { get; set; } = DateTime.UtcNow;

        [JsonPropertyName("completedAtUtc")]
        public DateTime CompletedAtUtc { get; set; } = DateTime.UtcNow;
    }

    public class WebhookConfigDto
    {
        [JsonPropertyName("enabled")]
        public bool Enabled { get; set; }

        [JsonPropertyName("webhookUrl")]
        public string WebhookUrl { get; set; } = string.Empty;

        [JsonPropertyName("hasWebhookUrl")]
        public bool HasWebhookUrl { get; set; }

        [JsonPropertyName("notifyOnRoutineComplete")]
        public bool NotifyOnRoutineComplete { get; set; } = true;

        [JsonPropertyName("notifyOnCriticalAlert")]
        public bool NotifyOnCriticalAlert { get; set; } = true;
    }

    public class WebhookUpdateConfigRequest
    {
        [JsonPropertyName("enabled")]
        public bool Enabled { get; set; }

        [JsonPropertyName("webhookUrl")]
        public string? WebhookUrl { get; set; }

        [JsonPropertyName("notifyOnRoutineComplete")]
        public bool NotifyOnRoutineComplete { get; set; } = true;

        [JsonPropertyName("notifyOnCriticalAlert")]
        public bool NotifyOnCriticalAlert { get; set; } = true;
    }

    public class WebhookTestRequest
    {
        [JsonPropertyName("customMessage")]
        public string? CustomMessage { get; set; }
    }
}
