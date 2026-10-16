using System.Diagnostics;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using DroidDeck.Services;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Actions.Providers
{
    /// <summary>
    /// Abre um jogo da Steam pelo appid (steam://rungameid/...). Nao e privilegiada: so
    /// aceita um numero, entao quem aperta nao escolhe o que roda alem de "um jogo instalado".
    /// </summary>
    public class SteamProvider : IActionProvider
    {
        private readonly ILogger<SteamProvider> _logger;

        public SteamProvider(ILogger<SteamProvider> logger) => _logger = logger;

        public string Type => "steam";

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Jogo da Steam",
            Icon = "sports_esports",
            Category = "Sistema",
            Editor = "steam",
            Fields =
            {
                ActionField.Dynamic("appId", "Jogo", "/api/steam/games"),
            },
        };

        public Task ExecuteAsync(ActionContext c)
        {
            var appId = c.Get("appId");
            if (!Regex.IsMatch(appId, @"^\d{1,10}$"))
            {
                _logger.LogWarning("Steam: appid invalido '{AppId}'", appId);
                return Task.CompletedTask;
            }
            Process.Start(new ProcessStartInfo($"steam://rungameid/{appId}") { UseShellExecute = true })?.Dispose();
            return Task.CompletedTask;
        }
    }
}
