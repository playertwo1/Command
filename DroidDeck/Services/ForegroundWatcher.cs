using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    /// <summary>
    /// Troca de perfil pelo app em foco: observa a janela em primeiro plano e, quando o
    /// processo dela esta na lista AutoSwitchApps de um perfil, avisa os celulares
    /// (ReceiveAutoProfile). Quando o foco vai para um app sem perfil, avisa com profileId
    /// nulo e o celular volta para onde estava.
    ///
    /// Le o foco a cada 500 ms em vez de usar SetWinEventHook: o hook exige uma thread com
    /// laco de mensagens so para isso, e meio segundo de atraso nao se nota numa troca de
    /// perfil. Sem celular conectado, nao faz nada.
    /// </summary>
    public class ForegroundWatcher : BackgroundService
    {
        public const string Event = "ReceiveAutoProfile";

        private readonly IHubContext<DeckHub> _hub;
        private readonly StreamDeckConfigService _config;
        private readonly ILogger<ForegroundWatcher> _logger;

        private uint _lastPid;
        private string? _lastProcess;
        private string? _currentProfileId;

        public ForegroundWatcher(IHubContext<DeckHub> hub, StreamDeckConfigService config, ILogger<ForegroundWatcher> logger)
        {
            _hub = hub;
            _config = config;
            _logger = logger;
        }

        /// <summary>Estado atual, enviado a quem conecta.</summary>
        public object GetState() => new { profileId = _currentProfileId, app = _lastProcess };

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var ownPid = (uint)Environment.ProcessId;
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    if (DeckHub.ConnectedCount > 0)
                    {
                        var pid = ForegroundPid();
                        // A propria janela do DroidDeck (QR, avisos) nao conta como troca.
                        if (pid != 0 && pid != _lastPid && pid != ownPid)
                        {
                            _lastPid = pid;
                            _lastProcess = ProcessName(pid);
                            var profileId = Match(_config.GetProfiles(), _lastProcess);
                            if (profileId != _currentProfileId)
                            {
                                _currentProfileId = profileId;
                                _logger.LogInformation("Perfil automatico: {App} -> {Profile}", _lastProcess, profileId ?? "(nenhum)");
                                await _hub.Clients.All.SendAsync(Event, GetState(), stoppingToken);
                            }
                        }
                    }
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    _logger.LogDebug(ex, "ForegroundWatcher");
                }

                try { await Task.Delay(500, stoppingToken); } catch (OperationCanceledException) { }
            }
        }

        /// <summary>Primeiro perfil cuja lista contem o processo (sem diferenciar maiusculas, com ou sem .exe).</summary>
        public static string? Match(IEnumerable<Models.DeckProfile> profiles, string? process)
        {
            if (string.IsNullOrEmpty(process)) return null;
            var name = Normalize(process);
            return profiles.FirstOrDefault(p => p.AutoSwitchApps?.Any(a => Normalize(a) == name) == true)?.Id;
        }

        private static string Normalize(string app)
        {
            var s = app.Trim();
            if (s.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) s = s[..^4];
            return s.ToLowerInvariant();
        }

        private static string? ProcessName(uint pid)
        {
            try
            {
                using var p = Process.GetProcessById((int)pid);
                return p.ProcessName;
            }
            catch
            {
                return null;
            }
        }

        private static uint ForegroundPid()
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return 0;
            GetWindowThreadProcessId(hwnd, out var pid);
            return pid;
        }

        /// <summary>Apps com janela visivel agora, para o editor sugerir.</summary>
        public static List<Actions.FieldOption> RunningApps()
        {
            var titles = new Dictionary<uint, string>();
            EnumWindows((hwnd, _) =>
            {
                if (!IsWindowVisible(hwnd)) return true;
                var length = GetWindowTextLength(hwnd);
                if (length == 0) return true;
                var sb = new StringBuilder(length + 1);
                GetWindowText(hwnd, sb, sb.Capacity);
                GetWindowThreadProcessId(hwnd, out var pid);
                titles.TryAdd(pid, sb.ToString());
                return true;
            }, IntPtr.Zero);

            var ownPid = (uint)Environment.ProcessId;
            return titles
                .Where(t => t.Key != ownPid)
                .Select(t => (name: ProcessName(t.Key), title: t.Value))
                .Where(t => t.name != null && t.name != "explorer" && t.name != "TextInputHost" && t.name != "ApplicationFrameHost")
                .GroupBy(t => t.name!, StringComparer.OrdinalIgnoreCase)
                .Select(g => new Actions.FieldOption(g.Key, $"{g.Key} — {g.First().title}"))
                .OrderBy(o => o.Value, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

        [DllImport("user32.dll")]
        private static extern int GetWindowTextLength(IntPtr hWnd);
    }
}
