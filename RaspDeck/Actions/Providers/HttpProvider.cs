using System;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Actions.Providers
{
    /// <summary>
    /// Requisicao HTTP (webhook): n8n, Home Assistant, IFTTT, qualquer API.
    ///
    /// Privilegiada (ActionPolicy): a requisicao sai do PC, com o acesso de rede dele -- inclusive
    /// a servicos que so escutam em localhost. Por isso so nasce no configurador do PC.
    /// </summary>
    public class HttpProvider : IActionProvider
    {
        private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(10);

        private readonly IHttpClientFactory _http;
        private readonly ILogger<HttpProvider> _logger;

        public HttpProvider(IHttpClientFactory http, ILogger<HttpProvider> logger)
        {
            _http = http;
            _logger = logger;
        }

        public string Type => "http";

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Requisição HTTP (webhook)",
            Icon = "http",
            Category = "Utilidades",
            Description = "Chama uma URL a partir do PC: webhooks do n8n, Home Assistant, IFTTT ou qualquer API.",
            Fields =
            {
                ActionField.Select("method", "Método",
                    ("POST", "POST"), ("GET", "GET"), ("PUT", "PUT"), ("PATCH", "PATCH"), ("DELETE", "DELETE")),
                ActionField.Text("url", "URL", "https://exemplo.com/webhook", required: true),
                ActionField.Multiline("headers", "Cabeçalhos (opcional)", "Authorization: Bearer …",
                    "Um por linha, no formato Nome: valor."),
                ActionField.Select("contentType", "Formato do corpo",
                    ("application/json", "JSON"),
                    ("application/x-www-form-urlencoded", "Formulário"),
                    ("text/plain", "Texto"))
                    .When("method", "POST", "PUT", "PATCH"),
                ActionField.Multiline("body", "Corpo (opcional)", "{\"evento\": \"deck\"}")
                    .When("method", "POST", "PUT", "PATCH"),
            },
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            var url = c.Get("url").Trim();
            if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || (uri.Scheme != "http" && uri.Scheme != "https"))
            {
                _logger.LogWarning("HTTP: URL invalida '{Url}'", url);
                return;
            }

            var method = new HttpMethod(c.Get("method", "POST").ToUpperInvariant());
            using var request = BuildRequest(method, uri, c.Get("headers"), c.Get("body"), c.Get("contentType", "application/json"));

            using var cts = new CancellationTokenSource(Timeout);
            var client = _http.CreateClient();
            try
            {
                using var response = await client.SendAsync(request, cts.Token);
                if (response.IsSuccessStatusCode)
                    _logger.LogInformation("HTTP: {Method} {Host} -> {Status}", method, uri.Host, (int)response.StatusCode);
                else
                    _logger.LogWarning("HTTP: {Method} {Host} -> {Status}", method, uri.Host, (int)response.StatusCode);
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("HTTP: {Method} {Host} expirou ({Seconds}s)", method, uri.Host, Timeout.TotalSeconds);
            }
        }

        /// <summary>Monta a requisicao. Cabecalhos invalidos sao ignorados (com log no chamador).</summary>
        public static HttpRequestMessage BuildRequest(HttpMethod method, Uri uri, string headers, string body, string contentType)
        {
            var request = new HttpRequestMessage(method, uri);
            var hasBody = method != HttpMethod.Get && method != HttpMethod.Delete && body.Length > 0;
            if (hasBody)
                request.Content = new StringContent(body, Encoding.UTF8, contentType.Length > 0 ? contentType : "application/json");

            foreach (var raw in headers.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var colon = raw.IndexOf(':');
                if (colon <= 0) continue;
                var name = raw[..colon].Trim();
                var value = raw[(colon + 1)..].Trim();
                // Cabecalhos de conteudo (Content-Type...) so valem no Content.
                if (!request.Headers.TryAddWithoutValidation(name, value) && request.Content != null)
                {
                    request.Content.Headers.Remove(name);
                    request.Content.Headers.TryAddWithoutValidation(name, value);
                }
            }
            return request;
        }
    }
}
