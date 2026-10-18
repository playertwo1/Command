using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IWebhookNotificationService
    {
        WebhookConfigDto GetConfig();
        WebhookConfigDto UpdateConfig(bool enabled, string? webhookUrl, bool notifyRoutine, bool notifyCritical);
        string FormatSanitizedPayload(string title, string body);
        Task<bool> SendNotificationAsync(string title, string body, CancellationToken ct = default);
    }
}
