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
}
