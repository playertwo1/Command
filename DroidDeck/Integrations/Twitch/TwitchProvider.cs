using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Actions;
using DroidDeck.Hubs;
using DroidDeck.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Integrations
{
    /// <summary>Acao "twitch": marcador, clipe, anuncio, mensagem no chat, enquete e titulo.</summary>
    public class TwitchProvider : IStatefulActionProvider
    {
        public const string TypeName = "twitch";

        private readonly TwitchIntegration _twitch;

        public TwitchProvider(TwitchIntegration twitch) => _twitch = twitch;

        public string Type => TypeName;
        public string StateEvent => TwitchIntegration.Event;
        public object GetState() => _twitch.GetState();

        public ActionSchema Describe() => new()
        {
            Type = TypeName,
            Title = "Twitch",
            Icon = "sensors",
            Category = "Streaming",
            Description = "Marcador, clipe, anúncio, chat, enquete e título do seu canal; mostra se está ao vivo.",
            Stateful = true,
            Settings = "twitch",
            StateEvent = StateEvent,
            Fields =
            {
                ActionField.Select("operation", "O que fazer",
                    ("marker", "Criar marcador"),
                    ("clip", "Criar clipe"),
                    ("ad", "Rodar anúncio"),
                    ("chat", "Mandar mensagem no chat"),
                    ("poll", "Abrir enquete"),
                    ("title", "Trocar o título"),
                    ("status", "Só mostrar ao vivo/espectadores")),
                ActionField.Text("description", "Descrição (opcional)", "Momento épico").When("operation", "marker"),
                ActionField.Select("length", "Duração", ("30", "30 s"), ("60", "1 min"), ("90", "1 min 30"), ("120", "2 min"), ("180", "3 min")).When("operation", "ad"),
                ActionField.Multiline("message", "Mensagem", "Sigam o canal!").When("operation", "chat"),
                ActionField.Text("question", "Pergunta", "Qual jogo agora?", required: true).When("operation", "poll"),
                ActionField.Multiline("choices", "Opções (uma por linha, 2 a 5)", "Sim\nNão").When("operation", "poll"),
                ActionField.Number("duration", "Duração", 60, 15, 1800, "s").When("operation", "poll"),
                ActionField.Text("title", "Novo título", required: true).When("operation", "title"),
            },
        };

        public async Task ExecuteAsync(ActionContext ctx)
        {
            var id = _twitch.UserId ?? throw new InvalidOperationException("Twitch desconectada.");
            switch (ctx.Operation("marker"))
            {
                case "marker":
                    var description = ctx.Get("description").Trim();
                    var marker = new Dictionary<string, string> { ["user_id"] = id };
                    if (description.Length > 0) marker["description"] = description;
                    await _twitch.CallAsync(HttpMethod.Post, "/streams/markers", marker);
                    break;
                case "clip":
                    await _twitch.CallAsync(HttpMethod.Post, "/clips?broadcaster_id=" + id);
                    break;
                case "ad":
                    await _twitch.CallAsync(HttpMethod.Post, "/channels/commercial", new { broadcaster_id = id, length = ctx.Int("length", 30) });
                    break;
                case "chat":
                    var message = ctx.Get("message").Trim();
                    if (message.Length == 0) return;
                    await _twitch.CallAsync(HttpMethod.Post, "/chat/messages", new { broadcaster_id = id, sender_id = id, message });
                    break;
                case "poll":
                    var choices = ctx.Get("choices").Split('\n').Select(c => c.Trim()).Where(c => c.Length > 0).Take(5)
                        .Select(c => new { title = c }).ToArray();
                    if (choices.Length < 2) throw new InvalidOperationException("A enquete precisa de 2 opções.");
                    await _twitch.CallAsync(HttpMethod.Post, "/polls", new
                    {
                        broadcaster_id = id,
                        title = ctx.Get("question").Trim(),
                        choices,
                        duration = Math.Clamp(ctx.Int("duration", 60), 15, 1800),
                    });
                    break;
                case "title":
                    await _twitch.CallAsync(new HttpMethod("PATCH"), "/channels?broadcaster_id=" + id, new { title = ctx.Get("title").Trim() });
                    _twitch.RefreshSoon();
                    break;
                case "status":
                    _twitch.RefreshSoon();
                    break;
            }
        }
    }
}
