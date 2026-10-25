using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class WebhookNotificationService : IWebhookNotificationService
    {
        private readonly HttpClient? _httpClient;
        private readonly ILogger<WebhookNotificationService>? _logger;
        private static readonly HttpClient _fallbackClient = new();
        private readonly object _lock = new();

        private bool _enabled = false;
        private string _webhookUrl = string.Empty;
        private bool _notifyRoutine = true;
        private bool _notifyCritical = true;

        public WebhookNotificationService(
            HttpClient? httpClient = null,
            ILogger<WebhookNotificationService>? logger = null)
        {
            _httpClient = httpClient;
            _logger = logger;
        }

        public WebhookConfigDto GetConfig()
        {
            lock (_lock)
            {
                return new WebhookConfigDto
                {
                    Enabled = _enabled,
                    WebhookUrl = !string.IsNullOrWhiteSpace(_webhookUrl) ? "[CONFIGURED]" : string.Empty,
                    HasWebhookUrl = !string.IsNullOrWhiteSpace(_webhookUrl),
                    NotifyOnRoutineComplete = _notifyRoutine,
                    NotifyOnCriticalAlert = _notifyCritical
                };
            }
        }

        public WebhookConfigDto UpdateConfig(bool enabled, string? webhookUrl, bool notifyRoutine, bool notifyCritical)
        {
            lock (_lock)
            {
                _enabled = enabled;
                if (webhookUrl != null)
                {
                    _webhookUrl = string.IsNullOrWhiteSpace(webhookUrl) ? string.Empty : webhookUrl.Trim();
                }
                _notifyRoutine = notifyRoutine;
                _notifyCritical = notifyCritical;
                return GetConfig();
            }
        }

        public string FormatSanitizedPayload(string title, string body)
        {
            string cleanTitle = SensitiveTextSanitizer.SanitizeText(title);
            string cleanBody = SensitiveTextSanitizer.SanitizeText(body);

            var payloadObj = new
            {
                username = "Command DroidDeck",
                content = $"**{cleanTitle}**\n{cleanBody}",
                embeds = new[]
                {
                    new
                    {
                        title = cleanTitle,
                        description = cleanBody,
                        color = 0x5865F2,
                        timestamp = DateTime.UtcNow.ToString("o")
                    }
                }
            };

            return JsonSerializer.Serialize(payloadObj);
        }

        public async Task<bool> SendNotificationAsync(string title, string body, CancellationToken ct = default)
        {
            string url;
            bool enabled;
            lock (_lock)
            {
                enabled = _enabled;
                url = _webhookUrl;
            }

            if (!enabled || string.IsNullOrWhiteSpace(url))
            {
                return false;
            }

            try
            {
                string json = FormatSanitizedPayload(title, body);
                using var content = new StringContent(json, Encoding.UTF8, "application/json");
                var client = _httpClient ?? _fallbackClient;
                var response = await client.PostAsync(url, content, ct);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                _logger?.LogWarning(ex, "Falha ao despachar notificação webhook sanitizada");
                return false;
            }
        }
    }
}
