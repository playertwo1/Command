using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Actions;
using DroidDeck.Hubs;
using DroidDeck.Lib;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Integrations
{
    /// <summary>Acao "youtube": mensagem no chat da live e mostrar ao vivo/espectadores.</summary>
    public class YouTubeProvider : IStatefulActionProvider
    {
        public const string TypeName = "youtube";

        private readonly YouTubeIntegration _youtube;

        public YouTubeProvider(YouTubeIntegration youtube) => _youtube = youtube;

        public string Type => TypeName;
        public string StateEvent => YouTubeIntegration.Event;
        public object GetState() => _youtube.GetState();

        public ActionSchema Describe() => new()
        {
            Type = TypeName,
            Title = "YouTube",
            Icon = "smart_display",
            Category = "Streaming",
            Description = "Manda mensagens no chat da sua live e mostra se está ao vivo e quantos assistem.",
            Stateful = true,
            Settings = "youtube",
            StateEvent = StateEvent,
            Fields =
            {
                ActionField.Select("operation", "O que fazer",
                    ("chat", "Mandar mensagem no chat"),
                    ("status", "Só mostrar ao vivo/espectadores")),
                ActionField.Multiline("message", "Mensagem", "Obrigado por assistir!").When("operation", "chat"),
            },
        };

        public async Task ExecuteAsync(ActionContext ctx)
        {
            switch (ctx.Operation("chat"))
            {
                case "chat":
                    var message = ctx.Get("message").Trim();
                    if (message.Length > 0) await _youtube.SendChatAsync(message);
                    break;
                default:
                    _youtube.RefreshSoon();
                    break;
            }
        }
    }
}
