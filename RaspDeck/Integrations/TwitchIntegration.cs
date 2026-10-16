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
    /// <summary>
    /// Twitch (Helix) com o app do proprio usuario, por "device code": o DroidDeck mostra um
    /// codigo, o usuario confirma em twitch.tv/activate e pronto -- sem segredo nem endereco
    /// de retorno. Ao vivo e espectadores sao consultados a cada 30 s.
    /// </summary>
    public class TwitchIntegration : AccountIntegration
    {
        public const string Event = "ReceiveTwitchState";
        private const string Helix = "https://api.twitch.tv/helix";
        private const string Scopes = "channel:manage:broadcast channel:edit:commercial clips:edit channel:manage:polls user:write:chat";

        private readonly IHttpClientFactory _http;
        private readonly OAuthTokens _tokens;
        private string? _error;
        private string? _userCode;
        private string? _verificationUri;
        private CancellationTokenSource? _devicePoll;
        private bool _live;
        private int? _viewers;
        private string? _streamTitle;
        private DateTime _nextRefresh;

        public TwitchIntegration(ILogger<TwitchIntegration> logger, IHubContext<DeckHub> hub, StreamDeckConfigService config,
            IHttpClientFactory http) : base(logger, hub, config)
        {
            _http = http;
            _tokens = new OAuthTokens(Get, v => Set(v), http)
            {
                TokenEndpoint = "https://id.twitch.tv/oauth2/token",
                ClientFields = () => new() { ["client_id"] = ClientId ?? "" },
            };
        }

        public override string Name => "twitch";
        public override string Title => "Twitch";
        public override string StateEvent => Event;

        private string? ClientId => Get("clientId");
        public string? UserId => Get("userId");
        private string? Login => Get("login");
        private bool Connected => _tokens.HasToken && UserId != null;

        public override IntegrationStatus GetStatus() => new()
        {
            Connected = Connected,
            Configured = ClientId != null,
            Account = Connected ? Login : null,
            Message = Connected ? null : _error,
            LoginPending = _userCode != null,
            UserCode = _userCode,
            VerificationUri = _verificationUri,
            Fields = new() { ["clientId"] = ClientId ?? "" },
        };

        public override object GetState() => new
        {
            connected = Connected,
            account = Connected ? Login : null,
            live = _live,
            viewers = _viewers,
            title = _streamTitle,
        };

        public override async Task<IntegrationStatus> ConfigureAsync(Dictionary<string, string> fields)
        {
            var clientId = (fields.GetValueOrDefault("clientId") ?? ClientId ?? "").Trim();
            if (clientId.Length < 10) throw new InvalidOperationException("Cole o Client ID do app que você criou no console da Twitch.");
            if (clientId != ClientId) Clear();
            Set(("clientId", clientId));
            _error = null;

            var client = _http.CreateClient();
            using var response = await client.PostAsync("https://id.twitch.tv/oauth2/device",
                new FormUrlEncodedContent(new Dictionary<string, string> { ["client_id"] = clientId, ["scopes"] = Scopes }));
            var body = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException("A Twitch recusou o Client ID: " + ApiCall.ErrorText(body, (int)response.StatusCode) +
                                                    ". O app precisa ser do tipo \"Público\".");
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            _userCode = root.GetProperty("user_code").GetString();
            _verificationUri = root.GetProperty("verification_uri").GetString();
            var deviceCode = root.GetProperty("device_code").GetString()!;
            var interval = root.TryGetProperty("interval", out var i) ? i.GetInt32() : 5;
            var expires = root.TryGetProperty("expires_in", out var e) ? e.GetInt32() : 1800;

            _devicePoll?.Cancel();
            _devicePoll = new CancellationTokenSource(TimeSpan.FromSeconds(expires));
            _ = PollDeviceAsync(deviceCode, interval, _devicePoll.Token);
            if (_verificationUri != null) OpenBrowser(_verificationUri);
            return GetStatus();
        }

        private async Task PollDeviceAsync(string deviceCode, int interval, CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                await Wait(TimeSpan.FromSeconds(interval), ct);
                if (ct.IsCancellationRequested) break;
                try
                {
                    await _tokens.RequestAsync(new()
                    {
                        ["client_id"] = ClientId ?? "",
                        ["scopes"] = Scopes,
                        ["device_code"] = deviceCode,
                        ["grant_type"] = "urn:ietf:params:oauth:grant-type:device_code",
                    });
                    await ValidateAsync();
                    _userCode = null;
                    _verificationUri = null;
                    _nextRefresh = DateTime.MinValue;
                    await BroadcastAsync();
                    return;
                }
                catch (OAuthException ex) when (ex.Message.Contains("authorization_pending"))
                {
                }
                catch (OAuthException ex) when (ex.Message.Contains("slow_down"))
                {
                    interval += 5;
                }
                catch (Exception ex)
                {
                    _error = ex.Message.Contains("expired") ? "O código expirou. Tente de novo." : ex.Message;
                    break;
                }
            }
            _userCode = null;
            _verificationUri = null;
        }

        /// <summary>Descobre a conta dona do token.</summary>
        private async Task ValidateAsync()
        {
            var token = await _tokens.GetAccessTokenAsync() ?? throw new InvalidOperationException("Sem token.");
            var client = _http.CreateClient();
            using var request = new HttpRequestMessage(HttpMethod.Get, "https://id.twitch.tv/oauth2/validate");
            request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("OAuth", token);
            using var response = await client.SendAsync(request);
            response.EnsureSuccessStatusCode();
            using var doc = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            Set(("userId", doc.RootElement.GetProperty("user_id").GetString()), ("login", doc.RootElement.GetProperty("login").GetString()));
            _error = null;
        }

        public override Task LogoutAsync()
        {
            _devicePoll?.Cancel();
            _userCode = null;
            Clear("clientId");
            _live = false;
            _viewers = null;
            _ = BroadcastAsync();
            return Task.CompletedTask;
        }

        public Task<JsonDocument?> CallAsync(HttpMethod method, string path, object? body = null) =>
            ApiCall.SendAsync(_http, _tokens, method, Helix + path, body, h => h.Add("Client-Id", ClientId));

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                if (Connected && DateTime.UtcNow >= _nextRefresh && DeckHub.ConnectedCount > 0 && ActionsOfType(TwitchProvider.TypeName).Any())
                {
                    _nextRefresh = DateTime.UtcNow.AddSeconds(30);
                    try { await RefreshAsync(); }
                    catch (Exception ex) { Logger.LogDebug(ex, "Twitch: falha ao ler o canal"); }
                }
                await Wait(TimeSpan.FromSeconds(2), stoppingToken);
            }
        }

        public async Task RefreshAsync()
        {
            using var streams = await CallAsync(HttpMethod.Get, "/streams?user_id=" + UserId);
            var data = streams?.RootElement.GetProperty("data");
            bool live = data?.GetArrayLength() > 0;
            int? viewers = live ? data!.Value[0].GetProperty("viewer_count").GetInt32() : null;
            string? title = live ? data!.Value[0].GetProperty("title").GetString() : null;
            if (!live)
            {
                using var channel = await CallAsync(HttpMethod.Get, "/channels?broadcaster_id=" + UserId);
                var ch = channel?.RootElement.GetProperty("data");
                if (ch?.GetArrayLength() > 0) title = ch.Value[0].GetProperty("title").GetString();
            }
            var changed = live != _live || viewers != _viewers || title != _streamTitle;
            (_live, _viewers, _streamTitle) = (live, viewers, title);
            if (changed) await BroadcastAsync();
        }

        public void RefreshSoon() => _nextRefresh = DateTime.UtcNow.AddSeconds(2);
    }

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
