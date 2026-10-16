using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using DroidDeck.Actions;
using DroidDeck.Lib;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    /// <summary>Catalogo dos tipos de acao, usado pelo editor do app para montar o formulario.</summary>
    [Route("api/[controller]")]
    [ApiController]
    public class ActionsController : ControllerBase
    {
        private readonly ActionExecutorService _executor;

        public ActionsController(ActionExecutorService executor) => _executor = executor;

        [HttpGet("schema")]
        public ActionResult<List<ActionSchema>> Schema()
        {
            var schemas = _executor.DescribeAll();
            return Ok(L.English ? schemas.Select(Translated).ToList() : schemas);
        }

        /// <summary>
        /// Copia do schema com os textos em ingles. Copia (pelo JSON, para nao esquecer campo
        /// novo) porque os provedores podem devolver objetos guardados.
        /// </summary>
        private static ActionSchema Translated(ActionSchema source)
        {
            var s = JsonSerializer.Deserialize<ActionSchema>(JsonSerializer.Serialize(source))!;
            s.Title = L.T(s.Title);
            s.Category = L.T(s.Category);
            s.Description = L.TOrNull(s.Description);
            foreach (var f in s.Fields)
            {
                f.Label = L.T(f.Label);
                f.Help = L.TOrNull(f.Help);
                f.Hint = L.TOrNull(f.Hint);
                f.Unit = L.TOrNull(f.Unit);
                foreach (var o in f.Options ?? new List<FieldOption>())
                    o.Label = L.T(o.Label);
            }
            return s;
        }

        /// <summary>Estado atual de um provedor (o mesmo que vai pelo SignalR).</summary>
        [HttpGet("state/{type}")]
        public IActionResult State(string type) =>
            _executor.Find(type) is IStatefulActionProvider p ? Ok(p.GetState()) : NotFound();

        /// <summary>Timers que um botao pode controlar (campo "target" da acao timer).</summary>
        [HttpGet("timer/targets")]
        public IActionResult TimerTargets() =>
            _executor.Find("timer") is Actions.Providers.TimerProvider t ? Ok(t.Targets()) : NotFound();

        /// <summary>Dispositivos de audio ativos (acao windows/setDefaultAudio).</summary>
        [HttpGet("windows/audio-devices")]
        public IActionResult AudioDevices([FromQuery] string? kind, [FromQuery] bool optional = false) =>
            Ok(Actions.Providers.WindowsProvider.AudioDevices(kind == "input", optional));
    }
}
