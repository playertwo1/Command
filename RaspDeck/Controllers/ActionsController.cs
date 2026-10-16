using System.Collections.Generic;
using DroidDeck.Actions;
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
        public ActionResult<List<ActionSchema>> Schema() => Ok(_executor.DescribeAll());

        /// <summary>Estado atual de um provedor (o mesmo que vai pelo SignalR).</summary>
        [HttpGet("state/{type}")]
        public IActionResult State(string type) =>
            _executor.Find(type) is IStatefulActionProvider p ? Ok(p.GetState()) : NotFound();
    }
}
