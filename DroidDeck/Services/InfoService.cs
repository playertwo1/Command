using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Hubs;
using DroidDeck.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    /// <summary>
    /// Botoes de informacao: clima, saida de um comando, valor de uma URL e "tocando agora".
    /// O relogio e calculado no celular; o resto e buscado aqui, so para os botoes que existem
    /// nos perfis, e vai para os clientes quando muda.
    /// </summary>
    public class InfoService : BackgroundService
    {
        public const string Event = "ReceiveInfoState";
        public const string NowPlayingEvent = "ReceiveNowPlaying";

        public const string TypeWeather = "weather";
        public const string TypeCommand = "command";
        public const string TypeUrl = "url";
        public const string TypeNowPlaying = "now_playing";

        private static readonly TimeSpan WeatherEvery = TimeSpan.FromMinutes(15);
        private const int MaxText = 200;

        private readonly ILogger<InfoService> _logger;
        private readonly IHubContext<DeckHub> _hub;
        private readonly StreamDeckConfigService _config;
        private readonly MediaControlService _media;
        private readonly IHttpClientFactory _http;

        private readonly ConcurrentDictionary<string, InfoValue> _values = new();
        private readonly ConcurrentDictionary<string, DateTime> _nextRun = new();
        private readonly ConcurrentDictionary<string, bool> _running = new();
        private readonly ConcurrentDictionary<string, (DateTime at, InfoValue value)> _weatherCache = new();

        private string? _nowPlayingKey;
        private int _thumbRetries;

        public InfoService(ILogger<InfoService> logger, IHubContext<DeckHub> hub, StreamDeckConfigService config,
            MediaControlService media, IHttpClientFactory http)
        {
            _logger = logger;
            _hub = hub;
            _config = config;
            _media = media;
            _http = http;
        }

        public class InfoValue
        {
            public string Text { get; set; } = "";
            public string? Sub { get; set; }

            /// <summary>Clima: codigo WMO do tempo (o app escolhe o icone).</summary>
            public int? Code { get; set; }
            public bool? IsDay { get; set; }
            public bool Error { get; set; }

            public bool SameAs(InfoValue? o) =>
                o != null && o.Text == Text && o.Sub == Sub && o.Code == Code && o.IsDay == IsDay && o.Error == Error;
        }

        public class NowPlayingInfo
        {
            public string? Title { get; set; }
            public string? Artist { get; set; }
            public bool Playing { get; set; }
            public string? ThumbnailBase64 { get; set; }
        }

        public NowPlayingInfo? NowPlaying { get; private set; }

        /// <summary>Valor de cada botao de informacao, por id do botao.</summary>
        public object GetState() => _values.ToDictionary(kv => kv.Key, kv => kv.Value);

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var tick = 0;
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var buttons = _config.GetProfiles()
                        .SelectMany(p => p.Buttons ?? new List<DeckButton>())
                        .Where(b => !string.IsNullOrEmpty(b.DynamicType))
                        .ToList();

                    // Botoes apagados ou que mudaram de tipo saem do estado.
                    var ids = buttons.Where(b => b.DynamicType is TypeWeather or TypeCommand or TypeUrl)
                        .Select(b => b.Id).ToHashSet();
                    var removed = false;
                    foreach (var id in _values.Keys.Where(k => !ids.Contains(k)).ToList())
                        removed |= _values.TryRemove(id, out _);
                    if (removed) await BroadcastAsync();

                    var now = DateTime.UtcNow;
                    foreach (var b in buttons)
                    {
                        if (b.DynamicType is not (TypeWeather or TypeCommand or TypeUrl)) continue;
                        var key = b.Id + "|" + Signature(b);
                        if (_nextRun.TryGetValue(key, out var next) && next > now) continue;
                        if (!_running.TryAdd(b.Id, true)) continue;
                        _nextRun[key] = now + Interval(b);
                        _ = RefreshAsync(b);
                    }

                    if (tick % 3 == 0 && DeckHub.ConnectedCount > 0 && buttons.Any(b => b.DynamicType == TypeNowPlaying))
                        await RefreshNowPlayingAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Info: falha no ciclo");
                }

                tick++;
                try { await Task.Delay(1000, stoppingToken); }
                catch (TaskCanceledException) { }
            }
        }

        private static string Signature(DeckButton b) =>
            b.DynamicType + ":" + string.Join(";", (b.DynamicParameters ?? new()).OrderBy(kv => kv.Key).Select(kv => kv.Key + "=" + kv.Value));

        private static string Param(DeckButton b, string key, string fallback = "") =>
            b.DynamicParameters != null && b.DynamicParameters.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v.Trim() : fallback;

        public static TimeSpan Interval(DeckButton b)
        {
            if (b.DynamicType == TypeWeather) return WeatherEvery;
            var secs = int.TryParse(Param(b, "interval"), NumberStyles.Integer, CultureInfo.InvariantCulture, out var s) ? s : 60;
            return TimeSpan.FromSeconds(Math.Clamp(secs, 5, 24 * 3600));
        }

        private async Task RefreshAsync(DeckButton b)
        {
            try
            {
                var value = b.DynamicType switch
                {
                    TypeWeather => await WeatherAsync(Param(b, "city"), Param(b, "units", "c")),
                    TypeCommand => Format(b, await RunCommandAsync(Param(b, "command"))),
                    TypeUrl => Format(b, await FetchUrlAsync(Param(b, "url"), Param(b, "path"))),
                    _ => null,
                };
                if (value == null) return;
                if (_values.TryGetValue(b.Id, out var old) && old.SameAs(value)) return;
                _values[b.Id] = value;
                await BroadcastAsync();
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Info: botao {Id} ({Type}) falhou", b.Id, b.DynamicType);
                var err = new InfoValue { Text = "—", Sub = Short(ex.Message, 60), Error = true };
                if (!(_values.TryGetValue(b.Id, out var old) && old.SameAs(err)))
                {
                    _values[b.Id] = err;
                    await BroadcastAsync();
                }
            }
            finally
            {
                _running.TryRemove(b.Id, out _);
            }
        }

        /// <summary>Aplica o modelo "format" (ex.: "{value} °C") ao texto obtido.</summary>
        public static InfoValue Format(DeckButton b, string raw)
        {
            var template = Param(b, "format", "{value}");
            var text = template.Contains("{value}") ? template.Replace("{value}", raw) : template + raw;
            return new InfoValue { Text = Short(text, MaxText) };
        }

        private static string Short(string s, int max) => s.Length <= max ? s : s[..max];

        // ---- Comando ----

        private static async Task<string> RunCommandAsync(string command)
        {
            if (string.IsNullOrWhiteSpace(command)) throw new InvalidOperationException("Sem comando");
            var psi = new ProcessStartInfo("cmd.exe", "/d /c chcp 65001>nul & " + command)
            {
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8,
            };
            using var proc = Process.Start(psi) ?? throw new InvalidOperationException("Não abriu o cmd");
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            var stdout = proc.StandardOutput.ReadToEndAsync(cts.Token);
            var stderr = proc.StandardError.ReadToEndAsync(cts.Token);
            try
            {
                await proc.WaitForExitAsync(cts.Token);
            }
            catch (OperationCanceledException)
            {
                try { proc.Kill(entireProcessTree: true); } catch { }
                throw new TimeoutException("O comando passou de 10 s");
            }
            var output = (await stdout).Trim();
            if (output.Length == 0) output = (await stderr).Trim();
            return output;
        }

        // ---- URL ----

        private async Task<string> FetchUrlAsync(string url, string path)
        {
            if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || (uri.Scheme != "http" && uri.Scheme != "https"))
                throw new InvalidOperationException("URL inválida");
            var client = _http.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(10);
            // Varias APIs (GitHub, p.ex.) recusam pedidos sem User-Agent.
            using var request = new HttpRequestMessage(HttpMethod.Get, uri);
            request.Headers.UserAgent.ParseAdd("DroidDeck");
            using var response = await client.SendAsync(request);
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException($"HTTP {(int)response.StatusCode}");
            var body = await response.Content.ReadAsStringAsync();
            return string.IsNullOrWhiteSpace(path) ? body.Trim() : JsonPath(body, path);
        }

        /// <summary>Le um valor de um JSON por um caminho simples: "current.temp", "items[0].name".</summary>
        public static string JsonPath(string json, string path)
        {
            using var doc = JsonDocument.Parse(json);
            var el = doc.RootElement;
            foreach (Match m in Regex.Matches(path, @"([^.\[\]]+)|\[(\d+)\]"))
            {
                if (m.Groups[2].Success)
                {
                    var i = int.Parse(m.Groups[2].Value, CultureInfo.InvariantCulture);
                    if (el.ValueKind != JsonValueKind.Array || i >= el.GetArrayLength())
                        throw new InvalidOperationException($"Sem o item [{i}]");
                    el = el[i];
                }
                else
                {
                    var name = m.Groups[1].Value;
                    if (el.ValueKind == JsonValueKind.Array && int.TryParse(name, out var idx) && idx < el.GetArrayLength())
                        el = el[idx];
                    else if (el.ValueKind != JsonValueKind.Object || !el.TryGetProperty(name, out el))
                        throw new InvalidOperationException($"Sem o campo \"{name}\"");
                }
            }
            return el.ValueKind switch
            {
                JsonValueKind.String => el.GetString() ?? "",
                JsonValueKind.Number => el.GetDouble().ToString("0.##", CultureInfo.InvariantCulture),
                JsonValueKind.True => "sim",
                JsonValueKind.False => "não",
                JsonValueKind.Null => "",
                _ => el.GetRawText(),
            };
        }

        // ---- Clima (Open-Meteo, sem chave) ----

        private async Task<InfoValue> WeatherAsync(string city, string units)
        {
            if (string.IsNullOrWhiteSpace(city)) throw new InvalidOperationException("Sem cidade");
            var fahrenheit = units.Equals("f", StringComparison.OrdinalIgnoreCase);
            var cacheKey = city.ToLowerInvariant() + "|" + (fahrenheit ? "f" : "c");
            if (_weatherCache.TryGetValue(cacheKey, out var cached) && DateTime.UtcNow - cached.at < WeatherEvery - TimeSpan.FromSeconds(30))
                return cached.value;

            var client = _http.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(10);
            client.DefaultRequestHeaders.UserAgent.ParseAdd("DroidDeck");
            using var geo = JsonDocument.Parse(await client.GetStringAsync(
                "https://geocoding-api.open-meteo.com/v1/search?count=1&language=pt&name=" + Uri.EscapeDataString(city)));
            if (!geo.RootElement.TryGetProperty("results", out var results) || results.GetArrayLength() == 0)
                throw new InvalidOperationException("Cidade não encontrada");
            var place = results[0];
            var lat = place.GetProperty("latitude").GetDouble().ToString(CultureInfo.InvariantCulture);
            var lon = place.GetProperty("longitude").GetDouble().ToString(CultureInfo.InvariantCulture);
            var name = place.TryGetProperty("name", out var n) ? n.GetString() : city;

            using var wx = JsonDocument.Parse(await client.GetStringAsync(
                $"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code,is_day"
                + (fahrenheit ? "&temperature_unit=fahrenheit" : "")));
            var current = wx.RootElement.GetProperty("current");
            var value = new InfoValue
            {
                Text = Math.Round(current.GetProperty("temperature_2m").GetDouble()).ToString(CultureInfo.InvariantCulture) + "°",
                Sub = name,
                Code = current.GetProperty("weather_code").GetInt32(),
                IsDay = current.GetProperty("is_day").GetInt32() == 1,
            };
            _weatherCache[cacheKey] = (DateTime.UtcNow, value);
            return value;
        }

        // ---- Tocando agora ----

        private async Task RefreshNowPlayingAsync()
        {
            var info = await _media.GetNowPlayingAsync(includeThumbnail: false);
            var key = info == null ? "" : info.Title + "|" + info.Artist;
            var playing = info?.PlaybackStatus == "Playing";

            // A leitura da capa as vezes falha (broker de midia ocupado): tenta de novo
            // algumas vezes antes de desistir dela para esta faixa.
            var retryThumb = key == _nowPlayingKey && info != null && NowPlaying?.ThumbnailBase64 == null && _thumbRetries < 3;
            if (key == _nowPlayingKey && NowPlaying != null && NowPlaying.Playing == playing && !retryThumb) return;

            string? thumbnail = NowPlaying?.ThumbnailBase64;
            if (key != _nowPlayingKey || retryThumb)
            {
                _thumbRetries = key != _nowPlayingKey ? 0 : _thumbRetries + 1;
                thumbnail = info == null ? null : Shrink((await _media.GetNowPlayingAsync(includeThumbnail: true))?.ThumbnailBase64);
                if (retryThumb && thumbnail == null && NowPlaying?.Playing == playing) return;
            }
            _nowPlayingKey = key;
            NowPlaying = new NowPlayingInfo
            {
                Title = info?.Title,
                Artist = info?.Artist,
                Playing = playing,
                ThumbnailBase64 = thumbnail,
            };
            try { await _hub.Clients.All.SendAsync(NowPlayingEvent, NowPlaying); }
            catch { }
        }

        /// <summary>Reduz a capa para ~200 px em JPEG: a original passa de 250 KB e vai para todos os celulares.</summary>
        public static string? Shrink(string? base64, int size = 200)
        {
            if (string.IsNullOrEmpty(base64)) return base64;
            // A midia do Windows entrega "data:image/...;base64,<dados>".
            var comma = base64.StartsWith("data:", StringComparison.Ordinal) ? base64.IndexOf(',') : -1;
            if (comma >= 0) base64 = base64[(comma + 1)..];
            try
            {
                using var input = new System.IO.MemoryStream(Convert.FromBase64String(base64));
                using var src = System.Drawing.Image.FromStream(input);
                if (src.Width <= size && src.Height <= size) return base64;
                var scale = (double)size / Math.Max(src.Width, src.Height);
                using var dst = new System.Drawing.Bitmap(Math.Max(1, (int)(src.Width * scale)), Math.Max(1, (int)(src.Height * scale)));
                using (var g = System.Drawing.Graphics.FromImage(dst))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.DrawImage(src, 0, 0, dst.Width, dst.Height);
                }
                using var output = new System.IO.MemoryStream();
                dst.Save(output, System.Drawing.Imaging.ImageFormat.Jpeg);
                return Convert.ToBase64String(output.ToArray());
            }
            catch
            {
                return base64;
            }
        }

        private async Task BroadcastAsync()
        {
            try { await _hub.Clients.All.SendAsync(Event, GetState()); }
            catch { }
        }
    }
}
