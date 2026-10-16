using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Hubs;
using DroidDeck.Lib;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Integrations
{
    /// <summary>
    /// O que a tela de configuracao de uma integracao mostra (GET /api/integrations/{nome}).
    /// </summary>
    public class IntegrationStatus
    {
        public bool Connected { get; set; }

        /// <summary>Ja tem o que precisa (Client ID, URL...) para tentar conectar.</summary>
        public bool Configured { get; set; }

        /// <summary>Conta ou servidor conectado ("@canal", "Casa").</summary>
        public string? Account { get; set; }

        /// <summary>Erro ou orientacao para o usuario.</summary>
        public string? Message { get; set; }

        /// <summary>Login em andamento pelo navegador do PC.</summary>
        public bool LoginPending { get; set; }

        /// <summary>Login por codigo (Twitch): o codigo a digitar e onde.</summary>
        public string? UserCode { get; set; }
        public string? VerificationUri { get; set; }

        /// <summary>Valores atuais dos campos que nao sao segredo, para preencher a tela.</summary>
        public Dictionary<string, string> Fields { get; set; } = new();

        /// <summary>Endereco de retorno (redirect URI) para cadastrar no app do servico.</summary>
        public string? RedirectUri { get; set; }
    }

    /// <summary>
    /// Base das integracoes com conta (Home Assistant, Spotify, Twitch, YouTube): guarda a
    /// configuracao cifrada em %LocalAppData%\DroidDeck\{nome}.json, publica o estado ao vivo
    /// e expoe o mesmo fluxo para a tela do app (configurar, entrar, sair).
    /// </summary>
    public abstract class AccountIntegration : BackgroundService, IIntegration
    {
        protected readonly ILogger Logger;
        protected readonly IHubContext<DeckHub> Hub;
        protected readonly StreamDeckConfigService Config;
        private readonly object _storeLock = new();
        private Dictionary<string, string>? _store;

        protected AccountIntegration(ILogger logger, IHubContext<DeckHub> hub, StreamDeckConfigService config)
        {
            Logger = logger;
            Hub = hub;
            Config = config;
        }

        /// <summary>Nome na URL e no arquivo: "spotify".</summary>
        public abstract string Name { get; }

        public abstract string Title { get; }

        /// <summary>Evento SignalR do estado (ex.: "ReceiveSpotifyState").</summary>
        public abstract string StateEvent { get; }

        public abstract IntegrationStatus GetStatus();

        public bool IsConnected => GetStatus().Connected;

        public string? AccountName => GetStatus().Account;

        public abstract object GetState();

        /// <summary>Grava os campos da tela e tenta conectar (ou inicia o login).</summary>
        public abstract Task<IntegrationStatus> ConfigureAsync(Dictionary<string, string> fields);

        /// <summary>Esquece a conta (e o token).</summary>
        public virtual Task LogoutAsync()
        {
            Clear();
            _ = BroadcastAsync();
            return Task.CompletedTask;
        }

        /// <summary>Retorno do login OAuth no navegador. Devolve o texto da pagina mostrada.</summary>
        public virtual Task<string> CallbackAsync(IQueryCollection query) =>
            Task.FromResult(L.T("Esta integração não usa login pelo navegador."));

        /// <summary>Listas para os selects do editor (entidades, playlists...).</summary>
        public virtual Task<List<Actions.FieldOption>> OptionsAsync(string list, IQueryCollection query) =>
            Task.FromResult(new List<Actions.FieldOption>());

        // ---- Configuracao persistida ----

        private string StorePath => Path.Combine(AppPaths.LocalDir, Name + ".json");

        protected Dictionary<string, string> Store
        {
            get
            {
                lock (_storeLock)
                {
                    if (_store != null) return _store;
                    try
                    {
                        _store = File.Exists(StorePath)
                            ? JsonSerializer.Deserialize<Dictionary<string, string>>(SecretFile.ReadAllText(StorePath)) ?? new()
                            : new();
                    }
                    catch (Exception ex)
                    {
                        Logger.LogWarning(ex, "{Name}: configuração ilegível, começando do zero", Name);
                        _store = new();
                    }
                    return _store;
                }
            }
        }

        protected string? Get(string key) => Store.TryGetValue(key, out var v) && !string.IsNullOrEmpty(v) ? v : null;

        protected void Set(params (string key, string? value)[] values)
        {
            lock (_storeLock)
            {
                var store = Store;
                foreach (var (key, value) in values)
                {
                    if (string.IsNullOrEmpty(value)) store.Remove(key);
                    else store[key] = value;
                }
                try { SecretFile.WriteAllText(StorePath, JsonSerializer.Serialize(store)); }
                catch (Exception ex) { Logger.LogWarning(ex, "{Name}: falha ao gravar a configuração", Name); }
            }
        }

        protected void Clear(params string[] keepKeys)
        {
            lock (_storeLock)
            {
                var keep = Store.Where(kv => keepKeys.Contains(kv.Key)).ToDictionary(kv => kv.Key, kv => kv.Value);
                _store = keep;
                try
                {
                    if (keep.Count == 0) File.Delete(StorePath);
                    else SecretFile.WriteAllText(StorePath, JsonSerializer.Serialize(keep));
                }
                catch { }
            }
        }

        // ---- Utilitarios ----

        protected async Task BroadcastAsync()
        {
            try { await Hub.Clients.All.SendAsync(StateEvent, GetState()); }
            catch { }
        }

        /// <summary>Botoes de todos os perfis com uma acao deste tipo (em qualquer gesto).</summary>
        protected IEnumerable<DeckAction> ActionsOfType(string type) =>
            Config.GetProfiles()
                .SelectMany(p => p.Buttons ?? new List<DeckButton>())
                .SelectMany(b => DeckButton.ActionSlots.Select(b.ActionFor))
                .Where(a => a != null && string.Equals(a.Type, type, StringComparison.OrdinalIgnoreCase))!;

        /// <summary>Abre uma pagina no navegador padrao do PC.</summary>
        public static void OpenBrowser(string url)
        {
            try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
            catch { }
        }

        public static string RedirectUriFor(string name) => $"http://127.0.0.1:4787/api/integrations/{name}/callback";

        /// <summary>Pagina simples de retorno do login. Titulo e texto sao escapados: o erro vem da URL.</summary>
        protected static string Html(string title, string body)
        {
            title = System.Net.WebUtility.HtmlEncode(title);
            body = System.Net.WebUtility.HtmlEncode(body);
            return $"<!doctype html><meta charset=utf-8><title>{title}</title>" +
                "<body style=\"font-family:system-ui;background:#111;color:#eee;display:grid;place-items:center;height:90vh\">" +
                $"<div style=\"text-align:center\"><h2>{title}</h2><p>{body}</p></div>";
        }

        /// <summary>Espera, sem estourar se o servico estiver parando.</summary>
        protected static async Task Wait(TimeSpan delay, CancellationToken ct)
        {
            try { await Task.Delay(delay, ct); }
            catch (TaskCanceledException) { }
        }
    }

    /// <summary>
    /// OAuth 2 com PKCE (Spotify, YouTube) e device code (Twitch): troca e renova tokens e
    /// guarda tudo pelo AccountIntegration.
    /// </summary>
    public class OAuthTokens
    {
        private readonly Func<string, string?> _get;
        private readonly Action<(string, string?)[]> _set;
        private readonly IHttpClientFactory _http;
        private readonly SemaphoreSlim _refreshLock = new(1, 1);

        public OAuthTokens(Func<string, string?> get, Action<(string, string?)[]> set, IHttpClientFactory http)
        {
            _get = get;
            _set = set;
            _http = http;
        }

        public string TokenEndpoint { get; init; } = "";

        /// <summary>Campos extras na renovacao (client_id, client_secret).</summary>
        public Func<Dictionary<string, string>> ClientFields { get; init; } = () => new();

        public bool HasToken => _get("refresh_token") != null || _get("access_token") != null;

        // PKCE: verificador aleatorio e o desafio (SHA-256, base64url).
        public static (string verifier, string challenge) NewPkce()
        {
            var verifier = Base64Url(RandomNumberGenerator.GetBytes(48));
            var challenge = Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));
            return (verifier, challenge);
        }

        public static string NewState() => Base64Url(RandomNumberGenerator.GetBytes(16));

        private static string Base64Url(byte[] bytes) =>
            Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

        /// <summary>POST no endpoint de token; grava access/refresh/validade. Lanca com a mensagem do servico.</summary>
        public async Task RequestAsync(Dictionary<string, string> form)
        {
            var client = _http.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(15);
            using var response = await client.PostAsync(TokenEndpoint, new FormUrlEncodedContent(form));
            var body = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(body) ? "{}" : body);
            var root = doc.RootElement;
            if (!response.IsSuccessStatusCode)
            {
                var error = root.TryGetProperty("error", out var e) ? e.ToString() : $"HTTP {(int)response.StatusCode}";
                var description = root.TryGetProperty("error_description", out var d) ? d.GetString()
                    : root.TryGetProperty("message", out var m) ? m.GetString() : null;
                throw new OAuthException(error, description);
            }
            var access = root.GetProperty("access_token").GetString();
            var refresh = root.TryGetProperty("refresh_token", out var r) ? r.GetString() : null;
            var expires = root.TryGetProperty("expires_in", out var x) && x.TryGetInt32(out var secs) ? secs : 3600;
            _set(new (string, string?)[]
            {
                ("access_token", access),
                ("refresh_token", refresh ?? _get("refresh_token")),
                ("expires_at", DateTimeOffset.UtcNow.AddSeconds(expires - 60).ToUnixTimeSeconds().ToString()),
            });
        }

        /// <summary>Token valido, renovado se preciso. Null = precisa entrar de novo.</summary>
        public async Task<string?> GetAccessTokenAsync()
        {
            var access = _get("access_token");
            if (access != null && long.TryParse(_get("expires_at"), out var exp) &&
                DateTimeOffset.UtcNow.ToUnixTimeSeconds() < exp)
                return access;

            var refresh = _get("refresh_token");
            if (refresh == null) return null;
            await _refreshLock.WaitAsync();
            try
            {
                // Outra chamada pode ter renovado enquanto esperava.
                if (_get("access_token") is { } again && again != access) return again;
                var form = ClientFields();
                form["grant_type"] = "refresh_token";
                form["refresh_token"] = refresh;
                await RequestAsync(form);
                return _get("access_token");
            }
            catch (OAuthException ex) when (ex.Error is "invalid_grant" or "invalid_client" || ex.Error.StartsWith("HTTP 4"))
            {
                // Token revogado: o usuario precisa entrar de novo.
                _set(new (string, string?)[] { ("access_token", null), ("refresh_token", null), ("expires_at", null) });
                return null;
            }
            finally
            {
                _refreshLock.Release();
            }
        }

        /// <summary>Marca o token atual como vencido (o servico respondeu 401).</summary>
        public void Expire() => _set(new (string, string?)[] { ("expires_at", "0") });
    }

    public class OAuthException : Exception
    {
        public OAuthException(string error, string? description)
            : base(string.IsNullOrEmpty(description) ? error : $"{error}: {description}")
        {
            Error = error;
        }

        public string Error { get; }
    }

    /// <summary>Chamadas JSON autenticadas, com uma nova tentativa depois de renovar o token.</summary>
    public static class ApiCall
    {
        public static async Task<JsonDocument?> SendAsync(IHttpClientFactory http, OAuthTokens tokens, HttpMethod method,
            string url, object? body = null, Action<HttpRequestHeaders>? headers = null)
        {
            for (var attempt = 0; attempt < 2; attempt++)
            {
                var token = await tokens.GetAccessTokenAsync() ?? throw new InvalidOperationException("Entre na conta de novo.");
                var client = http.CreateClient();
                client.Timeout = TimeSpan.FromSeconds(10);
                using var request = new HttpRequestMessage(method, url);
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                request.Headers.UserAgent.ParseAdd("DroidDeck");
                headers?.Invoke(request.Headers);
                if (body != null)
                    request.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
                using var response = await client.SendAsync(request);
                if (response.StatusCode == System.Net.HttpStatusCode.Unauthorized && attempt == 0)
                {
                    tokens.Expire();
                    continue;
                }
                var text = await response.Content.ReadAsStringAsync();
                if (!response.IsSuccessStatusCode)
                    throw new HttpRequestException(ErrorText(text, (int)response.StatusCode), null, response.StatusCode);
                return string.IsNullOrWhiteSpace(text) ? null : JsonDocument.Parse(text);
            }
            throw new InvalidOperationException("Entre na conta de novo.");
        }

        /// <summary>Mensagem de erro das APIs (Spotify, Twitch e Google mandam formatos diferentes).</summary>
        public static string ErrorText(string body, int status)
        {
            try
            {
                using var doc = JsonDocument.Parse(body);
                var root = doc.RootElement;
                if (root.TryGetProperty("error", out var e))
                {
                    if (e.ValueKind == JsonValueKind.Object && e.TryGetProperty("message", out var m)) return m.GetString() ?? $"HTTP {status}";
                    if (root.TryGetProperty("message", out var tm)) return tm.GetString() ?? e.ToString();
                    return e.ToString();
                }
            }
            catch { }
            return $"HTTP {status}";
        }
    }
}
