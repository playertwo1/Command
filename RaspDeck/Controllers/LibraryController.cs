using System.IO;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Hubs;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Controllers
{
    /// <summary>Jogos da Steam, apps abertos (troca de perfil) e backup dos perfis.</summary>
    [ApiController]
    public class LibraryController : ControllerBase
    {
        private readonly SteamLibrary _steam;
        private readonly BackupService _backup;
        private readonly StreamDeckConfigService _config;
        private readonly IHubContext<DeckHub> _hub;
        private readonly ILogger<LibraryController> _logger;

        public LibraryController(SteamLibrary steam, BackupService backup, StreamDeckConfigService config,
            IHubContext<DeckHub> hub, ILogger<LibraryController> logger)
        {
            _steam = steam;
            _backup = backup;
            _config = config;
            _hub = hub;
            _logger = logger;
        }

        // ---- Steam ----

        [HttpGet("api/steam/games")]
        public IActionResult Games() =>
            Ok(_steam.Games().Select(g => new { value = g.AppId, label = g.Name }));

        [HttpGet("api/steam/icon/{appId}")]
        public IActionResult Icon(string appId) =>
            _steam.IconBase64(appId) is { } icon ? Ok(new { iconBase64 = icon }) : NotFound();

        // ---- Apps abertos (troca automatica de perfil) ----

        [HttpGet("api/system/apps")]
        public IActionResult Apps() => Ok(ForegroundWatcher.RunningApps());

        /// <summary>Nome do PC e versao: o celular usa para identificar cada PC pareado.</summary>
        [HttpGet("api/system/info")]
        public IActionResult Info() => Ok(new
        {
            name = System.Environment.MachineName,
            version = typeof(LibraryController).Assembly.GetName().Version?.ToString(3),
        });

        // ---- Backup ----

        [HttpGet("api/backup")]
        public IActionResult Export()
        {
            var name = $"DroidDeck-{System.DateTime.Now:yyyy-MM-dd}.droiddeck";
            return File(_backup.Export(), "application/zip", name);
        }

        /// <summary>
        /// Restaura um .droiddeck (corpo da requisicao = o arquivo). De fora do PC, recusa se o
        /// backup criaria ou mudaria botoes que executam codigo (mesma regra do POST profiles).
        /// </summary>
        [HttpPost("api/backup")]
        [RequestSizeLimit(BackupService.MaxSize)]
        public async Task<IActionResult> Import()
        {
            using var ms = new MemoryStream();
            await Request.Body.CopyToAsync(ms);
            ms.Position = 0;

            System.Collections.Generic.List<Models.DeckProfile> profiles;
            try { profiles = BackupService.Read(ms); }
            catch (InvalidDataException ex) { return BadRequest(new { error = ex.Message }); }

            if (!ActionPolicy.IsLocal(HttpContext.Connection.RemoteIpAddress))
            {
                foreach (var p in profiles)
                {
                    var violation = ActionPolicy.FindRemoteViolation(p, _config.GetProfile(p.Id));
                    if (violation != null)
                        return StatusCode(StatusCodes.Status403Forbidden, new
                        {
                            error = "O backup tem botões que abrem programas, enviam atalhos ou fazem requisições. " +
                                    "Importe pelo configurador no PC (http://localhost:4787)."
                        });
                }
            }

            var count = _backup.Import(profiles);
            _logger.LogInformation("Backup importado: {Count} perfis", count);
            await _hub.Clients.All.SendAsync("ReceiveDeckUpdate", new { profileId = (string?)null });
            return Ok(new { imported = count });
        }
    }
}
