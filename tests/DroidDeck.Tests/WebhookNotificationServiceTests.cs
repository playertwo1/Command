using DroidDeck.Services;
using Xunit;

namespace DroidDeck.Tests
{
    public class WebhookNotificationServiceTests
    {
        [Fact]
        public void FormatSanitizedPayload_RedactsSensitiveData()
        {
            var service = new WebhookNotificationService();

            string title = @"Alerta no host C:\Users\notefael\projeto";
            string body = "Dispositivo em 192.168.0.15 reportou erro com token Bearer sec12345 e sk-live987654321";

            string json = service.FormatSanitizedPayload(title, body);

            Assert.NotNull(json);
            Assert.Contains("[REDACTED]", json);
            Assert.Contains(@"C:\\Users\\[REDACTED]", json);
            Assert.DoesNotContain("notefael", json);
            Assert.Contains("xxx.xxx.*.***", json);
            Assert.DoesNotContain("192.168.0.15", json);
            Assert.Contains("[REDACTED_KEY]", json);
            Assert.DoesNotContain("sec12345", json);
            Assert.DoesNotContain("sk-live987654321", json);
        }

        [Fact]
        public void GetConfig_MasksWebhookUrl_WhenConfigured()
        {
            var service = new WebhookNotificationService();

            var initial = service.GetConfig();
            Assert.False(initial.Enabled);
            Assert.False(initial.HasWebhookUrl);
            Assert.Equal(string.Empty, initial.WebhookUrl);

            var updated = service.UpdateConfig(true, "https://discord.com/api/webhooks/secret_token_path", true, true);
            Assert.True(updated.Enabled);
            Assert.True(updated.HasWebhookUrl);
            Assert.Equal("[CONFIGURED]", updated.WebhookUrl);

            var fetched = service.GetConfig();
            Assert.True(fetched.Enabled);
            Assert.True(fetched.HasWebhookUrl);
            Assert.Equal("[CONFIGURED]", fetched.WebhookUrl);
        }

        [Fact]
        public async System.Threading.Tasks.Task SendNotificationAsync_WhenDisabledOrNoUrl_ReturnsFalse()
        {
            var service = new WebhookNotificationService();

            bool resultDisabled = await service.SendNotificationAsync("Teste", "Corpo");
            Assert.False(resultDisabled);

            service.UpdateConfig(true, "", true, true);
            bool resultNoUrl = await service.SendNotificationAsync("Teste", "Corpo");
            Assert.False(resultNoUrl);
        }
    }
}
