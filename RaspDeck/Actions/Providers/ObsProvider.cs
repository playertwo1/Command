using System.Threading.Tasks;
using DroidDeck.Services;

namespace DroidDeck.Actions.Providers
{
    public class ObsProvider : IStatefulActionProvider
    {
        private readonly ObsService _obs;

        public ObsProvider(ObsService obs) => _obs = obs;

        public string Type => "obs";
        public string StateEvent => "ReceiveObsState";
        public object GetState() => _obs.GetStatePayload();

        public ActionSchema Describe() => new()
        {
            Type = Type,
            Title = "OBS Studio",
            Icon = "videocam",
            Category = "Streaming",
            Stateful = true,
            Settings = "obs",
            Fields =
            {
                ActionField.Select("operation", "Ação do OBS",
                    ("setScene", "Trocar de cena"),
                    ("toggleRecord", "Gravar (alternar)"),
                    ("toggleStream", "Transmitir / Live (alternar)"),
                    ("toggleVirtualCam", "Câmera virtual (alternar)"),
                    ("toggleReplayBuffer", "Replay buffer (alternar)"),
                    ("saveReplay", "Salvar replay"),
                    ("toggleInputMute", "Mutar fonte de áudio (alternar)")),
                ActionField.Dynamic("scene", "Cena", "/api/obs/scenes")
                    .When("operation", "setScene"),
                ActionField.Dynamic("inputName", "Fonte de áudio", "/api/obs/audio-inputs")
                    .When("operation", "toggleInputMute"),
            },
        };

        public async Task ExecuteAsync(ActionContext c)
        {
            switch (c.Operation(""))
            {
                case "setscene":
                    if (c.Get("scene").Length > 0) await _obs.SetSceneAsync(c.Get("scene"));
                    break;
                case "togglerecord":
                    await _obs.ToggleRecordAsync();
                    break;
                case "startrecord":
                    await _obs.StartRecordAsync();
                    break;
                case "stoprecord":
                    await _obs.StopRecordAsync();
                    break;
                case "togglestream":
                    await _obs.ToggleStreamAsync();
                    break;
                case "togglevirtualcam":
                    await _obs.ToggleVirtualCamAsync();
                    break;
                case "togglereplaybuffer":
                    await _obs.ToggleReplayBufferAsync();
                    break;
                case "savereplay":
                    await _obs.SaveReplayAsync();
                    break;
                case "toggleinputmute":
                    if (c.Get("inputName").Length > 0) await _obs.ToggleInputMuteAsync(c.Get("inputName"));
                    break;
            }
        }
    }
}
