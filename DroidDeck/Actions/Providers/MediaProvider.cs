using System.Threading.Tasks;
using DroidDeck.Hubs;
using DroidDeck.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Actions.Providers
{
    public class MediaProvider : IActionProvider
    {
        private readonly MediaControlService _media;
        private readonly IHubContext<DeckHub> _hub;
        private readonly ILogger<MediaProvider> _logger;

        public MediaProvider(MediaControlService media, IHubContext<DeckHub> hub, ILogger<MediaProvider> logger)
        {
            _media = media;
            _hub = hub;
            _logger = logger;
        }

        public string Type => "media";

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Mídia",
            Icon = "play",
            Category = "Mídia",
            Fields =
            {
                ActionField.Select("command", "Comando",
                    ("playpause", "Play / Pause"),
                    ("next", "Próxima faixa"),
                    ("previous", "Faixa anterior"),
                    ("stop", "Parar"),
                    ("play", "Play"),
                    ("pause", "Pause")),
            },
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            var command = c.Get("command");
            if (command.Length == 0) return;

            // sessionId vazio = "a sessao que esta tocando" (como as teclas de midia). Quem
            // resolve isso e o MediaControlService, dentro da MESMA operacao serializada
            // que envia o comando: antes eram duas idas ao WinRT por toque (listar sessoes,
            // com capa de album e tudo, e so depois mandar o comando) e perder a disputa pelo
            // semaforo em qualquer uma delas fazia o botao nao fazer nada, sem log.
            var sessionId = c.Get("sessionId") is { Length: > 0 } s ? s : null;

            var result = await _media.SendCommandAsync(sessionId, command);
            if (!result.Success)
            {
                _logger.LogWarning("Midia: comando '{Command}' do deck nao foi aplicado.", command);
                return;
            }

            // Empurra o estado real pros clientes: o botao pinta otimista no toque e precisa
            // ser corrigido se o comando pegou uma sessao diferente da esperada.
            if (result.Playing.HasValue)
                await _hub.Clients.All.SendAsync("ReceiveMediaStatus", new { playing = result.Playing.Value });
        }
    }
}
