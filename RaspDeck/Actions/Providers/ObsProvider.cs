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
                    ("toggleInputMute", "Mutar fonte de áudio (alternar)"),
                    ("toggleSourceVisibility", "Mostrar / ocultar fonte"),
                    ("toggleFilter", "Ligar / desligar filtro"),
                    ("toggleRecordPause", "Pausar gravação (alternar)"),
                    ("createChapter", "Marcador de capítulo na gravação"),
                    ("screenshot", "Captura de tela da cena")),
                ActionField.Dynamic("scene", "Cena", "/api/obs/scenes")
                    .When("operation", "setScene", "toggleSourceVisibility"),
                ActionField.Dynamic("sourceName", "Fonte", "/api/obs/scene-items?scene={scene}")
                    .When("operation", "toggleSourceVisibility"),
                ActionField.Dynamic("filterSource", "Fonte ou cena do filtro", "/api/obs/sources")
                    .When("operation", "toggleFilter"),
                ActionField.Dynamic("filterName", "Filtro", "/api/obs/filters?source={filterSource}")
                    .When("operation", "toggleFilter"),
                ActionField.Text("chapterName", "Nome do capítulo (opcional)",
                    help: "Exige OBS 30.2 ou mais novo, gravando em MP4 híbrido.")
                    .When("operation", "createChapter"),
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
                case "togglesourcevisibility":
                    if (c.Get("scene").Length > 0 && c.Get("sourceName").Length > 0)
                        await _obs.ToggleSceneItemAsync(c.Get("scene"), c.Get("sourceName"));
                    break;
                case "togglefilter":
                    if (c.Get("filterSource").Length > 0 && c.Get("filterName").Length > 0)
                        await _obs.ToggleFilterAsync(c.Get("filterSource"), c.Get("filterName"));
                    break;
                case "togglerecordpause":
                    await _obs.ToggleRecordPauseAsync();
                    break;
                case "createchapter":
                    await _obs.CreateRecordChapterAsync(c.Get("chapterName"));
                    break;
                case "screenshot":
                    await _obs.ScreenshotAsync();
                    break;
            }
        }
    }
}
