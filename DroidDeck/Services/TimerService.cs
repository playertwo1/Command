using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Hubs;
using DroidDeck.Lib;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    /// <summary>
    /// Timers, cronometros, pomodoros e contadores dos botoes do deck.
    ///
    /// O estado mora no PC para que todos os celulares (e o configurador) vejam o mesmo
    /// relogio, e para que o fim de uma contagem seja detectado mesmo com a tela do celular
    /// apagada. Os clientes recebem o tempo restante/decorrido no instante do envio e contam
    /// sozinhos a partir dai: o servidor so transmite quando algo muda, nao a cada segundo.
    ///
    /// Contadores sobrevivem a reinicios (counters.json); timers nao -- um timer que estava
    /// rodando quando o PC desligou nao tem como saber quanto tempo passou de verdade.
    /// </summary>
    public class TimerService : BackgroundService
    {
        public const string ModeCountdown = "countdown";
        public const string ModeStopwatch = "stopwatch";
        public const string ModePomodoro = "pomodoro";
        public const string ModeCounter = "counter";

        private readonly ILogger<TimerService> _logger;
        private readonly IHubContext<DeckHub> _hub;
        private readonly object _lock = new();
        private readonly Dictionary<string, TimerEntry> _timers = new();

        /// <summary>Relogio injetavel (testes).</summary>
        public Func<DateTime> Now { get; set; } = () => DateTime.UtcNow;

        /// <summary>Chamado quando uma contagem termina (beep no PC). Trocavel nos testes.</summary>
        public Action<TimerEntry> OnFinished { get; set; } = _ =>
        {
            try { System.Media.SystemSounds.Exclamation.Play(); } catch { }
        };

        public TimerService(ILogger<TimerService> logger, IHubContext<DeckHub> hub)
        {
            _logger = logger;
            _hub = hub;
            LoadCounters();
        }

        public class TimerEntry
        {
            public string Id { get; set; } = "";
            public string Mode { get; set; } = ModeCountdown;
            public bool Running { get; set; }
            public bool Finished { get; set; }

            /// <summary>Duracao total da fase atual (countdown/pomodoro).</summary>
            public TimeSpan Duration { get; set; }

            /// <summary>Tempo acumulado ate o ultimo pause (ou ate StartedAt, se rodando).</summary>
            public TimeSpan Accumulated { get; set; }
            public DateTime? StartedAt { get; set; }

            public long Count { get; set; }

            /// <summary>Pomodoro: "work" ou "break".</summary>
            public string Phase { get; set; } = "work";

            /// <summary>Pomodoro: quantos ciclos de foco ja terminaram.</summary>
            public int Cycles { get; set; }

            public TimeSpan WorkDuration { get; set; } = TimeSpan.FromMinutes(25);
            public TimeSpan BreakDuration { get; set; } = TimeSpan.FromMinutes(5);

            public TimeSpan Elapsed(DateTime now) =>
                Accumulated + (Running && StartedAt.HasValue ? now - StartedAt.Value : TimeSpan.Zero);
        }

        // ---- Acoes ----

        /// <summary>
        /// Aplica uma operacao no timer <paramref name="id"/>. A configuracao (modo, duracoes)
        /// vem dos parametros do botao a cada toque, entao editar o botao vale no proximo toque
        /// sem precisar apagar o estado antigo.
        /// </summary>
        public void Apply(string id, string operation, IReadOnlyDictionary<string, string> p)
        {
            if (string.IsNullOrWhiteSpace(id)) return;
            var now = Now();
            TimerEntry snapshot;

            lock (_lock)
            {
                var t = GetOrCreate(id);
                Configure(t, p);

                var step = p.TryGetValue("step", out var s) && long.TryParse(s, out var st) ? Math.Max(1, st) : 1;

                switch ((operation ?? "").Trim().ToLowerInvariant())
                {
                    case "reset":
                        Reset(t);
                        t.Count = 0;
                        break;
                    case "increment":
                        t.Count += step;
                        break;
                    case "decrement":
                        t.Count -= step;
                        break;
                    case "skip":
                        if (t.Mode == ModePomodoro) NextPhase(t, now, startRunning: t.Running);
                        break;
                    default: // toggle
                        Toggle(t, now, step);
                        break;
                }

                if (t.Mode == ModeCounter) SaveCounters();
                snapshot = t;
            }

            _logger.LogInformation("Timer {Id}: {Op} ({Mode})", id, operation, snapshot.Mode);
            _ = BroadcastAsync();
        }

        private TimerEntry GetOrCreate(string id)
        {
            if (!_timers.TryGetValue(id, out var t))
            {
                t = new TimerEntry { Id = id };
                _timers[id] = t;
            }
            return t;
        }

        private static void Configure(TimerEntry t, IReadOnlyDictionary<string, string> p)
        {
            var mode = p.TryGetValue("mode", out var m) && m is { Length: > 0 } ? m.ToLowerInvariant() : ModeCountdown;
            if (mode != t.Mode)
            {
                // Trocou o modo do botao: comeca do zero no modo novo.
                t.Mode = mode;
                Reset(t);
                t.Count = 0;
            }

            if (Seconds(p, "durationSec") is { } d) t.Duration = d;
            if (Seconds(p, "workSec") is { } w) t.WorkDuration = w;
            if (Seconds(p, "breakSec") is { } b) t.BreakDuration = b;

            if (t.Mode == ModePomodoro && !t.Running && t.Accumulated == TimeSpan.Zero)
                t.Duration = t.Phase == "break" ? t.BreakDuration : t.WorkDuration;
            if (t.Mode == ModeCountdown && t.Duration <= TimeSpan.Zero)
                t.Duration = TimeSpan.FromMinutes(5);
        }

        private static TimeSpan? Seconds(IReadOnlyDictionary<string, string> p, string key) =>
            p.TryGetValue(key, out var v) && double.TryParse(v, System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture, out var sec) && sec > 0
                ? TimeSpan.FromSeconds(Math.Min(sec, 24 * 3600 * 7))
                : null;

        private static void Toggle(TimerEntry t, DateTime now, long step)
        {
            if (t.Mode == ModeCounter)
            {
                t.Count += step;
                return;
            }

            // Contagem que ja terminou: o toque zera, o seguinte comeca de novo.
            if (t.Finished)
            {
                Reset(t);
                return;
            }

            if (t.Running)
            {
                t.Accumulated = t.Elapsed(now);
                t.StartedAt = null;
                t.Running = false;
            }
            else
            {
                t.StartedAt = now;
                t.Running = true;
            }
        }

        private static void Reset(TimerEntry t)
        {
            t.Running = false;
            t.Finished = false;
            t.StartedAt = null;
            t.Accumulated = TimeSpan.Zero;
            if (t.Mode == ModePomodoro)
            {
                t.Phase = "work";
                t.Cycles = 0;
                t.Duration = t.WorkDuration;
            }
        }

        private static void NextPhase(TimerEntry t, DateTime now, bool startRunning)
        {
            if (t.Phase == "work") t.Cycles++;
            t.Phase = t.Phase == "work" ? "break" : "work";
            t.Duration = t.Phase == "break" ? t.BreakDuration : t.WorkDuration;
            t.Accumulated = TimeSpan.Zero;
            t.Finished = false;
            t.Running = startRunning;
            t.StartedAt = startRunning ? now : null;
        }

        // ---- Laco: detecta contagens que chegaram ao fim ----

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    if (Tick()) await BroadcastAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Timer: erro no laco");
                }
                try { await Task.Delay(250, stoppingToken); } catch (TaskCanceledException) { }
            }
        }

        /// <summary>Avanca timers vencidos. Devolve true se algum mudou.</summary>
        public bool Tick()
        {
            var now = Now();
            var finished = new List<TimerEntry>();
            lock (_lock)
            {
                foreach (var t in _timers.Values)
                {
                    if (!t.Running || (t.Mode != ModeCountdown && t.Mode != ModePomodoro)) continue;
                    if (t.Elapsed(now) < t.Duration) continue;

                    if (t.Mode == ModePomodoro)
                    {
                        // A fase seguinte comeca sozinha, contando do instante em que a
                        // anterior terminou (e nao de agora), para nao acumular atraso.
                        var endedAt = t.StartedAt!.Value + (t.Duration - t.Accumulated);
                        NextPhase(t, endedAt, startRunning: true);
                    }
                    else
                    {
                        t.Accumulated = t.Duration;
                        t.StartedAt = null;
                        t.Running = false;
                        t.Finished = true;
                    }
                    finished.Add(t);
                }
            }

            foreach (var t in finished)
            {
                _logger.LogInformation("Timer {Id} terminou ({Mode})", t.Id, t.Mode);
                try { OnFinished(t); } catch { }
            }
            return finished.Count > 0;
        }

        // ---- Estado para os clientes ----

        public Dictionary<string, object> GetStatePayload()
        {
            var now = Now();
            lock (_lock)
            {
                return _timers.Values.ToDictionary(t => t.Id, t => (object)new
                {
                    mode = t.Mode,
                    running = t.Running,
                    finished = t.Finished,
                    elapsedMs = (long)t.Elapsed(now).TotalMilliseconds,
                    durationMs = (long)t.Duration.TotalMilliseconds,
                    count = t.Count,
                    phase = t.Phase,
                    cycles = t.Cycles,
                });
            }
        }

        private async Task BroadcastAsync()
        {
            try { await _hub.Clients.All.SendAsync("ReceiveTimerState", GetStatePayload()); }
            catch { }
        }

        // ---- Contadores persistentes ----

        private static string CountersPath => Path.Combine(AppPaths.RoamingDir, "counters.json");

        private void LoadCounters()
        {
            try
            {
                if (!File.Exists(CountersPath)) return;
                var saved = JsonSerializer.Deserialize<Dictionary<string, long>>(File.ReadAllText(CountersPath));
                if (saved == null) return;
                foreach (var (id, count) in saved)
                    _timers[id] = new TimerEntry { Id = id, Mode = ModeCounter, Count = count };
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Timer: counters.json ilegivel, contadores zerados");
            }
        }

        private void SaveCounters()
        {
            try
            {
                var data = _timers.Values.Where(t => t.Mode == ModeCounter).ToDictionary(t => t.Id, t => t.Count);
                var tmp = CountersPath + ".tmp";
                File.WriteAllText(tmp, JsonSerializer.Serialize(data));
                File.Move(tmp, CountersPath, overwrite: true);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Timer: falha ao gravar counters.json");
            }
        }
    }
}
