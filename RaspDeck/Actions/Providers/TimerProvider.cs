using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Lib;
using DroidDeck.Models;
using DroidDeck.Services;

namespace DroidDeck.Actions.Providers
{
    /// <summary>
    /// Timer, cronometro, pomodoro e contador num botao. O estado mora no TimerService; o
    /// botao mostra o tempo ao vivo.
    ///
    /// Cada botao e dono do proprio timer (o id e o do botao). Um botao pode agir sobre o
    /// timer de outro (parametro "target"), por exemplo um "zerar" ao lado do relogio: ai o
    /// modo e as duracoes continuam vindo do botao dono.
    /// </summary>
    public class TimerProvider : IStatefulActionProvider
    {
        public const string Self = "self";

        private readonly TimerService _timers;
        private readonly StreamDeckConfigService _config;

        public TimerProvider(TimerService timers, StreamDeckConfigService config)
        {
            _timers = timers;
            _config = config;
        }

        public string Type => "timer";
        public string StateEvent => "ReceiveTimerState";
        public object GetState() => _timers.GetStatePayload();

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Timer, pomodoro e contador",
            Icon = "timer",
            Category = "Utilidades",
            Stateful = true,
            Description = "O botão mostra o tempo ao vivo. Quando uma contagem termina, o PC toca um aviso e o celular vibra.",
            Fields =
            {
                ActionField.Select("mode", "Tipo",
                    ("countdown", "Timer (contagem regressiva)"),
                    ("stopwatch", "Cronômetro"),
                    ("pomodoro", "Pomodoro (foco e pausa)"),
                    ("counter", "Contador")),
                ActionField.Number("durationMin", "Duração", 5, min: 0.1, unit: "min")
                    .When("mode", "countdown"),
                ActionField.Number("workMin", "Foco", 25, min: 1, max: 120, unit: " min")
                    .When("mode", "pomodoro"),
                ActionField.Number("breakMin", "Pausa", 5, min: 1, max: 60, unit: " min")
                    .When("mode", "pomodoro"),
                ActionField.Select("operation", "Ao tocar",
                    ("toggle", "Iniciar / pausar (contador: somar)"),
                    ("reset", "Zerar"),
                    ("skip", "Pular para a próxima fase (pomodoro)"),
                    ("increment", "Somar (contador)"),
                    ("decrement", "Subtrair (contador)")),
                ActionField.Number("step", "Passo", 1, min: 1, max: 100)
                    .When("mode", "counter"),
                new ActionField
                {
                    Key = "target",
                    Label = "Timer controlado",
                    Kind = FieldKind.Select,
                    Default = Self,
                    OptionsSource = "/api/actions/timer/targets",
                    Help = "Para um botão de \"zerar\" separado, escolha o timer de outro botão.",
                },
            },
        };

        public Task ExecuteAsync(ActionContext c)
        {
            var target = c.Get("target", Self);
            var ownerId = target == Self || target.Length == 0 ? c.ButtonId : target;
            if (string.IsNullOrEmpty(ownerId))
                ownerId = "avulso"; // /execute sem botao: um timer compartilhado

            // Configuracao vem do dono; o passo do contador, de quem apertou.
            var owner = ownerId == c.ButtonId ? c.Parameters : FindButtonAction(ownerId)?.Parameters ?? c.Parameters;
            var p = ToServiceParams(owner);
            if (c.Get("step").Length > 0) p["step"] = c.Get("step");

            _timers.Apply(ownerId, c.Operation("toggle"), p);
            return Task.CompletedTask;
        }

        /// <summary>Minutos do editor para os segundos que o TimerService usa.</summary>
        private static Dictionary<string, string> ToServiceParams(IDictionary<string, string> source)
        {
            var p = new Dictionary<string, string>(source);
            foreach (var (from, to) in new[] { ("durationMin", "durationSec"), ("workMin", "workSec"), ("breakMin", "breakSec") })
            {
                if (source.TryGetValue(from, out var v) &&
                    double.TryParse(v, NumberStyles.Float, CultureInfo.InvariantCulture, out var min) && min > 0)
                    p[to] = (min * 60).ToString(CultureInfo.InvariantCulture);
            }
            return p;
        }

        private DeckAction? FindButtonAction(string buttonId) =>
            _config.GetProfiles()
                .SelectMany(pr => pr.Buttons ?? new List<DeckButton>())
                .FirstOrDefault(b => b.Id == buttonId)?.Action;

        /// <summary>Opcoes do campo "target": este botao ou qualquer botao-timer salvo.</summary>
        public List<FieldOption> Targets()
        {
            var options = new List<FieldOption> { new(Self, L.T("Este botão")) };
            foreach (var profile in _config.GetProfiles())
            {
                foreach (var b in profile.Buttons ?? new List<DeckButton>())
                {
                    if (b.Action?.Type != Type) continue;
                    if (b.Action.Parameters.TryGetValue("target", out var t) && t != Self && t.Length > 0) continue;
                    var mode = b.Action.Parameters.TryGetValue("mode", out var m) ? m : "countdown";
                    var name = string.IsNullOrWhiteSpace(b.Label) ? ModeName(mode) : b.Label;
                    options.Add(new FieldOption(b.Id, $"{profile.Name} › {name}"));
                }
            }
            return options;
        }

        private static string ModeName(string mode) => mode switch
        {
            "stopwatch" => "Cronômetro",
            "pomodoro" => "Pomodoro",
            "counter" => "Contador",
            _ => "Timer",
        };
    }
}
