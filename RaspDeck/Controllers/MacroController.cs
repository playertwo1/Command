using System;
using System.Text.Json;
using DroidDeck.Lib.Input;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    /// <summary>
    /// Gravacao de macro pelo teclado do PC. Le tudo o que se digita, entao so responde a
    /// pedidos do proprio PC (o configurador em localhost), nunca do celular.
    /// </summary>
    [Route("api/macro")]
    [ApiController]
    public class MacroController : ControllerBase
    {
        private static readonly JsonSerializerOptions Json = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

        private readonly MacroRecorder _recorder;

        public MacroController(MacroRecorder recorder) => _recorder = recorder;

        private bool Local => ActionPolicy.IsLocal(HttpContext.Connection.RemoteIpAddress);

        private ObjectResult OnlyOnPc() =>
            StatusCode(403, new { error = "Gravar macro só funciona no configurador do PC (http://localhost:4787)." });

        [HttpGet]
        public ActionResult Status()
        {
            if (!Local) return OnlyOnPc();
            return Ok(new
            {
                recording = _recorder.Recording,
                keys = _recorder.Count,
                seconds = _recorder.StartedAt is { } at ? (int)(DateTime.UtcNow - at).TotalSeconds : 0,
                maxSeconds = (int)MacroRecorder.MaxDuration.TotalSeconds,
            });
        }

        [HttpPost("start")]
        public ActionResult Start()
        {
            if (!Local) return OnlyOnPc();
            _recorder.Start();
            return Ok(new { recording = _recorder.Recording });
        }

        /// <summary>Para e devolve os passos no formato da multi-acao (parameters["steps"]).</summary>
        [HttpPost("stop")]
        public ActionResult Stop()
        {
            if (!Local) return OnlyOnPc();
            var steps = MacroRecorder.ToSteps(_recorder.Stop());
            return Ok(new { steps = JsonSerializer.Serialize(steps, Json), count = steps.Count });
        }
    }
}
