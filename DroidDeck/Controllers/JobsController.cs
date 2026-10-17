using System.Collections.Generic;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Route("api/v1/[controller]")]
    public class JobsController : ControllerBase
    {
        private readonly IJobHistoryService _jobHistory;

        public JobsController(IJobHistoryService jobHistory)
        {
            _jobHistory = jobHistory;
        }

        /// <summary>
        /// Lista o histórico recente de execuções de ações e comandos.
        /// </summary>
        [HttpGet]
        public ActionResult<IReadOnlyList<CommandJob>> GetJobs([FromQuery] string? deviceId, [FromQuery] int limit = 50)
        {
            return Ok(_jobHistory.GetJobs(deviceId, limit));
        }

        /// <summary>
        /// Obtém o estado detalhado de um job específico por ID ou RequestId.
        /// </summary>
        [HttpGet("{id}")]
        public ActionResult<CommandJob> GetJob(string id)
        {
            var job = _jobHistory.GetJob(id);
            if (job == null) return NotFound(new { error = $"Job com ID '{id}' não encontrado." });
            return Ok(job);
        }

        /// <summary>
        /// Limpa o histórico de execuções (opcionalmente filtrado por dispositivo).
        /// </summary>
        [HttpDelete]
        public ActionResult ClearJobs([FromQuery] string? deviceId)
        {
            _jobHistory.ClearHistory(deviceId);
            return NoContent();
        }
    }
}
