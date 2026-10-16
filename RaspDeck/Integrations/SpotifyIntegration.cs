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
    /// <summary>
    /// Spotify Web API com o app do proprio usuario (Client ID, sem segredo: PKCE). Controlar a
    /// reproducao exige Spotify Premium. O estado (faixa, capa, curtida) e consultado a cada 3 s
    /// enquanto ha celular conectado e botao de Spotify no deck: a API nao avisa mudancas.
    /// </summary>
    public class SpotifyIntegration : AccountIntegration
    {
        public const string Event = "ReceiveSpotifyState";
        private const string Api = "https://api.spotify.com/v1";
        private const string Scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing " +
                                      "user-library-read user-library-modify playlist-read-private playlist-read-collaborative";

        private readonly IHttpClientFactory _http;
        private readonly OAuthTokens _tokens;
        private string? _pendingState;
        private string? _pendingVerifier;
        private string? _error;
        private string? _account;
        private Playback? _playback;
        private string? _coverUrl;
        private string? _coverBase64;

        public SpotifyIntegration(ILogger<SpotifyIntegration> logger, IHubContext<DeckHub> hub, StreamDeckConfigService config,
            IHttpClientFactory http) : base(logger, hub, config)
        {
            _http = http;
            _tokens = new OAuthTokens(Get, v => Set(v), http)
            {
                TokenEndpoint = "https://accounts.spotify.com/api/token",
                ClientFields = () => new() { ["client_id"] = Get("clientId") ?? "" },
            };
        }

        public override string Name => "spotify";
        public override string Title => "Spotify";
        public override string StateEvent => Event;

        public class Playback
        {
            public bool Playing { get; set; }
            public string? TrackId { get; set; }
            public string? Track { get; set; }
            public string? Artist { get; set; }
            public bool Liked { get; set; }
            public bool Shuffle { get; set; }
            public string Repeat { get; set; } = "off";
            public int? Volume { get; set; }
            public string? Device { get; set; }
        }

        private bool Connected => _tokens.HasToken && _account != null;

        public override IntegrationStatus GetStatus() => new()
        {
            Connected = Connected,
            Configured = Get("clientId") != null,
            Account = _account,
            Message = Connected ? null : _error,
            LoginPending = _pendingState != null,
            RedirectUri = RedirectUriFor(Name),
            Fields = new() { ["clientId"] = Get("clientId") ?? "" },
        };

        public override object GetState() => new
        {
            connected = Connected,
            account = _account,
            playing = _playback?.Playing ?? false,
            trackId = _playback?.TrackId,
            track = _playback?.Track,
            artist = _playback?.Artist,
            liked = _playback?.Liked ?? false,
            shuffle = _playback?.Shuffle ?? false,
            repeat = _playback?.Repeat ?? "off",
            volume = _playback?.Volume,
            device = _playback?.Device,
            coverBase64 = _coverBase64,
        };

        public override Task<IntegrationStatus> ConfigureAsync(Dictionary<string, string> fields)
        {
            var clientId = (fields.GetValueOrDefault("clientId") ?? Get("clientId") ?? "").Trim();
            if (clientId.Length < 16) throw new InvalidOperationException("Cole o Client ID do app que você criou no Spotify for Developers.");
            if (clientId != Get("clientId")) Clear();
            Set(("clientId", clientId));

            var (verifier, challenge) = OAuthTokens.NewPkce();
            _pendingVerifier = verifier;
            _pendingState = OAuthTokens.NewState();
            _error = null;
            OpenBrowser("https://accounts.spotify.com/authorize?response_type=code" +
                        "&client_id=" + Uri.EscapeDataString(clientId) +
                        "&redirect_uri=" + Uri.EscapeDataString(RedirectUriFor(Name)) +
                        "&scope=" + Uri.EscapeDataString(Scopes) +
                        "&code_challenge_method=S256&code_challenge=" + challenge +
                        "&state=" + _pendingState);
            return Task.FromResult(GetStatus());
        }

        public override async Task<string> CallbackAsync(IQueryCollection query)
        {
            if (_pendingState == null || query["state"] != _pendingState)
                return Html("Spotify", L.T("Este link de login expirou. Comece de novo pelo DroidDeck."));
            _pendingState = null;
            if (!string.IsNullOrEmpty(query["error"]))
            {
                _error = query["error"] == "access_denied" ? "Login cancelado." : $"O Spotify recusou: {query["error"]}";
                return Html("Spotify", query["error"] == "access_denied"
                    ? L.T("Login cancelado.")
                    : L.T("O Spotify recusou: {error}", ("error", query["error"].ToString())));
            }
            try
            {
                await _tokens.RequestAsync(new()
                {
                    ["grant_type"] = "authorization_code",
                    ["code"] = query["code"].ToString(),
                    ["redirect_uri"] = RedirectUriFor(Name),
                    ["client_id"] = Get("clientId") ?? "",
                    ["code_verifier"] = _pendingVerifier ?? "",
                });
                await LoadAccountAsync();
                await BroadcastAsync();
                return Html(L.T("Spotify conectado"), L.T("Conta {account}. Pode fechar esta aba.", ("account", _account)));
            }
            catch (Exception ex)
            {
                _error = ex.Message;
                return Html("Spotify", L.T("Não deu certo: {error}", ("error", L.T(ex.Message))));
            }
        }

        public override Task LogoutAsync()
        {
            Clear("clientId");
            _account = null;
            _playback = null;
            _coverBase64 = null;
            _coverUrl = null;
            _ = BroadcastAsync();
            return Task.CompletedTask;
        }

        private async Task LoadAccountAsync()
        {
            using var me = await CallAsync(HttpMethod.Get, "/me");
            _account = me?.RootElement.TryGetProperty("display_name", out var n) == true && n.ValueKind == JsonValueKind.String
                ? n.GetString()
                : me?.RootElement.GetProperty("id").GetString();
            _error = null;
        }

        public Task<JsonDocument?> CallAsync(HttpMethod method, string path, object? body = null) =>
            ApiCall.SendAsync(_http, _tokens, method, Api + path, body);

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    if (_tokens.HasToken && _account == null) await LoadAccountAsync();
                    if (Connected && DeckHub.ConnectedCount > 0 && ActionsOfType(SpotifyProvider.TypeName).Any())
                        await RefreshAsync();
                }
                catch (Exception ex)
                {
                    Logger.LogDebug(ex, "Spotify: falha ao ler o estado");
                    if (!_tokens.HasToken) { _account = null; await BroadcastAsync(); }
                }
                await Wait(TimeSpan.FromSeconds(3), stoppingToken);
            }
        }

        /// <summary>Le o player e publica se algo mudou.</summary>
        public async Task RefreshAsync()
        {
            using var doc = await CallAsync(HttpMethod.Get, "/me/player");
            var p = new Playback();
            string? cover = null;
            if (doc != null)
            {
                var root = doc.RootElement;
                p.Playing = root.TryGetProperty("is_playing", out var ip) && ip.GetBoolean();
                p.Shuffle = root.TryGetProperty("shuffle_state", out var sh) && sh.ValueKind == JsonValueKind.True;
                p.Repeat = root.TryGetProperty("repeat_state", out var rp) ? rp.GetString() ?? "off" : "off";
                if (root.TryGetProperty("device", out var dev) && dev.ValueKind == JsonValueKind.Object)
                {
                    p.Device = dev.TryGetProperty("name", out var dn) ? dn.GetString() : null;
                    if (dev.TryGetProperty("volume_percent", out var vp) && vp.ValueKind == JsonValueKind.Number) p.Volume = vp.GetInt32();
                }
                if (root.TryGetProperty("item", out var item) && item.ValueKind == JsonValueKind.Object)
                {
                    p.TrackId = item.TryGetProperty("id", out var id) ? id.GetString() : null;
                    p.Track = item.TryGetProperty("name", out var nm) ? nm.GetString() : null;
                    if (item.TryGetProperty("artists", out var ar) && ar.ValueKind == JsonValueKind.Array)
                        p.Artist = string.Join(", ", ar.EnumerateArray().Select(a => a.GetProperty("name").GetString()));
                    else if (item.TryGetProperty("show", out var show)) p.Artist = show.GetProperty("name").GetString();
                    var album = item.TryGetProperty("album", out var al) ? al : default;
                    if (album.ValueKind == JsonValueKind.Object && album.TryGetProperty("images", out var imgs) && imgs.GetArrayLength() > 0)
                        cover = imgs[imgs.GetArrayLength() - 1].GetProperty("url").GetString();
                }
            }

            // Curtida so muda quando o usuario mexe: consulta so na troca de faixa.
            if (p.TrackId != null && p.TrackId == _playback?.TrackId) p.Liked = _playback.Liked;
            else if (p.TrackId != null) p.Liked = await IsLikedAsync(p.TrackId);

            if (cover != _coverUrl)
            {
                _coverUrl = cover;
                _coverBase64 = cover == null ? null : await DownloadCoverAsync(cover);
            }

            var changed = JsonSerializer.Serialize(p) != JsonSerializer.Serialize(_playback);
            _playback = p;
            if (changed) await BroadcastAsync();
        }

        private async Task<bool> IsLikedAsync(string trackId)
        {
            try
            {
                using var doc = await CallAsync(HttpMethod.Get, "/me/tracks/contains?ids=" + trackId);
                return doc?.RootElement.ValueKind == JsonValueKind.Array && doc.RootElement[0].GetBoolean();
            }
            catch { return false; }
        }

        private async Task<string?> DownloadCoverAsync(string url)
        {
            try
            {
                var bytes = await _http.CreateClient().GetByteArrayAsync(url);
                return InfoService.Shrink(Convert.ToBase64String(bytes));
            }
            catch { return null; }
        }

        public async Task SetLikedAsync(bool like)
        {
            var id = _playback?.TrackId ?? throw new InvalidOperationException("Nada tocando no Spotify.");
            await CallAsync(like ? HttpMethod.Put : HttpMethod.Delete, "/me/tracks?ids=" + id);
            _playback!.Liked = like;
            await BroadcastAsync();
        }

        public Playback? Current => _playback;

        public override async Task<List<FieldOption>> OptionsAsync(string list, IQueryCollection query)
        {
            if (list != "playlists") return await base.OptionsAsync(list, query);
            var result = new List<FieldOption>();
            var next = "/me/playlists?limit=50";
            while (next != null && result.Count < 300)
            {
                using var doc = await CallAsync(HttpMethod.Get, next);
                if (doc == null) break;
                foreach (var pl in doc.RootElement.GetProperty("items").EnumerateArray())
                {
                    if (pl.ValueKind != JsonValueKind.Object) continue;
                    result.Add(new FieldOption(pl.GetProperty("uri").GetString() ?? "", pl.GetProperty("name").GetString() ?? ""));
                }
                next = doc.RootElement.TryGetProperty("next", out var n) && n.ValueKind == JsonValueKind.String
                    ? n.GetString()!.Replace(Api, "")
                    : null;
            }
            return result;
        }
    }

    /// <summary>Acao "spotify": controles do player, curtir, aleatorio, repetir, volume e tocar uma playlist.</summary>
    public class SpotifyProvider : IStatefulActionProvider
    {
        public const string TypeName = "spotify";

        private readonly SpotifyIntegration _spotify;

        public SpotifyProvider(SpotifyIntegration spotify) => _spotify = spotify;

        public string Type => TypeName;
        public string StateEvent => SpotifyIntegration.Event;
        public object GetState() => _spotify.GetState();

        public ActionSchema Describe() => new()
        {
            Type = TypeName,
            Title = "Spotify",
            Icon = "music_note",
            Category = "Mídia",
            Description = "Controla o Spotify da sua conta (Premium), com capa, curtida e aleatório no botão.",
            Stateful = true,
            Settings = "spotify",
            StateEvent = StateEvent,
            Fields =
            {
                ActionField.Select("operation", "O que fazer",
                    ("playPause", "Tocar/pausar"),
                    ("next", "Próxima"),
                    ("previous", "Anterior"),
                    ("like", "Curtir/descurtir a faixa"),
                    ("shuffle", "Aleatório liga/desliga"),
                    ("repeat", "Repetir (desligado → playlist → faixa)"),
                    ("volume", "Volume (+/-)"),
                    ("playlist", "Tocar uma playlist"),
                    ("nowPlaying", "Mostrar o que está tocando")),
                ActionField.Number("step", "Passo do volume", 10, -100, 100, "%").When("operation", "volume"),
                ActionField.Dynamic("uri", "Playlist", "/api/integrations/spotify/options/playlists", allowCustom: true).When("operation", "playlist"),
                ActionField.Toggle("shuffleOn", "Começar no aleatório").When("operation", "playlist"),
            },
        };

        public async Task ExecuteAsync(ActionContext ctx)
        {
            var p = _spotify.Current;
            switch (ctx.Operation("playpause"))
            {
                case "playpause":
                case "nowplaying":
                    await _spotify.CallAsync(HttpMethod.Put, p?.Playing == true ? "/me/player/pause" : "/me/player/play");
                    break;
                case "next":
                    await _spotify.CallAsync(HttpMethod.Post, "/me/player/next");
                    break;
                case "previous":
                    await _spotify.CallAsync(HttpMethod.Post, "/me/player/previous");
                    break;
                case "like":
                    await _spotify.SetLikedAsync(!(p?.Liked ?? false));
                    return;
                case "shuffle":
                    await _spotify.CallAsync(HttpMethod.Put, "/me/player/shuffle?state=" + (!(p?.Shuffle ?? false)).ToString().ToLowerInvariant());
                    break;
                case "repeat":
                    var next = (p?.Repeat ?? "off") switch { "off" => "context", "context" => "track", _ => "off" };
                    await _spotify.CallAsync(HttpMethod.Put, "/me/player/repeat?state=" + next);
                    break;
                case "volume":
                    var volume = Math.Clamp((p?.Volume ?? 50) + ctx.Int("step", 10), 0, 100);
                    await _spotify.CallAsync(HttpMethod.Put, "/me/player/volume?volume_percent=" + volume);
                    break;
                case "playlist":
                    var uri = ctx.Get("uri").Trim();
                    if (uri.Length == 0) throw new InvalidOperationException("Escolha a playlist.");
                    if (ctx.Get("shuffleOn") == "true")
                        await _spotify.CallAsync(HttpMethod.Put, "/me/player/shuffle?state=true");
                    await _spotify.CallAsync(HttpMethod.Put, "/me/player/play", new { context_uri = uri });
                    break;
            }
            // Mostra o efeito sem esperar o proximo ciclo de 3 s.
            await Task.Delay(300);
            try { await _spotify.RefreshAsync(); } catch { }
        }
    }
}
