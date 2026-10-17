using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Actions;
using DroidDeck.Hubs;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Integrations
{
    /// <summary>
    /// Home Assistant pela API WebSocket (token de longa duracao): le todos os estados,
    /// acompanha state_changed e chama servicos. Para os celulares vao so as entidades usadas
    /// em algum botao.
    /// </summary>
    public class HomeAssistantIntegration : AccountIntegration
    {
        public const string Event = "ReceiveHomeAssistantState";

        private readonly ConcurrentDictionary<string, Entity> _entities = new();
        private readonly ConcurrentDictionary<int, TaskCompletionSource<JsonNode?>> _pending = new();
        private readonly SemaphoreSlim _sendLock = new(1, 1);
        private ClientWebSocket? _socket;
        private int _nextId = 10;
        private bool _connected;
        private string? _error;
        private string? _location;
        private CancellationTokenSource? _reconnect;
        private int _broadcastQueued;

        public HomeAssistantIntegration(ILogger<HomeAssistantIntegration> logger, IHubContext<DeckHub> hub, StreamDeckConfigService config)
            : base(logger, hub, config) { }

        public override string Name => "homeassistant";
        public override string Title => "Home Assistant";
        public override string StateEvent => Event;

        public class Entity
        {
            public string Id { get; set; } = "";
            public string State { get; set; } = "";
            public string? Name { get; set; }
            public string? Unit { get; set; }

            /// <summary>Brilho de 0 a 100 (luzes acesas).</summary>
            public int? Brightness { get; set; }

            /// <summary>Cor da luz em #RRGGBB, quando tem.</summary>
            public string? Color { get; set; }

            public string Domain => Id.Split('.')[0];
        }

        private string? Url => Get("url");
        private string? Token => Get("token");

        public override IntegrationStatus GetStatus() => new()
        {
            Connected = _connected,
            Configured = Url != null && Token != null,
            Account = _connected ? (_location ?? Url) : null,
            Message = _connected ? null : _error,
            Fields = new() { ["url"] = Url ?? "" },
        };

        public override object GetState()
        {
            var used = UsedEntities();
            return new
            {
                connected = _connected,
                entities = _entities.Values.Where(e => used.Contains(e.Id)).ToDictionary(e => e.Id, e => e),
            };
        }

        private HashSet<string> UsedEntities() =>
            ActionsOfType(HomeAssistantProvider.TypeName)
                .Select(a => a.Parameters.TryGetValue("entityId", out var id) ? id : null)
                .Where(id => !string.IsNullOrEmpty(id))
                .ToHashSet(StringComparer.OrdinalIgnoreCase)!;

        public override async Task<IntegrationStatus> ConfigureAsync(Dictionary<string, string> fields)
        {
            var url = (fields.GetValueOrDefault("url") ?? "").Trim().TrimEnd('/');
            if (url.Length > 0 && !url.StartsWith("http", StringComparison.OrdinalIgnoreCase)) url = "http://" + url;
            if (!Uri.TryCreate(url, UriKind.Absolute, out _))
                throw new InvalidOperationException("Endereço inválido. Ex.: http://homeassistant.local:8123");
            var token = (fields.GetValueOrDefault("token") ?? "").Trim();
            Set(("url", url), ("token", token.Length > 0 ? token : Token));
            if (Token == null) throw new InvalidOperationException("Falta o token de acesso.");

            Restart();
            // Espera a primeira tentativa para a tela ja mostrar o resultado.
            for (var i = 0; i < 40 && !_connected && _error == null; i++) await Task.Delay(250);
            return GetStatus();
        }

        public override Task LogoutAsync()
        {
            Clear();
            Restart();
            return Task.CompletedTask;
        }

        private void Restart()
        {
            _error = null;
            _reconnect?.Cancel();
            try { _socket?.Abort(); } catch { }
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var delay = TimeSpan.FromSeconds(5);
            while (!stoppingToken.IsCancellationRequested)
            {
                _reconnect = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                if (Url == null || Token == null)
                {
                    await Wait(TimeSpan.FromDays(1), _reconnect.Token);
                    continue;
                }
                try
                {
                    await RunAsync(_reconnect.Token);
                    delay = TimeSpan.FromSeconds(5);
                }
                catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
                {
                    if (!_reconnect.IsCancellationRequested)
                    {
                        _error = ex is WebSocketException or System.Net.Http.HttpRequestException
                            ? "Não foi possível conectar ao Home Assistant. Confira o endereço."
                            : ex.Message;
                        Logger.LogInformation("Home Assistant: {Error}", ex.Message);
                    }
                }
                if (_connected)
                {
                    _connected = false;
                    await BroadcastAsync();
                }
                foreach (var p in _pending.Values) p.TrySetCanceled();
                _pending.Clear();
                if (!_reconnect.IsCancellationRequested)
                {
                    await Wait(delay, _reconnect.Token);
                    delay = TimeSpan.FromSeconds(Math.Min(delay.TotalSeconds * 2, 60));
                }
            }
        }

        private async Task RunAsync(CancellationToken ct)
        {
            var http = new Uri(Url!);
            var ws = new UriBuilder(http) { Scheme = http.Scheme == "https" ? "wss" : "ws", Path = "/api/websocket" }.Uri;
            using var socket = new ClientWebSocket();
            _socket = socket;
            await socket.ConnectAsync(ws, ct);

            var hello = await ReceiveAsync(socket, ct);
            if (hello?["type"]?.GetValue<string>() != "auth_required") throw new InvalidOperationException("Resposta inesperada do Home Assistant.");
            await SendRawAsync(socket, new JsonObject { ["type"] = "auth", ["access_token"] = Token }, ct);
            var auth = await ReceiveAsync(socket, ct);
            if (auth?["type"]?.GetValue<string>() != "auth_ok")
                throw new InvalidOperationException("Token recusado pelo Home Assistant. Gere outro no seu perfil.");

            await SendRawAsync(socket, new JsonObject { ["id"] = 1, ["type"] = "get_states" }, ct);
            await SendRawAsync(socket, new JsonObject { ["id"] = 2, ["type"] = "subscribe_events", ["event_type"] = "state_changed" }, ct);
            await SendRawAsync(socket, new JsonObject { ["id"] = 3, ["type"] = "get_config" }, ct);

            while (!ct.IsCancellationRequested && socket.State == WebSocketState.Open)
            {
                var msg = await ReceiveAsync(socket, ct);
                if (msg == null) break;
                var type = msg["type"]?.GetValue<string>();
                var id = msg["id"]?.GetValue<int>() ?? 0;
                if (type == "result" && id == 1 && msg["result"] is JsonArray states)
                {
                    _entities.Clear();
                    foreach (var s in states) if (Parse(s) is { } e) _entities[e.Id] = e;
                    _connected = true;
                    _error = null;
                    await BroadcastAsync();
                }
                else if (type == "result" && id == 3)
                {
                    _location = msg["result"]?["location_name"]?.GetValue<string>();
                }
                else if (type == "event")
                {
                    var data = msg["event"]?["data"];
                    var entityId = data?["entity_id"]?.GetValue<string>();
                    if (entityId == null) continue;
                    if (Parse(data?["new_state"]) is { } e) _entities[e.Id] = e;
                    else _entities.TryRemove(entityId, out _);
                    if (UsedEntities().Contains(entityId)) QueueBroadcast();
                }
                else if (type == "result" && _pending.TryRemove(id, out var tcs))
                {
                    if (msg["success"]?.GetValue<bool>() == true) tcs.TrySetResult(msg["result"]);
                    else tcs.TrySetException(new InvalidOperationException(msg["error"]?["message"]?.GetValue<string>() ?? "O Home Assistant recusou."));
                }
            }
        }

        /// <summary>Junta varias mudancas seguidas (uma cena mexe em dez luzes) num envio so.</summary>
        private void QueueBroadcast()
        {
            if (Interlocked.Exchange(ref _broadcastQueued, 1) == 1) return;
            _ = Task.Run(async () =>
            {
                await Task.Delay(150);
                Interlocked.Exchange(ref _broadcastQueued, 0);
                await BroadcastAsync();
            });
        }

        public static Entity? Parse(JsonNode? s)
        {
            var id = s?["entity_id"]?.GetValue<string>();
            if (id == null) return null;
            var attrs = s!["attributes"];
            var e = new Entity
            {
                Id = id,
                State = s["state"]?.GetValue<string>() ?? "",
                Name = attrs?["friendly_name"]?.GetValue<string>(),
                Unit = attrs?["unit_of_measurement"]?.GetValue<string>(),
            };
            if (attrs?["brightness"] is JsonValue b && b.TryGetValue<double>(out var level))
                e.Brightness = (int)Math.Round(level / 255.0 * 100);
            if (attrs?["rgb_color"] is JsonArray rgb && rgb.Count == 3)
                e.Color = "#" + string.Concat(rgb.Select(c => ((int)(c?.GetValue<double>() ?? 0)).ToString("X2")));
            return e;
        }

        public Entity? Find(string entityId) => _entities.TryGetValue(entityId, out var e) ? e : null;

        /// <summary>Chama um servico (ex.: light.turn_on) e espera a resposta.</summary>
        public async Task CallServiceAsync(string domain, string service, string? entityId, JsonObject? data = null)
        {
            var socket = _socket;
            if (!_connected || socket == null) throw new InvalidOperationException("Home Assistant desconectado.");
            var id = Interlocked.Increment(ref _nextId);
            var msg = new JsonObject { ["id"] = id, ["type"] = "call_service", ["domain"] = domain, ["service"] = service };
            if (data != null) msg["service_data"] = data;
            if (!string.IsNullOrEmpty(entityId)) msg["target"] = new JsonObject { ["entity_id"] = entityId };
            var tcs = new TaskCompletionSource<JsonNode?>(TaskCreationOptions.RunContinuationsAsynchronously);
            _pending[id] = tcs;
            await SendRawAsync(socket, msg, CancellationToken.None);
            var done = await Task.WhenAny(tcs.Task, Task.Delay(TimeSpan.FromSeconds(8)));
            _pending.TryRemove(id, out _);
            if (done != tcs.Task) throw new TimeoutException("O Home Assistant não respondeu.");
            await tcs.Task;
        }

        private async Task SendRawAsync(ClientWebSocket socket, JsonObject msg, CancellationToken ct)
        {
            var bytes = Encoding.UTF8.GetBytes(msg.ToJsonString());
            await _sendLock.WaitAsync(ct);
            try { await socket.SendAsync(bytes, WebSocketMessageType.Text, true, ct); }
            finally { _sendLock.Release(); }
        }

        private static async Task<JsonNode?> ReceiveAsync(ClientWebSocket socket, CancellationToken ct)
        {
            var buffer = new byte[64 * 1024];
            using var ms = new System.IO.MemoryStream();
            while (true)
            {
                var r = await socket.ReceiveAsync(buffer, ct);
                if (r.MessageType == WebSocketMessageType.Close) return null;
                ms.Write(buffer, 0, r.Count);
                if (r.EndOfMessage) break;
            }
            return JsonNode.Parse(ms.ToArray());
        }

        // ---- Listas do editor ----

        /// <summary>Dominios de cada operacao do botao.</summary>
        public static string[] DomainsFor(string? operation) => (operation ?? "").ToLowerInvariant() switch
        {
            "scene" => new[] { "scene" },
            "script" => new[] { "script" },
            "brightness" => new[] { "light" },
            "display" => new[] { "sensor", "binary_sensor", "weather", "climate", "person", "device_tracker", "sun", "input_number", "input_text", "counter" },
            "service" => Array.Empty<string>(),
            _ => new[] { "light", "switch", "fan", "cover", "lock", "media_player", "input_boolean", "climate", "automation", "siren", "humidifier", "vacuum" },
        };

        public override Task<List<FieldOption>> OptionsAsync(string list, IQueryCollection query)
        {
            if (list != "entities") return base.OptionsAsync(list, query);
            if (!_connected) throw new InvalidOperationException("Home Assistant desconectado.");
            var domains = DomainsFor(query["operation"]);
            var options = _entities.Values
                .Where(e => domains.Length == 0 || domains.Contains(e.Domain))
                .OrderBy(e => e.Domain).ThenBy(e => e.Name ?? e.Id, StringComparer.CurrentCultureIgnoreCase)
                .Select(e => new FieldOption(e.Id, $"{e.Name ?? e.Id} ({e.Id})"))
                .ToList();
            return Task.FromResult(options);
        }
    }
}
