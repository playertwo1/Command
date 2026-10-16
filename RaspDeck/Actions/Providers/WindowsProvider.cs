using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Audio;
using DroidDeck.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using NAudio.CoreAudioApi;
using NAudio.CoreAudioApi.Interfaces;

namespace DroidDeck.Actions.Providers
{
    /// <summary>
    /// Acoes do proprio Windows: trocar o dispositivo de audio padrao, travar, suspender e
    /// desligar a tela. Nenhuma executa codigo arbitrario, entao valem tambem pelo celular.
    ///
    /// O estado (dispositivos padrao atuais) acompanha trocas feitas fora do deck: o
    /// Windows avisa pelo IMMNotificationClient.
    /// </summary>
    public sealed class WindowsProvider : IStatefulActionProvider, IMMNotificationClient, IDisposable
    {
        public const string None = "none";

        private readonly IHubContext<DeckHub> _hub;
        private readonly ILogger<WindowsProvider> _logger;
        private readonly MMDeviceEnumerator? _enumerator;
        private System.Threading.Timer? _debounce;

        public WindowsProvider(IHubContext<DeckHub> hub, ILogger<WindowsProvider> logger)
        {
            _hub = hub;
            _logger = logger;
            try
            {
                _enumerator = new MMDeviceEnumerator();
                _enumerator.RegisterEndpointNotificationCallback(this);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Windows: sem aviso de troca de dispositivo padrao");
            }
        }

        public string Type => "windows";
        public string StateEvent => "ReceiveWindowsState";

        public object GetState() => new
        {
            defaultOutput = DefaultAudioEndpoint.GetDefault(input: false),
            defaultInput = DefaultAudioEndpoint.GetDefault(input: true),
        };

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Windows",
            Icon = "computer",
            Category = "Sistema",
            Stateful = true,
            Fields =
            {
                ActionField.Select("operation", "AÃ§Ã£o",
                    ("setDefaultAudio", "Trocar o dispositivo de Ã¡udio padrÃ£o"),
                    ("lock", "Travar o computador"),
                    ("sleep", "Suspender"),
                    ("displayOff", "Desligar a tela")),
                ActionField.Select("deviceKind", "Tipo",
                    ("output", "SaÃ­da (fone, caixa de som)"),
                    ("input", "Entrada (microfone)"))
                    .When("operation", "setDefaultAudio"),
                ActionField.Dynamic("deviceId", "Dispositivo", "/api/actions/windows/audio-devices?kind={deviceKind}")
                    .When("operation", "setDefaultAudio"),
                new ActionField
                {
                    Key = "altDeviceId",
                    Label = "Alternar com (opcional)",
                    Kind = FieldKind.Select,
                    Default = None,
                    OptionsSource = "/api/actions/windows/audio-devices?kind={deviceKind}&optional=true",
                    Help = "Com um segundo dispositivo, cada toque alterna entre os dois (fone â†” caixa de som).",
                }.When("operation", "setDefaultAudio"),
            },
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            switch (c.Operation("setdefaultaudio"))
            {
                case "lock":
                    LockWorkStation();
                    break;
                case "sleep":
                    // Suspende (nao hiberna). Assincrono: o Windows dorme depois de responder.
                    _ = Task.Run(() => SetSuspendState(false, false, false));
                    break;
                case "displayoff":
                    // SC_MONITORPOWER 2 = desligar. SendMessageTimeout: um app travado no
                    // broadcast nao pode prender o deck.
                    SendMessageTimeout(HwndBroadcast, WmSysCommand, ScMonitorPower, (IntPtr)2, 0x0002, 1000, out _);
                    break;
                default:
                    await SetDefaultAudioAsync(c);
                    break;
            }
        }

        private async Task SetDefaultAudioAsync(ActionContext c)
        {
            var deviceId = c.Get("deviceId");
            if (deviceId.Length == 0)
            {
                _logger.LogWarning("Windows: trocar audio sem dispositivo");
                return;
            }

            var input = c.Get("deviceKind") == "input";
            var alt = c.Get("altDeviceId", None);
            var target = deviceId;
            // Alterna: se o principal ja e o padrao, vai para o outro.
            if (alt != None && alt.Length > 0 && DefaultAudioEndpoint.GetDefault(input) == deviceId)
                target = alt;

            try
            {
                DefaultAudioEndpoint.Set(target);
                _logger.LogInformation("Windows: dispositivo padrao de {Kind} trocado", input ? "entrada" : "saida");
            }
            catch (Exception ex)
            {
                // Id de um dispositivo desconectado cai aqui.
                _logger.LogWarning(ex, "Windows: nao foi possivel trocar o dispositivo padrao");
            }
            await BroadcastAsync();
        }

        /// <summary>Opcoes do campo de dispositivo.</summary>
        public static List<Actions.FieldOption> AudioDevices(bool input, bool optional)
        {
            var list = DefaultAudioEndpoint.List(input)
                .Select(d => new Actions.FieldOption(d.Id, d.Name))
                .ToList();
            if (optional) list.Insert(0, new Actions.FieldOption(None, "Nenhum (sÃ³ define o de cima)"));
            return list;
        }

        private async Task BroadcastAsync()
        {
            try { await _hub.Clients.All.SendAsync(StateEvent, GetState()); } catch { }
        }

        // ---- IMMNotificationClient: troca feita fora do deck (bandeja do Windows, outro app) ----

        public void OnDefaultDeviceChanged(DataFlow flow, Role role, string defaultDeviceId)
        {
            // O Windows avisa uma vez por papel; agrupa num envio so.
            _debounce?.Dispose();
            _debounce = new System.Threading.Timer(_ => _ = BroadcastAsync(), null, 300, Timeout.Infinite);
        }

        public void OnDeviceStateChanged(string deviceId, DeviceState newState) { }
        public void OnDeviceAdded(string pwstrDeviceId) { }
        public void OnDeviceRemoved(string deviceId) { }
        public void OnPropertyValueChanged(string pwstrDeviceId, PropertyKey key) { }

        public void Dispose()
        {
            try { _enumerator?.UnregisterEndpointNotificationCallback(this); } catch { }
            _enumerator?.Dispose();
            _debounce?.Dispose();
        }

        // ---- Win32 ----

        private static readonly IntPtr HwndBroadcast = new(0xffff);
        private const uint WmSysCommand = 0x0112;
        private static readonly IntPtr ScMonitorPower = new(0xF170);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool LockWorkStation();

        [DllImport("powrprof.dll", SetLastError = true)]
        private static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam,
            uint flags, uint timeout, out IntPtr result);
    }
}
