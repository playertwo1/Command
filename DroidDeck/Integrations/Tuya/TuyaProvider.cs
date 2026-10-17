using System.Threading.Tasks;
using DroidDeck.Services;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Actions.Providers
{
    /// <summary>
    /// Casa inteligente Tuya/Smart Life (cobre os rebrands: Nova Digital, Positivo, RSmart...).
    ///
    /// "toggle" e o caso comum de um deck e depende do estado que o push MQTT mantem em
    /// memoria -- por isso ele nao faz leitura na nuvem antes (o que gastaria cota a cada
    /// clique). Se o push estiver fora do ar o estado pode estar velho; nesse caso o usuario
    /// ve o botao inverter "para o lado errado" uma vez e acerta no clique seguinte.
    /// Para um comando deterministico use "set" com o valor explicito.
    /// </summary>
    public class TuyaProvider : IStatefulActionProvider
    {
        private readonly TuyaService _tuya;
        private readonly ILogger<TuyaProvider> _logger;

        public TuyaProvider(TuyaService tuya, ILogger<TuyaProvider> logger)
        {
            _tuya = tuya;
            _logger = logger;
        }

        public string Type => "tuya";

        // Sem isto, quem conecta depois do backend só receberia algo quando algum aparelho
        // mudasse — os botões abririam sem cor.
        public string StateEvent => "ReceiveTuyaState";
        public object GetState() => _tuya.GetStatePayload();

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Casa inteligente (Tuya)",
            Icon = "lightbulb",
            Category = "Casa",
            Stateful = true,
            Editor = "tuya",
            Settings = "tuya",
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            var deviceId = c.Get("deviceId");
            var code = c.Get("code");
            if (deviceId.Length == 0 || code.Length == 0)
            {
                _logger.LogWarning("Tuya: acao sem deviceId/code");
                return;
            }

            switch (c.Operation("toggle"))
            {
                case "toggle":
                    await _tuya.ToggleAsync(deviceId, code);
                    break;
                case "set":
                    await _tuya.SendCommandAsync(deviceId, code, ParseValue(c.Get("value"), c.Get("valueType")));
                    break;
                default:
                    _logger.LogWarning("Tuya: operacao desconhecida {Op}", c.Get("operation"));
                    break;
            }
        }

        /// <summary>
        /// Os parametros de acao sao string (Dictionary&lt;string,string&gt;), mas a Tuya exige o
        /// tipo certo: mandar "true" onde ela espera booleano faz a API recusar. O valueType vem
        /// do specifications do proprio aparelho, gravado no botao pelo editor.
        /// </summary>
        private static object? ParseValue(string raw, string valueType)
        {
            switch ((valueType ?? "").Trim().ToLowerInvariant())
            {
                case "boolean":
                    return bool.TryParse(raw, out var b) && b;
                case "integer":
                    return long.TryParse(raw, out var l) ? l : 0L;
                default:
                    // Enum, String e Json seguem como texto -- e o que a Tuya espera nesses casos.
                    return raw;
            }
        }
    }
}
