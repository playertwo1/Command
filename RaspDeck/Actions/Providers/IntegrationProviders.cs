using System.Threading.Tasks;
using DroidDeck.Services;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Actions.Providers
{
    public class DiscordProvider : IStatefulActionProvider
    {
        private readonly DiscordRpcService _discord;

        public DiscordProvider(DiscordRpcService discord) => _discord = discord;

        public string Type => "discord";
        public string StateEvent => "ReceiveDiscordState";
        public object GetState() => _discord.GetStatePayload();

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Discord",
            Icon = "headset_mic",
            Category = "Streaming",
            Stateful = true,
            Editor = "discord",
            Settings = "discord",
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            switch (c.Operation("togglemute"))
            {
                case "toggledeafen":
                case "toggledeaf":
                    await _discord.SetDeafAsync(null);
                    break;
                case "mute":
                    await _discord.SetMuteAsync(true);
                    break;
                case "unmute":
                    await _discord.SetMuteAsync(false);
                    break;

                // Canal de voz
                case "joinchannel":
                    if (c.Get("channelId").Length > 0)
                        await _discord.SelectVoiceChannelAsync(c.Get("channelId"));
                    break;
                case "leavechannel":
                case "disconnect":
                    await _discord.SelectVoiceChannelAsync(null);
                    break;

                // Volume de mic / saída
                case "inputvolumeup":
                    await _discord.NudgeInputVolumeAsync(c.Number("delta", 10));
                    break;
                case "inputvolumedown":
                    await _discord.NudgeInputVolumeAsync(-c.Number("delta", 10));
                    break;
                case "outputvolumeup":
                    await _discord.NudgeOutputVolumeAsync(c.Number("delta", 10));
                    break;
                case "outputvolumedown":
                    await _discord.NudgeOutputVolumeAsync(-c.Number("delta", 10));
                    break;
                case "setinputvolume":
                    await _discord.SetInputVolumeAsync(c.Number("value", 100));
                    break;
                case "setoutputvolume":
                    await _discord.SetOutputVolumeAsync(c.Number("value", 100));
                    break;

                // Modo de voz
                case "togglevoicemode":
                case "toggleptt":
                    await _discord.ToggleVoiceModeAsync();
                    break;
                case "setvoicemode":
                    await _discord.SetVoiceModeAsync(c.Get("mode", "VOICE_ACTIVITY"));
                    break;

                // Por usuário
                case "usermute":
                case "usermutetoggle":
                    if (c.Get("userId").Length > 0)
                        await _discord.ToggleUserMuteAsync(c.Get("userId"));
                    break;
                case "uservolume":
                    if (c.Get("userId").Length > 0)
                        await _discord.SetUserVoiceAsync(c.Get("userId"), null, c.Number("value", 100));
                    break;

                default: // toggleMute
                    await _discord.SetMuteAsync(null);
                    break;
            }
        }
    }

    public class SoundboardProvider : IActionProvider
    {
        private readonly SoundboardService _soundboard;
        private readonly DiscordRpcService _discord;

        public SoundboardProvider(SoundboardService soundboard, DiscordRpcService discord)
        {
            _soundboard = soundboard;
            _discord = discord;
        }

        public string Type => "soundboard";

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "Soundboard",
            Icon = "campaign",
            Category = "Streaming",
            Editor = "soundboard",
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            if (c.Operation("play") == "stop")
            {
                _soundboard.StopAll();
                return;
            }

            if (c.Get("source", "myinstants").ToLowerInvariant() == "discord")
            {
                // Toca um som da soundboard NATIVA do Discord no canal de voz atual (sem cabo).
                var guildId = c.Get("guildId");
                await _discord.PlaySoundboardSoundAsync(c.Get("soundId"), guildId.Length > 0 ? guildId : null);
                return;
            }

            // MyInstants: toca o mp3 no dispositivo de saída configurado.
            var title = c.Get("title");
            await _soundboard.PlayAsync(c.Get("id"), c.Get("url"), title.Length > 0 ? title : null);
        }
    }

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
